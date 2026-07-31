import SwiftUI

struct SalahPalette {
    let accent: Color
    let accentSoft: Color
    let accentForeground: Color
    let heroHighlight: Color
    let heroStart: Color
    let heroEnd: Color
    let warm: Color
    let screenBackground = Color(uiColor: .systemGroupedBackground)
    let groupedSurface = Color(uiColor: .systemBackground)

    static let greyishBlue = SalahPalette(
        accent: Color("AccentColor"),
        accentSoft: Color("AccentSoft"),
        accentForeground: Color("AccentForeground"),
        heroHighlight: Color(red: 0.322, green: 0.420, blue: 0.604),
        heroStart: Color("BrandNavy"),
        heroEnd: Color("BrandNavyDeep"),
        warm: Color("AccentColor")
    )

    static let greenishDark = SalahPalette(
        accent: Color("GreenAccent"),
        accentSoft: Color("GreenAccentSoft"),
        accentForeground: Color("GreenAccentForeground"),
        heroHighlight: Color(red: 0.090, green: 0.306, blue: 0.271),
        heroStart: Color("GreenHero"),
        heroEnd: Color("GreenHeroDeep"),
        warm: Color("GreenAccent")
    )

    static let slateInkNavy = SalahPalette(
        accent: Color(red: 0.345, green: 0.518, blue: 0.788),
        accentSoft: Color(red: 0.902, green: 0.937, blue: 0.996),
        accentForeground: Color(red: 0.165, green: 0.286, blue: 0.537),
        heroHighlight: Color(red: 0.322, green: 0.420, blue: 0.604),
        heroStart: Color(red: 0.153, green: 0.235, blue: 0.408),
        heroEnd: Color(red: 0.075, green: 0.137, blue: 0.247),
        warm: Color(red: 0.345, green: 0.518, blue: 0.788)
    )

    var heroGradient: LinearGradient {
        LinearGradient(
            colors: [heroHighlight, heroStart, heroEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension ThemePreference {
    func palette(customColor: CustomThemeColor = .oceanBlue) -> SalahPalette {
        switch self {
        case .greyishBlue: .greyishBlue
        case .greenishDark: .greenishDark
        case .slateInkNavy: .slateInkNavy
        case .custom: customColor.palette
        }
    }
}

extension CustomThemeColor {
    var palette: SalahPalette {
        SalahPalette(
            accent: adaptiveColor(
                lightSaturation: saturation * 0.78,
                lightBrightness: 0.68,
                darkSaturation: saturation * 0.58,
                darkBrightness: 0.86
            ),
            accentSoft: adaptiveColor(
                lightSaturation: 0.12,
                lightBrightness: 0.98,
                darkSaturation: saturation * 0.50,
                darkBrightness: 0.18
            ),
            accentForeground: adaptiveColor(
                lightSaturation: saturation * 0.88,
                lightBrightness: 0.45,
                darkSaturation: saturation * 0.45,
                darkBrightness: 0.92
            ),
            heroHighlight: Color(hue: hue, saturation: saturation * 0.58, brightness: 0.58),
            heroStart: Color(hue: hue, saturation: saturation * 0.82, brightness: 0.40),
            heroEnd: Color(hue: hue, saturation: saturation * 0.88, brightness: 0.20),
            warm: adaptiveColor(
                lightSaturation: saturation * 0.78,
                lightBrightness: 0.68,
                darkSaturation: saturation * 0.58,
                darkBrightness: 0.86
            )
        )
    }

    var swatch: Color {
        Color(hue: hue, saturation: saturation * 0.76, brightness: 0.72)
    }

    private var hue: Double {
        switch self {
        case .oceanBlue: 0.59
        case .deepTeal: 0.49
        case .emerald: 0.40
        case .indigo: 0.65
        case .mutedPurple: 0.75
        case .dustyRose: 0.95
        case .terracotta: 0.055
        }
    }

    private var saturation: Double {
        switch self {
        case .oceanBlue: 0.72
        case .deepTeal: 0.64
        case .emerald: 0.66
        case .indigo: 0.60
        case .mutedPurple: 0.46
        case .dustyRose: 0.46
        case .terracotta: 0.64
        }
    }

    private func adaptiveColor(
        lightSaturation: Double,
        lightBrightness: Double,
        darkSaturation: Double,
        darkBrightness: Double
    ) -> Color {
        Color(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            return UIColor(
                hue: hue,
                saturation: isDark ? darkSaturation : lightSaturation,
                brightness: isDark ? darkBrightness : lightBrightness,
                alpha: 1
            )
        })
    }
}

private struct SalahPaletteEnvironmentKey: EnvironmentKey {
    static let defaultValue = SalahPalette.greyishBlue
}

extension EnvironmentValues {
    var salahPalette: SalahPalette {
        get { self[SalahPaletteEnvironmentKey.self] }
        set { self[SalahPaletteEnvironmentKey.self] = newValue }
    }
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
    var tint: Color?
    @Environment(\.salahPalette) private var palette

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(tint ?? palette.accent)
            .background(palette.accentSoft, in: Capsule())
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
    @Environment(\.salahPalette) private var palette

    var body: some View {
        Image(systemName: prayer.symbol)
            .font(.headline)
            .foregroundStyle(active ? .white : palette.accentForeground)
            .frame(width: 40, height: 40)
            .background(active ? palette.accent : palette.accentSoft, in: RoundedRectangle(cornerRadius: 10))
            .accessibilityHidden(true)
    }
}

struct TrackerSymbolIcon: View {
    let symbol: String
    var active = false
    @Environment(\.salahPalette) private var palette

    var body: some View {
        Image(systemName: symbol)
            .font(.headline)
            .foregroundStyle(active ? .white : palette.accentForeground)
            .frame(width: 40, height: 40)
            .background(active ? palette.accent : palette.accentSoft, in: RoundedRectangle(cornerRadius: 10))
            .accessibilityHidden(true)
    }
}

extension ShapeStyle where Self == Color {
    static var separator: Color { Color(uiColor: .separator) }
}
