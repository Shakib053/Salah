import Charts
import SwiftUI

struct DailyChartValue: Identifiable {
    let day: LocalDay
    let count: Int
    var id: String { day.key }
}

struct HistoryView: View {
    @Bindable var container: AppContainer
    @Environment(\.salahPalette) private var palette
    @State private var records: [PrayerRecordSnapshot] = []

    private var today: LocalDay { LocalDay(.now, timeZone: container.settings.location.timeZone) }
    private var insights: TrackerInsights {
        TrackerInsightCalculator.calculate(records: records, today: today, timeZone: container.settings.location.timeZone)
    }
    private var chartValues: [DailyChartValue] {
        (0..<7).reversed().map { offset in
            let day = today.adding(days: -offset, in: container.settings.location.timeZone)
            return DailyChartValue(day: day, count: Set(records.filter { $0.localDay == day && $0.completed }.map(\.prayer)).count)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if records.filter(\.completed).isEmpty {
                    ContentUnavailableView {
                        Label("No history yet", systemImage: "chart.bar")
                    } description: {
                        Text("Completed prayers will create a private history here.")
                    }
                    .frame(minHeight: 300)
                } else {
                    HStack(spacing: 12) {
                        metricCard("Current streak", value: insights.currentStreak.formatted(.number.locale(L10n.locale)), detail: "full days")
                        metricCard("Best streak", value: insights.bestStreak.formatted(.number.locale(L10n.locale)), detail: "full days")
                    }
                    metricCard(
                        "Completion",
                        value: insights.completionPercentage.formatted(.percent.precision(.fractionLength(0)).locale(L10n.locale)),
                        detail: L10n.string("\(insights.completed) of \(insights.possible) prayers since tracking began")
                    )

                    SalahCard {
                        Text("Last 7 Days").font(.headline)
                        Chart(chartValues) { value in
                            BarMark(
                                x: .value("Day", value.day.key),
                                y: .value("Completed", value.count)
                            )
                            .foregroundStyle(value.day == today ? palette.heroStart : palette.accent)
                            .cornerRadius(5)
                        }
                        .chartYScale(domain: 0...5)
                        .chartYAxis { AxisMarks(values: [0, 1, 2, 3, 4, 5]) }
                        .frame(height: 190)
                        .accessibilityChartDescriptor(PrayerHistoryChartDescriptor(values: chartValues))
                    }

                    SalahCard {
                        Text("This Month").font(.headline)
                        let monthRecords = records.filter { $0.localDay.year == today.year && $0.localDay.month == today.month && $0.completed }
                        Text("\(monthRecords.count) prayers recorded")
                            .font(.title2.bold())
                        Text("A private summary for reflection—never a public score.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recent Completions").font(.title3.bold())
                        ForEach(insights.recent) { record in
                            HStack {
                                PrayerIcon(prayer: record.prayer)
                                VStack(alignment: .leading) {
                                    Text(record.prayer.title).font(.headline)
                                    Text(record.localDay.key).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let date = record.completedAt {
                                    Text(date.formatted(.dateTime.hour().minute().locale(L10n.locale))).font(.caption)
                                }
                            }
                            .padding(.vertical, 4)
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
            .padding()
        }
        .background(palette.screenBackground.ignoresSafeArea())
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .phoneOnlyHideTabBar()
        .task { records = (try? container.trackingRepository.allRecords()) ?? [] }
    }

    private func metricCard(_ title: String, value: String, detail: String) -> some View {
        SalahCard {
            Text(L10n.dynamic(title)).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.largeTitle.bold().monospacedDigit())
            Text(L10n.dynamic(detail)).font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct PrayerHistoryChartDescriptor: AXChartDescriptorRepresentable {
    let values: [DailyChartValue]

    func makeChartDescriptor() -> AXChartDescriptor {
        let xAxis = AXCategoricalDataAxisDescriptor(title: "Day", categoryOrder: values.map { $0.day.key })
        let yAxis = AXNumericDataAxisDescriptor(title: "Prayers completed", range: 0...5, gridlinePositions: [0, 1, 2, 3, 4, 5]) { "\(Int($0))" }
        let series = AXDataSeriesDescriptor(
            name: "Daily completion",
            isContinuous: false,
            dataPoints: values.map { AXDataPoint(x: $0.day.key, y: Double($0.count), label: "\($0.day.key): \($0.count) of 5") }
        )
        return AXChartDescriptor(title: "Prayer completion for the last seven days", summary: nil, xAxis: xAxis, yAxis: yAxis, additionalAxes: [], series: [series])
    }
}
