import SwiftUI

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
