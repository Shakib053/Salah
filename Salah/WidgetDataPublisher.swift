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

        let prayerItems = prayerDay.windows.map { window in
            WidgetPrayer(
                name: window.prayer.title,
                time: window.start,
                end: window.end,
                symbolName: window.prayer.symbol,
                completed: completed.contains(window.prayer),
                isNext: false,
                isCurrent: false
            )
        }

        let sunriseItem = WidgetPrayer(
            name: String(localized: "Sunrise"),
            time: prayerDay.sunrise,
            end: prayerDay.sunrise,
            symbolName: "sunrise.fill",
            completed: false,
            isNext: false,
            isCurrent: false
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
                end: $0,
                symbolName: PrayerType.fajr.symbol,
                completed: false,
                isNext: false,
                isCurrent: false
            )
        }

        let moment = WidgetSnapshot.moment(at: now, prayers: scheduleItems, tomorrowFajr: tomorrowItem)
        let flaggedItems = scheduleItems.map { item in
            WidgetPrayer(
                name: item.name,
                time: item.time,
                end: item.end,
                symbolName: item.symbolName,
                completed: item.completed,
                isNext: moment.next?.name == item.name && moment.next?.time == item.time,
                isCurrent: moment.current?.name == item.name && moment.current?.time == item.time
            )
        }

        let snapshot = WidgetSnapshot(
            updatedAt: .now,
            localDayKey: prayerDay.localDay.key,
            gregorianSummary: prayerDay.gregorianSummary,
            hijriSummary: prayerDay.hijriSummary,
            timeZoneIdentifier: prayerDay.timeZoneIdentifier,
            prayers: flaggedItems,
            currentPrayer: moment.current,
            nextPrayer: moment.next,
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
                    end: item.end,
                    symbolName: item.symbolName,
                    completed: completed,
                    isNext: item.isNext,
                    isCurrent: item.isCurrent
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
            currentPrayer: updating(snapshot.currentPrayer, prayer: prayer, completed: completed),
            nextPrayer: updating(snapshot.nextPrayer, prayer: prayer, completed: completed),
            tomorrowFajr: snapshot.tomorrowFajr
        )

        WidgetDataStore.save(updated)
    }

    /// Returns `item` with `completed` updated, but only when its name matches
    /// `prayer`; otherwise `item` is left untouched.
    private static func updating(
        _ item: WidgetPrayer?,
        prayer: PrayerType,
        completed: Bool
    ) -> WidgetPrayer? {
        item.map { current in
            current.name == prayer.title
                ? WidgetPrayer(
                    name: current.name,
                    time: current.time,
                    end: current.end,
                    symbolName: current.symbolName,
                    completed: completed,
                    isNext: current.isNext,
                    isCurrent: current.isCurrent
                )
                : current
        }
    }
}
