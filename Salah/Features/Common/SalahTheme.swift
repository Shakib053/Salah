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
