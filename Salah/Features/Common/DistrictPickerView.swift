import SwiftUI

struct DistrictPickerView: View {
    let districts: [District]
    let onSelect: (District) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: [District] {
        guard !search.isEmpty else { return districts }
        return districts.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.banglaName.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        List(filtered) { district in
            Button {
                onSelect(district)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(district.localizedName).foregroundStyle(.primary)
                    if L10n.usesBangla {
                        Text(district.name).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
        }
        .navigationTitle("Choose District")
        .searchable(text: $search, prompt: "District name")
        .overlay {
            if filtered.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}
