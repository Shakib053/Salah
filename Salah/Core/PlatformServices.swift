@preconcurrency import CoreLocation
import Foundation
import Network
import Observation
import UserNotifications

enum LocationAuthorization: String, Sendable {
    case notDetermined, authorized, denied, restricted
}

enum LocationServiceError: LocalizedError {
    case denied, restricted, unavailable, failed(String)

    var errorDescription: String? {
        switch self {
        case .denied: "Location access is denied. Choose a district manually or enable access in Settings."
        case .restricted: "Location access is restricted on this device. Choose a district manually."
        case .unavailable: "Your current location is unavailable."
        case .failed: "The location request failed."
        }
    }
}

@MainActor
protocol LocationProviding: AnyObject {
    var authorization: LocationAuthorization { get }
    func requestCurrentLocation() async throws -> PrayerLocation
}

@MainActor
@Observable
final class CoreLocationProvider: NSObject, LocationProviding, @preconcurrency CLLocationManagerDelegate {
    private let manager: CLLocationManager
    private var authorizationContinuation: CheckedContinuation<Void, Never>?
    private var locationContinuation: CheckedContinuation<PrayerLocation, Error>?

    private(set) var authorization: LocationAuthorization

    override init() {
        manager = CLLocationManager()
        authorization = Self.map(manager.authorizationStatus)
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestCurrentLocation() async throws -> PrayerLocation {
        switch authorization {
        case .notDetermined:
            await withCheckedContinuation { continuation in
                authorizationContinuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        case .denied: throw LocationServiceError.denied
        case .restricted: throw LocationServiceError.restricted
        case .authorized: break
        }

        switch authorization {
        case .denied: throw LocationServiceError.denied
        case .restricted: throw LocationServiceError.restricted
        case .notDetermined: throw LocationServiceError.unavailable
        case .authorized:
            return try await withCheckedThrowingContinuation { continuation in
                locationContinuation = continuation
                manager.requestLocation()
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = Self.map(manager.authorizationStatus)
        authorizationContinuation?.resume()
        authorizationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let value = locations.last else {
            locationContinuation?.resume(throwing: LocationServiceError.unavailable)
            locationContinuation = nil
            return
        }
        let continuation = locationContinuation
        locationContinuation = nil
        Task {
            let placemark = try? await CLGeocoder().reverseGeocodeLocation(value).first
            continuation?.resume(returning: PrayerLocation(
                name: placemark?.locality.map { "\($0), Current Location" } ?? "Current Location",
                latitude: value.coordinate.latitude,
                longitude: value.coordinate.longitude,
                timeZoneIdentifier: placemark?.timeZone?.identifier ?? TimeZone.current.identifier,
                source: .automatic
            ))
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: LocationServiceError.failed(error.localizedDescription))
        locationContinuation = nil
    }

    private static func map(_ status: CLAuthorizationStatus) -> LocationAuthorization {
        switch status {
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        case .denied: .denied
        case .authorizedAlways, .authorizedWhenInUse: .authorized
        @unknown default: .restricted
        }
    }
}

struct District: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let banglaName: String
    let latitude: Double
    let longitude: Double

    enum CodingKeys: String, CodingKey {
        case id, name
        case banglaName = "bn_name"
        case latitude = "lat"
        case longitude = "lon"
    }

    init(id: String, name: String, banglaName: String, latitude: Double, longitude: Double) {
        self.id = id
        self.name = name
        self.banglaName = banglaName
        self.latitude = latitude
        self.longitude = longitude
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        banglaName = try container.decode(String.self, forKey: .banglaName)
        let latitudeString = try container.decode(String.self, forKey: .latitude)
        let longitudeString = try container.decode(String.self, forKey: .longitude)
        guard let latitude = Double(latitudeString), let longitude = Double(longitudeString) else {
            throw PrayerDataError.invalidData("Invalid district coordinate")
        }
        self.latitude = latitude
        self.longitude = longitude
    }

    var prayerLocation: PrayerLocation {
        PrayerLocation(
            name: "\(name), Bangladesh",
            latitude: latitude,
            longitude: longitude,
            timeZoneIdentifier: "Asia/Dhaka",
            source: .district
        )
    }
}

private struct DistrictEnvelope: Codable {
    let districts: [District]
}

enum DistrictLoader {
    static func load(bundle: Bundle = .main) -> [District] {
        guard let url = bundle.url(forResource: "districts", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let envelope = try? JSONDecoder().decode(DistrictEnvelope.self, from: data) else {
            return [District(id: "fallback-dhaka", name: "Dhaka", banglaName: "ঢাকা", latitude: 23.7115253, longitude: 90.4111451)]
        }
        return envelope.districts.sorted {
            if $0.name == "Dhaka" { return true }
            if $1.name == "Dhaka" { return false }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
}

enum NotificationAuthorization: String, Sendable {
    case notDetermined, authorized, denied
}

struct ReminderPreference: Codable, Equatable, Sendable {
    var enabled: Bool = false
    var offsetMinutes: Int = 0
}

@MainActor
protocol NotificationScheduling: AnyObject {
    func authorizationStatus() async -> NotificationAuthorization
    func requestAuthorization() async -> NotificationAuthorization
    func reconcile(days: [PrayerDay], preferences: [PrayerEvent: ReminderPreference]) async
    func cancel(event: PrayerEvent) async
}

enum ReminderIdentifier {
    static func make(event: PrayerEvent, day: LocalDay) -> String {
        "salah.reminder.\(event.rawValue).\(day.key)"
    }
}

struct ReminderCandidate: Equatable, Sendable {
    let triggerDate: Date
    let event: PrayerEvent
    let day: LocalDay
    let timeZone: TimeZone

    var identifier: String { ReminderIdentifier.make(event: event, day: day) }
}

enum ReminderPlan {
    static func make(
        days: [PrayerDay],
        preferences: [PrayerEvent: ReminderPreference],
        now: Date,
        limit: Int = 60
    ) -> [ReminderCandidate] {
        guard limit > 0 else { return [] }
        var candidatesByDay: [LocalDay: [ReminderCandidate]] = [:]
        var identifiers: Set<String> = []
        for day in days.sorted(by: { $0.localDay < $1.localDay }) {
            for event in PrayerEvent.allCases {
                guard let preference = preferences[event], preference.enabled,
                      let eventDate = day.eventDate(event) else { continue }
                let triggerDate = eventDate.addingTimeInterval(TimeInterval(-preference.offsetMinutes * 60))
                let candidate = ReminderCandidate(triggerDate: triggerDate, event: event, day: day.localDay, timeZone: day.timeZone)
                guard triggerDate > now, identifiers.insert(candidate.identifier).inserted else { continue }
                candidatesByDay[candidate.day, default: []].append(candidate)
            }
        }
        var result: [ReminderCandidate] = []
        for day in candidatesByDay.keys.sorted() {
            let group = (candidatesByDay[day] ?? []).sorted { $0.triggerDate < $1.triggerDate }
            guard result.count + group.count <= limit else { break }
            result.append(contentsOf: group)
        }
        return result
    }
}

@MainActor
final class LocalNotificationScheduler: NotificationScheduling {
    private let center: UNUserNotificationCenter
    private let prefix = "salah.reminder."

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> NotificationAuthorization {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .authorized
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }

    func requestAuthorization() async -> NotificationAuthorization {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return await authorizationStatus()
        } catch {
            return .denied
        }
    }

    func reconcile(days: [PrayerDay], preferences: [PrayerEvent: ReminderPreference]) async {
        let pending = await center.pendingNotificationRequests()
        let owned = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: owned)

        for candidate in ReminderPlan.make(days: days, preferences: preferences, now: .now) {
            let content = UNMutableNotificationContent()
            content.title = candidate.event.title
            content.body = candidate.event == .sahri ? "Sahri time is approaching." : candidate.event == .iftar ? "Iftar time is approaching." : "It is time for \(candidate.event.title)."
            content.sound = .default
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = candidate.timeZone
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: candidate.triggerDate)
            components.timeZone = candidate.timeZone
            let request = UNNotificationRequest(
                identifier: candidate.identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            try? await center.add(request)
        }
    }

    func cancel(event: PrayerEvent) async {
        let pending = await center.pendingNotificationRequests()
        let eventPrefix = "\(prefix)\(event.rawValue)."
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(eventPrefix) })
    }
}

@MainActor
@Observable
final class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "org.salah.network-monitor")
    private(set) var isConnected = true

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in self?.isConnected = path.status == .satisfied }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}
