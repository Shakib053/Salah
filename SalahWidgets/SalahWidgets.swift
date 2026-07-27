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
        let prayerTransition = snapshot?.nextPrayer?.time.addingTimeInterval(1)
        let refreshDate = min(
            prayerTransition ?? periodicRefresh,
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

            if let snapshot, let next = snapshot.nextPrayer {
                Text("NEXT PRAYER")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.1)
                    .foregroundStyle(WidgetTheme.accent)

                Text(next.name)
                    .font(.system(size: 27, weight: .medium, design: .serif))
                    .foregroundStyle(WidgetTheme.primary)
                    .lineLimit(1)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("in")
                        .foregroundStyle(WidgetTheme.accent)
                    Text(next.time, style: .timer)
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
                    Text(WidgetTimeFormatter.time(next.time, timezoneIdentifier: snapshot.timeZoneIdentifier))
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
        HStack(spacing: 14) {
            if let snapshot, let next = snapshot.nextPrayer {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .foregroundStyle(WidgetTheme.accent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(snapshot.gregorianSummary)
                                .font(.caption.weight(.semibold))
                            Text(snapshot.hijriSummary)
                                .font(.caption2)
                                .foregroundStyle(WidgetTheme.secondary)
                        }
                    }

                    Spacer(minLength: 12)

                    Text("NEXT PRAYER")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.1)
                        .foregroundStyle(WidgetTheme.accent)
                    Text(next.name)
                        .font(.system(size: 36, weight: .medium, design: .serif))
                        .foregroundStyle(WidgetTheme.primary)
                        .lineLimit(1)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("in")
                        Text(next.time, style: .timer)
                            .monospacedDigit()
                    }
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(WidgetTheme.accent)

                    Spacer(minLength: 8)

                    HStack(spacing: 8) {
                        Image(systemName: "moon.stars.fill")
                            .font(.title2)
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
                        Text("Updated (WidgetTimeFormatter.time(snapshot.updatedAt, timezoneIdentifier: snapshot.timeZoneIdentifier))")
                        Image(systemName: "arrow.clockwise")
                    }
                    .font(.caption2)
                    .foregroundStyle(WidgetTheme.secondary)
                    .padding(.bottom, 5)

                    ForEach(snapshot.prayers) { prayer in
                        HStack(spacing: 7) {
                            Image(systemName: prayer.symbolName)
                                .frame(width: 17)
                                .foregroundStyle(prayer.isNext ? WidgetTheme.accent : WidgetTheme.secondary)
                            Text(prayer.name)
                                .foregroundStyle(prayer.isNext ? WidgetTheme.accent : WidgetTheme.secondary)
                            Spacer(minLength: 4)
                            Text(WidgetTimeFormatter.time(prayer.time, timezoneIdentifier: snapshot.timeZoneIdentifier))
                                .foregroundStyle(prayer.isNext ? WidgetTheme.accent : WidgetTheme.secondary)
                                .monospacedDigit()
                        }
                        .font(.caption)
                        .fontWeight(prayer.isNext ? .semibold : .regular)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)

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
        .padding(16)
    }
}

struct SalahWidgets: Widget {
    let kind: String = "SalahWidgets"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            SalahWidgetsEntryView(entry: entry)
        }
        .supportedFamilies([.systemSmall, .systemMedium])
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

#Preview(as: .systemSmall) {
    SalahWidgets()
} timeline: {
    SimpleEntry(date: .now, configuration: .smiley, snapshot: nil)
    SimpleEntry(date: .now, configuration: .starEyes, snapshot: nil)
}

#Preview(as: .systemMedium) {
    SalahWidgets()
} timeline: {
    SimpleEntry(date: .now, configuration: .smiley, snapshot: nil)
}
