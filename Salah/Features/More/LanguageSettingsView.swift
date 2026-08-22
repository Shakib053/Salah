import SwiftUI

struct LanguageSettingsView: View {
    @Bindable var container: AppContainer

    var body: some View {
        @Bindable var settings = container.settings
        Form {
            Section {
                Picker("Language", selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(verbatim: language.selectorTitle).tag(language)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .accessibilityIdentifier("settings.language.picker")
            } footer: {
                Text("System follows your iPhone language. English and Bangla override it only inside Salah.")
            }
        }
        .navigationTitle("Language")
        .navigationBarTitleDisplayMode(.inline)
        .phoneOnlyHideTabBar()
    }
}
