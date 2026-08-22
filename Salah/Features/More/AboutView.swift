import SwiftUI

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
