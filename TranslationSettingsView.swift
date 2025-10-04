import SwiftUI

struct TranslationSettingsView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @AppStorage("translationEnabled") private var translationEnabled = false
    @AppStorage("translationAutoDetect") private var translationAutoDetect = true
    @AppStorage("translationTargetLanguage") private var translationTargetLanguage = "auto"
    @AppStorage("translationShowOriginal") private var translationShowOriginal = true

    var body: some View {
        Form {
            Section(header: Text(localizedText("translation")), footer: Text(localizedText("translation_footer"))) {
                Toggle(isOn: $translationEnabled) {
                    HStack(spacing: 12) {
                        Image(systemName: "character.bubble")
                            .foregroundColor(.teal)
                        Text(localizedText("translation_enable"))
                    }
                }
                Toggle(isOn: $translationAutoDetect) {
                    HStack(spacing: 12) {
                        Image(systemName: "text.magnifyingglass")
                            .foregroundColor(.indigo)
                        Text(localizedText("translation_auto_detect"))
                    }
                }
                Picker(localizedText("translation_target"), selection: $translationTargetLanguage) {
                    Text(localizedText("auto")).tag("auto")
                    Text("한국어").tag("ko")
                    Text("English").tag("en")
                    Text("日本語").tag("ja")
                    Text("中文(简体)").tag("zh-Hans")
                    Text("中文(繁體)").tag("zh-Hant")
                }
                .pickerStyle(.navigationLink)
                Toggle(isOn: $translationShowOriginal) {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .foregroundColor(.gray)
                        Text(localizedText("translation_show_original"))
                    }
                }
            }
        }
        .navigationTitle(localizedText("translation"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func localizedText(_ key: String) -> String {
        let isKorean = (languageManager.currentLanguage == .korean)
        switch key {
        case "translation": return isKorean ? "번역" : "Translation"
        case "translation_footer": return isKorean ? "언어 자동 감지 또는 대상 언어를 지정할 수 있습니다" : "Enable auto-detect or choose a target language"
        case "translation_enable": return isKorean ? "번역 활성화" : "Enable Translation"
        case "translation_auto_detect": return isKorean ? "자동 감지" : "Auto Detect"
        case "translation_target": return isKorean ? "대상 언어" : "Target Language"
        case "translation_show_original": return isKorean ? "원문 함께 표시" : "Show Original"
        case "auto": return isKorean ? "자동" : "Auto"
        default: return key
        }
    }
}
