import Charts
@preconcurrency import CoreLocation
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
            WidgetDataPublisher.updateCompletion(
                prayer: prayer,
                day: selectedDay,
                completed: value
            )
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

private enum DeedsSection: String, CaseIterable, Identifiable {
    case prayers, repentance, deeds, charity, insights

    var id: Self { self }

    var title: String {
        switch self {
        case .prayers: String(localized: "Ṣalāh")
        case .repentance: String(localized: "Dhikr")
        case .deeds: String(localized: "Deeds")
        case .charity: String(localized: "Charity")
        case .insights: String(localized: "Insights")
        }
    }
}

private struct GoodDeedDefinition: Identifiable {
    let id: Int
    let title: String
    let symbol: String
}

struct DeedsView: View {
    @Bindable var container: AppContainer
    @Environment(\.salahPalette) private var palette
    @State private var viewModel: TrackerViewModel
    @State private var selection = DeedsSection.prayers
    @State private var showingDatePicker = false
    @State private var records: [PrayerRecordSnapshot] = []
    @AppStorage("salah.deeds.istighfar-count") private var istighfarCount = 0
    @AppStorage("salah.deeds.good-deeds-mask") private var goodDeedsMask = 0
    @AppStorage("salah.deeds.good-deeds-day") private var goodDeedsDay = ""
    @AppStorage("salah.deeds.charity-total") private var charityTotal = 0
    @AppStorage("salah.deeds.charity-goal") private var charityGoal = 100
    @AppStorage("salah.deeds.charity-month") private var charityMonth = ""

    private let goodDeeds = [
        GoodDeedDefinition(id: 0, title: "Read the Qurʾān", symbol: "book.closed.fill"),
        GoodDeedDefinition(id: 1, title: "Morning and evening adhkār", symbol: "sun.horizon.fill"),
        GoodDeedDefinition(id: 2, title: "Gave ṣadaqah", symbol: "heart.fill"),
        GoodDeedDefinition(id: 3, title: "Helped someone in need", symbol: "hands.sparkles.fill"),
        GoodDeedDefinition(id: 4, title: "Kept ties of kinship", symbol: "person.2.fill"),
        GoodDeedDefinition(id: 5, title: "Made duʿāʾ for others", symbol: "sparkles")
    ]

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: TrackerViewModel(container: container))
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Deeds category", selection: $selection) {
                ForEach(DeedsSection.allCases) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            ScrollView {
                LazyVStack(spacing: 16) {
                    switch selection {
                    case .prayers: prayerTracker
                    case .repentance: repentanceTracker
                    case .deeds: goodDeedsTracker
                    case .charity: charityTracker
                    case .insights: insightsTracker
                    }
                }
                .padding()
            }
        }
        .background(palette.screenBackground.ignoresSafeArea())
        .navigationTitle("Deeds")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if selection == .prayers {
                    Button { showingDatePicker = true } label: { Label("Choose date", systemImage: "calendar") }
                }
                NavigationLink {
                    HistoryView(container: container)
                } label: {
                    Label("Prayer history", systemImage: "chart.bar.fill")
                }
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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .navigationTitle("Choose Date")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingDatePicker = false } } }
            }
            .presentationDetents([.fraction(0.70)])
        }
        .safeAreaInset(edge: .bottom) {
            if selection == .prayers, viewModel.lastChanged != nil {
                HStack {
                    Text("Prayer tracking updated")
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
        .task {
            prepareLocalTrackers()
            refreshRecords()
        }
        .onChange(of: selection) { _, newValue in
            if newValue == .insights { refreshRecords() }
        }
    }

    @ViewBuilder
    private var prayerTracker: some View {
        SalahCard(isTransparent: true) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isToday ? "Today’s Ṣalāh" : PrayerDateFormatting.fullDate(viewModel.selectedDay, timeZone: container.settings.location.timeZone))
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
            LinearGradient(colors: [palette.heroStart, palette.heroEnd], startPoint: .topLeading, endPoint: .bottomTrailing),
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
    }

    @ViewBuilder
    private var repentanceTracker: some View {
        SalahCard {
            Text("Istighfār counter")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            ZStack {
                Circle().stroke(palette.accent.opacity(0.15), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: min(1, Double(istighfarCount) / 100))
                    .stroke(palette.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 4) {
                    Text("\(istighfarCount)")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold).monospacedDigit())
                    Text("of 100")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 190, height: 190)
            .frame(maxWidth: .infinity)
            Text("Astaghfirullāh")
                .font(.title2.bold())
                .foregroundStyle(palette.accent)
                .frame(maxWidth: .infinity)
            Text("I seek the forgiveness of Allah")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }

        Button("Count", systemImage: "plus") { istighfarCount += 1 }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)

        Button("Reset", systemImage: "arrow.counterclockwise", role: .destructive) { istighfarCount = 0 }
            .buttonStyle(.bordered)

        Text("This private counter is a quiet reminder, never a public score.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private var goodDeedsTracker: some View {
        HStack {
            Text("Good deeds today").font(.title3.bold())
            Spacer()
            Text("\(goodDeedsCount) of \(goodDeeds.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }

        SalahCard {
            ForEach(goodDeeds) { deed in
                Toggle(isOn: goodDeedBinding(deed.id)) {
                    Label(deed.title, systemImage: deed.symbol)
                }
                .frame(minHeight: 44)
                if deed.id != goodDeeds.last?.id { Divider() }
            }
        }

        Text("These reflections stay on this device and reset only when you choose to change them.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var charityTracker: some View {
        SalahCard {
            Text("Given this month")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline) {
                Text(charityTotal, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .font(.largeTitle.bold().monospacedDigit())
                Spacer()
                Text("of \(charityGoal, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(charityTotal), total: Double(max(1, charityGoal)))
            Stepper("Monthly intention: \(charityGoal, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))", value: $charityGoal, in: 10...10_000, step: 10)
            Button("Record 5", systemImage: "heart.fill") { charityTotal += 5 }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
        }

        SalahCard {
            Label("Give with intention", systemImage: "heart.text.square.fill")
                .font(.headline)
            Text("Salah does not process donations. Use this local total to reflect on charity you gave through organizations you trust.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var insightsTracker: some View {
        if records.filter(\.completed).isEmpty {
            ContentUnavailableView {
                Label("No insights yet", systemImage: "chart.bar")
            } description: {
                Text("Completed prayers will create a private history here.")
            }
            .frame(minHeight: 300)
        } else {
            HStack(spacing: 12) {
                insightCard("Current streak", value: "\(insights.currentStreak)", detail: "full days")
                insightCard("Best streak", value: "\(insights.bestStreak)", detail: "full days")
            }

            SalahCard {
                HStack {
                    Text("Last 7 Days").font(.headline)
                    Spacer()
                    Text(insights.completionPercentage, format: .percent.precision(.fractionLength(0)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Chart(chartValues) { value in
                    BarMark(
                        x: .value("Day", value.day.key),
                        y: .value("Completed", value.count)
                    )
                    .foregroundStyle(value.day == today ? palette.heroStart : palette.accent)
                    .cornerRadius(5)
                }
                .chartYScale(domain: 0...5)
                .frame(height: 190)
                .accessibilityChartDescriptor(PrayerHistoryChartDescriptor(values: chartValues))
            }

            NavigationLink {
                HistoryView(container: container)
            } label: {
                Label("Open Full Prayer History", systemImage: "clock.arrow.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private var today: LocalDay {
        LocalDay(.now, timeZone: container.settings.location.timeZone)
    }

    private var insights: TrackerInsights {
        TrackerInsightCalculator.calculate(records: records, today: today, timeZone: container.settings.location.timeZone)
    }

    private var chartValues: [DailyChartValue] {
        (0..<7).reversed().map { offset in
            let day = today.adding(days: -offset, in: container.settings.location.timeZone)
            return DailyChartValue(day: day, count: Set(records.filter { $0.localDay == day && $0.completed }.map(\.prayer)).count)
        }
    }

    private var goodDeedsCount: Int {
        goodDeeds.filter { goodDeedsMask & (1 << $0.id) != 0 }.count
    }

    private func goodDeedBinding(_ id: Int) -> Binding<Bool> {
        Binding(
            get: { goodDeedsMask & (1 << id) != 0 },
            set: { enabled in
                if enabled {
                    goodDeedsMask |= (1 << id)
                } else {
                    goodDeedsMask &= ~(1 << id)
                }
            }
        )
    }

    private func refreshRecords() {
        records = (try? container.trackingRepository.allRecords()) ?? []
    }

    private func prepareLocalTrackers() {
        if goodDeedsDay != today.key {
            goodDeedsDay = today.key
            goodDeedsMask = 0
        }
        let month = String(format: "%04d-%02d", today.year, today.month)
        if charityMonth != month {
            charityMonth = month
            charityTotal = 0
        }
    }

    private func insightCard(_ title: String, value: String, detail: String) -> some View {
        SalahCard {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.largeTitle.bold().monospacedDigit())
            Text(detail).font(.caption).foregroundStyle(.secondary)
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
    @Environment(\.salahPalette) private var palette

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
                    .foregroundStyle(completed ? palette.accent : .secondary)
                    .accessibilityHidden(true)
            }
            .padding()
            .frame(minHeight: 64)
            .background(palette.groupedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(prayer.title), \(completed ? "completed" : "not completed")")
        .accessibilityHint(completed ? "Double tap to mark as not completed" : "Double tap to mark as completed")
    }
}

@MainActor
@Observable
final class QiblaHeadingProvider: NSObject, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var heading: Double?
    private(set) var accuracy: Double?
    private(set) var isAvailable = CLLocationManager.headingAvailable()

    override init() {
        super.init()
        manager.delegate = self
        manager.headingFilter = 1
    }

    func start() {
        isAvailable = CLLocationManager.headingAvailable()
        guard isAvailable else { return }
        manager.startUpdatingHeading()
    }

    func stop() {
        manager.stopUpdatingHeading()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        accuracy = newHeading.headingAccuracy
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        (accuracy ?? 0) > 20
    }
}

enum QiblaGeometry {
    static let kaaba = CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)

    static func bearing(from location: PrayerLocation) -> Double {
        let latitude = location.latitude * .pi / 180
        let longitude = location.longitude * .pi / 180
        let destinationLatitude = kaaba.latitude * .pi / 180
        let destinationLongitude = kaaba.longitude * .pi / 180
        let delta = destinationLongitude - longitude
        let bearingYComponent = sin(delta) * cos(destinationLatitude)
        let bearingXComponent = cos(latitude) * sin(destinationLatitude) - sin(latitude) * cos(destinationLatitude) * cos(delta)
        return normalized(atan2(bearingYComponent, bearingXComponent) * 180 / .pi)
    }

    static func distance(from location: PrayerLocation) -> Measurement<UnitLength> {
        let origin = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let destination = CLLocation(latitude: kaaba.latitude, longitude: kaaba.longitude)
        return Measurement(value: origin.distance(from: destination), unit: .meters).converted(to: .kilometers)
    }

    static func normalized(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value >= 0 ? value : value + 360
    }

    static func shortestAngle(_ degrees: Double) -> Double {
        let value = normalized(degrees)
        return value > 180 ? value - 360 : value
    }
}

struct QiblaView: View {
    @Bindable var container: AppContainer
    @Environment(\.salahPalette) private var palette
    @State private var headingProvider = QiblaHeadingProvider()

    private var qiblaBearing: Double {
        QiblaGeometry.bearing(from: container.settings.location)
    }

    private var relativeBearing: Double {
        QiblaGeometry.shortestAngle(qiblaBearing - (headingProvider.heading ?? 0))
    }

    private var isAligned: Bool {
        headingProvider.heading != nil && abs(relativeBearing) < 6
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Label(container.settings.location.name, systemImage: "location.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if headingProvider.isAvailable {
                    compass
                    Label(
                        isAligned ? "Aligned — facing the Kaʿbah" : "Turn until the marker points up",
                        systemImage: isAligned ? "checkmark.circle.fill" : "location.north.line.fill"
                    )
                    .font(.headline)
                    .foregroundStyle(isAligned ? palette.accent : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                } else {
                    ContentUnavailableView {
                        Label("Compass Unavailable", systemImage: "location.slash")
                    } description: {
                        Text("This device does not provide live heading updates. The calculated Qibla bearing is still shown below.")
                    }
                    .frame(minHeight: 260)
                }

                HStack(spacing: 12) {
                    qiblaMetric("Heading", value: headingProvider.heading.map { "\(Int($0.rounded()))°" } ?? "—")
                    qiblaMetric("Qibla", value: "\(Int(qiblaBearing.rounded()))°")
                    qiblaMetric("To Makkah", value: QiblaGeometry.distance(from: container.settings.location).formatted(.measurement(width: .abbreviated, usage: .road)))
                }

                SalahCard {
                    Label("Compass guidance", systemImage: "iphone.gen3.radiowaves.left.and.right")
                        .font(.headline)
                    Text("Hold the iPhone flat and turn slowly. Move away from metal, magnets, and electronic equipment if the heading drifts.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let accuracy = headingProvider.accuracy, accuracy > 20 {
                        Label("Compass accuracy is currently low", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding()
        }
        .background(palette.screenBackground.ignoresSafeArea())
        .navigationTitle("Qibla")
        .onAppear { headingProvider.start() }
        .onDisappear { headingProvider.stop() }
    }

    private var compass: some View {
        ZStack {
            Circle()
                .fill(Color(uiColor: .secondarySystemBackground))
            Circle()
                .stroke(Color(uiColor: .separator), lineWidth: 1)
            Circle()
                .stroke(Color(uiColor: .separator), style: StrokeStyle(lineWidth: 1, dash: [2, 8]))
                .padding(24)

            ZStack {
                Text("N").font(.headline).frame(maxHeight: .infinity, alignment: .top).padding(.top, 18)
                Text("S").font(.headline).frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 18)
                Text("W").font(.headline).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 18)
                Text("E").font(.headline).frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 18)
            }
            .rotationEffect(.degrees(-(headingProvider.heading ?? 0)))
            .animation(.smooth(duration: 0.45), value: headingProvider.heading)

            VStack(spacing: 5) {
                Image(systemName: "building.columns.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(palette.accent, in: RoundedRectangle(cornerRadius: 10))
                Image(systemName: "arrowtriangle.up.fill")
                    .foregroundStyle(palette.accent)
                Rectangle()
                    .fill(LinearGradient(colors: [palette.accent, .clear], startPoint: .top, endPoint: .bottom))
                    .frame(width: 2, height: 72)
                Spacer(minLength: 0)
            }
            .padding(.top, 8)
            .rotationEffect(.degrees(relativeBearing))
            .animation(.smooth(duration: 0.45), value: relativeBearing)

            Circle()
                .fill(Color.primary)
                .frame(width: 16, height: 16)
                .overlay {
                    if isAligned {
                        Circle().stroke(palette.accent, lineWidth: 3).frame(width: 52, height: 52)
                    }
                }
        }
        .frame(width: 270, height: 270)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Qibla compass")
        .accessibilityValue(headingProvider.heading == nil ? "Waiting for heading" : "Qibla is \(Int(abs(relativeBearing).rounded())) degrees \(relativeBearing < 0 ? "left" : "right")")
    }

    private func qiblaMetric(_ title: String, value: String) -> some View {
        SalahCard {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.headline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }
}

private struct DailyChartValue: Identifiable {
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
        .background(palette.screenBackground.ignoresSafeArea())
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
