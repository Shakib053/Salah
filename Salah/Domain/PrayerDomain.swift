import Foundation

enum PrayerType: String, CaseIterable, Codable, Identifiable, Sendable {
    case fajr, dhuhr, asr, maghrib, isha

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fajr: L10n.string("Fajr")
        case .dhuhr: L10n.string("Dhuhr")
        case .asr: L10n.string("Asr")
        case .maghrib: L10n.string("Maghrib")
        case .isha: L10n.string("Isha")
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
        case .fajr: L10n.string("Fajr")
        case .dhuhr: L10n.string("Dhuhr")
        case .asr: L10n.string("Asr")
        case .maghrib: L10n.string("Maghrib")
        case .isha: L10n.string("Isha")
        case .sahri: L10n.string("Sahri")
        case .iftar: L10n.string("Iftar")
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
        case .automatic: L10n.string("Automatic by location")
        case .karachi: L10n.string("UIS Karachi")
        case .muslimWorldLeague: L10n.string("Muslim World League")
        case .ummAlQura: L10n.string("Umm al-Qura")
        case .egyptian: L10n.string("Egyptian Authority")
        case .isna: L10n.string("ISNA")
        }
    }

    var fullTitle: String {
        switch self {
        case .automatic: L10n.string("Automatic by location")
        case .karachi: L10n.string("University of Islamic Sciences, Karachi")
        case .muslimWorldLeague: L10n.string("Muslim World League")
        case .ummAlQura: L10n.string("Umm al-Qura University, Makkah")
        case .egyptian: L10n.string("Egyptian General Authority of Survey")
        case .isna: L10n.string("Islamic Society of North America (ISNA)")
        }
    }
}

enum Madhab: String, CaseIterable, Codable, Identifiable, Sendable {
    case hanafi, standard

    var id: String { rawValue }
    var title: String {
        self == .hanafi
            ? L10n.string("Hanafi")
            : L10n.string("Standard (Shafi, Maliki, Hanbali)")
    }
}

enum TimeFormatPreference: String, CaseIterable, Codable, Identifiable, Sendable {
    case system, twelveHour, twentyFourHour

    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: L10n.string("System")
        case .twelveHour: L10n.string("12-hour")
        case .twentyFourHour: L10n.string("24-hour")
        }
    }
}

enum AppearancePreference: String, CaseIterable, Codable, Identifiable, Sendable {
    case system, light, dark

    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: L10n.string("System")
        case .light: L10n.string("Light")
        case .dark: L10n.string("Dark")
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
        case .greyishBlue: L10n.string("Greyish Blue")
        case .greenishDark: L10n.string("Greenish Dark")
        case .slateInkNavy: L10n.string("Slate to Ink Navy")
        case .custom: L10n.string("Custom Color")
        }
    }

    var subtitle: String {
        switch self {
        case .greyishBlue: L10n.string("The original calm blue palette")
        case .greenishDark: L10n.string("Deep green with a mint accent")
        case .slateInkNavy: L10n.string("Layered slate and navy with a crisp blue accent")
        case .custom: L10n.string("Choose from seven curated colors")
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
        case .oceanBlue: L10n.string("Ocean")
        case .deepTeal: L10n.string("Teal")
        case .emerald: L10n.string("Emerald")
        case .indigo: L10n.string("Indigo")
        case .mutedPurple: L10n.string("Purple")
        case .dustyRose: L10n.string("Rose")
        case .terracotta: L10n.string("Terracotta")
        }
    }
}

enum LocationSource: String, Codable, Sendable {
    case automatic, district, fallback

    var title: String {
        switch self {
        case .automatic: L10n.string("Automatic")
        case .district: L10n.string("District")
        case .fallback: L10n.string("Default")
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
    static let schemaVersion = 4

    var day: LocalDay
    var latitude: Double
    var longitude: Double
    var method: CalculationMethod
    var madhab: Madhab
    var hijriAdjustment: Int
    var cautionMinutes: Int
    var languageIdentifier: String
    var schemaVersion: Int = Self.schemaVersion

    init(day: LocalDay, location: PrayerLocation, settings: CalculationSettings) {
        self.day = day
        latitude = (location.latitude * 10_000).rounded() / 10_000
        longitude = (location.longitude * 10_000).rounded() / 10_000
        method = settings.method
        madhab = settings.madhab
        hijriAdjustment = settings.hijriAdjustment
        cautionMinutes = settings.cautionMinutes
        languageIdentifier = L10n.locale.identifier
    }

    var signature: String {
        [
            "v\(schemaVersion)",
            String(format: "%.4f", latitude),
            String(format: "%.4f", longitude),
            method.rawValue,
            madhab.rawValue,
            "h\(hijriAdjustment)",
            "c\(cautionMinutes)",
            "l\(languageIdentifier)"
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

enum PrayerCardEvent: Equatable, Sendable {
    case obligatory(PrayerWindow)
    case nafl(practice: NaflPractice, start: Date, end: Date)

    var title: String {
        switch self {
        case .obligatory(let window):
            window.prayer.title
        case .nafl(let practice, _, _):
            switch practice {
            case .tahajjud: L10n.string("Tahajjud")
            case .ishrak: L10n.string("Ishrak")
            case .morningAdhkar, .eveningAdhkar, .quran: practice.title
            }
        }
    }

    var symbol: String {
        switch self {
        case .obligatory(let window): window.prayer.symbol
        case .nafl(let practice, _, _): practice.symbol
        }
    }

    var start: Date {
        switch self {
        case .obligatory(let window): window.start
        case .nafl(_, let start, _): start
        }
    }

    var end: Date {
        switch self {
        case .obligatory(let window): window.end
        case .nafl(_, _, let end): end
        }
    }

    var isNafl: Bool {
        if case .nafl = self { return true }
        return false
    }
}

struct PrayerCardMoment: Equatable, Sendable {
    var event: PrayerCardEvent?
    var isCurrent: Bool
    var remaining: TimeInterval?
    var progress: Double
}

enum PrayerTimeline {
    /// A conservative buffer after sunrise avoids the prohibited sunrise period.
    static let ishrakSunriseBuffer: TimeInterval = 20 * 60
    /// Ishrak/Duha ends shortly before Dhuhr rather than at the same instant.
    static let ishrakDhuhrBuffer: TimeInterval = 10 * 60

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

    /// Builds the Today hero-card timeline. Nafl windows intentionally live here
    /// instead of `PrayerDay.windows` so the five obligatory-prayer schedule and
    /// completion model remain unchanged.
    static func cardMoment(now: Date, today: PrayerDay, previous: PrayerDay?) -> PrayerCardMoment {
        if let fajr = today.window(for: .fajr),
           let midnight = today.localDay.date(in: today.timeZone, hour: 0),
           midnight < fajr.start {
            let tahajjud = PrayerCardEvent.nafl(practice: .tahajjud, start: midnight, end: fajr.start)
            if now >= midnight, now < fajr.start {
                return currentCardMoment(tahajjud, now: now)
            }
        }

        if let dhuhr = today.window(for: .dhuhr) {
            let start = today.sunrise.addingTimeInterval(ishrakSunriseBuffer)
            let end = dhuhr.start.addingTimeInterval(-ishrakDhuhrBuffer)
            if start < end {
                let ishrak = PrayerCardEvent.nafl(practice: .ishrak, start: start, end: end)
                if now >= today.sunrise, now < start {
                    return upcomingCardMoment(ishrak, now: now)
                }
                if now >= start, now < end {
                    return currentCardMoment(ishrak, now: now)
                }
            }
        }

        let obligatory = moment(now: now, today: today, previous: previous)
        if let current = obligatory.current {
            return currentCardMoment(.obligatory(current), now: now)
        }
        if let next = obligatory.next {
            return upcomingCardMoment(.obligatory(next), now: now)
        }
        return PrayerCardMoment(event: nil, isCurrent: false, remaining: nil, progress: 0)
    }

    /// True from local civil midnight until Fajr for the current prayer day.
    static func isMidnightToFajrWindow(now: Date, today: PrayerDay) -> Bool {
        guard today.localDay == LocalDay(now, timeZone: today.timeZone),
              let fajr = today.window(for: .fajr),
              let midnight = today.localDay.date(in: today.timeZone, hour: 0) else { return false }
        return now >= midnight && now < fajr.start
    }

    /// True only for the civil-midnight-to-Fajr exception where the current
    /// day's Isha row actually represents the *next* Isha, not the one still
    /// available from the previous day.
    static func isPreviousDayIshaCarryover(now: Date, today: PrayerDay) -> Bool {
        isMidnightToFajrWindow(now: now, today: today)
    }

    private static func currentCardMoment(_ event: PrayerCardEvent, now: Date) -> PrayerCardMoment {
        let duration = event.end.timeIntervalSince(event.start)
        let progress = duration > 0
            ? min(1, max(0, now.timeIntervalSince(event.start) / duration))
            : 0
        return PrayerCardMoment(
            event: event,
            isCurrent: true,
            remaining: max(0, event.end.timeIntervalSince(now)),
            progress: progress
        )
    }

    private static func upcomingCardMoment(_ event: PrayerCardEvent, now: Date) -> PrayerCardMoment {
        PrayerCardMoment(
            event: event,
            isCurrent: false,
            remaining: max(0, event.start.timeIntervalSince(now)),
            progress: 0
        )
    }
}

enum PrayerDateFormatting {
    static func time(_ date: Date, preference: TimeFormatPreference, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = L10n.locale
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
        formatter.locale = L10n.locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEE d MMMM yyyy")
        return formatter.string(from: date)
    }

    static func countdown(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        let formatter = NumberFormatter()
        formatter.locale = L10n.locale
        formatter.minimumIntegerDigits = 2
        formatter.maximumFractionDigits = 0
        let values = [seconds / 3600, (seconds % 3600) / 60, seconds % 60]
        return values.map { formatter.string(from: NSNumber(value: $0)) ?? String(format: "%02d", $0) }
            .joined(separator: ":")
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
        case .invalidURL: L10n.string("The prayer-time calculation could not be created.")
        case .transport: L10n.string("Prayer times could not be calculated.")
        case .httpStatus(let code): String(
            format: L10n.string("The prayer-time calculation returned error %@."),
            String(code)
        )
        case .decoding, .invalidData: L10n.string("Prayer times could not be calculated for this date.")
        case .unavailableOffline: L10n.string("Prayer times are unavailable for this date.")
        case .cancelled: L10n.string("The request was cancelled.")
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

enum CharityCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case sadaqah
    case zakat
    case food
    case education
    case emergency
    case other

    var id: Self { self }

    var title: String {
        switch self {
        case .sadaqah: L10n.string("Sadaqah")
        case .zakat: L10n.string("Zakat")
        case .food: L10n.string("Food")
        case .education: L10n.string("Education")
        case .emergency: L10n.string("Emergency relief")
        case .other: L10n.string("Other")
        }
    }

    var symbol: String {
        switch self {
        case .sadaqah: "heart.fill"
        case .zakat: "moon.stars.fill"
        case .food: "takeoutbag.and.cup.and.straw.fill"
        case .education: "book.closed.fill"
        case .emergency: "cross.case.fill"
        case .other: "gift.fill"
        }
    }
}

enum CharityCurrency {
    static func code(for locale: Locale = .current) -> String {
        locale.currency?.identifier ?? "USD"
    }
}

struct CharityEntry: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var amount: Double
    var date: Date
    var category: CharityCategory
    var currencyCode: String
    var recipient: String
    var note: String

    private enum CodingKeys: String, CodingKey {
        case id
        case amount
        case date
        case category
        case currencyCode
        case recipient
        case note
    }

    init(
        id: UUID = UUID(),
        amount: Double,
        date: Date,
        category: CharityCategory,
        currencyCode: String = CharityCurrency.code(),
        recipient: String = "",
        note: String = ""
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.category = category
        self.currencyCode = currencyCode
        self.recipient = recipient
        self.note = note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        amount = try container.decode(Double.self, forKey: .amount)
        date = try container.decode(Date.self, forKey: .date)
        category = try container.decode(CharityCategory.self, forKey: .category)
        currencyCode = try container.decodeIfPresent(String.self, forKey: .currencyCode) ?? CharityCurrency.code()
        recipient = try container.decodeIfPresent(String.self, forKey: .recipient) ?? ""
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(amount, forKey: .amount)
        try container.encode(date, forKey: .date)
        try container.encode(category, forKey: .category)
        try container.encode(currencyCode, forKey: .currencyCode)
        try container.encode(recipient, forKey: .recipient)
        try container.encode(note, forKey: .note)
    }
}

enum CharityLedger {
    static let storageKey = "salah.deeds.charity-entries.v1"

    private struct CurrencyProbe: Decodable {
        let currencyCode: String?
    }

    static func decode(_ data: Data) -> [CharityEntry] {
        guard !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([CharityEntry].self, from: data)) ?? []
    }

    static func encode(_ entries: [CharityEntry]) -> Data {
        (try? JSONEncoder().encode(entries)) ?? Data()
    }

    static func needsCurrencyMigration(_ data: Data) -> Bool {
        guard let probes = try? JSONDecoder().decode([CurrencyProbe].self, from: data) else { return false }
        return probes.contains { $0.currencyCode == nil }
    }

    static func entries(
        _ entries: [CharityEntry],
        inMonthContaining date: Date,
        calendar: Calendar = .current
    ) -> [CharityEntry] {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return [] }
        return entries.filter { interval.contains($0.date) }
    }

    static func total(
        _ entries: [CharityEntry],
        inMonthContaining date: Date,
        calendar: Calendar = .current
    ) -> Double {
        self.entries(entries, inMonthContaining: date, calendar: calendar).reduce(0) { $0 + $1.amount }
    }
}

enum NaflPractice: Int, CaseIterable, Codable, Identifiable, Sendable {
    case tahajjud
    case ishrak
    case morningAdhkar
    case eveningAdhkar
    case quran

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .tahajjud: L10n.string("Prayed Tahajjud")
        case .ishrak: L10n.string("Prayed Ishrak")
        case .morningAdhkar: L10n.string("Morning Adhkar")
        case .eveningAdhkar: L10n.string("Evening Adhkar")
        case .quran: L10n.string("Read Quran")
        }
    }

    var symbol: String {
        switch self {
        case .tahajjud: "moon.stars.fill"
        case .ishrak: "sunrise.fill"
        case .morningAdhkar: "sun.horizon.fill"
        case .eveningAdhkar: "sunset.fill"
        case .quran: "book.closed.fill"
        }
    }
}

struct TasbihDailyRecord: Codable, Equatable, Identifiable, Sendable {
    var day: LocalDay
    var count: Int
    var goal: Int
    var updatedAt: Date

    var id: String { day.key }
}

enum TasbihHistoryLedger {
    static let storageKey = "salah.deeds.tasbih-history.v1"

    static func decode(_ data: Data) -> [TasbihDailyRecord] {
        guard !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([TasbihDailyRecord].self, from: data)) ?? []
    }

    static func encode(_ records: [TasbihDailyRecord]) -> Data {
        (try? JSONEncoder().encode(records.sorted { $0.day < $1.day })) ?? Data()
    }

    static func recording(count: Int, goal: Int, on day: LocalDay, in data: Data) -> Data {
        var records = decode(data)
        if let index = records.firstIndex(where: { $0.day == day }) {
            records[index].count = max(0, count)
            records[index].goal = max(0, goal)
            records[index].updatedAt = .now
        } else {
            records.append(TasbihDailyRecord(day: day, count: max(0, count), goal: max(0, goal), updatedAt: .now))
        }
        return encode(records)
    }

    static func incrementing(goal: Int, on day: LocalDay, in data: Data) -> Data {
        let current = decode(data).first(where: { $0.day == day })?.count ?? 0
        return recording(count: current + 1, goal: goal, on: day, in: data)
    }
}

struct NaflDailyRecord: Codable, Equatable, Identifiable, Sendable {
    var day: LocalDay
    var completedMask: Int
    var updatedAt: Date

    var id: String { day.key }
    var completedCount: Int {
        NaflPractice.allCases.filter { completedMask & (1 << $0.rawValue) != 0 }.count
    }

    func contains(_ practice: NaflPractice) -> Bool {
        completedMask & (1 << practice.rawValue) != 0
    }
}

enum NaflHistoryLedger {
    static let storageKey = "salah.deeds.nafl-history.v1"

    static func decode(_ data: Data) -> [NaflDailyRecord] {
        guard !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([NaflDailyRecord].self, from: data)) ?? []
    }

    static func encode(_ records: [NaflDailyRecord]) -> Data {
        (try? JSONEncoder().encode(records.sorted { $0.day < $1.day })) ?? Data()
    }

    static func recording(mask: Int, on day: LocalDay, in data: Data) -> Data {
        var records = decode(data)
        if let index = records.firstIndex(where: { $0.day == day }) {
            records[index].completedMask = max(0, mask)
            records[index].updatedAt = .now
        } else {
            records.append(NaflDailyRecord(day: day, completedMask: max(0, mask), updatedAt: .now))
        }
        return encode(records)
    }
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
