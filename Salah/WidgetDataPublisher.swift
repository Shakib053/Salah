import Foundation

enum WidgetDataPublisher {
    static func save(
        prayerDay: PrayerDay,
        completed: Set<PrayerType>,
        tomorrowFajr: Date? = nil
    ) {
        let today = LocalDay(.now, timeZone: prayerDay.timeZone)
        guard prayerDay.localDay == today else { return }

        let now = Date()
        let nextPrayerType = prayerDay.windows.first { $0.start > now }?.prayer
            ?? (tomorrowFajr == nil ? nil : .fajr)

        let prayerItems = prayerDay.windows.map { window in
            WidgetPrayer(
                name: window.prayer.title,
                time: window.start,
                symbolName: window.prayer.symbol,
                completed: completed.contains(window.prayer),
                isNext: window.prayer == nextPrayerType
            )
        }

        let sunriseItem = WidgetPrayer(
            name: "Sunrise",
            time: prayerDay.sunrise,
            symbolName: "sunrise.fill",
            completed: false,
            isNext: false
        )
        let scheduleItems = prayerItems.reduce(into: [WidgetPrayer]()) { result, item in
            result.append(item)
            if item.name == PrayerType.fajr.title {
                result.append(sunriseItem)
            }
        }

        let tomorrowItem = tomorrowFajr.map {
            WidgetPrayer(
                name: PrayerType.fajr.title,
                time: $0,
                symbolName: PrayerType.fajr.symbol,
                completed: false,
                isNext: nextPrayerType == .fajr && prayerDay.windows.allSatisfy { $0.start <= now }
            )
        }

        let nextPrayer = scheduleItems.first(where: \.isNext) ?? tomorrowItem
        let snapshot = WidgetSnapshot(
            updatedAt: .now,
            localDayKey: prayerDay.localDay.key,
            gregorianSummary: prayerDay.gregorianSummary,
            hijriSummary: prayerDay.hijriSummary,
            timeZoneIdentifier: prayerDay.timeZoneIdentifier,
            prayers: scheduleItems,
            nextPrayer: nextPrayer,
            tomorrowFajr: tomorrowItem
        )

        WidgetDataStore.save(snapshot)
    }

    static func updateCompletion(
        prayer: PrayerType,
        day: LocalDay,
        completed: Bool
    ) {
        guard let snapshot = WidgetDataStore.load(), snapshot.localDayKey == day.key else { return }

        let updatedPrayers = snapshot.prayers.map { item in
            item.name == prayer.title
                ? WidgetPrayer(
                    name: item.name,
                    time: item.time,
                    symbolName: item.symbolName,
                    completed: completed,
                    isNext: item.isNext
                )
                : item
        }
        let updatedNextPrayer = snapshot.nextPrayer.map { item in
            item.name == prayer.title
                ? WidgetPrayer(
                    name: item.name,
                    time: item.time,
                    symbolName: item.symbolName,
                    completed: completed,
                    isNext: item.isNext
                )
                : item
        }

        let updated = WidgetSnapshot(
            updatedAt: .now,
            localDayKey: snapshot.localDayKey,
            gregorianSummary: snapshot.gregorianSummary,
            hijriSummary: snapshot.hijriSummary,
            timeZoneIdentifier: snapshot.timeZoneIdentifier,
            prayers: updatedPrayers,
            nextPrayer: updatedNextPrayer,
            tomorrowFajr: snapshot.tomorrowFajr
        )

        WidgetDataStore.save(updated)
    }
}
