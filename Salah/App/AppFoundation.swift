import CoreLocation
import Foundation
import Observation
import SwiftData

enum AppTab: Hashable {
    case today, calendar, tracker, qibla, more
}

@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .today
    var selectedDay: LocalDay

    init(timeZone: TimeZone = PrayerLocation.dhaka.timeZone) {
        selectedDay = LocalDay(.now, timeZone: timeZone)
    }

    func showToday(timeZone: TimeZone) {
        selectedDay = LocalDay(.now, timeZone: timeZone)
        selectedTab = .today
    }

    func show(_ day: LocalDay) {
        selectedDay = day
        selectedTab = .today
    }
}

private struct StoredSettings: Codable {
    var onboardingComplete = false
    var locationEducationSeen = false
    var location = PrayerLocation.dhaka
    var calculation = CalculationSettings()
    var appearance = AppearancePreference.system
    var theme: ThemePreference?
    var reminders: [String: ReminderPreference] = [:]
}

@MainActor
@Observable
final class AppSettings {
    private let defaults: UserDefaults
    private let key = "salah.settings.v2"

    var onboardingComplete: Bool { didSet { save() } }
    var locationEducationSeen: Bool { didSet { save() } }
    var location: PrayerLocation { didSet { save() } }
    var calculation: CalculationSettings { didSet { save() } }
    var appearance: AppearancePreference { didSet { save() } }
    var theme: ThemePreference { didSet { save() } }
    private var storedReminders: [String: ReminderPreference] { didSet { save() } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ui-testing"), (arguments.contains("-reset-state") || arguments.contains("-reset-onboarding")) {
            defaults.removeObject(forKey: key)
        }
        let stored: StoredSettings
        if let data = defaults.data(forKey: key), let decoded = try? JSONDecoder().decode(StoredSettings.self, from: data) {
            stored = decoded
        } else {
            stored = StoredSettings()
        }
        var initialLocation = stored.location
        if initialLocation.source == .automatic,
           initialLocation.name.localizedCaseInsensitiveContains("current location"),
           let nearestDistrict = DistrictLoader.nearest(
               to: CLLocationCoordinate2D(latitude: initialLocation.latitude, longitude: initialLocation.longitude)
           ) {
            initialLocation.name = "\(nearestDistrict.name), Bangladesh"
        }

        onboardingComplete = arguments.contains("-ui-testing") && arguments.contains("-onboarding-complete") ? true : stored.onboardingComplete
        locationEducationSeen = stored.locationEducationSeen
        location = initialLocation
        calculation = stored.calculation
        appearance = stored.appearance
        theme = stored.theme ?? .greyishBlue
        storedReminders = stored.reminders
        if initialLocation != stored.location { save() }
    }

    var reminders: [PrayerEvent: ReminderPreference] {
        Dictionary(uniqueKeysWithValues: PrayerEvent.allCases.map { ($0, reminder(for: $0)) })
    }

    func reminder(for event: PrayerEvent) -> ReminderPreference {
        storedReminders[event.rawValue] ?? ReminderPreference()
    }

    func setReminder(_ preference: ReminderPreference, for event: PrayerEvent) {
        storedReminders[event.rawValue] = preference
    }

    private func save() {
        let value = StoredSettings(
            onboardingComplete: onboardingComplete,
            locationEducationSeen: locationEducationSeen,
            location: location,
            calculation: calculation,
            appearance: appearance,
            theme: theme,
            reminders: storedReminders
        )
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }
}

@MainActor
final class InMemoryPrayerTrackingRepository: PrayerTrackingRepository {
    private var values: [String: PrayerRecordSnapshot] = [:]

    func records(on day: LocalDay) throws -> [PrayerRecordSnapshot] {
        values.values.filter { $0.localDay == day }.sorted { $0.prayer.rawValue < $1.prayer.rawValue }
    }

    func completedPrayerTypes(on day: LocalDay) throws -> Set<PrayerType> {
        Set(try records(on: day).filter(\.completed).map(\.prayer))
    }

    func setCompleted(_ completed: Bool, prayer: PrayerType, day: LocalDay, timeZone: TimeZone, source: String) throws {
        let key = "\(day.key)|\(prayer.rawValue)"
        let existingID = values[key]?.id ?? UUID()
        values[key] = PrayerRecordSnapshot(
            id: existingID,
            prayer: prayer,
            localDay: day,
            completed: completed,
            completedAt: completed ? .now : nil,
            source: source,
            notes: values[key]?.notes
        )
    }

    func allRecords() throws -> [PrayerRecordSnapshot] {
        values.values.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    func clearAll() throws { values.removeAll() }
}

protocol TrackerSyncCoordinating: Sendable {
    var isAvailable: Bool { get }
}

struct LocalOnlySyncCoordinator: TrackerSyncCoordinating {
    let isAvailable = false
}

@MainActor
@Observable
final class AppContainer {
    let settings: AppSettings
    let router: AppRouter
    let prayerTimesRepository: any PrayerTimesRepository
    let locationProvider: any LocationProviding
    let notificationScheduler: any NotificationScheduling
    let trackingRepository: any PrayerTrackingRepository
    let syncCoordinator: any TrackerSyncCoordinating
    let modelContainer: ModelContainer?
    let districts: [District]

    init(
        settings: AppSettings? = nil,
        prayerTimesRepository: (any PrayerTimesRepository)? = nil,
        locationProvider: (any LocationProviding)? = nil,
        notificationScheduler: (any NotificationScheduling)? = nil,
        trackingRepository: (any PrayerTrackingRepository)? = nil
    ) {
        let arguments = ProcessInfo.processInfo.arguments
        let isUITesting = arguments.contains("-ui-testing")
        let settingsValue = settings ?? AppSettings()
        self.settings = settingsValue
        router = AppRouter(timeZone: settingsValue.location.timeZone)
        #if DEBUG
        self.locationProvider = locationProvider ?? (isUITesting
            ? UITestLocationProvider(denied: arguments.contains("-location-denied"))
            : CoreLocationProvider())
        self.notificationScheduler = notificationScheduler ?? (isUITesting
            ? UITestNotificationScheduler(denied: arguments.contains("-notification-denied"))
            : LocalNotificationScheduler())
        #else
        self.locationProvider = locationProvider ?? CoreLocationProvider()
        self.notificationScheduler = notificationScheduler ?? LocalNotificationScheduler()
        #endif
        syncCoordinator = LocalOnlySyncCoordinator()
        districts = DistrictLoader.load()

        #if DEBUG
        if let prayerTimesRepository {
            self.prayerTimesRepository = prayerTimesRepository
        } else if isUITesting {
            self.prayerTimesRepository = UITestPrayerTimesRepository(
                offline: arguments.contains("-offline"),
                slowLoading: arguments.contains("-slow-loading")
            )
        } else {
            self.prayerTimesRepository = DefaultPrayerTimesRepository(
                calculator: AdhanPrayerTimesCalculator(),
                cache: PrayerTimesCache()
            )
        }
        #else
        if let prayerTimesRepository {
            self.prayerTimesRepository = prayerTimesRepository
        } else {
            self.prayerTimesRepository = DefaultPrayerTimesRepository(
                calculator: AdhanPrayerTimesCalculator(),
                cache: PrayerTimesCache()
            )
        }
        #endif

        if let trackingRepository {
            self.trackingRepository = trackingRepository
            modelContainer = nil
        } else if let container = try? ModelContainer(for: PrayerRecord.self) {
            modelContainer = container
            self.trackingRepository = SwiftDataPrayerTrackingRepository(container: container)
        } else {
            modelContainer = nil
            self.trackingRepository = InMemoryPrayerTrackingRepository()
        }
        if isUITesting, arguments.contains("-reset-tracker") {
            try? self.trackingRepository.clearAll()
        }
    }
}
