import SwiftUI

struct TrackerPrayerRow: View {
    let prayer: PrayerType
    let completed: Bool
    let action: () -> Void
    @Environment(\.salahPalette) private var palette

    var body: some View {
        Button(action: action) {
            TrackerStatusRowContent(
                title: prayer.title,
                subtitle: completed ? "Completed" : "Not marked yet",
                completed: completed,
                accent: palette.accent
            ) {
                PrayerIcon(prayer: prayer)
            }
            .padding()
            .frame(minHeight: 64)
            .background(palette.groupedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.string("\(prayer.title), \(completed ? L10n.string("completed") : L10n.string("not completed"))"))
        .accessibilityHint(L10n.dynamic(completed ? "Double tap to mark as not completed" : "Double tap to mark as completed"))
    }
}

struct GoodDeedRow: View {
    let title: String
    let symbol: String
    let completed: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            TrackerStatusRowContent(
                title: title,
                subtitle: completed ? "Completed" : "Not marked yet",
                completed: completed,
                accent: accent
            ) {
                TrackerSymbolIcon(symbol: symbol)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(title)
        .accessibilityValue(L10n.dynamic(completed ? "completed" : "not completed"))
        .accessibilityHint(L10n.dynamic(completed ? "Double tap to mark as not completed" : "Double tap to mark as completed"))
    }
}

private struct TrackerStatusRowContent<Leading: View>: View {
    let title: String
    let subtitle: String
    let completed: Bool
    let accent: Color
    @ViewBuilder let leading: Leading

    var body: some View {
        HStack(spacing: 12) {
            leading
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.dynamic(title)).font(.headline)
                Text(L10n.dynamic(subtitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(completed ? accent : .secondary)
                .accessibilityHidden(true)
        }
    }
}
