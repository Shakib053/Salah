import Observation
import SwiftUI

@MainActor
@Observable
final class TodayViewModel {
    private let repository: any PrayerTimesRepository
    private let trackingRepository: any PrayerTrackingRepository
    private let settings: AppSettings

    var state: FeatureLoadState<PrayerDay> = .idle
    var previousDay: PrayerDay?
    var selectedPrayer: PrayerType?
    var completed: Set<PrayerType> = []
    private var requestID = UUID()

    init(container: AppContainer) {
        repository = container.prayerTimesRepository
        trackingRepository = container.trackingRepository
        settings = container.settings
    }

    func load(day: LocalDay, policy: CachePolicy = .cacheFirst) async {
        let token = UUID()
        requestID = token
        state = .loading
        let location = settings.location
        let calculation = settings.calculation
        do {
            async let main = repository.day(
                for: PrayerTimesQuery(day: day, location: location, settings: calculation),
                location: location,
                policy: policy
            )
            let priorLocalDay = day.adding(days: -1, in: location.timeZone)
            async let prior = try? repository.day(
                for: PrayerTimesQuery(day: priorLocalDay, location: location, settings: calculation),
                location: location,
                policy: .cacheFirst
            )
            let loaded = try await main
            let priorLoaded = await prior
            guard requestID == token else { return }
            previousDay = priorLoaded?.value
            completed = (try? trackingRepository.completedPrayerTypes(on: day)) ?? []
            state = loaded.isStale
                ? .offline(loaded.value, lastUpdated: loaded.value.fetchedAt)
                : .loaded(loaded.value, source: loaded.source)
        } catch is CancellationError {
            if requestID == token { state = .failed(.cancelled) }
        } catch let error as PrayerDataError {
            if requestID == token { state = .failed(error) }
        } catch {
            if requestID == token { state = .failed(.transport(error.localizedDescription)) }
        }
    }

    func toggle(_ prayer: PrayerType, on day: LocalDay, timeZone: TimeZone, source: String = "today") {
        let newValue = !completed.contains(prayer)
        do {
            try trackingRepository.setCompleted(newValue, prayer: prayer, day: day, timeZone: timeZone, source: source)
            if newValue { completed.insert(prayer) } else { completed.remove(prayer) }
        } catch { }
    }
}

struct TodayView: View {
    @Bindable var container: AppContainer
    @State private var viewModel: TodayViewModel
    @State private var showingDatePicker = false

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: TodayViewModel(container: container))
    }

    private var queryIdentity: String {
        PrayerTimesQuery(
            day: container.router.selectedDay,
            location: container.settings.location,
            settings: container.settings.calculation
        ).cacheKey
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView("Loading prayer times…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let day, _):
                dashboard(day: day, offlineDate: nil)
            case .offline(let day, let lastUpdated):
                dashboard(day: day, offlineDate: lastUpdated)
            case .failed(let error):
                PrayerDataUnavailableView(error: error) {
                    await viewModel.load(day: container.router.selectedDay, policy: .reload)
                }
            case .empty:
                ContentUnavailableView("No prayer times", systemImage: "calendar.badge.exclamationmark")
            case .permissionDenied:
                LocationEducationView(container: container)
            }
        }
        .navigationTitle("Today")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingDatePicker = true } label: {
                    Label("Choose date", systemImage: "calendar")
                }
                .accessibilityHint("Shows a date picker")
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            NavigationStack {
                DatePicker(
                    "Prayer date",
                    selection: Binding(
                        get: { container.router.selectedDay.date(in: container.settings.location.timeZone) ?? .now },
                        set: { container.router.selectedDay = LocalDay($0, timeZone: container.settings.location.timeZone) }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                .navigationTitle("Choose Date")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingDatePicker = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .task(id: queryIdentity) {
            await viewModel.load(day: container.router.selectedDay)
        }
    }

    @ViewBuilder
    private func dashboard(day: PrayerDay, offlineDate: Date?) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if let offlineDate { OfflineBanner(lastUpdated: offlineDate) }

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(day.gregorianSummary).font(.headline)
                        Text(day.hijriSummary).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if day.localDay != LocalDay(.now, timeZone: day.timeZone) {
                        Button("Today") { container.router.showToday(timeZone: container.settings.location.timeZone) }
                            .buttonStyle(.bordered)
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "location.fill").accessibilityHidden(true)
                    Text(container.settings.location.name)
                    if container.settings.location.isFallback {
                        Text("Default").font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 3)
                            .background(.orange.opacity(0.15), in: Capsule())
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

                if day.localDay == LocalDay(.now, timeZone: day.timeZone) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        currentPrayerCard(day: day, now: context.date)
                    }
                } else {
                    SalahCard {
                        Label("Schedule for selected date", systemImage: "calendar")
                            .font(.headline)
                        Text("Live countdowns are shown only for today.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    eventCard(title: "Sunrise", date: day.sunrise, symbol: "sunrise.fill", day: day)
                    eventCard(title: "Sunset", date: day.sunset, symbol: "sunset.fill", day: day)
                }

                Text("Prayer Schedule")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 0) {
                    ForEach(day.windows) { window in
                        Button {
                            viewModel.selectedPrayer = window.prayer
                        } label: {
                            PrayerScheduleRow(
                                window: window,
                                day: day,
                                preference: container.settings.calculation.timeFormat,
                                isActive: isActive(window, day: day),
                                isCompleted: viewModel.completed.contains(window.prayer)
                            )
                        }
                        .buttonStyle(.plain)
                        if window.prayer != .isha { Divider().padding(.leading, 62) }
                    }
                }
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))

                Text("Fasting")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 12) {
                    eventCard(title: "Sahri ends", date: day.sahri, symbol: "moon.stars.fill", day: day)
                    eventCard(title: "Iftar begins", date: day.iftar, symbol: "sun.horizon.fill", day: day)
                }

                Text("Times use \(day.methodName), \(container.settings.calculation.madhab.title). Confirm locally when necessary.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .refreshable {
            await viewModel.load(day: container.router.selectedDay, policy: .reload)
        }
        .sheet(item: $viewModel.selectedPrayer) { prayer in
            if let window = day.window(for: prayer) {
                PrayerDetailSheet(
                    window: window,
                    day: day,
                    container: container,
                    isCompleted: viewModel.completed.contains(prayer)
                ) {
                    viewModel.toggle(prayer, on: day.localDay, timeZone: day.timeZone, source: "detail")
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func isActive(_ window: PrayerWindow, day: PrayerDay) -> Bool {
        day.localDay == LocalDay(.now, timeZone: day.timeZone) && window.contains(.now)
    }

    @ViewBuilder
    private func currentPrayerCard(day: PrayerDay, now: Date) -> some View {
        let moment = PrayerTimeline.moment(now: now, today: day, previous: viewModel.previousDay)
        SalahCard(isTransparent: true) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle().stroke(.white.opacity(0.25), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: moment.progress)
                        .stroke(.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: moment.current?.prayer.symbol ?? "clock.fill")
                        .font(.title2)
                }
                .frame(width: 78, height: 78)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(moment.current == nil ? "Next prayer" : "Current prayer")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                    Text((moment.current ?? moment.next)?.prayer.title ?? "Schedule complete")
                        .font(.title.bold())
                    if let remaining = moment.remaining {
                        Text(PrayerDateFormatting.countdown(remaining))
                            .font(.title3.bold().monospacedDigit())
                        Text(moment.current == nil ? "until it begins" : "remaining in this window")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                Spacer()
            }
            .foregroundStyle(.white)
        }
        .background(
            LinearGradient(colors: [SalahPalette.accent, SalahPalette.accentSecondary], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20)
        )
        .accessibilityElement(children: .combine)
    }

    private func eventCard(title: String, date: Date, symbol: String, day: PrayerDay) -> some View {
        SalahCard {
            Image(systemName: symbol).foregroundStyle(SalahPalette.warm).accessibilityHidden(true)
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(PrayerDateFormatting.time(date, preference: container.settings.calculation.timeFormat, timeZone: day.timeZone))
                .font(.headline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .accessibilityElement(children: .combine)
    }
}

struct PrayerScheduleRow: View {
    let window: PrayerWindow
    let day: PrayerDay
    let preference: TimeFormatPreference
    let isActive: Bool
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: 12) {
            PrayerIcon(prayer: window.prayer, active: isActive)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(window.prayer.title).font(.headline)
                    if isActive { StatusBadge(text: "Current", symbol: "clock.fill") }
                    if isCompleted { Image(systemName: "checkmark.circle.fill").foregroundStyle(SalahPalette.accent).accessibilityLabel("Completed") }
                }
                Text("Ends \(PrayerDateFormatting.time(window.displayEnd, preference: preference, timeZone: day.timeZone))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(PrayerDateFormatting.time(window.start, preference: preference, timeZone: day.timeZone))
                .font(.headline.monospacedDigit())
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .frame(minHeight: 64)
        .background(isActive ? SalahPalette.accent.opacity(0.08) : .clear)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(window.prayer.title), starts \(PrayerDateFormatting.time(window.start, preference: preference, timeZone: day.timeZone)), ends \(PrayerDateFormatting.time(window.displayEnd, preference: preference, timeZone: day.timeZone))\(isActive ? ", current prayer" : "")\(isCompleted ? ", completed" : "")")
        .accessibilityHint("Opens prayer details")
    }
}

struct PrayerDetailSheet: View {
    let window: PrayerWindow
    let day: PrayerDay
    @Bindable var container: AppContainer
    let isCompleted: Bool
    let toggleCompletion: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showingReminderEducation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    PrayerIcon(prayer: window.prayer, active: window.contains(.now))
                        .scaleEffect(1.25)
                        .padding(.top)
                    Text(window.prayer.title).font(.largeTitle.bold())
                    if window.contains(.now) { StatusBadge(text: "Current prayer", symbol: "clock.fill") }

                    HStack(spacing: 12) {
                        detailBox("Starts", window.start)
                        detailBox("Ends", window.displayEnd)
                    }
                    SalahCard {
                        Label("Calculation", systemImage: "function")
                            .font(.headline)
                        Text("\(day.methodName) · \(container.settings.calculation.madhab.title)")
                        Text("Prayer windows may differ from local authorities. Review your calculation settings and confirm locally when needed.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }

                    Button(isCompleted ? "Mark as Not Completed" : "Mark as Completed") {
                        toggleCompletion()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                    Button(container.settings.reminder(for: PrayerEvent(rawValue: window.prayer.rawValue) ?? .fajr).enabled ? "Manage Reminder" : "Enable Reminder") {
                        showingReminderEducation = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding()
            }
            .navigationTitle("Prayer Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showingReminderEducation) {
                ReminderEducationSheet(event: PrayerEvent(rawValue: window.prayer.rawValue) ?? .fajr, container: container)
                    .presentationDetents([.medium])
            }
        }
    }

    private func detailBox(_ title: String, _ date: Date) -> some View {
        SalahCard {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(PrayerDateFormatting.time(date, preference: container.settings.calculation.timeFormat, timeZone: day.timeZone))
                .font(.title3.bold().monospacedDigit())
        }
    }
}

@MainActor
@Observable
final class CalendarViewModel {
    private let repository: any PrayerTimesRepository
    private let tracking: any PrayerTrackingRepository
    private let settings: AppSettings
    var state: FeatureLoadState<[PrayerDay]> = .idle
    var selectedDay: LocalDay
    var monthAnchor: LocalDay
    var trackerDays: Set<LocalDay> = []
    var selectedPrayer: PrayerType?

    init(container: AppContainer) {
        repository = container.prayerTimesRepository
        tracking = container.trackingRepository
        settings = container.settings
        let today = LocalDay(.now, timeZone: settings.location.timeZone)
        selectedDay = today
        monthAnchor = LocalDay(year: today.year, month: today.month, day: 1)
    }

    func load(policy: CachePolicy = .cacheFirst) async {
        state = .loading
        do {
            let loaded = try await repository.month(
                containing: monthAnchor,
                location: settings.location,
                settings: settings.calculation,
                policy: policy
            )
            trackerDays = Set((try? tracking.allRecords().filter(\.completed).map(\.localDay)) ?? [])
            let days = loaded.map(\.value)
            if loaded.contains(where: \.isStale), let timestamp = days.map(\.fetchedAt).max() {
                state = .offline(days, lastUpdated: timestamp)
            } else {
                state = .loaded(days, source: loaded.contains { $0.source == .network } ? .network : .diskCache)
            }
        } catch let error as PrayerDataError {
            state = .failed(error)
        } catch {
            state = .failed(.transport(error.localizedDescription))
        }
    }

    func moveMonth(_ amount: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = settings.location.timeZone
        guard let date = monthAnchor.date(in: settings.location.timeZone),
              let moved = calendar.date(byAdding: .month, value: amount, to: date) else { return }
        let local = LocalDay(moved, timeZone: settings.location.timeZone)
        monthAnchor = LocalDay(year: local.year, month: local.month, day: 1)
        selectedDay = monthAnchor
    }
}

struct PrayerCalendarView: View {
    @Bindable var container: AppContainer
    @State private var viewModel: CalendarViewModel
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: CalendarViewModel(container: container))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView("Loading month…")
            case .loaded(let days, _): calendar(days: days, offline: nil)
            case .offline(let days, let date): calendar(days: days, offline: date)
            case .failed(let error):
                PrayerDataUnavailableView(error: error) { await viewModel.load(policy: .reload) }
            case .empty:
                ContentUnavailableView("No calendar data", systemImage: "calendar.badge.exclamationmark")
            case .permissionDenied:
                Text("Choose a prayer location in More.")
            }
        }
        .navigationTitle("Calendar")
        .task(id: "\(viewModel.monthAnchor.key)|\(container.settings.location.name)|\(container.settings.calculation)") {
            await viewModel.load()
        }
    }

    private func calendar(days: [PrayerDay], offline: Date?) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if let offline { OfflineBanner(lastUpdated: offline) }
                HStack {
                    Button { viewModel.moveMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    Spacer()
                    Text(monthTitle).font(.title3.bold())
                    Spacer()
                    Button { viewModel.moveMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                }

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Calendar.current.shortWeekdaySymbols, id: \.self) { symbol in
                        Text(symbol).font(.caption.bold()).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }
                    ForEach(0..<leadingBlankCount, id: \.self) { _ in Color.clear.frame(height: 44) }
                    ForEach(days) { day in
                        calendarCell(day)
                    }
                }

                if let selected = days.first(where: { $0.localDay == viewModel.selectedDay }) {
                    SalahCard {
                        Text(selected.gregorianSummary).font(.headline)
                        Text(selected.hijriSummary).foregroundStyle(.secondary)
                        if viewModel.trackerDays.contains(selected.localDay) {
                            StatusBadge(text: "Has tracker records", symbol: "checkmark.circle.fill")
                        }
                        Button("Open in Today") { container.router.show(selected.localDay) }
                            .buttonStyle(.bordered)
                    }
                    VStack(spacing: 0) {
                        ForEach(selected.windows) { window in
                            Button { viewModel.selectedPrayer = window.prayer } label: {
                                PrayerScheduleRow(
                                    window: window,
                                    day: selected,
                                    preference: container.settings.calculation.timeFormat,
                                    isActive: false,
                                    isCompleted: (try? container.trackingRepository.completedPrayerTypes(on: selected.localDay).contains(window.prayer)) ?? false
                                )
                            }
                            .buttonStyle(.plain)
                            if window.prayer != .isha { Divider().padding(.leading, 62) }
                        }
                    }
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
                    .sheet(item: $viewModel.selectedPrayer) { prayer in
                        if let window = selected.window(for: prayer) {
                            PrayerDetailSheet(
                                window: window,
                                day: selected,
                                container: container,
                                isCompleted: (try? container.trackingRepository.completedPrayerTypes(on: selected.localDay).contains(prayer)) ?? false
                            ) {
                                let current = (try? container.trackingRepository.completedPrayerTypes(on: selected.localDay).contains(prayer)) ?? false
                                try? container.trackingRepository.setCompleted(!current, prayer: prayer, day: selected.localDay, timeZone: selected.timeZone, source: "calendar")
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .refreshable { await viewModel.load(policy: .reload) }
    }

    private func calendarCell(_ day: PrayerDay) -> some View {
        let today = LocalDay(.now, timeZone: day.timeZone)
        let selected = day.localDay == viewModel.selectedDay
        return Button {
            viewModel.selectedDay = day.localDay
        } label: {
            ZStack(alignment: .bottom) {
                Text("\(day.localDay.day)")
                    .font(.body.weight(selected ? .bold : .regular))
                    .foregroundStyle(selected ? .white : .primary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(selected ? SalahPalette.accent : .clear, in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        if day.localDay == today, !selected {
                            RoundedRectangle(cornerRadius: 12).stroke(SalahPalette.accent, lineWidth: 2)
                        }
                    }
                if viewModel.trackerDays.contains(day.localDay) {
                    Circle().fill(selected ? .white : SalahPalette.accent).frame(width: 5, height: 5).padding(.bottom, 4)
                }
            }
        }
        .accessibilityLabel("\(day.gregorianSummary)\(day.localDay == today ? ", today" : "")\(viewModel.trackerDays.contains(day.localDay) ? ", has tracker records" : "")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var monthTitle: String {
        guard let date = viewModel.monthAnchor.date(in: container.settings.location.timeZone) else { return viewModel.monthAnchor.key }
        return date.formatted(.dateTime.month(.wide).year())
    }

    private var leadingBlankCount: Int {
        guard let date = viewModel.monthAnchor.date(in: container.settings.location.timeZone) else { return 0 }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = container.settings.location.timeZone
        return max(0, calendar.component(.weekday, from: date) - 1)
    }
}
