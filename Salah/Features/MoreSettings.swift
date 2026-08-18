import SwiftUI
import UIKit

private enum ExternalLinks {
    static let support = URL(string: "https://www.linkedin.com/in/mahi-al-jawad/")
    static let repository = URL(string: "https://github.com/Shakib053/Salah")
    static let license = URL(string: "https://github.com/Shakib053/Salah/blob/main/LICENSE")
    static let adhanSwift = URL(string: "https://github.com/batoulapps/adhan-swift")
    static let adhanSwiftLicense = URL(string: "https://github.com/batoulapps/adhan-swift/blob/main/LICENSE")
}

struct SettingsOpener {
    let open: @MainActor () -> Void

    @MainActor
    func callAsFunction() {
        open()
    }

    static let system = SettingsOpener {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct SettingsOpenerEnvironmentKey: EnvironmentKey {
    static let defaultValue = SettingsOpener.system
}

extension EnvironmentValues {
    var settingsOpener: SettingsOpener {
        get { self[SettingsOpenerEnvironmentKey.self] }
        set { self[SettingsOpenerEnvironmentKey.self] = newValue }
    }
}

@MainActor
enum ReminderCoordinator {
    static func reconcile(container: AppContainer) async {
        guard await container.notificationScheduler.authorizationStatus() == .authorized else { return }
        let location = container.settings.location
        let settings = container.settings.calculation
        let today = LocalDay(.now, timeZone: location.timeZone)
        var days: [PrayerDay] = []
        if let current = try? await container.prayerTimesRepository.month(
            containing: today,
            location: location,
            settings: settings,
            policy: .cacheFirst
        ) {
            days.append(contentsOf: current.map(\.value))
        }
        let nextMonthDate = Calendar(identifier: .gregorian).date(byAdding: .month, value: 1, to: today.date(in: location.timeZone) ?? .now) ?? .now
        let nextMonth = LocalDay(nextMonthDate, timeZone: location.timeZone)
        if let next = try? await container.prayerTimesRepository.month(
            containing: nextMonth,
            location: location,
            settings: settings,
            policy: .cacheFirst
        ) {
            days.append(contentsOf: next.map(\.value))
        }
        await container.notificationScheduler.reconcile(days: days, preferences: container.settings.reminders)
        if container.settings.charityReminder.enabled {
            await container.notificationScheduler.scheduleCharityReminder(container.settings.charityReminder)
        } else {
            await container.notificationScheduler.cancelCharityReminder()
        }
    }
}

struct MoreView: View {
    @Bindable var container: AppContainer
    @Environment(\.salahPalette) private var palette
    #if DEBUG
    @State private var showingDebugDrawer = false
    #endif

    var body: some View {
        List {
            Section {
                NavigationLink { RemindersView(container: container) } label: {
                    settingsLabel("Prayer Reminders", subtitle: "Optional local notifications", symbol: "bell.fill", tint: .orange)
                }
                NavigationLink { LocationCalculationView(container: container) } label: {
                    settingsLabel("Location & Calculation", subtitle: container.localizedLocationName, symbol: "location.fill", tint: .blue)
                }
                NavigationLink { AppearanceView(container: container) } label: {
                    settingsLabel("Appearances & Theme", subtitle: "Display mode and colors", symbol: "paintpalette.fill", tint: palette.accent)
                }
                NavigationLink { LanguageSettingsView(container: container) } label: {
                    settingsLabel("Language", subtitle: container.settings.language.selectorTitle, symbol: "character.bubble.fill", tint: .indigo)
                }
                NavigationLink { CharityHistoryView(container: container) } label: {
                    settingsLabel("Sadaqah", subtitle: "A private giving intention", symbol: "heart.fill", tint: .pink)
                }
            }

            Section {
                NavigationLink { PrivacyView(container: container) } label: {
                    settingsLabel("Privacy & Data", subtitle: "Local-first and transparent", symbol: "hand.raised.fill", tint: palette.accent)
                }
                NavigationLink { AboutView() } label: {
                    settingsLabel("About Salah", subtitle: "Charitable and open source", symbol: "info.circle.fill", tint: .purple)
                }
                NavigationLink { OpenSourceView() } label: {
                    settingsLabel("Open-Source Information", subtitle: "License and attribution", symbol: "chevron.left.forwardslash.chevron.right", tint: .gray)
                }
                if let supportURL = ExternalLinks.support {
                    Link(destination: supportURL) {
                        settingsLabel("Support & Contact", subtitle: "Contact the project maintainer", symbol: "person.crop.circle.fill", tint: .teal)
                    }
                }
            }

            Section {
                #if DEBUG
                LabeledContent("Version", value: versionText)
                    .onTapGesture(count: 5) { showingDebugDrawer = true }
                #else
                LabeledContent("Version", value: versionText)
                #endif
            } footer: {
                Text("Salah is free, has no advertising, and does not require an account.")
            }
        }
        .navigationTitle("More")
        #if DEBUG
        .sheet(isPresented: $showingDebugDrawer) {
            DebugDrawerView(container: container)
                .presentationDetents([.medium])
        }
        #endif
    }

    private func settingsLabel(_ title: String, subtitle: String, symbol: String, tint: Color) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title)).foregroundStyle(.primary)
                Text(LocalizedStringKey(subtitle)).font(.caption).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(tint, in: RoundedRectangle(cornerRadius: 8))
        }
        .frame(minHeight: 44)
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}

struct LanguageSettingsView: View {
    @Bindable var container: AppContainer

    var body: some View {
        @Bindable var settings = container.settings
        Form {
            Section {
                Picker("Language", selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(verbatim: language.selectorTitle).tag(language)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .accessibilityIdentifier("settings.language.picker")
            } footer: {
                Text("System follows your iPhone language. English and Bangla override it only inside Salah.")
            }
        }
        .navigationTitle("Language")
        .navigationBarTitleDisplayMode(.inline)
        .phoneOnlyHideTabBar()
    }
}

struct ReminderEducationSheet: View {
    private enum Target {
        case prayer(PrayerEvent)
        case charity

        var title: String {
            switch self {
            case .prayer(let event): event.title
            case .charity: L10n.string("Charity")
            }
        }
    }

    private let target: Target
    @Bindable var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.salahPalette) private var palette
    @Environment(\.settingsOpener) private var settingsOpener
    @State private var status: NotificationAuthorization = .notDetermined

    init(event: PrayerEvent, container: AppContainer) {
        target = .prayer(event)
        self.container = container
    }

    init(charity container: AppContainer) {
        target = .charity
        self.container = container
    }

    var body: some View {
        NavigationStack {
            ZStack {
                palette.screenBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Capsule(style: .continuous)
                        .fill(.secondary.opacity(0.18))
                        .frame(width: 36, height: 4)
                        .padding(.top, 8)

                    VStack(spacing: 10) {
                        Text("Reminder permission")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Image(systemName: "bell")
                            .font(.system(size: 28, weight: .regular))
                            .foregroundStyle(palette.warm)
                            .accessibilityHidden(true)
                        Text("Enable \(target.title) reminder?")
                            .font(.title3.bold())
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 22)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)

                    VStack(spacing: 12) {
                        Text("Notifications are optional and scheduled locally on your device.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        if status == .denied {
                            Text("Notifications are turned off for this app. Turn them on in Settings to get this reminder.")
                                .font(.body)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)

                    Divider()

                    VStack {
                        if status == .denied {
                            Button {
                                openAppSettings()
                            } label: {
                                Text("Open settings")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(palette.heroStart)
                            .frame(minHeight: 52)
                        } else {
                            Button {
                                Task {
                                    await enableNotifications()
                                }
                            } label: {
                                Text("Enable notifications")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(palette.heroStart)
                            .frame(minHeight: 52)
                        }

                        Divider()

                        Button {
                            dismiss()
                        } label: {
                            Text("Not now")
                                .frame(maxWidth: .infinity)
                        }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .tint(.secondary)
                            .frame(minHeight: 52)
                    }
                    .padding(.horizontal, 10)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(palette.screenBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .task { await refreshStatus() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await refreshStatus() }
                }
            }
        }
    }

    private func refreshStatus() async {
        status = await container.notificationScheduler.authorizationStatus()
    }

    private func openAppSettings() {
        settingsOpener()
    }

    private func enableNotifications() async {
        let newStatus = await container.notificationScheduler.requestAuthorization()
        status = newStatus
        if newStatus == .authorized {
            switch target {
            case .prayer(let event):
                var preference = container.settings.reminder(for: event)
                preference.enabled = true
                container.settings.setReminder(preference, for: event)
            case .charity:
                var preference = container.settings.charityReminder
                if preference.date <= .now {
                    preference.date = CharityReminderPreference.suggestedDate()
                }
                preference.enabled = true
                container.settings.charityReminder = preference
            }
            await ReminderCoordinator.reconcile(container: container)
            dismiss()
        }
    }
}

struct RemindersView: View {
    @Bindable var container: AppContainer
    @State private var status: NotificationAuthorization = .notDetermined
    @State private var educationEvent: PrayerEvent = .fajr
    @State private var editingReminderEvent: PrayerEvent?
    @State private var showingEducation = false
    @State private var showingCharityEducation = false
    @State private var charityReminderEnabled: Bool
    @State private var charityReminderDate: Date
    @State private var charityReminderRepeat: CharityReminderRepeat
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.settingsOpener) private var settingsOpener

    init(container: AppContainer) {
        self.container = container
        _charityReminderEnabled = State(initialValue: container.settings.charityReminder.enabled)
        _charityReminderDate = State(initialValue: container.settings.charityReminder.date)
        _charityReminderRepeat = State(initialValue: container.settings.charityReminder.repeatCycle)
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Permission", value: permissionText)
                if status == .denied {
                    Button("Open settings") { openAppSettings() }
                }
            } footer: {
                Text("Notification permission is managed in iPhone Settings.")
            }

            Section {
                charityReminderControls
            } header: {
                Text("Charity")
            } footer: {
                Text("Choose when to begin and whether to remind once, weekly, or monthly. Notifications stay on this device and do not make a donation.")
            }

            Section("Daily Prayers") {
                ForEach(PrayerEvent.allCases.filter { ![.sahri, .iftar].contains($0) }) { event in
                    reminderControls(event)
                }
            }

            Section("Fasting") {
                reminderControls(.sahri)
                reminderControls(.iftar)
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .phoneOnlyHideTabBar()
        .navigationDestination(item: $editingReminderEvent) { event in
            PrayerReminderSettingsView(container: container, event: event)
        }
        .task {
            syncCharityPreference()
            await refreshStatus()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await refreshStatus() }
            }
        }
        .sheet(isPresented: $showingEducation) {
            ReminderEducationSheet(event: educationEvent, container: container)
                .presentationDetents([.medium])
                .onDisappear { Task { await refreshStatus() } }
        }
        .sheet(isPresented: $showingCharityEducation) {
            ReminderEducationSheet(charity: container)
                .presentationDetents([.medium])
                .onDisappear {
                    syncCharityPreference()
                    Task { await refreshStatus() }
                }
        }
    }

    @ViewBuilder
    private var charityReminderControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !charityReminderEnabled, status != .authorized {
                Button {
                    showingCharityEducation = true
                } label: {
                    HStack {
                        Label("Charity reminder", systemImage: "heart.fill")
                        Spacer()
                        Image(systemName: "circle").foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .accessibilityLabel("Charity reminder, off")
                .accessibilityHint("Opens reminder settings and permission options")
            } else {
                Toggle(isOn: $charityReminderEnabled) {
                    Label("Charity reminder", systemImage: "heart.fill")
                }
                .frame(minHeight: 44)
                .accessibilityIdentifier("charity.reminder.toggle")
                .onChange(of: charityReminderEnabled) { _, enabled in
                    persistCharityEnabled(enabled)
                }
            }

            if charityReminderEnabled {
                Picker("Repeat", selection: $charityReminderRepeat) {
                    ForEach(CharityReminderRepeat.allCases) { repeatCycle in
                        Text(repeatCycle.title).tag(repeatCycle)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("charity.reminder.repeat")
                .onChange(of: charityReminderRepeat) { _, repeatCycle in
                    persistCharityRepeat(repeatCycle)
                }

                charityDatePicker

                LabeledContent("Schedule", value: charityScheduleSummary)
                    .font(.subheadline)
            }
        }
    }

    @ViewBuilder
    private var charityDatePicker: some View {
        if charityReminderRepeat == .once {
            DatePicker(
                "Reminder date",
                selection: $charityReminderDate,
                in: Date.now...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .accessibilityIdentifier("charity.reminder.date")
            .onChange(of: charityReminderDate) { _, date in
                persistCharityDate(date)
            }
        } else {
            DatePicker(
                "First reminder",
                selection: $charityReminderDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .accessibilityIdentifier("charity.reminder.date")
            .onChange(of: charityReminderDate) { _, date in
                persistCharityDate(date)
            }
        }
    }

    @ViewBuilder
    private func reminderControls(_ event: PrayerEvent) -> some View {
        let preference = container.settings.reminder(for: event)
        VStack(alignment: .leading, spacing: 8) {
            if !preference.enabled, status != .authorized {
                Button {
                    educationEvent = event
                    showingEducation = true
                } label: {
                    HStack {
                        Label(event.title, systemImage: event.symbol)
                        Spacer()
                        Image(systemName: "circle").foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .accessibilityLabel("\(event.title) reminder, off")
                .accessibilityHint("Opens reminder settings and permission options")
            } else {
                HStack(spacing: 12) {
                    Button {
                        if preference.enabled {
                            editingReminderEvent = event
                        } else {
                            updateEnabled(true, event: event, opensDetail: true)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Label(event.title, systemImage: event.symbol)
                                .foregroundStyle(.primary)
                            Spacer()
                            if preference.enabled {
                                Text(reminderSummary(for: preference))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(preference.enabled ? "\(event.title) reminder, \(reminderSummary(for: preference))" : "\(event.title) reminder, off")
                    .accessibilityHint(L10n.dynamic(preference.enabled ? "Opens reminder timing settings" : "Turns on this reminder and opens timing settings"))

                    Toggle(isOn: Binding(
                        get: { container.settings.reminder(for: event).enabled },
                        set: { newValue in updateEnabled(newValue, event: event, opensDetail: newValue) }
                    )) {
                        Text(event.title)
                    }
                    .labelsHidden()
                    .accessibilityLabel(event.title)
                    .accessibilityHint(L10n.dynamic(preference.enabled ? "Turns off and cancels scheduled reminders" : "Turns on this reminder"))
                }
                .frame(minHeight: 44)
            }
        }
    }

    private func updateEnabled(_ enabled: Bool, event: PrayerEvent, opensDetail: Bool = false) {
        if enabled {
            if status == .authorized {
                var preference = container.settings.reminder(for: event)
                preference.enabled = true
                container.settings.setReminder(preference, for: event)
                Task { await ReminderCoordinator.reconcile(container: container) }
                if opensDetail {
                    editingReminderEvent = event
                }
            }
        } else {
            var preference = container.settings.reminder(for: event)
            preference.enabled = false
            container.settings.setReminder(preference, for: event)
            Task { await container.notificationScheduler.cancel(event: event) }
        }
    }

    private func persistCharityEnabled(_ enabled: Bool) {
        var preference = container.settings.charityReminder
        preference.enabled = enabled
        if enabled, preference.date <= .now {
            preference.date = CharityReminderPreference.suggestedDate()
        }
        charityReminderDate = preference.date
        container.settings.charityReminder = preference
        Task {
            if enabled {
                await container.notificationScheduler.scheduleCharityReminder(preference)
            } else {
                await container.notificationScheduler.cancelCharityReminder()
            }
        }
    }

    private func persistCharityDate(_ date: Date) {
        var preference = container.settings.charityReminder
        preference.date = date
        container.settings.charityReminder = preference
        if preference.enabled {
            Task { await container.notificationScheduler.scheduleCharityReminder(preference) }
        }
    }

    private func persistCharityRepeat(_ repeatCycle: CharityReminderRepeat) {
        var preference = container.settings.charityReminder
        preference.repeatCycle = repeatCycle
        if repeatCycle == .once, preference.date <= .now {
            preference.date = CharityReminderPreference.suggestedDate()
            charityReminderDate = preference.date
        }
        container.settings.charityReminder = preference
        if preference.enabled {
            Task { await container.notificationScheduler.scheduleCharityReminder(preference) }
        }
    }

    private func syncCharityPreference() {
        let preference = container.settings.charityReminder
        charityReminderEnabled = preference.enabled
        charityReminderDate = preference.date
        charityReminderRepeat = preference.repeatCycle
    }

    private var charityScheduleSummary: String {
        switch charityReminderRepeat {
        case .once:
            charityReminderDate.formatted(.dateTime.year().month(.abbreviated).day().hour().minute().locale(L10n.locale))
        case .weekly:
            String(
                format: L10n.string("Every %@ at %@"),
                charityReminderDate.formatted(.dateTime.weekday(.wide).locale(L10n.locale)),
                charityReminderDate.formatted(.dateTime.hour().minute().locale(L10n.locale))
            )
        case .monthly:
            String(
                format: L10n.string("Monthly on day %lld at %@"),
                Int64(Calendar.current.component(.day, from: charityReminderDate)),
                charityReminderDate.formatted(.dateTime.hour().minute().locale(L10n.locale))
            )
        }
    }

    private var permissionText: String {
        switch status {
        case .notDetermined: L10n.string("Not requested")
        case .authorized: L10n.string("Allowed")
        case .denied: L10n.string("Denied")
        }
    }

    private func reminderSummary(for preference: ReminderPreference) -> String {
        preference.offsetMinutes == 0
            ? L10n.string("Exact time")
            : L10n.string("\(preference.offsetMinutes) min before")
    }

    private func refreshStatus() async {
        status = await container.notificationScheduler.authorizationStatus()
    }

    private func openAppSettings() {
        settingsOpener()
    }
}

struct LocationCalculationView: View {
    @Bindable var container: AppContainer
    @State private var showingDistricts = false
    @State private var showingLocationEducation = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Current", value: container.localizedLocationName)
                LabeledContent("Source", value: container.settings.location.source.title)
                LabeledContent("Permission", value: container.locationProvider.authorization.title)
                Button("Use Current Location") { showingLocationEducation = true }
                Button("Choose District Manually") { showingDistricts = true }
            } header: {
                Text("Prayer Location")
            } footer: {
                Text("Location is used only to calculate prayer times on this device. Approximate When In Use access is sufficient.")
            }

            Section {
                Picker("Method", selection: calculationBinding(\.method)) {
                    ForEach(CalculationMethod.allCases) { method in Text(method.title).tag(method) }
                }
                Picker("Asr calculation", selection: calculationBinding(\.madhab)) {
                    ForEach(Madhab.allCases) { madhab in Text(madhab.title).tag(madhab) }
                }
                Stepper("Hijri adjustment: \(signed(container.settings.calculation.hijriAdjustment)) day", value: calculationBinding(\.hijriAdjustment), in: -2...2)
                Stepper("Safety adjustment: \(container.settings.calculation.cautionMinutes) min", value: calculationBinding(\.cautionMinutes), in: 0...10)
                Picker("Time format", selection: calculationBinding(\.timeFormat)) {
                    ForEach(TimeFormatPreference.allCases) { format in Text(format.title).tag(format) }
                }
            } header: {
                Text("Calculation")
            } footer: {
                Text("Safety adjustment ends Sahri earlier and begins Maghrib and Iftar later. Published times may differ; confirm with an appropriate local authority when necessary.")
            }
        }
        .navigationTitle("Location & Calculation")
        .navigationBarTitleDisplayMode(.inline)
        .phoneOnlyHideTabBar()
        .sheet(isPresented: $showingDistricts) {
            NavigationStack {
                DistrictPickerView(districts: container.districts) { district in
                    showingDistricts = false
                    updateLocation(district.prayerLocation)
                }
            }
        }
        .sheet(isPresented: $showingLocationEducation) {
            CurrentLocationSettingsSheet(container: container) { location in
                showingLocationEducation = false
                updateLocation(location)
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func calculationBinding<Value>(_ keyPath: WritableKeyPath<CalculationSettings, Value>) -> Binding<Value> {
        Binding(
            get: { container.settings.calculation[keyPath: keyPath] },
            set: { value in
                let oldSignature = PrayerTimesQuery(
                    day: container.router.selectedDay,
                    location: container.settings.location,
                    settings: container.settings.calculation
                ).signature
                var calculation = container.settings.calculation
                calculation[keyPath: keyPath] = value
                container.settings.calculation = calculation
                Task {
                    await container.prayerTimesRepository.invalidate(signature: oldSignature)
                    await ReminderCoordinator.reconcile(container: container)
                }
            }
        )
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

    private func signed(_ value: Int) -> String { value > 0 ? "+\(value)" : "\(value)" }
}

struct CurrentLocationSettingsSheet: View {
    @Bindable var container: AppContainer
    let onLocation: (PrayerLocation) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.salahPalette) private var palette
    @State private var isWorking = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "location.circle.fill").font(.system(size: 64)).foregroundStyle(palette.accent)
                Text("Use Current Location").font(.title.bold())
                Text("Salah retrieves one approximate coordinate and calculates prayer times on this device. Background tracking and location transmission are not used.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
                if let error { Text(error).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center) }
                Spacer()
                Button {
                    isWorking = true
                    Task {
                        do {
                            onLocation(try await container.locationProvider.requestCurrentLocation())
                        } catch {
                            self.error = error.localizedDescription
                        }
                        isWorking = false
                    }
                } label: {
                    if isWorking {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent).controlSize(.large).disabled(isWorking)
                Button("Cancel") { dismiss() }.frame(minHeight: 44)
            }
            .padding()
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct AppearanceView: View {
    @Bindable var container: AppContainer

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Color scheme", selection: Binding(
                    get: { container.settings.appearance },
                    set: { container.settings.appearance = $0 }
                )) {
                    ForEach(AppearancePreference.allCases) { appearance in Text(appearance.title).tag(appearance) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .accessibilityLabel("Color scheme")
            }

            Section {
                Picker("Theme", selection: Binding(
                    get: { container.settings.theme },
                    set: { container.settings.theme = $0 }
                )) {
                    ForEach(ThemePreference.allCases) { theme in
                        ThemeOptionLabel(
                            theme: theme,
                            customColor: container.settings.customThemeColor
                        )
                            .tag(theme)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .accessibilityLabel("Theme")
            } header: {
                Text("Theme")
            } footer: {
                Text("Themes change accent and feature colors throughout Salah. Custom Color applies the same balanced shading to your selected color.")
            }

            if container.settings.theme == .custom {
                Section("Custom Color") {
                    CustomThemeColorPicker(selection: Binding(
                        get: { container.settings.customThemeColor },
                        set: { container.settings.customThemeColor = $0 }
                    ))
                }
            }

            Section("Dynamic Type Preview") {
                CurrentPrayerCard(moment: Self.previewMoment)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .navigationTitle("Appearances & Theme")
        .navigationBarTitleDisplayMode(.inline)
        .phoneOnlyHideTabBar()
    }

    private static let previewDate = Date(timeIntervalSinceReferenceDate: 0)
    private static let previewMoment = PrayerCardMoment(
        event: .obligatory(PrayerWindow(
            prayer: .asr,
            start: previewDate.addingTimeInterval(-58 * 60),
            end: previewDate.addingTimeInterval(42 * 60)
        )),
        isCurrent: true,
        remaining: 42 * 60,
        progress: 0.58
    )
}

private struct ThemeOptionLabel: View {
    let theme: ThemePreference
    let customColor: CustomThemeColor

    private var palette: SalahPalette {
        theme.palette(customColor: customColor)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(palette.heroGradient)
                    .frame(width: 34, height: 34)
                Circle()
                    .fill(palette.accent)
                    .frame(width: 14, height: 14)
                    .overlay {
                        Circle()
                            .stroke(Color(uiColor: .systemBackground), lineWidth: 2)
                            .frame(width: 16, height: 16)
                    }
                    .offset(x: 10, y: 10)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(theme.title)
                    .foregroundStyle(.primary)
                Text(theme.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CustomThemeColorPicker: View {
    @Binding var selection: CustomThemeColor

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 8),
        count: 4
    )

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(CustomThemeColor.allCases) { color in
                Button {
                    selection = color
                } label: {
                    VStack(spacing: 7) {
                        ZStack {
                            Circle()
                                .fill(color.swatch)
                                .frame(width: 42, height: 42)
                                .overlay {
                                    Circle()
                                        .stroke(
                                            selection == color ? Color.primary : Color.secondary.opacity(0.22),
                                            lineWidth: selection == color ? 3 : 1
                                        )
                                        .padding(selection == color ? -4 : 0)
                                }

                            if selection == color {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                            }
                        }

                        Text(color.title)
                            .font(.caption2)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(color.title)
                .accessibilityValue(selection == color ? L10n.string("Selected") : "")
                .accessibilityAddTraits(selection == color ? .isSelected : [])
            }
        }
        .padding(.vertical, 6)
    }
}

struct PrivacyView: View {
    @Bindable var container: AppContainer
    @Environment(\.salahPalette) private var palette
    @State private var showingClearConfirmation = false
    @State private var cleared = false

    var body: some View {
        List {
            Section {
                Label("Privacy by design", systemImage: "hand.raised.fill").font(.title3.bold())
                Text("Salah collects the minimum information required for prayer timings and remains useful when optional permissions are declined.")
            }
            Section("How Data Is Used") {
                privacyRow("Location", detail: "Prayer times are calculated on this device. Your coordinate is not sent to a prayer-time service, and continuous or background tracking is not used.", symbol: "location.fill")
                privacyRow("Prayer tracking", detail: "Completion records and notes stay in local SwiftData on this device.", symbol: "checkmark.circle.fill")
                privacyRow("Notifications", detail: "Optional reminders are scheduled locally. No marketing notification service is used.", symbol: "bell.fill")
                privacyRow("Advertising and analytics", detail: "The app contains no advertising identifier, tracking SDK, or unnecessary analytics.", symbol: "eye.slash.fill")
                privacyRow("Data sale", detail: "The project does not sell personal data.", symbol: "dollarsign.circle.fill")
            }
            Section {
                Button("Clear Local Tracker Data", role: .destructive) { showingClearConfirmation = true }
                if cleared { Label("Tracker data cleared", systemImage: "checkmark.circle.fill").foregroundStyle(palette.accent) }
            } header: {
                Text("Your Data")
            } footer: {
                Text("Prayer-time cache and lightweight preferences can be replaced automatically; tracker deletion cannot be undone.")
            }
        }
        .navigationTitle("Privacy & Data")
        .navigationBarTitleDisplayMode(.inline)
        .phoneOnlyHideTabBar()
        .confirmationDialog("Clear all tracker data?", isPresented: $showingClearConfirmation, titleVisibility: .visible) {
            Button("Clear Tracker Data", role: .destructive) {
                try? container.trackingRepository.clearAll()
                UserDefaults.standard.set(0, forKey: "salah.deeds.istighfar-count")
                UserDefaults.standard.set(0, forKey: "salah.deeds.tasbih-goal")
                UserDefaults.standard.removeObject(forKey: "salah.deeds.tasbih-day")
                UserDefaults.standard.removeObject(forKey: TasbihHistoryLedger.storageKey)
                UserDefaults.standard.set(0, forKey: "salah.deeds.good-deeds-mask")
                UserDefaults.standard.removeObject(forKey: "salah.deeds.good-deeds-day")
                UserDefaults.standard.removeObject(forKey: NaflHistoryLedger.storageKey)
                UserDefaults.standard.set(0, forKey: "salah.deeds.charity-total")
                UserDefaults.standard.removeObject(forKey: CharityLedger.storageKey)
                cleared = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This permanently removes prayer, Tasbih, good deeds, and charity history stored on this device.")
        }
    }

    private func privacyRow(_ title: String, detail: String, symbol: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.dynamic(title)).font(.headline)
                Text(L10n.dynamic(detail)).font(.subheadline).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: symbol).foregroundStyle(palette.accent)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct AboutView: View {
    @Environment(\.salahPalette) private var palette

    var body: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    Image(systemName: "moon.stars.fill").font(.system(size: 58)).foregroundStyle(palette.accent)
                    Text("Salah").font(.largeTitle.bold())
                    Text("A free, charitable, and non-profit prayer timing and tracking project.")
                        .multilineTextAlignment(.center).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical)
            }
            Section("Prayer-Time Notice") {
                Text("Prayer timings can vary by calculation method, madhab, adjustments, local conditions, and local authority. Salah is not an official religious authority. Confirm timings with an appropriate local authority when necessary.")
            }
        }
        .navigationTitle("About Salah")
        .navigationBarTitleDisplayMode(.inline)
        .phoneOnlyHideTabBar()
    }
}

struct OpenSourceView: View {
    var body: some View {
        List {
            Section("Salah") {
                Text("Copyright © 2024 Mahi Al Jawad")
                Text("Released under the MIT License.")
                if let url = ExternalLinks.license { Link("Read the repository license", destination: url) }
            }
            Section("Prayer-Time Calculation") {
                Text("Prayer times are calculated on-device using the MIT-licensed Adhan Swift library by Batoul Apps. Hijri dates are calculated on-device using Apple's calendar framework.")
                DisclosureGroup("Adhan Swift license notice") {
                    Text(Self.adhanSwiftLicenseNotice)
                        .font(.footnote)
                        .textSelection(.enabled)
                }
                if let url = ExternalLinks.adhanSwiftLicense { Link("Adhan Swift MIT License", destination: url) }
            }
            Section("Apple Frameworks") {
                Text("SwiftUI, SwiftData, Charts, Core Location, Foundation, and UserNotifications are used under the platform terms supplied with iOS.")
            }
        }
        .navigationTitle("Open Source")
        .navigationBarTitleDisplayMode(.inline)
        .phoneOnlyHideTabBar()
    }

    private static let adhanSwiftLicenseNotice = """
    The MIT License (MIT)

    Copyright (c) 2016 Batoul Apps

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    """
}
