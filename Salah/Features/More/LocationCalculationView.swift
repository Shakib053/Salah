import SwiftUI

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
