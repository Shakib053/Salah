import SwiftUI
import UIKit

struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var container: AppContainer

    private var preferredScheme: ColorScheme? {
        switch container.settings.appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var body: some View {
        Group {
            if container.settings.onboardingComplete {
                RootTabView(container: container)
            } else {
                OnboardingFlow(container: container)
            }
        }
        .environment(\.salahPalette, container.settings.palette)
        .environment(\.locale, container.settings.language.locale)
        .tint(container.settings.palette.accent)
        .preferredColorScheme(preferredScheme)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, container.settings.onboardingComplete {
                Task { await reconcileReminders() }
            }
        }
    }

    private func reconcileReminders() async {
        guard container.settings.reminders.values.contains(where: \.enabled) || container.settings.charityReminder.enabled,
              await container.notificationScheduler.authorizationStatus() == .authorized else { return }
        await ReminderCoordinator.reconcile(container: container)
    }
}

struct RootTabView: View {
    @Bindable var container: AppContainer

    var body: some View {
        SystemTabRootView(container: container)
    }
}

private struct SystemTabRootView: View {
    @Bindable var container: AppContainer

    var body: some View {
        @Bindable var router = container.router
        TabView(selection: $router.selectedTab) {
            NavigationStack {
                TodayView(container: container)
            }
            .tabItem { Label(AppTab.today.title, systemImage: AppTab.today.systemImage) }
            .tag(AppTab.today)

            NavigationStack {
                PrayerCalendarView(container: container)
            }
            .tabItem { Label(AppTab.calendar.title, systemImage: AppTab.calendar.systemImage) }
            .tag(AppTab.calendar)

            NavigationStack {
                TrackerView(container: container)
            }
            .tabItem { Label(AppTab.tracker.title, systemImage: AppTab.tracker.systemImage) }
            .tag(AppTab.tracker)

            NavigationStack {
                QiblaView(container: container)
            }
            .tabItem { Label(AppTab.qibla.title, systemImage: AppTab.qibla.systemImage) }
            .tag(AppTab.qibla)

            NavigationStack {
                MoreView(container: container)
            }
            .tabItem { Label(AppTab.more.title, systemImage: AppTab.more.systemImage) }
            .tag(AppTab.more)
        }
    }
}

private struct PadSidebarRootView: View {
    @Bindable var container: AppContainer
    @Environment(\.salahPalette) private var palette

    var body: some View {
        @Bindable var router = container.router
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {

                VStack(spacing: 6) {
                    ForEach(AppTab.allCases) { tab in
                        Button {
                            router.selectedTab = tab
                        } label: {
                            Label(tab.title, systemImage: tab.systemImage)
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                                .padding(.horizontal, 12)
                                .foregroundStyle(router.selectedTab == tab ? .white : .white.opacity(0.82))
                                .background(
                                    router.selectedTab == tab ? .white.opacity(0.14) : .clear,
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(router.selectedTab == tab ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 12)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.heroGradient)
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        } detail: {
            NavigationStack {
                AppTabContent(tab: router.selectedTab, container: container)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

private struct PadBottomTabRootView: View {
    @Bindable var container: AppContainer

    var body: some View {
        @Bindable var router = container.router
        NavigationStack {
            AppTabContent(tab: router.selectedTab, container: container)
        }
        .safeAreaInset(edge: .bottom) {
            PadBottomTabBar(selection: $router.selectedTab)
        }
    }
}

private struct PadBottomTabBar: View {
    @Binding var selection: AppTab
    @Environment(\.salahPalette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 18, weight: .semibold))
                        Text(tab.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selection == tab ? palette.accent : .secondary)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

private struct AppTabContent: View {
    let tab: AppTab
    @Bindable var container: AppContainer

    var body: some View {
        switch tab {
        case .today:
            TodayView(container: container)
        case .calendar:
            PrayerCalendarView(container: container)
        case .tracker:
            TrackerView(container: container)
        case .qibla:
            QiblaView(container: container)
        case .more:
            MoreView(container: container)
        }
    }
}

private struct OnboardingPage: Identifiable {
    let id: Int
    let symbol: String
    let title: String
    let body: String
}

struct OnboardingFlow: View {
    @Bindable var container: AppContainer
    @Environment(\.salahPalette) private var palette
    @State private var page = 0
    @State private var showingLocationEducation = false

    private var pages: [OnboardingPage] {
        [
            OnboardingPage(id: 0, symbol: "clock.badge.checkmark", title: L10n.string("Prayer times at a glance"), body: L10n.string("See today’s prayer windows, the next prayer, and a calm live countdown.")),
            OnboardingPage(id: 1, symbol: "checklist", title: L10n.string("Track privately"), body: L10n.string("Record daily prayers and view supportive history. Your tracker stays on this device.")),
            OnboardingPage(id: 2, symbol: "moon.stars", title: L10n.string("Fasting and optional reminders"), body: L10n.string("See Sahri and Iftar times. Enable only the reminders that are useful to you."))
        ]
    }

    var body: some View {
        if showingLocationEducation {
            LocationEducationView(container: container)
        } else {
            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button("Skip") {
                        container.settings.location = .dhaka
                        container.settings.onboardingComplete = true
                    }
                    .frame(minHeight: 44)
                }

                TabView(selection: $page) {
                    ForEach(pages) { page in
                        VStack(spacing: 26) {
                            Image(systemName: page.symbol)
                                .font(.system(size: 72, weight: .medium))
                                .foregroundStyle(palette.accent)
                                .frame(width: 150, height: 150)
                                .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 42))
                                .accessibilityHidden(true)
                            Text(page.title)
                                .font(.largeTitle.bold())
                                .multilineTextAlignment(.center)
                            Text(page.body)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal)
                        .tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button(page == pages.count - 1 ? "Choose Prayer Location" : "Continue") {
                    if page < pages.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        showingLocationEducation = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
    }
}

struct LocationEducationView: View {
    @Bindable var container: AppContainer
    @Environment(\.salahPalette) private var palette
    @State private var isRequesting = false
    @State private var errorMessage: String?
    @State private var showingDistricts = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "location.circle.fill")
                .font(.system(size: 88))
                .foregroundStyle(palette.accent)
                .accessibilityHidden(true)
            Text("Use your location?")
                .font(.largeTitle.bold())
            Text("Salah uses a one-time location request to calculate prayer times on this device. It does not transmit or track your location in the background. You can choose a district instead.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 14) {
                Label("When In Use access only", systemImage: "checkmark.circle.fill")
                Label("Approximate location is sufficient", systemImage: "checkmark.circle.fill")
                Label("Manual district selection always works", systemImage: "checkmark.circle.fill")
            }
            .foregroundStyle(.secondary)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Location error. \(errorMessage)")
            }
            Spacer()

            Button {
                requestLocation()
            } label: {
                if isRequesting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Use Current Location")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isRequesting)

            Button("Choose District Manually") { showingDistricts = true }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: .infinity)

            Button("Use Dhaka as Default") {
                complete(with: .dhaka)
            }
            .frame(minHeight: 44)
        }
        .padding()
        .sheet(isPresented: $showingDistricts) {
            NavigationStack {
                DistrictPickerView(districts: container.districts) { district in
                    showingDistricts = false
                    complete(with: district.prayerLocation)
                }
            }
        }
    }

    private func requestLocation() {
        isRequesting = true
        errorMessage = nil
        Task {
            do {
                let location = try await container.locationProvider.requestCurrentLocation()
                complete(with: location)
            } catch {
                errorMessage = error.localizedDescription
            }
            isRequesting = false
        }
    }

    private func complete(with location: PrayerLocation) {
        container.settings.location = location
        container.settings.locationEducationSeen = true
        container.router.selectedDay = LocalDay(.now, timeZone: location.timeZone)
        container.settings.onboardingComplete = true
    }
}

struct DistrictPickerView: View {
    let districts: [District]
    let onSelect: (District) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: [District] {
        guard !search.isEmpty else { return districts }
        return districts.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.banglaName.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        List(filtered) { district in
            Button {
                onSelect(district)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(district.localizedName).foregroundStyle(.primary)
                    if L10n.usesBangla {
                        Text(district.name).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
        }
        .navigationTitle("Choose District")
        .searchable(text: $search, prompt: "District name")
        .overlay {
            if filtered.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}
