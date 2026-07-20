import SwiftUI

enum SalahPalette {
    static let accent = Color.accentColor
    static let accentSecondary = Color(red: 0.18, green: 0.55, blue: 0.72)
    static let warm = Color(red: 0.88, green: 0.55, blue: 0.20)
}

struct SalahCard<Content: View>: View {
    var isTransparent = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isTransparent ? Color.clear : Color(uiColor: .secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isTransparent ? Color.clear : .separator.opacity(0.35), lineWidth: 0.5)
            }
    }
}

struct StatusBadge: View {
    let text: String
    let symbol: String
    var tint: Color = SalahPalette.accent

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(tint)
            .background(tint.opacity(0.12), in: Capsule())
            .accessibilityElement(children: .combine)
    }
}

struct PrayerDataUnavailableView: View {
    let error: PrayerDataError
    let retry: () async -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Prayer times unavailable", systemImage: "wifi.exclamationmark")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            Button("Try Again") { Task { await retry() } }
                .buttonStyle(.borderedProminent)
        }
    }
}

struct OfflineBanner: View {
    let lastUpdated: Date

    var body: some View {
        Label {
            Text("Offline · Cached \(lastUpdated.formatted(date: .omitted, time: .shortened))")
        } icon: {
            Image(systemName: "wifi.slash")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: Capsule())
        .accessibilityLabel("Offline. Showing cached prayer times updated \(lastUpdated.formatted())")
    }
}

struct PrayerIcon: View {
    let prayer: PrayerType
    var active = false

    var body: some View {
        Image(systemName: prayer.symbol)
            .font(.headline)
            .foregroundStyle(active ? .white : SalahPalette.accent)
            .frame(width: 40, height: 40)
            .background(active ? SalahPalette.accent : SalahPalette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityHidden(true)
    }
}

extension ShapeStyle where Self == Color {
    static var separator: Color { Color(uiColor: .separator) }
}
