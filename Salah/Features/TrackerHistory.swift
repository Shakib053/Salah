import Charts
@preconcurrency import CoreLocation
import AVFoundation
import Observation
import SwiftUI
import UIKit

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

private enum TrackerSection: String, CaseIterable, Identifiable {
    case prayers, tasbih, deeds, charity, insights

    var id: Self { self }

    var title: String {
        switch self {
        case .prayers: String(localized: "Ṣalāh")
        case .tasbih: String(localized: "Tasbih")
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

struct TrackerView: View {
    @Bindable var container: AppContainer
    @Environment(\.salahPalette) private var palette
    @State private var viewModel: TrackerViewModel
    @State private var selection = TrackerSection.prayers
    @State private var showingDatePicker = false
    @State private var records: [PrayerRecordSnapshot] = []
    @AppStorage("salah.deeds.istighfar-count") private var tasbihCount = 0
    @AppStorage("salah.deeds.tasbih-goal") private var tasbihGoal = 0
    @AppStorage("salah.deeds.good-deeds-mask") private var goodDeedsMask = 0
    @AppStorage("salah.deeds.good-deeds-day") private var goodDeedsDay = ""
    @AppStorage("salah.deeds.charity-total") private var charityTotal = 0
    @AppStorage("salah.deeds.charity-goal") private var charityGoal = 100
    @AppStorage("salah.deeds.charity-month") private var charityMonth = ""

    private let goodDeeds = [
        GoodDeedDefinition(id: 0, title: "Read the Qurʾān", symbol: "book.closed.fill"),
        GoodDeedDefinition(id: 1, title: "Morning and evening adhkār", symbol: "sun.horizon.fill"),
        GoodDeedDefinition(id: 2, title: "Gave ṣadaqah", symbol: "heart.fill")
    ]

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: TrackerViewModel(container: container))
    }

    var body: some View {
        VStack(spacing: 0) {
            trackerSectionPicker
                .padding(.horizontal)
                .padding(.top, 8)

            if selection == .tasbih {
                tasbihTracker
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        switch selection {
                        case .prayers: prayerTracker
                        case .tasbih: EmptyView()
                        case .deeds: goodDeedsTracker
                        case .charity: charityTracker
                        case .insights: insightsTracker
                        }
                    }
                    .padding()
                }
            }
        }
        .background(palette.screenBackground.ignoresSafeArea())
        .navigationTitle("Tracker")
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

    private var trackerSectionPicker: some View {
        Picker("Tracker section", selection: $selection) {
            ForEach(TrackerSection.allCases) { section in
                Text(section.title).tag(section)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityLabel("Tracker section")
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

    private var tasbihTracker: some View {
        TasbihCounterPad(count: $tasbihCount, goal: $tasbihGoal)
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

        VStack(spacing: 12) {
            ForEach(goodDeeds) { deed in
                SalahCard {
                    GoodDeedRow(
                        title: deed.title,
                        symbol: deed.symbol,
                        completed: isGoodDeedCompleted(deed.id),
                        accent: palette.accent
                    ) {
                        withAnimation(.snappy) {
                            toggleGoodDeed(deed.id)
                        }
                    }
                }
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

    private func isGoodDeedCompleted(_ id: Int) -> Bool {
        goodDeedsMask & (1 << id) != 0
    }

    private func toggleGoodDeed(_ id: Int) {
        if goodDeedsMask & (1 << id) != 0 {
            goodDeedsMask &= ~(1 << id)
        } else {
            goodDeedsMask |= (1 << id)
        }
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

private struct TasbihCounterPad: View {
    @Binding var count: Int
    @Binding var goal: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.salahPalette) private var palette
    @State private var resetArmed = false
    @State private var rippleExpanded = true
    @State private var showingCustomGoal = false
    @State private var customGoalText = ""
    @State private var showingGoalCompletion = false
    @State private var completedGoal = 0

    private let presetGoals = [33, 99, 100]

    private var goalProgress: Double {
        guard goal > 0 else { return 0 }
        return min(1, Double(count) / Double(goal))
    }

    private var customGoalValue: Int? {
        guard let value = Int(customGoalText), (1...999_999).contains(value) else { return nil }
        return value
    }

    var body: some View {
        GeometryReader { proxy in
            let contentHeight = min(proxy.size.height, 752)
            let contentTop = max(0, (proxy.size.height - contentHeight) / 2)
            let ringSize = min(460, max(280, min(proxy.size.width * 0.92, contentHeight * 0.62)))
            let countSize = min(136, max(80, proxy.size.width * 0.30))
            let handWidth = min(148, max(100, proxy.size.width * 0.25))
            let handHeight = handWidth * 86 / 72
            let ringCenterY = contentTop + contentHeight * 0.39
            let hintSpacing = min(88, max(52, contentHeight * 0.09))
            let hintHeight = handHeight + 42
            let preferredHintTop = ringCenterY + ringSize * 0.27 + hintSpacing
            let hintTop = min(preferredHintTop, proxy.size.height - hintHeight - 24)

            ZStack(alignment: .topTrailing) {
                Button(action: increment) {
                    ZStack {
                        padBackground

                        Circle()
                            .stroke(palette.accent.opacity(rippleExpanded ? 0 : 0.45), lineWidth: 2)
                            .frame(width: 96, height: 96)
                            .scaleEffect(rippleExpanded ? 1.7 : 0.35)
                            .position(x: proxy.size.width / 2, y: ringCenterY)

                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        stops: [
                                            .init(color: palette.groupedSurface.opacity(colorScheme == .dark ? 0.52 : 0.96), location: 0),
                                            .init(color: palette.groupedSurface.opacity(colorScheme == .dark ? 0.52 : 0.96), location: 0.27),
                                            .init(color: palette.groupedSurface.opacity(colorScheme == .dark ? 0.28 : 0.48), location: 0.29),
                                            .init(color: palette.groupedSurface.opacity(colorScheme == .dark ? 0.18 : 0.34), location: 0.54),
                                            .init(color: .clear, location: 0.56),
                                            .init(color: .clear, location: 0.73),
                                            .init(color: palette.groupedSurface.opacity(colorScheme == .dark ? 0.18 : 0.34), location: 0.75),
                                            .init(color: palette.groupedSurface.opacity(colorScheme == .dark ? 0.12 : 0.24), location: 0.98),
                                            .init(color: .clear, location: 1)
                                        ],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: ringSize / 2
                                    )
                                )
                                .frame(width: ringSize, height: ringSize)

                            if goal > 0 {
                                Circle()
                                    .trim(from: 0, to: goalProgress)
                                    .stroke(
                                        palette.accent,
                                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                    )
                                    .frame(width: ringSize * 0.72, height: ringSize * 0.72)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.snappy, value: goalProgress)
                            }

                            VStack(spacing: 8) {
                                Text(count, format: .number)
                                    .font(.system(size: countSize, weight: .semibold, design: .rounded).monospacedDigit())
                                    .tracking(-3)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.45)
                                Text("count")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                if goal > 0 {
                                    Text("\(count) of \(goal)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(palette.accentForeground)
                                }
                            }
                            .padding(.horizontal, 22)
                        }
                        .position(x: proxy.size.width / 2, y: ringCenterY)

                        VStack(spacing: 13) {
                            TasbihHandHint(color: palette.accent)
                                .frame(width: handWidth, height: handHeight)

                            Text("Tap anywhere to count")
                                .font(.system(size: min(21, max(16, proxy.size.width * 0.045)), weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(height: hintHeight, alignment: .top)
                        .position(x: proxy.size.width / 2, y: hintTop + hintHeight / 2)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
                .buttonStyle(TasbihPadButtonStyle())
                .accessibilityLabel("Tasbih counter. Current count \(count).")
                .accessibilityHint("Tap anywhere to increase the count")
                .accessibilityIdentifier("tasbih.counter")

                VStack {
                    HStack(alignment: .top) {
                        goalMenu
                        Spacer(minLength: 12)
                        resetButton
                    }
                    Spacer()
                }
                .padding(16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.05), lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Tasbih goal completed", isPresented: $showingGoalCompletion) {
            Button("OK") {
                count = 0
            }
        } message: {
            Text("You completed \(completedGoal) counts.")
        }
    }

    private var padBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            palette.groupedSurface,
                            palette.accentSoft.opacity(colorScheme == .dark ? 0.76 : 0.94)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            palette.groupedSurface.opacity(colorScheme == .dark ? 0.54 : 0.92),
                            palette.accent.opacity(colorScheme == .dark ? 0.07 : 0.04),
                            .clear
                        ],
                        center: UnitPoint(x: 0.5, y: 0.39),
                        startRadius: 4,
                        endRadius: 230
                    )
                )

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [palette.accent.opacity(0.10), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 170
                    )
                )
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .offset(y: 230)
        }
    }

    private var resetButton: some View {
        Button(action: handleReset) {
            Label(resetArmed ? "Tap again" : "Reset", systemImage: "arrow.counterclockwise")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .foregroundStyle(resetArmed ? Color.red : palette.accentForeground)
                .background(resetArmed ? Color.red.opacity(0.13) : palette.accentSoft, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(resetArmed ? "Confirm reset counter" : "Reset counter")
        .accessibilityIdentifier("tasbih.reset")
        .animation(.easeInOut(duration: 0.18), value: resetArmed)
    }

    private var goalMenu: some View {
        Menu {
            Button {
                selectGoal(0)
            } label: {
                if goal == 0 {
                    Label("No Goal", systemImage: "checkmark")
                } else {
                    Text("No Goal")
                }
            }

            ForEach(presetGoals, id: \.self) { preset in
                Button {
                    selectGoal(preset)
                } label: {
                    if goal == preset {
                        Label("\(preset)", systemImage: "checkmark")
                    } else {
                        Text("\(preset)")
                    }
                }
            }

            Divider()

            Button {
                customGoalText = goal > 0 ? String(goal) : ""
                showingCustomGoal = true
            } label: {
                Label("Custom…", systemImage: "number")
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "target")
                Text(goal > 0 ? "Goal: \(goal)" : "Set Goal")
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .foregroundStyle(palette.accentForeground)
            .background(palette.accentSoft, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(goal > 0 ? "Tasbih goal, \(goal)" : "Tasbih goal, none")
        .accessibilityIdentifier("tasbih.goal.menu")
        .alert("Custom Tasbih Goal", isPresented: $showingCustomGoal) {
            TextField("Goal count", text: $customGoalText)
                .keyboardType(.numberPad)
            Button("Set Goal") {
                if let customGoalValue {
                    selectGoal(customGoalValue)
                }
            }
            .disabled(customGoalValue == nil)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter a goal from 1 to 999,999.")
        }
    }

    private func increment() {
        let nextCount = count + 1
        count = nextCount

        if goal > 0, nextCount == goal {
            completedGoal = goal
            TasbihCompletionFeedback.shared.play()
            showingGoalCompletion = true
        } else {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }

        guard !reduceMotion else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            rippleExpanded = false
        }
        Task { @MainActor in
            await Task.yield()
            withAnimation(.easeOut(duration: 0.52)) {
                rippleExpanded = true
            }
        }
    }

    private func handleReset() {
        guard resetArmed else {
            resetArmed = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                resetArmed = false
            }
            return
        }

        count = 0
        resetArmed = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func selectGoal(_ newGoal: Int) {
        goal = newGoal
        if newGoal > 0, count >= newGoal {
            count = 0
        }
    }
}

private struct TasbihPadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? -0.015 : 0)
            .scaleEffect(configuration.isPressed ? 0.995 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct TasbihHandHint: View {
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / 72
            let fingertip = CGPoint(
                x: proxy.size.width * 34.5 / 72,
                y: proxy.size.height * 14 / 86
            )

            ZStack {
                Circle()
                    .stroke(color.opacity(0.22), lineWidth: 3 * scale)
                    .frame(width: 34 * scale, height: 34 * scale)
                    .position(fingertip)

                Circle()
                    .stroke(color.opacity(0.45), lineWidth: 3 * scale)
                    .frame(width: 20 * scale, height: 20 * scale)
                    .position(fingertip)

                TasbihFingerShape()
                    .stroke(
                        color,
                        style: StrokeStyle(
                            lineWidth: 3 * scale,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
            }
        }
        .accessibilityHidden(true)
    }
}

private struct TasbihFingerShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width / 72, y: rect.minY + y * rect.height / 86)
        }

        var path = Path()
        path.move(to: point(34.5, 14))
        path.addLine(to: point(34.5, 48))

        path.move(to: point(34.5, 48))
        path.addLine(to: point(34.5, 31.5))
        path.addCurve(
            to: point(39.5, 26),
            control1: point(34.5, 28.5),
            control2: point(36.5, 26)
        )
        path.addCurve(
            to: point(44.5, 31.4),
            control1: point(42.5, 26),
            control2: point(44.5, 28.4)
        )
        path.addLine(to: point(44.5, 45.5))
        path.addLine(to: point(44.5, 36.9))
        path.addCurve(
            to: point(49.5, 31.6),
            control1: point(44.5, 33.9),
            control2: point(46.5, 31.6)
        )
        path.addCurve(
            to: point(54.5, 37),
            control1: point(52.5, 31.6),
            control2: point(54.5, 34)
        )
        path.addLine(to: point(54.5, 47.6))
        path.addLine(to: point(54.5, 42.3))
        path.addCurve(
            to: point(59.5, 37.1),
            control1: point(54.5, 39.4),
            control2: point(56.6, 37.1)
        )
        path.addCurve(
            to: point(64.5, 42.3),
            control1: point(62.4, 37.1),
            control2: point(64.5, 39.4)
        )
        path.addLine(to: point(64.5, 56.2))
        path.addCurve(
            to: point(39.5, 82),
            control1: point(64.5, 71.7),
            control2: point(54, 82)
        )
        path.addLine(to: point(35.8, 82))
        path.addCurve(
            to: point(17.7, 71.4),
            control1: point(27.2, 82),
            control2: point(21.8, 77.4)
        )
        path.addLine(to: point(2.8, 54.7))
        path.addCurve(
            to: point(4.9, 46.9),
            control1: point(1.1, 52),
            control2: point(2.1, 48.4)
        )
        path.addCurve(
            to: point(12, 48.4),
            control1: point(7.3, 45.6),
            control2: point(10.3, 46.2)
        )
        path.addLine(to: point(19.5, 58.1))
        path.addLine(to: point(19.5, 14))
        path.addCurve(
            to: point(27, 6.5),
            control1: point(19.5, 9.8),
            control2: point(22.8, 6.5)
        )
        path.addCurve(
            to: point(34.5, 14),
            control1: point(31.2, 6.5),
            control2: point(34.5, 9.8)
        )
        path.closeSubpath()
        return path
    }
}

@MainActor
private final class TasbihCompletionFeedback {
    static let shared = TasbihCompletionFeedback()

    private var player: AVAudioPlayer?

    private init() { }

    func play() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        player = try? AVAudioPlayer(data: Self.completionChime)
        player?.volume = 0.45
        player?.prepareToPlay()
        player?.play()
    }

    private static let completionChime: Data = {
        let sampleRate: UInt32 = 44_100
        let duration = 0.52
        let sampleCount = Int(Double(sampleRate) * duration)
        let dataSize = UInt32(sampleCount * MemoryLayout<Int16>.size)
        var data = Data()

        func appendString(_ value: String) {
            data.append(contentsOf: value.utf8)
        }

        func appendInteger<T: FixedWidthInteger>(_ value: T) {
            var littleEndian = value.littleEndian
            withUnsafeBytes(of: &littleEndian) { bytes in
                data.append(contentsOf: bytes)
            }
        }

        appendString("RIFF")
        appendInteger(UInt32(36) + dataSize)
        appendString("WAVE")
        appendString("fmt ")
        appendInteger(UInt32(16))
        appendInteger(UInt16(1))
        appendInteger(UInt16(1))
        appendInteger(sampleRate)
        appendInteger(sampleRate * 2)
        appendInteger(UInt16(2))
        appendInteger(UInt16(16))
        appendString("data")
        appendInteger(dataSize)

        for sampleIndex in 0..<sampleCount {
            let time = Double(sampleIndex) / Double(sampleRate)
            let firstEnvelope = sineEnvelope(time, start: 0, end: 0.30)
            let secondEnvelope = sineEnvelope(time, start: 0.16, end: duration)
            let firstTone = sin(2 * Double.pi * 659.25 * time) * firstEnvelope
            let secondTone = sin(2 * Double.pi * 880.00 * time) * secondEnvelope
            let amplitude = (firstTone + secondTone) * 0.17
            appendInteger(Int16(clamping: Int(amplitude * Double(Int16.max))))
        }

        return data
    }()

    private static func sineEnvelope(_ time: Double, start: Double, end: Double) -> Double {
        guard time >= start, time <= end else { return 0 }
        let progress = (time - start) / (end - start)
        return sin(Double.pi * progress)
    }
}

struct TrackerPrayerRow: View {
    let prayer: PrayerType
    let completed: Bool
    let action: () -> Void
    @Environment(\.salahPalette) private var palette

    var body: some View {
        Button(action: action) {
            TrackerStatusRowContent(
                title: prayer.title,
                subtitle: completed ? "Completed" : "Not marked yet",
                completed: completed,
                accent: palette.accent
            ) {
                PrayerIcon(prayer: prayer)
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

private struct GoodDeedRow: View {
    let title: String
    let symbol: String
    let completed: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            TrackerStatusRowContent(
                title: title,
                subtitle: completed ? "Completed" : "Not marked yet",
                completed: completed,
                accent: accent
            ) {
                TrackerSymbolIcon(symbol: symbol)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(title)
        .accessibilityValue(completed ? "completed" : "not completed")
        .accessibilityHint(completed ? "Double tap to mark as not completed" : "Double tap to mark as completed")
    }
}

private struct TrackerStatusRowContent<Leading: View>: View {
    let title: String
    let subtitle: String
    let completed: Bool
    let accent: Color
    @ViewBuilder let leading: Leading

    var body: some View {
        HStack(spacing: 12) {
            leading
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(completed ? accent : .secondary)
                .accessibilityHidden(true)
        }
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
