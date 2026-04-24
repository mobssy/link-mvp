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
        switch key {
        case "translation": return languageManager.localize(ko: "번역", en: "Translation", ja: "翻訳", zh: "翻译", es: "Traducción")
        case "translation_footer": return languageManager.localize(ko: "언어 자동 감지 또는 대상 언어를 지정할 수 있습니다", en: "Enable auto-detect or choose a target language", ja: "言語の自動検出またはターゲット言語を指定できます", zh: "可以启用自动检测或指定目标语言", es: "Activa la detección automática o elige un idioma de destino")
        case "translation_enable": return languageManager.localize(ko: "번역 활성화", en: "Enable Translation", ja: "翻訳を有効にする", zh: "启用翻译", es: "Activar traducción")
        case "translation_auto_detect": return languageManager.localize(ko: "자동 감지", en: "Auto Detect", ja: "自動検出", zh: "自动检测", es: "Detección automática")
        case "translation_target": return languageManager.localize(ko: "대상 언어", en: "Target Language", ja: "ターゲット言語", zh: "目标语言", es: "Idioma de destino")
        case "translation_show_original": return languageManager.localize(ko: "원문 함께 표시", en: "Show Original", ja: "原文も表示", zh: "同时显示原文", es: "Mostrar original")
        case "auto": return languageManager.localize(ko: "자동", en: "Auto", ja: "自動", zh: "自动", es: "Automático")
        default: return key
        }
    }
}
