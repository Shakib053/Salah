import Foundation
import WidgetKit

enum WidgetLocalization {
    private static let languageKey = "salah.app-language"

    static var locale: Locale {
        switch UserDefaults(suiteName: WidgetDataStore.groupID)?.string(forKey: languageKey) {
        case "english": Locale(identifier: "en")
        case "bangla": Locale(identifier: "bn")
        default: .autoupdatingCurrent
        }
    }

    static func string(_ key: String.LocalizationValue) -> String {
        String(localized: key, locale: locale)
    }
}

enum WidgetPrayerKind: String, Codable, Sendable {
    case fajr, dhuhr, asr, maghrib, isha, sunrise, ishrak, tahajjud

    var isNafl: Bool { self == .ishrak || self == .tahajjud }
    var isObligatory: Bool {
        switch self {
        case .fajr, .dhuhr, .asr, .maghrib, .isha: true
        case .sunrise, .ishrak, .tahajjud: false
        }
    }
}

struct WidgetPrayer: Codable, Identifiable, Sendable {
    let kind: WidgetPrayerKind
    let name: String
    let time: Date
    let end: Date
    let symbolName: String
    let completed: Bool
    let isNext: Bool
    let isCurrent: Bool

    var id: String { kind.rawValue }
    var isNafl: Bool { kind.isNafl }

    init(
        name: String,
        time: Date,
        end: Date,
        symbolName: String,
        completed: Bool,
        isNext: Bool,
        isCurrent: Bool,
        kind: WidgetPrayerKind? = nil
    ) {
        self.kind = kind ?? Self.inferredKind(name: name, symbolName: symbolName)
        self.name = name
        self.time = time
        self.end = end
        self.symbolName = symbolName
        self.completed = completed
        self.isNext = isNext
        self.isCurrent = isCurrent
    }

    enum CodingKeys: String, CodingKey {
        case kind, name, time, end, symbolName, completed, isNext, isCurrent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        symbolName = try container.decode(String.self, forKey: .symbolName)
        kind = try container.decodeIfPresent(WidgetPrayerKind.self, forKey: .kind)
            ?? Self.inferredKind(name: name, symbolName: symbolName)
        time = try container.decode(Date.self, forKey: .time)
        // `end`/`isCurrent` were added later; snapshots saved before that lack
        // them, so fall back to `time`/`false` rather than failing to decode.
        end = try container.decodeIfPresent(Date.self, forKey: .end) ?? time
        completed = try container.decodeIfPresent(Bool.self, forKey: .completed) ?? false
        isNext = try container.decodeIfPresent(Bool.self, forKey: .isNext) ?? false
        isCurrent = try container.decodeIfPresent(Bool.self, forKey: .isCurrent) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(name, forKey: .name)
        try container.encode(time, forKey: .time)
        try container.encode(end, forKey: .end)
        try container.encode(symbolName, forKey: .symbolName)
        try container.encode(completed, forKey: .completed)
        try container.encode(isNext, forKey: .isNext)
        try container.encode(isCurrent, forKey: .isCurrent)
    }

    private static func inferredKind(name: String, symbolName: String) -> WidgetPrayerKind {
        if name == WidgetLocalization.string("Sunrise") { return .sunrise }
        switch symbolName {
        case "sun.max.fill": return .dhuhr
        case "sun.min.fill": return .asr
        case "sun.horizon.fill": return .maghrib
        case "moon.fill": return .isha
        case "sunrise.fill": return .sunrise
        default: return .fajr
        }
    }
}

struct WidgetDaySchedule: Codable, Sendable {
    let localDayKey: String
    let gregorianSummary: String
    let hijriSummary: String
    let prayers: [WidgetPrayer]
}

struct WidgetSnapshot: Codable, Sendable {
    let updatedAt: Date
    let localDayKey: String
    let gregorianSummary: String
    let hijriSummary: String
    let timeZoneIdentifier: String
    let prayers: [WidgetPrayer]
    let currentPrayer: WidgetPrayer?
    let nextPrayer: WidgetPrayer?
    let tomorrowFajr: WidgetPrayer?
    let nextDay: WidgetDaySchedule?
}

extension WidgetSnapshot {
    private static let ishrakSunriseBuffer: TimeInterval = 20 * 60
    private static let ishrakDhuhrBuffer: TimeInterval = 10 * 60

    /// Mirrors `PrayerTimeline.cardMoment`, using the exact ends calculated by
    /// the app. Old snapshots whose ends are absent still receive a derived
    /// fallback until the app publishes fresh data.
    static func moment(
        at date: Date,
        prayers: [WidgetPrayer],
        tomorrowFajr: WidgetPrayer?,
        timeZoneIdentifier: String = TimeZone.current.identifier
    ) -> (current: WidgetPrayer?, next: WidgetPrayer?) {
        let obligatory = prayers
            .filter { $0.kind.isObligatory }
            .sorted { $0.time < $1.time }
        let sunrise = prayers.first { $0.kind == .sunrise }
        let normalizedPrayers = obligatory.enumerated().map { index, prayer in
            Self.normalized(prayer, end: windowEnd(
                for: prayer,
                at: index,
                obligatory: obligatory,
                sunrise: sunrise,
                tomorrowFajr: tomorrowFajr
            ))
        }

        let fajrCandidates = normalizedPrayers.filter { $0.kind == WidgetPrayerKind.fajr }
            + [tomorrowFajr].compactMap { $0 }
        let futureFajr = fajrCandidates
            .filter { $0.time > date }
            .min { $0.time < $1.time }
        if let fajr = futureFajr {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
            let midnight = calendar.startOfDay(for: fajr.time)
            if date >= midnight, date < fajr.time {
                let tahajjud = WidgetPrayer(
                    name: WidgetLocalization.string("Tahajjud"),
                    time: midnight,
                    end: fajr.time,
                    symbolName: "moon.stars.fill",
                    completed: false,
                    isNext: false,
                    isCurrent: true,
                    kind: .tahajjud
                )
                return (tahajjud, flagged(fajr, asNext: true))
            }
        }

        if let sunrise,
           let dhuhr = normalizedPrayers.first(where: { $0.kind == WidgetPrayerKind.dhuhr }) {
            let start = sunrise.time.addingTimeInterval(ishrakSunriseBuffer)
            let end = dhuhr.time.addingTimeInterval(-ishrakDhuhrBuffer)
            if start < end {
                let ishrak = WidgetPrayer(
                    name: WidgetLocalization.string("Ishrak"),
                    time: start,
                    end: end,
                    symbolName: "sunrise.fill",
                    completed: false,
                    isNext: date >= sunrise.time && date < start,
                    isCurrent: date >= start && date < end,
                    kind: .ishrak
                )
                if ishrak.isNext { return (nil, ishrak) }
                if ishrak.isCurrent {
                    return (ishrak, flagged(dhuhr, asNext: true))
                }
            }
        }

        let current = normalizedPrayers.last { $0.time <= date && $0.end > date }
        let next = normalizedPrayers.first { $0.time > date } ?? tomorrowFajr
        return (
            current.map { flagged($0, asCurrent: true) },
            next.map { flagged($0, asNext: true) }
        )
    }

    func snapshot(at date: Date) -> WidgetSnapshot {
        let dateKey = Self.localDayKey(for: date, timeZoneIdentifier: timeZoneIdentifier)
        let usesNextDay = nextDay?.localDayKey == dateKey
        let activePrayers = usesNextDay ? (nextDay?.prayers ?? prayers) : prayers
        let activeTomorrowFajr = usesNextDay ? nil : tomorrowFajr
        let moment = Self.moment(
            at: date,
            prayers: activePrayers,
            tomorrowFajr: activeTomorrowFajr,
            timeZoneIdentifier: timeZoneIdentifier
        )
        let current = moment.current
        let next = moment.next

        let updatedPrayers = activePrayers.map { prayer in
            WidgetPrayer(
                name: prayer.name,
                time: prayer.time,
                end: prayer.end,
                symbolName: prayer.symbolName,
                completed: prayer.completed,
                isNext: next?.name == prayer.name && next?.time == prayer.time,
                isCurrent: current?.name == prayer.name && current?.time == prayer.time,
                kind: prayer.kind
            )
        }

        return WidgetSnapshot(
            updatedAt: updatedAt,
            localDayKey: usesNextDay ? (nextDay?.localDayKey ?? localDayKey) : localDayKey,
            gregorianSummary: usesNextDay ? (nextDay?.gregorianSummary ?? gregorianSummary) : gregorianSummary,
            hijriSummary: usesNextDay ? (nextDay?.hijriSummary ?? hijriSummary) : hijriSummary,
            timeZoneIdentifier: timeZoneIdentifier,
            prayers: updatedPrayers,
            currentPrayer: current,
            nextPrayer: next,
            tomorrowFajr: activeTomorrowFajr,
            nextDay: usesNextDay ? nil : nextDay
        )
    }

    func transitionDates(after date: Date, horizon: TimeInterval = 26 * 60 * 60) -> [Date] {
        let limit = date.addingTimeInterval(horizon)
        let schedules = [prayers, nextDay?.prayers].compactMap { $0 }
        var dates = Set<Date>()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current

        for schedule in schedules {
            for prayer in schedule {
                dates.insert(prayer.time)
                if prayer.end > prayer.time { dates.insert(prayer.end) }
            }
            if let sunrise = schedule.first(where: { $0.kind == .sunrise }),
               let dhuhr = schedule.first(where: { $0.kind == .dhuhr }) {
                dates.insert(sunrise.time.addingTimeInterval(Self.ishrakSunriseBuffer))
                dates.insert(dhuhr.time.addingTimeInterval(-Self.ishrakDhuhrBuffer))
            }
            if let fajr = schedule.first(where: { $0.kind == .fajr }) {
                dates.insert(calendar.startOfDay(for: fajr.time))
            }
        }
        if let tomorrowFajr {
            dates.insert(calendar.startOfDay(for: tomorrowFajr.time))
            dates.insert(tomorrowFajr.time)
        }
        return dates.filter { $0 > date && $0 <= limit }.sorted()
    }

    private static func windowEnd(
        for prayer: WidgetPrayer,
        at index: Int,
        obligatory: [WidgetPrayer],
        sunrise: WidgetPrayer?,
        tomorrowFajr: WidgetPrayer?
    ) -> Date {
        if prayer.end > prayer.time { return prayer.end }
        if prayer.kind == .fajr, let sunrise, sunrise.time > prayer.time { return sunrise.time }
        if index + 1 < obligatory.count { return obligatory[index + 1].time }
        return tomorrowFajr?.time ?? prayer.time
    }

    private static func normalized(_ prayer: WidgetPrayer, end: Date) -> WidgetPrayer {
        WidgetPrayer(
            name: prayer.name,
            time: prayer.time,
            end: end,
            symbolName: prayer.symbolName,
            completed: prayer.completed,
            isNext: false,
            isCurrent: false,
            kind: prayer.kind
        )
    }

    private static func flagged(
        _ prayer: WidgetPrayer,
        asCurrent: Bool = false,
        asNext: Bool = false
    ) -> WidgetPrayer {
        WidgetPrayer(
            name: prayer.name,
            time: prayer.time,
            end: prayer.end,
            symbolName: prayer.symbolName,
            completed: prayer.completed,
            isNext: asNext,
            isCurrent: asCurrent,
            kind: prayer.kind
        )
    }

    private static func localDayKey(for date: Date, timeZoneIdentifier: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

enum WidgetDataStore {
    static let groupID = "group.com.prayer.salah"
    private static let snapshotKey = "salah.widget.snapshot"

    static func save(_ snapshot: WidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: groupID),
              let data = try? JSONEncoder().encode(snapshot) else { return }

        defaults.set(data, forKey: snapshotKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "SalahWidgets")
    }

    static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: groupID)?.data(forKey: snapshotKey) else {
            return nil
        }

        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
