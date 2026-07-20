import Charts
import Observation
import SwiftUI

@MainActor
@Observable
final class TrackerViewModel {
    private let repository: any PrayerTrackingRepository
    private let settings: AppSettings

    var selectedDay: LocalDay
    var completed: Set<PrayerType> = []
    var lastChanged: PrayerType?
    var errorMessage: String?

    init(container: AppContainer) {
        repository = container.trackingRepository
        settings = container.settings
        selectedDay = LocalDay(.now, timeZone: settings.location.timeZone)
        refresh()
    }

    var completedCount: Int { completed.count }
    var remainingCount: Int { PrayerType.allCases.count - completed.count }
    var progress: Double { Double(completed.count) / Double(PrayerType.allCases.count) }

    func refresh() {
        do {
            completed = try repository.completedPrayerTypes(on: selectedDay)
            errorMessage = nil
        } catch {
            errorMessage = "Tracker data could not be loaded."
        }
    }

    func toggle(_ prayer: PrayerType) {
        let value = !completed.contains(prayer)
        do {
            try repository.setCompleted(value, prayer: prayer, day: selectedDay, timeZone: settings.location.timeZone, source: "tracker")
            if value { completed.insert(prayer) } else { completed.remove(prayer) }
            lastChanged = prayer
            errorMessage = nil
        } catch {
            errorMessage = "Your change could not be saved."
        }
    }

    func undo() {
        guard let lastChanged else { return }
        toggle(lastChanged)
        self.lastChanged = nil
    }
}

struct TrackerView: View {
    @Bindable var container: AppContainer
    @State private var viewModel: TrackerViewModel
    @State private var showingDatePicker = false

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: TrackerViewModel(container: container))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                SalahCard(isTransparent: true) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(isToday ? "Today’s progress" : PrayerDateFormatting.fullDate(viewModel.selectedDay, timeZone: container.settings.location.timeZone))
                                .font(.title3.bold())
                            Text("Private and stored on this device")
                                .font(.caption).foregroundStyle(.white.opacity(0.82))
                        }
                        Spacer()
                        Text("\(viewModel.completedCount)/5")
                            .font(.largeTitle.bold().monospacedDigit())
                    }
                    ProgressView(value: viewModel.progress)
                        .tint(.white)
                        .accessibilityLabel("Daily completion")
                        .accessibilityValue("\(viewModel.completedCount) of 5 prayers completed")
                    Text("\(viewModel.remainingCount) remaining")
                        .font(.caption.bold())
                }
                .foregroundStyle(.white)
                .background(
                    LinearGradient(colors: [SalahPalette.accent, Color.indigo], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 20)
                )

                if let message = viewModel.errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundStyle(.red)
                }

                VStack(spacing: 10) {
                    ForEach(PrayerType.allCases) { prayer in
                        TrackerPrayerRow(prayer: prayer, completed: viewModel.completed.contains(prayer)) {
                            withAnimation(.snappy) { viewModel.toggle(prayer) }
                        }
                    }
                }

                if viewModel.completed.isEmpty {
                    ContentUnavailableView {
                        Label("No prayers marked", systemImage: "checkmark.circle")
                    } description: {
                        Text("Use the controls above whenever you want to record this day.")
                    }
                    .frame(minHeight: 150)
                }

                NavigationLink {
                    HistoryView(container: container)
                } label: {
                    SalahCard {
                        Label("History and Insights", systemImage: "chart.bar.fill")
                            .font(.headline)
                        Text("View streaks, summaries, and recent completion history.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .navigationTitle("Tracker")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingDatePicker = true } label: { Label("Choose date", systemImage: "calendar") }
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            NavigationStack {
                DatePicker(
                    "Tracker date",
                    selection: Binding(
                        get: { viewModel.selectedDay.date(in: container.settings.location.timeZone) ?? .now },
                        set: {
                            viewModel.selectedDay = LocalDay($0, timeZone: container.settings.location.timeZone)
                            viewModel.refresh()
                        }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                .navigationTitle("Choose Date")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingDatePicker = false } } }
            }
            .presentationDetents([.medium])
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.lastChanged != nil {
                HStack {
                    Text("Tracker updated")
                    Spacer()
                    Button("Undo") { viewModel.undo() }.bold()
                }
                .padding()
                .background(.regularMaterial, in: Capsule())
                .padding(.horizontal)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityElement(children: .contain)
            }
        }
    }

    private var isToday: Bool {
        viewModel.selectedDay == LocalDay(.now, timeZone: container.settings.location.timeZone)
    }
}

struct TrackerPrayerRow: View {
    let prayer: PrayerType
    let completed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                PrayerIcon(prayer: prayer)
                VStack(alignment: .leading, spacing: 3) {
                    Text(prayer.title).font(.headline)
                    Text(completed ? "Completed" : "Not marked yet")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(completed ? SalahPalette.accent : .secondary)
                    .accessibilityHidden(true)
            }
            .padding()
            .frame(minHeight: 64)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(prayer.title), \(completed ? "completed" : "not completed")")
        .accessibilityHint(completed ? "Double tap to mark as not completed" : "Double tap to mark as completed")
    }
}

private struct DailyChartValue: Identifiable {
    let day: LocalDay
    let count: Int
    var id: String { day.key }
}

struct HistoryView: View {
    @Bindable var container: AppContainer
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
                        metricCard("Current streak", value: "\(insights.currentStreak)", detail: "full days")
                        metricCard("Best streak", value: "\(insights.bestStreak)", detail: "full days")
                    }
                    metricCard("Completion", value: insights.completionPercentage.formatted(.percent.precision(.fractionLength(0))), detail: "\(insights.completed) of \(insights.possible) prayers since tracking began")

                    SalahCard {
                        Text("Last 7 Days").font(.headline)
                        Chart(chartValues) { value in
                            BarMark(
                                x: .value("Day", value.day.key),
                                y: .value("Completed", value.count)
                            )
                            .foregroundStyle(value.day == today ? Color.indigo : SalahPalette.accent)
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
                                    Text(date.formatted(date: .omitted, time: .shortened)).font(.caption)
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
        .navigationTitle("History")
        .task { records = (try? container.trackingRepository.allRecords()) ?? [] }
    }

    private func metricCard(_ title: String, value: String, detail: String) -> some View {
        SalahCard {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.largeTitle.bold().monospacedDigit())
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PrayerHistoryChartDescriptor: AXChartDescriptorRepresentable {
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
