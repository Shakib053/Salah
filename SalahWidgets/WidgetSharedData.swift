import Foundation
import WidgetKit

struct WidgetPrayer: Codable, Identifiable, Sendable {
    let name: String
    let time: Date
    let end: Date
    let symbolName: String
    let completed: Bool
    let isNext: Bool
    let isCurrent: Bool

    var id: String { name }

    init(
        name: String,
        time: Date,
        end: Date,
        symbolName: String,
        completed: Bool,
        isNext: Bool,
        isCurrent: Bool
    ) {
        self.name = name
        self.time = time
        self.end = end
        self.symbolName = symbolName
        self.completed = completed
        self.isNext = isNext
        self.isCurrent = isCurrent
    }

    enum CodingKeys: String, CodingKey {
        case name, time, end, symbolName, completed, isNext, isCurrent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        time = try container.decode(Date.self, forKey: .time)
        // `end`/`isCurrent` were added later; snapshots saved before that lack
        // them, so fall back to `time`/`false` rather than failing to decode.
        end = try container.decodeIfPresent(Date.self, forKey: .end) ?? time
        symbolName = try container.decode(String.self, forKey: .symbolName)
        completed = try container.decodeIfPresent(Bool.self, forKey: .completed) ?? false
        isNext = try container.decodeIfPresent(Bool.self, forKey: .isNext) ?? false
        isCurrent = try container.decodeIfPresent(Bool.self, forKey: .isCurrent) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(time, forKey: .time)
        try container.encode(end, forKey: .end)
        try container.encode(symbolName, forKey: .symbolName)
        try container.encode(completed, forKey: .completed)
        try container.encode(isNext, forKey: .isNext)
        try container.encode(isCurrent, forKey: .isCurrent)
    }
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
}

extension WidgetSnapshot {
    /// Mirrors `PrayerTimeline.moment`: the waqt active at `date` (the "current"
    /// prayer) and the next waqt to begin. The Sunrise row is not a prayer
    /// window and is excluded.
    ///
    /// Window ends are **derived** from the contiguous prayer schedule (each
    /// window ends at the next prayer's start; Isha ends at tomorrow's Fajr)
    /// so this works even with old saved snapshots whose `end == time`.
    static func moment(
        at date: Date,
        prayers: [WidgetPrayer],
        tomorrowFajr: WidgetPrayer?
    ) -> (current: WidgetPrayer?, next: WidgetPrayer?) {
        let real = prayers.filter { $0.name != String(localized: "Sunrise") }

        // Build contiguous windows with derived ends.
        let windows: [(start: Date, end: Date, index: Int)] = real.enumerated().map { idx, prayer in
            let end = idx + 1 < real.count
                ? real[idx + 1].time
                : tomorrowFajr?.time ?? prayer.time
            return (start: prayer.time, end: end, index: idx)
        }

        // Active waqt: the last window that contains `date`.
        var current: WidgetPrayer?
        if let match = windows.last(where: { $0.start <= date && $0.end > date }) {
            let prayer = real[match.index]
            current = WidgetPrayer(
                name: prayer.name,
                time: prayer.time,
                end: match.end,       // derived end for accurate countdown
                symbolName: prayer.symbolName,
                completed: prayer.completed,
                isNext: false,
                isCurrent: false
            )
        }

        // Before Fajr the previous day's Isha is still active (its window wraps
        // past midnight); the app shows it as the current prayer. Synthesize it
        // with end = today's Fajr so the widget matches the dashboard.
        if current == nil, let fajrStart = windows.first?.start, date < fajrStart {
            current = WidgetPrayer(
                name: String(localized: "Isha"),
                time: fajrStart,
                end: fajrStart,
                symbolName: "moon.fill",
                completed: false,
                isNext: false,
                isCurrent: true
            )
        }

        let next = real.first { $0.time > date } ?? tomorrowFajr
        return (current, next)
    }

    func snapshot(at date: Date) -> WidgetSnapshot {
        let moment = Self.moment(at: date, prayers: prayers, tomorrowFajr: tomorrowFajr)
        let current = moment.current
        let next = moment.next

        let updatedPrayers = prayers.map { prayer in
            WidgetPrayer(
                name: prayer.name,
                time: prayer.time,
                end: prayer.end,
                symbolName: prayer.symbolName,
                completed: prayer.completed,
                isNext: next?.name == prayer.name && next?.time == prayer.time,
                isCurrent: current?.name == prayer.name && current?.time == prayer.time
            )
        }

        return WidgetSnapshot(
            updatedAt: updatedAt,
            localDayKey: localDayKey,
            gregorianSummary: gregorianSummary,
            hijriSummary: hijriSummary,
            timeZoneIdentifier: timeZoneIdentifier,
            prayers: updatedPrayers,
            currentPrayer: current,
            nextPrayer: next,
            tomorrowFajr: tomorrowFajr
        )
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
