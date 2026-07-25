import SwiftUI

enum SalahPalette {
    static let accent = Color.accentColor
    static let accentSoft = Color("AccentSoft")
    static let accentForeground = Color("AccentForeground")
    static let heroStart = Color("BrandNavy")
    static let heroEnd = Color("BrandNavyDeep")
    static let warm = Color.accentColor
    static let screenBackground = Color(uiColor: .systemGroupedBackground)
    static let groupedSurface = Color(uiColor: .systemBackground)
}

struct SalahCard<Content: View>: View {
    var isTransparent = false
    @ViewBuilder var content: Content

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    var body: some View {
        if isTransparent {
            cardContent
        } else if #available(iOS 26.0, *) {
            cardContent
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            cardContent
                .background(
                    Color(uiColor: .secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.separator.opacity(0.35), lineWidth: 0.5)
                }
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
            .background(SalahPalette.accentSoft, in: Capsule())
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
            .foregroundStyle(active ? .white : SalahPalette.accentForeground)
            .frame(width: 40, height: 40)
            .background(active ? SalahPalette.accent : SalahPalette.accentSoft, in: RoundedRectangle(cornerRadius: 10))
            .accessibilityHidden(true)
    }
}

extension ShapeStyle where Self == Color {
    static var separator: Color { Color(uiColor: .separator) }
}
