import SwiftUI

struct TranslationSettingsView: View {
    @Environment(LanguageManager.self) private var languageManager
    @AppStorage("translationEnabled") private var translationEnabled = false
    @AppStorage("translationTargetLanguage") private var translationTargetLanguage = "auto"

    var body: some View {
        Form {
            Section(header: Text(localizedText("translation")), footer: Text(localizedText("translation_footer"))) {
                Toggle(isOn: $translationEnabled) {
                    HStack(spacing: 12) {
                        Image(systemName: "character.bubble")
                            .foregroundStyle(.teal)
                        Text(localizedText("translation_enable"))
                    }
                }
                Picker(localizedText("translation_target"), selection: $translationTargetLanguage) {
                    Text(localizedText("auto")).tag("auto")
                    Text("한국어").tag("ko")
                    Text("English").tag("en")
                    Text("日本語").tag("ja")
                    Text("中文(简体)").tag("zh-Hans")
                    Text("中文(繁體)").tag("zh-Hant")
                    Text("Español").tag("es")
                }
                .pickerStyle(.navigationLink)
            }
        }
        .navigationTitle(localizedText("translation"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func localizedText(_ key: String) -> String {
        switch key {
        case "translation": return languageManager.localize(ko: "번역", en: "Translation", ja: "翻訳", zh: "翻译", es: "Traducción")
        case "translation_footer": return languageManager.localize(
            ko: "다른 언어로 온 메시지는 말풍선 안에 번역이 함께 보여요. 번역은 이 기기 안에서 이루어집니다.",
            en: "A message in another language shows its translation inside the bubble. Translation happens on this device.",
            ja: "ほかの言語で届いたメッセージは、吹き出しの中に翻訳が表示されます。翻訳はこのデバイス上で行われます。",
            zh: "其他语言的消息会在气泡内显示译文。翻译在此设备上完成。",
            es: "Un mensaje en otro idioma muestra su traducción dentro de la burbuja. La traducción se hace en este dispositivo.")
        case "translation_enable": return languageManager.localize(ko: "메시지 번역", en: "Translate Messages", ja: "メッセージを翻訳", zh: "翻译消息", es: "Traducir mensajes")
        case "translation_target": return languageManager.localize(ko: "번역할 언어", en: "Translate Into", ja: "翻訳先の言語", zh: "翻译成", es: "Traducir al")
        case "auto": return languageManager.localize(ko: "앱 언어", en: "App Language", ja: "アプリの言語", zh: "应用语言", es: "Idioma de la app")
        default: return key
        }
    }
}
