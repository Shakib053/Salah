//
//  SalahWidgets.swift
//  SalahWidgets
//
//  Created by Kazi Tanjim Shakib on 27/7/26.
//

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent(), snapshot: nil)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(
            date: .now,
            configuration: configuration,
            snapshot: WidgetDataStore.load()?.snapshot(at: .now)
        )
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let now = Date()
        let snapshot = WidgetDataStore.load()?.snapshot(at: now)
        let periodicRefresh = now.addingTimeInterval(15 * 60)
        // Refresh at the current waqt's end (so it flips to the next prayer)
        // and/or the next prayer's start, whichever comes first.
        let currentEnd = snapshot?.currentPrayer?.end
        let nextStart = snapshot?.nextPrayer?.time
        let transition = min(currentEnd ?? .distantFuture, nextStart ?? .distantFuture)
        let refreshDate = min(
            transition.addingTimeInterval(1),
            periodicRefresh
        )
        let entry = SimpleEntry(
            date: now,
            configuration: configuration,
            snapshot: snapshot
        )

        return Timeline(entries: [entry], policy: .after(refreshDate))
    }

//    func relevances() async -> WidgetRelevances<ConfigurationAppIntent> {
//        // Generate a list containing the contexts this widget is relevant in.
//    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let snapshot: WidgetSnapshot?
}

struct SalahWidgetsEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                MediumWidgetView(snapshot: entry.snapshot)
            case .systemLarge:
                LargeWidgetView(snapshot: entry.snapshot)
            default:
                SmallWidgetView(snapshot: entry.snapshot)
            }
        }
        .containerBackground(for: .widget) {
            WidgetTheme.background
        }
    }
}

private enum WidgetTheme {
    static let background = LinearGradient(
        colors: [Color(red: 0.035, green: 0.075, blue: 0.11), Color(red: 0.02, green: 0.04, blue: 0.065)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let panel = Color.white.opacity(0.055)
    static let primary = Color.white
    static let secondary = Color.white.opacity(0.62)
    static let muted = Color.white.opacity(0.36)
    static let accent = Color(red: 0.29, green: 0.82, blue: 0.75)
    static let divider = Color.white.opacity(0.13)
}

private enum WidgetTimeFormatter {
    static func time(_ date: Date, timezoneIdentifier: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = TimeZone(identifier: timezoneIdentifier) ?? .current
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Row highlighting helpers. The current waqt is the strongest; the next waqt
/// is secondary; everything else uses the view's baseline color.
private extension WidgetPrayer {
    var mediumRowColor: Color {
        if isCurrent { return WidgetTheme.accent }
        if isNext { return WidgetTheme.accent.opacity(0.6) }
        return WidgetTheme.secondary
    }
    var largeRowColor: Color {
        if isCurrent { return WidgetTheme.accent }
        if isNext { return WidgetTheme.accent.opacity(0.6) }
        return WidgetTheme.primary
    }
    var largeIconColor: Color {
        if isCurrent { return WidgetTheme.accent }
        if isNext { return WidgetTheme.accent.opacity(0.6) }
        return WidgetTheme.secondary
    }
    var rowWeight: Font.Weight {
        if isCurrent { return .semibold }
        if isNext { return .medium }
        return .regular
    }
}

private struct SmallWidgetView: View {
    let snapshot: WidgetSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "moon.stars.fill")
                    .font(.title3)
                    .foregroundStyle(WidgetTheme.accent)
                Spacer()
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(WidgetTheme.muted)
            }

            Spacer(minLength: 8)

            if let snapshot, let featured = snapshot.currentPrayer ?? snapshot.nextPrayer {
                let isCurrent = snapshot.currentPrayer != nil
                let countdownDate = isCurrent ? featured.end : featured.time

                Text(isCurrent ? "CURRENT PRAYER" : "NEXT PRAYER")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.1)
                    .foregroundStyle(WidgetTheme.accent)

                Text(featured.name)
                    .font(.system(size: 27, weight: .medium, design: .serif))
                    .foregroundStyle(WidgetTheme.primary)
                    .lineLimit(1)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(isCurrent ? "ends in" : "in")
                        .foregroundStyle(WidgetTheme.accent)
                    Text(countdownDate, style: .timer)
                        .foregroundStyle(WidgetTheme.accent)
                        .monospacedDigit()
                }
                .font(.subheadline.weight(.semibold))

                Spacer(minLength: 8)
                Rectangle()
                    .fill(WidgetTheme.divider)
                    .frame(height: 1)
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                    Text(WidgetTimeFormatter.time(featured.time, timezoneIdentifier: snapshot.timeZoneIdentifier))
                }
                .font(.caption)
                .foregroundStyle(WidgetTheme.secondary)
                .padding(.top, 8)
            } else {
                Text("Open Salah to load prayer times")
                    .font(.caption)
                    .foregroundStyle(WidgetTheme.secondary)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(16)
    }
}

private struct MediumWidgetView: View {
    let snapshot: WidgetSnapshot?

    var body: some View {
        HStack(spacing: 10) {
            if let snapshot, let featured = snapshot.currentPrayer ?? snapshot.nextPrayer {
                let isCurrent = snapshot.currentPrayer != nil
                let countdownDate = isCurrent ? featured.end : featured.time

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 5) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundStyle(WidgetTheme.accent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(snapshot.gregorianSummary)
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                            Text(snapshot.hijriSummary)
                                .font(.caption2)
                                .foregroundStyle(WidgetTheme.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 5)

                    Text(isCurrent ? "CURRENT PRAYER" : "NEXT PRAYER")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.1)
                        .foregroundStyle(WidgetTheme.accent)
                    Text(featured.name)
                        .font(.system(size: 31, weight: .medium, design: .serif))
                        .foregroundStyle(WidgetTheme.primary)
                        .lineLimit(1)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(isCurrent ? "ends in" : "in")
                        Text(countdownDate, style: .timer)
                            .monospacedDigit()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WidgetTheme.accent)

                    Spacer(minLength: 4)

                    HStack(spacing: 8) {
                        Image(systemName: "moon.stars.fill")
                            .font(.title3)
                        Image(systemName: "building.columns.fill")
                            .font(.title3)
                            .opacity(0.35)
                    }
                    .foregroundStyle(WidgetTheme.accent.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(WidgetTheme.divider)
                    .frame(width: 1)

                VStack(spacing: 0) {
                    HStack(spacing: 5) {
                        Spacer()
                        Text("Updated \(WidgetTimeFormatter.time(snapshot.updatedAt, timezoneIdentifier: snapshot.timeZoneIdentifier))")
                        Image(systemName: "arrow.clockwise")
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(WidgetTheme.secondary)
                    .frame(height: 12)
                    .padding(.bottom, 1)

                    ForEach(snapshot.prayers) { prayer in
                        HStack(spacing: 5) {
                            Image(systemName: prayer.symbolName)
                                .font(.system(size: 11))
                                .frame(width: 15)
                                .foregroundStyle(prayer.mediumRowColor)
                            Text(prayer.name)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .foregroundStyle(prayer.mediumRowColor)
                            Spacer(minLength: 4)
                            Text(WidgetTimeFormatter.time(prayer.time, timezoneIdentifier: snapshot.timeZoneIdentifier))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .foregroundStyle(prayer.mediumRowColor)
                                .monospacedDigit()
                        }
                        .font(.caption2)
                        .fontWeight(prayer.rowWeight)
                        .frame(maxWidth: .infinity)
                        .frame(height: 19)

                        if prayer.id != snapshot.prayers.last?.id {
                            Rectangle()
                                .fill(WidgetTheme.divider)
                                .frame(height: 1)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                Text("Open Salah to load prayer times")
                    .font(.caption)
                    .foregroundStyle(WidgetTheme.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(12)
    }
}

private struct LargeWidgetView: View {
    let snapshot: WidgetSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let snapshot, let featured = snapshot.currentPrayer ?? snapshot.nextPrayer {
                let isCurrent = snapshot.currentPrayer != nil
                let countdownDate = isCurrent ? featured.end : featured.time

                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(WidgetTheme.accent)
                        .padding(7)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(WidgetTheme.accent.opacity(0.7), lineWidth: 1)
                        )
                    Text(snapshot.hijriSummary)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WidgetTheme.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 14)

                Text(isCurrent ? "CURRENT PRAYER" : "NEXT PRAYER")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.1)
                    .foregroundStyle(WidgetTheme.accent)
                Text(featured.name)
                    .font(.system(size: 36, weight: .medium, design: .serif))
                    .foregroundStyle(WidgetTheme.primary)
                    .lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(isCurrent ? "ends in" : "in")
                    Text(countdownDate, style: .timer)
                        .monospacedDigit()
                }
                .font(.headline.weight(.semibold))
                .foregroundStyle(WidgetTheme.accent)

                Spacer(minLength: 14)

                Rectangle()
                    .fill(WidgetTheme.divider)
                    .frame(height: 1)
                    .padding(.bottom, 8)

                VStack(spacing: 0) {
                    ForEach(snapshot.prayers) { prayer in
                        HStack(spacing: 9) {
                            Image(systemName: prayer.symbolName)
                                .font(.caption)
                                .frame(width: 17)
                                .foregroundStyle(prayer.largeIconColor)
                            Text(prayer.name)
                                .fontWeight(prayer.rowWeight)
                                .foregroundStyle(prayer.largeRowColor)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(WidgetTimeFormatter.time(prayer.time, timezoneIdentifier: snapshot.timeZoneIdentifier))
                                .font(.subheadline.monospacedDigit())
                                .fontWeight(prayer.rowWeight)
                                .foregroundStyle(prayer.largeRowColor)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                    }
                }
            } else {
                Text("Open Salah to load prayer times")
                    .font(.subheadline)
                    .foregroundStyle(WidgetTheme.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .padding(20)
    }
}

struct SalahWidgets: Widget {
    let kind: String = "SalahWidgets"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            SalahWidgetsEntryView(entry: entry)
        }
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

extension ConfigurationAppIntent {
    fileprivate static var smiley: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "😀"
        return intent
    }

    fileprivate static var starEyes: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "🤩"
        return intent
    }
}

/// Sample snapshot whose Dhuhr window contains "now", so previews exercise the
/// current-prayer UI (live countdown to the waqt's end).
private func sampleSnapshot(now: Date = .now) -> WidgetSnapshot {
    func minutes(_ value: Double) -> Date { now.addingTimeInterval(value * 60) }
    let prayers = [
        WidgetPrayer(name: "Fajr", time: minutes(-360), end: minutes(-240), symbolName: "moon.stars.fill", completed: true, isNext: false, isCurrent: false),
        WidgetPrayer(name: "Sunrise", time: minutes(-240), end: minutes(-240), symbolName: "sunrise.fill", completed: false, isNext: false, isCurrent: false),
        WidgetPrayer(name: "Dhuhr", time: minutes(-120), end: minutes(120), symbolName: "sun.max.fill", completed: false, isNext: false, isCurrent: false),
        WidgetPrayer(name: "Asr", time: minutes(150), end: minutes(360), symbolName: "sun.min.fill", completed: false, isNext: false, isCurrent: false),
        WidgetPrayer(name: "Maghrib", time: minutes(370), end: minutes(480), symbolName: "sun.horizon.fill", completed: false, isNext: false, isCurrent: false),
        WidgetPrayer(name: "Isha", time: minutes(490), end: minutes(900), symbolName: "moon.fill", completed: false, isNext: false, isCurrent: false)
    ]
    let tomorrowFajr = WidgetPrayer(name: "Fajr", time: minutes(1440), end: minutes(1560), symbolName: "moon.stars.fill", completed: false, isNext: false, isCurrent: false)
    return WidgetSnapshot(
        updatedAt: now,
        localDayKey: "sample",
        gregorianSummary: "Saturday, 9 August",
        hijriSummary: "15 Safar 1448",
        timeZoneIdentifier: TimeZone.current.identifier,
        prayers: prayers,
        currentPrayer: nil,
        nextPrayer: nil,
        tomorrowFajr: tomorrowFajr
    )
}

#Preview(as: .systemSmall) {
    SalahWidgets()
} timeline: {
    SimpleEntry(date: .now, configuration: .smiley, snapshot: sampleSnapshot().snapshot(at: .now))
}

#Preview(as: .systemMedium) {
    SalahWidgets()
} timeline: {
    SimpleEntry(date: .now, configuration: .smiley, snapshot: sampleSnapshot().snapshot(at: .now))
}

#Preview(as: .systemLarge) {
    SalahWidgets()
} timeline: {
    SimpleEntry(date: .now, configuration: .smiley, snapshot: sampleSnapshot().snapshot(at: .now))
}
