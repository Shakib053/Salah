import Foundation
import WidgetKit

struct WidgetPrayer: Codable, Identifiable, Sendable {
    let name: String
    let time: Date
    let symbolName: String
    let completed: Bool
    let isNext: Bool

    var id: String { name }
}

struct WidgetSnapshot: Codable, Sendable {
    let updatedAt: Date
    let localDayKey: String
    let gregorianSummary: String
    let hijriSummary: String
    let timeZoneIdentifier: String
    let prayers: [WidgetPrayer]
    let nextPrayer: WidgetPrayer?
    let tomorrowFajr: WidgetPrayer?
}

extension WidgetSnapshot {
    func snapshot(at date: Date) -> WidgetSnapshot {
        let next = prayers
            .filter { $0.name != "Sunrise" && $0.time > date }
            .min { $0.time < $1.time } ?? tomorrowFajr

        let updatedPrayers = prayers.map { prayer in
            WidgetPrayer(
                name: prayer.name,
                time: prayer.time,
                symbolName: prayer.symbolName,
                completed: prayer.completed,
                isNext: next?.name == prayer.name && next?.time == prayer.time
            )
        }

        return WidgetSnapshot(
            updatedAt: updatedAt,
            localDayKey: localDayKey,
            gregorianSummary: gregorianSummary,
            hijriSummary: hijriSummary,
            timeZoneIdentifier: timeZoneIdentifier,
            prayers: updatedPrayers,
            nextPrayer: next,
            tomorrowFajr: tomorrowFajr
        )
    }
}

enum WidgetDataStore {
    static let groupID = "group.com.mahialjawad.salah"
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
