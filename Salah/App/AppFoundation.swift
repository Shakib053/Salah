import CoreLocation
import Foundation
import Observation
import SwiftData

enum AppTab: Hashable, CaseIterable, Identifiable {
    case today, calendar, tracker, qibla, more

    var id: Self { self }

    var title: String {
        switch self {
        case .today: String(localized: "Today")
        case .calendar: String(localized: "Calendar")
        case .tracker: String(localized: "Tracker")
        case .qibla: String(localized: "Qibla")
        case .more: String(localized: "More")
        }
    }

    var systemImage: String {
        switch self {
        case .today: "house.fill"
        case .calendar: "calendar"
        case .tracker: "checklist"
        case .qibla: "location.north.circle.fill"
        case .more: "ellipsis.circle.fill"
        }
    }
}

struct CalendarPrayerTarget: Identifiable, Equatable {
    let id = UUID()
    var day: LocalDay
    var prayer: PrayerType
}

@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .today
    var selectedDay: LocalDay
    var calendarPrayerTarget: CalendarPrayerTarget?

    init(timeZone: TimeZone = PrayerLocation.dhaka.timeZone) {
        selectedDay = LocalDay(.now, timeZone: timeZone)
    }

    func showToday(timeZone: TimeZone) {
        selectedDay = LocalDay(.now, timeZone: timeZone)
        selectedTab = .today
    }

    /// Sets selectedDay to the current local day if it differs.
    func syncSelectedDayToNow(timeZone: TimeZone) {
        let today = LocalDay(.now, timeZone: timeZone)
        if selectedDay != today { selectedDay = today }
    }

    func showPrayerInCalendar(day: LocalDay, prayer: PrayerType) {
        calendarPrayerTarget = CalendarPrayerTarget(day: day, prayer: prayer)
        selectedTab = .calendar
    }
}

private struct StoredSettings: Codable {
    var onboardingComplete = false
    var locationEducationSeen = false
    var location = PrayerLocation.dhaka
    var calculation = CalculationSettings()
    var appearance = AppearancePreference.system
    var theme: ThemePreference?
    var customThemeColor: CustomThemeColor?
    var reminders: [String: ReminderPreference] = [:]
    var charityReminder: CharityReminderPreference?
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
    var customThemeColor: CustomThemeColor { didSet { save() } }
    private var storedReminders: [String: ReminderPreference] { didSet { save() } }
    var charityReminder: CharityReminderPreference { didSet { save() } }

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
        customThemeColor = stored.customThemeColor ?? .oceanBlue
        storedReminders = stored.reminders
        charityReminder = stored.charityReminder ?? CharityReminderPreference()
        if initialLocation != stored.location { save() }
    }

    var palette: SalahPalette {
        theme.palette(customColor: customThemeColor)
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
            customThemeColor: customThemeColor,
            reminders: storedReminders,
            charityReminder: charityReminder
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
            ? UITestNotificationScheduler(status: arguments.contains("-notification-denied")
                ? .denied
                : arguments.contains("-notification-authorized")
                    ? .authorized
                    : .notDetermined)
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
            UserDefaults.standard.set(0, forKey: "salah.deeds.istighfar-count")
            UserDefaults.standard.set(0, forKey: "salah.deeds.tasbih-goal")
            UserDefaults.standard.removeObject(forKey: "salah.deeds.tasbih-day")
            UserDefaults.standard.removeObject(forKey: TasbihHistoryLedger.storageKey)
            UserDefaults.standard.set(0, forKey: "salah.deeds.good-deeds-mask")
            UserDefaults.standard.removeObject(forKey: "salah.deeds.good-deeds-day")
            UserDefaults.standard.removeObject(forKey: NaflHistoryLedger.storageKey)
            UserDefaults.standard.set(0, forKey: "salah.deeds.charity-total")
            UserDefaults.standard.removeObject(forKey: CharityLedger.storageKey)
        }
    }
}
