import Foundation

enum PrayerType: String, CaseIterable, Codable, Identifiable, Sendable {
    case fajr, dhuhr, asr, maghrib, isha

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fajr: String(localized: "Fajr")
        case .dhuhr: String(localized: "Dhuhr")
        case .asr: String(localized: "Asr")
        case .maghrib: String(localized: "Maghrib")
        case .isha: String(localized: "Isha")
        }
    }

    var symbol: String {
        switch self {
        case .fajr: "moon.stars.fill"
        case .dhuhr: "sun.max.fill"
        case .asr: "sun.min.fill"
        case .maghrib: "sun.horizon.fill"
        case .isha: "moon.fill"
        }
    }
}

enum PrayerEvent: String, CaseIterable, Codable, Identifiable, Sendable {
    case fajr, dhuhr, asr, maghrib, isha, sahri, iftar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fajr: String(localized: "Fajr")
        case .dhuhr: String(localized: "Dhuhr")
        case .asr: String(localized: "Asr")
        case .maghrib: String(localized: "Maghrib")
        case .isha: String(localized: "Isha")
        case .sahri: String(localized: "Sahri")
        case .iftar: String(localized: "Iftar")
        }
    }

    var symbol: String {
        switch self {
        case .fajr, .sahri: "moon.stars.fill"
        case .dhuhr: "sun.max.fill"
        case .asr: "sun.min.fill"
        case .maghrib, .iftar: "sun.horizon.fill"
        case .isha: "moon.fill"
        }
    }
}

enum CalculationMethod: String, CaseIterable, Codable, Identifiable, Sendable {
    case automatic, karachi, muslimWorldLeague, ummAlQura, egyptian, isna

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: String(localized: "Automatic by location")
        case .karachi: String(localized: "UIS Karachi")
        case .muslimWorldLeague: String(localized: "Muslim World League")
        case .ummAlQura: String(localized: "Umm al-Qura")
        case .egyptian: String(localized: "Egyptian Authority")
        case .isna: String(localized: "ISNA")
        }
    }

    var fullTitle: String {
        switch self {
        case .automatic: String(localized: "Automatic by location")
        case .karachi: String(localized: "University of Islamic Sciences, Karachi")
        case .muslimWorldLeague: String(localized: "Muslim World League")
        case .ummAlQura: String(localized: "Umm al-Qura University, Makkah")
        case .egyptian: String(localized: "Egyptian General Authority of Survey")
        case .isna: String(localized: "Islamic Society of North America (ISNA)")
        }
    }
}

enum Madhab: String, CaseIterable, Codable, Identifiable, Sendable {
    case hanafi, standard

    var id: String { rawValue }
    var title: String {
        self == .hanafi
            ? String(localized: "Hanafi")
            : String(localized: "Standard (Shafi, Maliki, Hanbali)")
    }
}

enum TimeFormatPreference: String, CaseIterable, Codable, Identifiable, Sendable {
    case system, twelveHour, twentyFourHour

    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: String(localized: "System")
        case .twelveHour: String(localized: "12-hour")
        case .twentyFourHour: String(localized: "24-hour")
        }
    }
}

enum AppearancePreference: String, CaseIterable, Codable, Identifiable, Sendable {
    case system, light, dark

    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: String(localized: "System")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }
}

enum ThemePreference: String, CaseIterable, Codable, Identifiable, Sendable {
    case greyishBlue
    case greenishDark
    case slateInkNavy
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .greyishBlue: String(localized: "Greyish Blue")
        case .greenishDark: String(localized: "Greenish Dark")
        case .slateInkNavy: String(localized: "Slate to Ink Navy")
        case .custom: String(localized: "Custom Color")
        }
    }

    var subtitle: String {
        switch self {
        case .greyishBlue: String(localized: "The original calm blue palette")
        case .greenishDark: String(localized: "Deep green with a mint accent")
        case .slateInkNavy: String(localized: "Layered slate and navy with a crisp blue accent")
        case .custom: String(localized: "Choose from seven curated colors")
        }
    }
}

enum CustomThemeColor: String, CaseIterable, Codable, Identifiable, Sendable {
    case oceanBlue
    case deepTeal
    case emerald
    case indigo
    case mutedPurple
    case dustyRose
    case terracotta

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oceanBlue: String(localized: "Ocean")
        case .deepTeal: String(localized: "Teal")
        case .emerald: String(localized: "Emerald")
        case .indigo: String(localized: "Indigo")
        case .mutedPurple: String(localized: "Purple")
        case .dustyRose: String(localized: "Rose")
        case .terracotta: String(localized: "Terracotta")
        }
    }
}

enum LocationSource: String, Codable, Sendable {
    case automatic, district, fallback

    var title: String {
        switch self {
        case .automatic: String(localized: "Automatic")
        case .district: String(localized: "District")
        case .fallback: String(localized: "Default")
        }
    }
}

struct PrayerLocation: Codable, Equatable, Sendable {
    var name: String
    var latitude: Double
    var longitude: Double
    var timeZoneIdentifier: String
    var countryCode: String? = nil
    var source: LocationSource

    static let dhaka = PrayerLocation(
        name: "Dhaka, Bangladesh",
        latitude: 23.7115253,
        longitude: 90.4111451,
        timeZoneIdentifier: "Asia/Dhaka",
        countryCode: "BD",
        source: .fallback
    )

    var timeZone: TimeZone { TimeZone(identifier: timeZoneIdentifier) ?? .current }
    var isFallback: Bool { source == .fallback }
}

struct CalculationSettings: Codable, Equatable, Sendable {
    var method: CalculationMethod = .karachi
    var madhab: Madhab = .hanafi
    var hijriAdjustment: Int = -1
    var cautionMinutes: Int = 3
    var timeFormat: TimeFormatPreference = .system
}

struct LocalDay: Hashable, Codable, Comparable, Identifiable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    var id: String { key }
    var key: String { String(format: "%04d-%02d-%02d", year, month, day) }

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(_ date: Date, timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: components.year ?? 1970, month: components.month ?? 1, day: components.day ?? 1)
    }

    func date(in timeZone: TimeZone, hour: Int = 12, minute: Int = 0) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(
            timeZone: timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))
    }

    func adding(days: Int, in timeZone: TimeZone) -> LocalDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let source = date(in: timeZone) ?? .now
        return LocalDay(calendar.date(byAdding: .day, value: days, to: source) ?? source, timeZone: timeZone)
    }

    static func < (lhs: LocalDay, rhs: LocalDay) -> Bool { lhs.key < rhs.key }
}

struct PrayerTimesQuery: Hashable, Codable, Sendable {
    static let schemaVersion = 3

    var day: LocalDay
    var latitude: Double
    var longitude: Double
    var method: CalculationMethod
    var madhab: Madhab
    var hijriAdjustment: Int
    var cautionMinutes: Int
    var schemaVersion: Int = Self.schemaVersion

    init(day: LocalDay, location: PrayerLocation, settings: CalculationSettings) {
        self.day = day
        latitude = (location.latitude * 10_000).rounded() / 10_000
        longitude = (location.longitude * 10_000).rounded() / 10_000
        method = settings.method
        madhab = settings.madhab
        hijriAdjustment = settings.hijriAdjustment
        cautionMinutes = settings.cautionMinutes
    }

    var signature: String {
        [
            "v\(schemaVersion)",
            String(format: "%.4f", latitude),
            String(format: "%.4f", longitude),
            method.rawValue,
            madhab.rawValue,
            "h\(hijriAdjustment)",
            "c\(cautionMinutes)"
        ].joined(separator: "|")
    }

    var cacheKey: String { "\(day.key)|\(signature)" }
}

struct PrayerWindow: Codable, Identifiable, Hashable, Sendable {
    var prayer: PrayerType
    var start: Date
    var end: Date

    var id: PrayerType { prayer }
    var displayEnd: Date { end.addingTimeInterval(-60) }
    func contains(_ date: Date) -> Bool { date >= start && date < end }
}

struct PrayerDay: Codable, Identifiable, Hashable, Sendable {
    var localDay: LocalDay
    var gregorianSummary: String
    var hijriSummary: String
    var timeZoneIdentifier: String
    var sunrise: Date
    var sunset: Date
    var sahri: Date
    var iftar: Date
    var windows: [PrayerWindow]
    var methodName: String
    var fetchedAt: Date

    var id: String { localDay.key }
    var timeZone: TimeZone { TimeZone(identifier: timeZoneIdentifier) ?? .current }

    func window(for prayer: PrayerType) -> PrayerWindow? {
        windows.first { $0.prayer == prayer }
    }

    func eventDate(_ event: PrayerEvent) -> Date? {
        switch event {
        case .sahri: sahri
        case .iftar: iftar
        case .fajr: window(for: .fajr)?.start
        case .dhuhr: window(for: .dhuhr)?.start
        case .asr: window(for: .asr)?.start
        case .maghrib: window(for: .maghrib)?.start
        case .isha: window(for: .isha)?.start
        }
    }
}

struct PrayerMoment: Equatable, Sendable {
    var current: PrayerWindow?
    var next: PrayerWindow?
    var remaining: TimeInterval?
    var progress: Double
}

enum PrayerTimeline {
    static func moment(now: Date, today: PrayerDay, previous: PrayerDay?) -> PrayerMoment {
        let candidates = (previous?.windows ?? []) + today.windows
        let current = candidates.last { $0.contains(now) }
        let next = candidates.filter { $0.start > now }.min { $0.start < $1.start }
        let remaining = current.map { max(0, $0.end.timeIntervalSince(now)) }
            ?? next.map { max(0, $0.start.timeIntervalSince(now)) }
        let progress: Double
        if let current {
            let duration = current.end.timeIntervalSince(current.start)
            progress = duration > 0 ? min(1, max(0, now.timeIntervalSince(current.start) / duration)) : 0
        } else {
            progress = 0
        }
        return PrayerMoment(current: current, next: next, remaining: remaining, progress: progress)
    }
}

enum PrayerDateFormatting {
    static func time(_ date: Date, preference: TimeFormatPreference, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = preference == .system ? .current : Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        switch preference {
        case .system: formatter.timeStyle = .short
        case .twelveHour: formatter.dateFormat = "h:mm a"
        case .twentyFourHour: formatter.dateFormat = "HH:mm"
        }
        return formatter.string(from: date)
    }

    static func fullDate(_ day: LocalDay, timeZone: TimeZone) -> String {
        guard let date = day.date(in: timeZone) else { return day.key }
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEE d MMMM yyyy")
        return formatter.string(from: date)
    }

    static func countdown(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }
}

enum FeatureLoadState<Value> {
    case idle
    case loading
    case loaded(Value, source: PrayerDataSource)
    case empty
    case offline(Value, lastUpdated: Date)
    case failed(PrayerDataError)
    case permissionDenied
}

enum PrayerDataSource: String, Codable, Sendable {
    case calculated, memoryCache, diskCache
}

enum PrayerDataError: Error, Equatable, LocalizedError, Sendable {
    case invalidURL
    case transport(String)
    case httpStatus(Int)
    case decoding(String)
    case invalidData(String)
    case unavailableOffline
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidURL: String(localized: "The prayer-time calculation could not be created.")
        case .transport: String(localized: "Prayer times could not be calculated.")
        case .httpStatus(let code): String(
            format: String(localized: "The prayer-time calculation returned error %@."),
            String(code)
        )
        case .decoding, .invalidData: String(localized: "Prayer times could not be calculated for this date.")
        case .unavailableOffline: String(localized: "Prayer times are unavailable for this date.")
        case .cancelled: String(localized: "The request was cancelled.")
        }
    }
}

struct LoadedPrayerDay: Sendable {
    var value: PrayerDay
    var source: PrayerDataSource
    var isStale: Bool
}

enum CachePolicy: Equatable, Sendable {
    case cacheFirst
    case reload
}

protocol PrayerTimesRepository: Sendable {
    func day(for query: PrayerTimesQuery, location: PrayerLocation, policy: CachePolicy) async throws -> LoadedPrayerDay
    func month(containing day: LocalDay, location: PrayerLocation, settings: CalculationSettings, policy: CachePolicy) async throws -> [LoadedPrayerDay]
    func invalidate(signature: String) async
}

@MainActor
protocol PrayerTrackingRepository: AnyObject {
    func records(on day: LocalDay) throws -> [PrayerRecordSnapshot]
    func completedPrayerTypes(on day: LocalDay) throws -> Set<PrayerType>
    func setCompleted(_ completed: Bool, prayer: PrayerType, day: LocalDay, timeZone: TimeZone, source: String) throws
    func allRecords() throws -> [PrayerRecordSnapshot]
    func clearAll() throws
}

struct PrayerRecordSnapshot: Identifiable, Equatable, Sendable {
    var id: UUID
    var prayer: PrayerType
    var localDay: LocalDay
    var completed: Bool
    var completedAt: Date?
    var source: String?
    var notes: String?
}

struct TrackerInsights: Equatable, Sendable {
    var currentStreak: Int
    var bestStreak: Int
    var completionPercentage: Double
    var completed: Int
    var possible: Int
    var recent: [PrayerRecordSnapshot]

    static let empty = TrackerInsights(currentStreak: 0, bestStreak: 0, completionPercentage: 0, completed: 0, possible: 0, recent: [])
}

enum TrackerInsightCalculator {
    static func calculate(records: [PrayerRecordSnapshot], today: LocalDay, timeZone: TimeZone) -> TrackerInsights {
        let completed = records.filter(\.completed)
        guard let firstDay = completed.map(\.localDay).min() else { return .empty }
        let grouped = Dictionary(grouping: completed, by: \.localDay)
        var cursor = firstDay
        var fullDays: [LocalDay] = []
        var possible = 0
        while cursor <= today {
            possible += 5
            if Set((grouped[cursor] ?? []).map(\.prayer)).count == 5 { fullDays.append(cursor) }
            cursor = cursor.adding(days: 1, in: timeZone)
        }

        var best = 0
        var run = 0
        var prior: LocalDay?
        for day in fullDays.sorted() {
            if let prior, prior.adding(days: 1, in: timeZone) == day { run += 1 } else { run = 1 }
            best = max(best, run)
            prior = day
        }

        let currentAnchor = Set((grouped[today] ?? []).map(\.prayer)).count == 5 ? today : today.adding(days: -1, in: timeZone)
        var current = 0
        var currentCursor = currentAnchor
        while Set((grouped[currentCursor] ?? []).map(\.prayer)).count == 5 {
            current += 1
            currentCursor = currentCursor.adding(days: -1, in: timeZone)
        }

        return TrackerInsights(
            currentStreak: current,
            bestStreak: best,
            completionPercentage: possible == 0 ? 0 : Double(completed.count) / Double(possible),
            completed: completed.count,
            possible: possible,
            recent: completed.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }.prefix(20).map { $0 }
        )
    }
}
