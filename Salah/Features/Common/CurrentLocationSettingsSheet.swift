import SwiftUI

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
