import SwiftUI
import UIKit

enum ExternalLinks {
    static let support = URL(string: "https://www.linkedin.com/in/mahi-al-jawad/")
}

struct SettingsOpener {
    let open: @MainActor () -> Void

    @MainActor
    func callAsFunction() {
        open()
    }

    static let system = SettingsOpener {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct SettingsOpenerEnvironmentKey: EnvironmentKey {
    static let defaultValue = SettingsOpener.system
}

extension EnvironmentValues {
    var settingsOpener: SettingsOpener {
        get { self[SettingsOpenerEnvironmentKey.self] }
        set { self[SettingsOpenerEnvironmentKey.self] = newValue }
    }
}
