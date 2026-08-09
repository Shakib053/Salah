import SwiftUI

struct PrayerReminderSettingsView: View {
    private enum ReminderMode {
        case exact
        case before
    }

    private static let allowedOffsets = [5, 10, 15, 30]

    @Bindable var container: AppContainer
    let event: PrayerEvent

    @Environment(\.dismiss) private var dismiss
    @Environment(\.salahPalette) private var palette
    @State private var mode: ReminderMode
    @State private var selectedOffset: Int

    init(container: AppContainer, event: PrayerEvent) {
        self.container = container
        self.event = event
        let preference = container.settings.reminder(for: event)
        _mode = State(initialValue: preference.offsetMinutes == 0 ? .exact : .before)
        _selectedOffset = State(initialValue: Self.normalizedOffset(preference.offsetMinutes))
    }

    var body: some View {
        ZStack {
            palette.screenBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        reminderSection
                        timeBeforeSection
                        previewSection
                        footnote
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }

                saveButton
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                    .background(.regularMaterial)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var topBar: some View {
        VStack(spacing: 14) {
            Capsule(style: .continuous)
                .fill(.secondary.opacity(0.25))
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            ZStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Color(uiColor: .secondarySystemBackground), in: Circle())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("Back")

                VStack(spacing: 6) {
                    Text("Prayer reminder")
                        .font(.headline.bold())
                    Text("Get notified at the time you choose")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Remind me")

            reminderChoice(
                title: "Exact salah time",
                subtitle: "Notify me at the exact time of each prayer",
                symbol: "bell",
                isSelected: mode == .exact
            ) {
                mode = .exact
            }

            reminderChoice(
                title: "Before prayer time",
                subtitle: "Notify me before each prayer",
                symbol: "sun.min",
                isSelected: mode == .before
            ) {
                mode = .before
            }
        }
    }

    private var timeBeforeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Time before prayer")

            HStack(spacing: 12) {
                Image(systemName: "clock")
                    .font(.headline)
                    .foregroundStyle(palette.accentForeground)
                    .frame(width: 42, height: 42)
                    .background(palette.accentSoft, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Notify me")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(selectedOffset) min before")
                        .font(.headline.bold())
                }

                Spacer()

                offsetButton(systemName: "minus") {
                    adjustOffset(by: -1)
                }
                .disabled(!canDecreaseOffset || mode == .exact)

                offsetButton(systemName: "plus") {
                    adjustOffset(by: 1)
                }
                .disabled(!canIncreaseOffset || mode == .exact)
            }
            .padding(14)
            .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.separator.opacity(0.45), lineWidth: 0.8)
            }
            .opacity(mode == .exact ? 0.55 : 1)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Notify me \(selectedOffset) minutes before")
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Preview")

            HStack(spacing: 12) {
                Image(systemName: "bell")
                    .font(.headline)
                    .foregroundStyle(.indigo)
                    .frame(width: 42, height: 42)
                    .background(Color.indigo.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Prayer reminder")
                        .font(.headline.weight(.semibold))
                    Text(previewBody)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(previewBadge)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.indigo)
                    .lineLimit(1)
            }
            .padding(14)
            .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.separator.opacity(0.45), lineWidth: 0.8)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var footnote: some View {
        Label("Prayer times are based on your current location.", systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text("Save")
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
        .buttonStyle(.borderedProminent)
        .tint(palette.accent)
        .accessibilityIdentifier("prayer.reminder.save")
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }

    private func reminderChoice(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        symbol: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.headline)
                    .foregroundStyle(palette.accentForeground)
                    .frame(width: 42, height: 42)
                    .background(palette.accentSoft, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? palette.accent : .secondary.opacity(0.45))
            }
            .padding(14)
            .background(
                isSelected ? palette.accentSoft : Color(uiColor: .systemBackground),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? palette.accent : .separator.opacity(0.45), lineWidth: isSelected ? 1.2 : 0.8)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func offsetButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("prayer.reminder.offset.\(systemName)")
    }

    private var canDecreaseOffset: Bool {
        guard let index = Self.allowedOffsets.firstIndex(of: selectedOffset) else { return false }
        return index > Self.allowedOffsets.startIndex
    }

    private var canIncreaseOffset: Bool {
        guard let index = Self.allowedOffsets.firstIndex(of: selectedOffset) else { return false }
        return index < Self.allowedOffsets.index(before: Self.allowedOffsets.endIndex)
    }

    private var previewBadge: String {
        switch mode {
        case .exact:
            L10n.string("Exact time")
        case .before:
            L10n.string("\(selectedOffset) min before")
        }
    }

    private var previewBody: String {
        switch mode {
        case .exact:
            L10n.string("You'll receive a notification at the time of each prayer.")
        case .before:
            L10n.string("You'll receive a notification \(selectedOffset) minutes before each prayer.")
        }
    }

    private func adjustOffset(by step: Int) {
        guard let index = Self.allowedOffsets.firstIndex(of: selectedOffset) else {
            selectedOffset = 15
            return
        }
        let newIndex = Self.allowedOffsets.index(index, offsetBy: step, limitedBy: step > 0 ? Self.allowedOffsets.index(before: Self.allowedOffsets.endIndex) : Self.allowedOffsets.startIndex) ?? index
        selectedOffset = Self.allowedOffsets[newIndex]
        mode = .before
    }

    private func save() {
        let offset = mode == .exact ? 0 : selectedOffset
        container.settings.setReminder(ReminderPreference(enabled: true, offsetMinutes: offset), for: event)
        dismiss()
        Task {
            await ReminderCoordinator.reconcile(container: container)
        }
    }

    private static func normalizedOffset(_ offset: Int) -> Int {
        guard offset > 0 else { return 15 }
        return allowedOffsets.min { abs($0 - offset) < abs($1 - offset) } ?? 15
    }
}
