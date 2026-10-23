import SwiftUI

struct ThemeSettingsView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @AppStorage("themeMode") private var themeMode: String = "system" // "system", "light", "dark"

    var body: some View {
        Form {
            Section(header: Text(localizedText("theme"))) {
                Picker(selection: $themeMode) {
                    Label(localizedText("appearance_system"), systemImage: "iphone")
                        .tag("system")
                    Label(localizedText("appearance_light"), systemImage: "sun.max.fill")
                        .tag("light")
                    Label(localizedText("appearance_dark"), systemImage: "moon.fill")
                        .tag("dark")
                } label: {
                    EmptyView()
                }
                .pickerStyle(.inline)
            }
        }
        .navigationTitle(localizedText("theme"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func localizedText(_ key: String) -> String {
        switch key {
        case "theme": return languageManager.localize(ko: "테마", en: "Theme", ja: "テーマ", zh: "主题", es: "Tema")
        case "appearance_system": return languageManager.localize(ko: "기기 설정", en: "Use System", ja: "システム設定", zh: "系统设置", es: "Configuración del sistema")
        case "appearance_light": return languageManager.localize(ko: "라이트 모드", en: "Light", ja: "ライトモード", zh: "浅色模式", es: "Modo claro")
        case "appearance_dark": return languageManager.localize(ko: "다크 모드", en: "Dark", ja: "ダークモード", zh: "深色模式", es: "Modo oscuro")
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
