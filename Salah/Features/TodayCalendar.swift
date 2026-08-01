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
            let tomorrowLocalDay = day.adding(days: 1, in: location.timeZone)
            async let prior = try? repository.day(
                for: PrayerTimesQuery(day: priorLocalDay, location: location, settings: calculation),
                location: location,
                policy: .cacheFirst
            )
            async let tomorrow = try? repository.day(
                for: PrayerTimesQuery(day: tomorrowLocalDay, location: location, settings: calculation),
                location: location,
                policy: .cacheFirst
            )
            let loaded = try await main
            let priorLoaded = await prior
            let tomorrowLoaded = await tomorrow
            guard requestID == token else { return }
            previousDay = priorLoaded?.value
            completed = (try? trackingRepository.completedPrayerTypes(on: day)) ?? []
            WidgetDataPublisher.save(
                prayerDay: loaded.value,
                completed: completed,
                tomorrowFajr: tomorrowLoaded?.value.window(for: .fajr)?.start
            )
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
            WidgetDataPublisher.updateCompletion(prayer: prayer, day: day, completed: newValue)
        } catch { }
    }
}

struct TodayView: View {
    @Bindable var container: AppContainer
    @Environment(\.salahPalette) private var palette
    @State private var viewModel: TodayViewModel
    @State private var showingDistricts = false
    @State private var showingCurrentLocation = false

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
            case let .offline(day, lastUpdated):
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
        .background(palette.screenBackground.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button("Use Current Location", systemImage: "location.fill") {
                        showingCurrentLocation = true
                    }
                    Button("Choose District Manually", systemImage: "map.fill") {
                        showingDistricts = true
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "location.fill")
                        Text(container.settings.location.name)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .layoutPriority(1)
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .accessibilityLabel("Prayer location, \(container.settings.location.name)")
                .accessibilityHint("Shows options to change the prayer location")
                .accessibilityIdentifier("today.location.menu")
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    RemindersView(container: container)
                } label: {
                    Label("Prayer reminders", systemImage: "bell")
                }
            }
        }
        .sheet(isPresented: $showingDistricts) {
            NavigationStack {
                DistrictPickerView(districts: container.districts) { district in
                    showingDistricts = false
                    updateLocation(district.prayerLocation)
                }
            }
        }
        .sheet(isPresented: $showingCurrentLocation) {
            CurrentLocationSettingsSheet(container: container) { location in
                showingCurrentLocation = false
                updateLocation(location)
            }
            .presentationDetents([.medium, .large])
        }
        .task(id: queryIdentity) {
            await viewModel.load(day: container.router.selectedDay)
        }
    }

    @ViewBuilder
    private func dashboard(day: PrayerDay, offlineDate: Date?) -> some View {
        ScrollView {
            LazyVStack(spacing: 14) {
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

                if day.localDay == LocalDay(.now, timeZone: day.timeZone) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        CurrentPrayerCard(
                            moment: PrayerTimeline.moment(
                                now: context.date,
                                today: day,
                                previous: viewModel.previousDay
                            ),
                            now: context.date
                        )
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

                HStack(alignment: .firstTextBaseline) {
                    Text("PRAYER SCHEDULE")
                        .font(.footnote.bold())
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Prayer Schedule")
                    Spacer()
                    Text("\(viewModel.completed.count) of 5 prayed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)

                VStack(spacing: 0) {
                    ForEach(day.windows) { window in
                        Button {
                            viewModel.toggle(window.prayer, on: day.localDay, timeZone: day.timeZone)
                        } label: {
                            PrayerScheduleRow(
                                window: window,
                                day: day,
                                preference: container.settings.calculation.timeFormat,
                                isActive: isActive(window, day: day),
                                isCompleted: viewModel.completed.contains(window.prayer),
                                showsDisclosure: false
                            )
                        }
                        .buttonStyle(.plain)
                        if window.prayer != .isha { Divider().padding(.leading, 62) }
                    }
                }
                .background(palette.groupedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                HStack(spacing: 12) {
                    eventCard(title: "Sunrise", date: day.sunrise, symbol: "sunrise.fill", day: day)
                    eventCard(title: "Sunset", date: day.sunset, symbol: "sunset.fill", day: day)
                }

                Text("FASTING")
                    .font(.footnote.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                HStack(spacing: 12) {
                    eventCard(title: "Sahri ends", date: day.sahri, symbol: "moon.stars.fill", day: day)
                    eventCard(title: "Iftar begins", date: day.iftar, symbol: "sun.horizon.fill", day: day)
                }

                Text("Times use \(day.methodName), \(container.settings.calculation.madhab.title). Confirm locally when necessary.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(palette.screenBackground)
        .refreshable {
            await viewModel.load(day: container.router.selectedDay, policy: .reload)
        }
    }

    private func isActive(_ window: PrayerWindow, day: PrayerDay) -> Bool {
        day.localDay == LocalDay(.now, timeZone: day.timeZone) && window.contains(.now)
    }

    private func eventCard(title: String, date: Date, symbol: String, day: PrayerDay) -> some View {
        SalahCard {
            Image(systemName: symbol).foregroundStyle(palette.warm).accessibilityHidden(true)
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(PrayerDateFormatting.time(date, preference: container.settings.calculation.timeFormat, timeZone: day.timeZone))
                .font(.headline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .accessibilityElement(children: .combine)
    }

    private func updateLocation(_ location: PrayerLocation) {
        let oldSignature = PrayerTimesQuery(
            day: container.router.selectedDay,
            location: container.settings.location,
            settings: container.settings.calculation
        ).signature
        container.settings.location = location
        container.router.selectedDay = LocalDay(.now, timeZone: location.timeZone)
        Task {
            await container.prayerTimesRepository.invalidate(signature: oldSignature)
            await ReminderCoordinator.reconcile(container: container)
        }
    }
}

struct CurrentPrayerCard: View {
    let moment: PrayerMoment
    let now: Date
    @Environment(\.salahPalette) private var palette

    var body: some View {
        let displayed = moment.current ?? moment.next
        let countdown = moment.current.map { max(0, $0.end.timeIntervalSince(now)) } ?? moment.next.map { max(0, $0.start.timeIntervalSince(now)) }
        SalahCard(isTransparent: true) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle().stroke(.white.opacity(0.22), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: moment.progress)
                        .stroke(.white, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: moment.current?.prayer.symbol ?? "clock.fill")
                        .font(.title2)
                }
                .frame(width: 92, height: 92)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(moment.current != nil ? "Current prayer" : (moment.next.map { "Next prayer · \($0.prayer.title)" } ?? "Current prayer"))
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(0.7)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(displayed?.prayer.title ?? "Schedule complete")
                        .font(.title.bold())
                    if let remaining = countdown {
                        Text(PrayerDateFormatting.countdown(remaining))
                            .font(.title2.bold().monospacedDigit())
                        Text(moment.current != nil ? "Waqt ends in" : (moment.next.map { "until \($0.prayer.title) begins" } ?? "Waqt ends in"))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                Spacer()
            }
            .foregroundStyle(.white)
        }
        .background(
            palette.heroGradient,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .shadow(color: palette.heroEnd.opacity(0.28), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
    }
}

struct PrayerScheduleRow: View {
    let window: PrayerWindow
    let day: PrayerDay
    let preference: TimeFormatPreference
    let isActive: Bool
    let isCompleted: Bool
    var showsDisclosure = true
    @Environment(\.salahPalette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            PrayerIcon(prayer: window.prayer, active: isActive)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(window.prayer.title).font(.headline)
                    Spacer()
                    if isActive { currentBadge }
                }
                Text("Ends \(PrayerDateFormatting.time(window.displayEnd, preference: preference, timeZone: day.timeZone))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(PrayerDateFormatting.time(window.start, preference: preference, timeZone: day.timeZone))
                .font(.headline.monospacedDigit())
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(palette.accent)
                    .accessibilityLabel("Completed")
            } else if !showsDisclosure {
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Not completed")
            }
            if showsDisclosure {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal)
        .frame(minHeight: 64)
        .background(isActive ? palette.accentSoft : .clear)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(window.prayer.title), starts \(PrayerDateFormatting.time(window.start, preference: preference, timeZone: day.timeZone)), ends \(PrayerDateFormatting.time(window.displayEnd, preference: preference, timeZone: day.timeZone))\(isActive ? ", current prayer" : "")\(isCompleted ? ", completed" : "")")
        .accessibilityHint(showsDisclosure ? "Opens prayer details" : (isCompleted ? "Marks this prayer as not completed" : "Marks this prayer as completed"))
    }

    private var currentBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.fill")
                .font(.caption2.weight(.semibold))
            Text("Current")
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: true, vertical: false)
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(palette.accent)
        .background(palette.accentSoft, in: Capsule())
        .accessibilityLabel("Current prayer")
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
                state = .loaded(days, source: loaded.contains { $0.source == .calculated } ? .calculated : .diskCache)
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
    @Environment(\.salahPalette) private var palette
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
                    .background(palette.groupedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                                WidgetDataPublisher.updateCompletion(prayer: prayer, day: selected.localDay, completed: !current)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .refreshable { await viewModel.load(policy: .reload) }
        .background(palette.screenBackground)
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
                    .background(selected ? palette.accent : .clear, in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        if day.localDay == today, !selected {
                            RoundedRectangle(cornerRadius: 12).stroke(palette.accent, lineWidth: 2)
                        }
                    }
                if viewModel.trackerDays.contains(day.localDay) {
                    Circle().fill(selected ? .white : palette.accent).frame(width: 5, height: 5).padding(.bottom, 4)
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
