import SwiftUI

struct ThemeSettingsView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @AppStorage("themeMode") private var themeMode: String = "system" // "system", "light", "dark"

    var body: some View {
        Form {
            Section(header: Text(localizedText("theme"))) {
                Picker("", selection: $themeMode) {
                    Text(localizedText("appearance_system")).tag("system")
                    Text(localizedText("appearance_light")).tag("light")
                    Text(localizedText("appearance_dark")).tag("dark")
                }
                .pickerStyle(.inline)
            }
        }
        .navigationTitle(localizedText("theme"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func localizedText(_ key: String) -> String {
        let isKorean = languageManager.isKorean
        switch key {
        case "theme": return isKorean ? "테마" : "Theme"
        case "appearance_system": return isKorean ? "기기 설정" : "Use System"
        case "appearance_light": return isKorean ? "라이트 모드" : "Light"
        case "appearance_dark": return isKorean ? "다크 모드" : "Dark"
        default: return key
        }
    }
}

#Preview {
    NavigationStack {
        ThemeSettingsView()
            .environmentObject(LanguageManager())
    }
}
