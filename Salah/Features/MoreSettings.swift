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
                    settingsLabel("Location & Calculation", subtitle: container.settings.location.name, symbol: "location.fill", tint: .blue)
                }
                NavigationLink { AppearanceView(container: container) } label: {
                    settingsLabel("Appearances & Theme", subtitle: "Display mode and colors", symbol: "paintpalette.fill", tint: palette.accent)
                }
                NavigationLink { CharityView() } label: {
                    settingsLabel("Ṣadaqah", subtitle: "A private giving intention", symbol: "heart.fill", tint: .pink)
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
                if let repositoryURL = ExternalLinks.repository {
                    ShareLink(item: repositoryURL) {
                        Label("Share Salah", systemImage: "square.and.arrow.up")
                    }
                }
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
                Text(title).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
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

struct CharityView: View {
    @AppStorage("salah.deeds.charity-total") private var charityTotal = 0
    @AppStorage("salah.deeds.charity-goal") private var charityGoal = 100
    @AppStorage("salah.deeds.charity-month") private var charityMonth = ""

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    var body: some View {
        Form {
            Section("This Month") {
                LabeledContent("Recorded", value: charityTotal.formatted(.currency(code: currencyCode)))
                ProgressView(value: Double(charityTotal), total: Double(max(1, charityGoal)))
                    .accessibilityLabel("Monthly charity intention")
                    .accessibilityValue("\(charityTotal) of \(charityGoal)")
                Stepper(
                    "Monthly intention: \(charityGoal.formatted(.currency(code: currencyCode)))",
                    value: $charityGoal,
                    in: 10...10_000,
                    step: 10
                )
                Button("Record 5", systemImage: "heart.fill") { charityTotal += 5 }
                    .buttonStyle(.borderedProminent)
            }

            Section("About Giving") {
                Label("Give quietly and consistently", systemImage: "heart.text.square.fill")
                Text("Salah does not collect or process donations. This optional total stays on your device and helps you reflect on charity given through organizations you trust.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Reset Monthly Total", role: .destructive) { charityTotal = 0 }
            }
        }
        .navigationTitle("Ṣadaqah")
        .task { prepareCurrentMonth() }
    }

    private func prepareCurrentMonth() {
        let components = Calendar.current.dateComponents([.year, .month], from: .now)
        let month = String(format: "%04d-%02d", components.year ?? 1970, components.month ?? 1)
        if charityMonth != month {
            charityMonth = month
            charityTotal = 0
        }
    }
}

struct ReminderEducationSheet: View {
    let event: PrayerEvent
    @Bindable var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.salahPalette) private var palette
    @Environment(\.settingsOpener) private var settingsOpener
    @State private var status: NotificationAuthorization = .notDetermined

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
                        Text("Enable \(event.title) reminder?")
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

                        Text("Notifications are turned off for this app. Turn them on in Settings to get this reminder.")
                            .font(.body)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)

                    Divider()

                    VStack {
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
}

struct RemindersView: View {
    @Bindable var container: AppContainer
    @State private var status: NotificationAuthorization = .notDetermined
    @State private var educationEvent: PrayerEvent = .fajr
    @State private var showingEducation = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.settingsOpener) private var settingsOpener

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
        .task { await refreshStatus() }
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
                Toggle(isOn: Binding(
                    get: { container.settings.reminder(for: event).enabled },
                    set: { newValue in updateEnabled(newValue, event: event) }
                )) {
                    Label(event.title, systemImage: event.symbol)
                }
                .frame(minHeight: 44)
                .accessibilityHint(preference.enabled ? "Turns off and cancels scheduled reminders" : "Turns on this reminder")
            }

            if preference.enabled {
                Picker("Notification time", selection: Binding(
                    get: { container.settings.reminder(for: event).offsetMinutes },
                    set: { updateOffset($0, event: event) }
                )) {
                    Text("At event time").tag(0)
                    Text("5 minutes before").tag(5)
                    Text("10 minutes before").tag(10)
                    Text("15 minutes before").tag(15)
                    Text("30 minutes before").tag(30)
                }
                .pickerStyle(.menu)
            }
        }
    }

    private func updateEnabled(_ enabled: Bool, event: PrayerEvent) {
        if enabled {
            if status == .authorized {
                var preference = container.settings.reminder(for: event)
                preference.enabled = true
                container.settings.setReminder(preference, for: event)
                Task { await ReminderCoordinator.reconcile(container: container) }
            }
        } else {
            var preference = container.settings.reminder(for: event)
            preference.enabled = false
            container.settings.setReminder(preference, for: event)
            Task { await container.notificationScheduler.cancel(event: event) }
        }
    }

    private func updateOffset(_ offset: Int, event: PrayerEvent) {
        var preference = container.settings.reminder(for: event)
        preference.offsetMinutes = offset
        container.settings.setReminder(preference, for: event)
        Task { await ReminderCoordinator.reconcile(container: container) }
    }

    private var permissionText: String {
        switch status {
        case .notDetermined: String(localized: "Not requested")
        case .authorized: String(localized: "Allowed")
        case .denied: String(localized: "Denied")
        }
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
                LabeledContent("Current", value: container.settings.location.name)
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
                        ThemeOptionLabel(theme: theme)
                            .tag(theme)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .accessibilityLabel("Theme")
            } header: {
                Text("Theme")
            } footer: {
                Text("Theme changes the accent and feature colors throughout Salah. Greenish Dark pairs deep blue-green surfaces with a mint accent.")
            }

            Section("Dynamic Type Preview") {
                CurrentPrayerCard(moment: Self.previewMoment, now: Self.previewDate)
            }
        }
        .navigationTitle("Appearances & Theme")
    }

    private static let previewDate = Date(timeIntervalSinceReferenceDate: 0)
    private static let previewMoment = PrayerMoment(
        current: PrayerWindow(
            prayer: .asr,
            start: previewDate.addingTimeInterval(-58 * 60),
            end: previewDate.addingTimeInterval(42 * 60)
        ),
        next: PrayerWindow(
            prayer: .maghrib,
            start: previewDate.addingTimeInterval(42 * 60),
            end: previewDate.addingTimeInterval(102 * 60)
        ),
        remaining: 42 * 60,
        progress: 0.58
    )
}

private struct ThemeOptionLabel: View {
    let theme: ThemePreference

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(theme.palette.heroStart)
                    .frame(width: 34, height: 34)
                Circle()
                    .fill(theme.palette.accent)
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
        .confirmationDialog("Clear all tracker data?", isPresented: $showingClearConfirmation, titleVisibility: .visible) {
            Button("Clear Tracker Data", role: .destructive) {
                try? container.trackingRepository.clearAll()
                cleared = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This permanently removes prayer completion history stored on this device.")
        }
    }

    private func privacyRow(_ title: String, detail: String, symbol: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
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
            Section("Project") {
                if let url = ExternalLinks.repository { Link("View Source on GitHub", destination: url) }
                if let url = ExternalLinks.adhanSwift { Link("Adhan Swift prayer-time library", destination: url) }
            }
        }
        .navigationTitle("About Salah")
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
    }

    private static let adhanSwiftLicenseNotice = """
    The MIT License (MIT)

    Copyright (c) 2016 Batoul Apps

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    """
}
