//
//  LanguageSettingsView.swift
//  L!nkMVP
//
//  Created by David Song on 10/3/25.
//

import SwiftUI

struct LanguageSettingsView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingRestartAlert = false
    @State private var pendingLanguage: LanguageManager.Language?

    var body: some View {
        NavigationStack {
            List {
                Section(
                    header: Text(localizedText(key: "language.settings.title")),
                    footer: Text(localizedText(key: "language.settings.footer"))
                ) {
                    ForEach(LanguageManager.Language.allCases, id: \.self) { language in
                        LanguageRow(
                            language: language,
                            isSelected: languageManager.currentLanguage == language
                        ) {
                            selectLanguage(language)
                        }
                    }
                }

                // 디버그 정보 섹션 (선택적)
                if ProcessInfo.processInfo.environment["SHOW_LANGUAGE_DEBUG"] == "1" {
                    Section(header: Text("Debug Info")) {
                        let info = languageManager.getLanguageInfo()
                        ForEach(Array(info.keys.sorted()), id: \.self) { key in
                            HStack {
                                Text(key)
                                    .font(.caption)
                                Spacer()
                                Text(info[key] ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(localizedText(key: "language.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizedText(key: "common.done")) {
                        dismiss()
                    }
                }
            }
            .alert(
                localizedText(key: "language.restart.title"),
                isPresented: $showingRestartAlert
            ) {
                Button(localizedText(key: "common.cancel"), role: .cancel) {
                    pendingLanguage = nil
                }
                Button(localizedText(key: "language.restart.confirm")) {
                    if let pendingLanguage = pendingLanguage {
                        languageManager.setLanguage(pendingLanguage)
                        // 앱을 다시 시작하도록 알림 또는 다른 처리 로직
                        dismiss()
                    }
                }
            } message: {
                Text(localizedText(key: "language.restart.message"))
            }
        }
    }

    private func selectLanguage(_ language: LanguageManager.Language) {
        if language != languageManager.currentLanguage {
            pendingLanguage = language
            showingRestartAlert = true
        }
    }

    private func localizedText(key: String) -> String {
        // 현재 언어 설정에 따른 지역화된 텍스트 반환
        switch key {
        case "language.settings.title":
            return languageManager.localize(
                ko: "언어 선택",
                en: "Language Selection",
                ja: "言語選択",
                zh: "语言选择",
                es: "Selección de idioma"
            )
        case "language.settings.footer":
            return languageManager.localize(
                ko: "언어를 변경하면 앱이 다시 시작됩니다.",
                en: "The app will restart when you change the language.",
                ja: "言語を変更するとアプリが再起動します。",
                zh: "更改语言后应用将重新启动。",
                es: "La aplicación se reiniciará al cambiar el idioma."
            )
        case "language.title":
            return languageManager.localize(
                ko: "언어",
                en: "Language",
                ja: "言語",
                zh: "语言",
                es: "Idioma"
            )
        case "common.done":
            return languageManager.localize(
                ko: "완료",
                en: "Done",
                ja: "完了",
                zh: "完成",
                es: "Listo"
            )
        case "common.cancel":
            return languageManager.localize(
                ko: "취소",
                en: "Cancel",
                ja: "キャンセル",
                zh: "取消",
                es: "Cancelar"
            )
        case "language.restart.title":
            return languageManager.localize(
                ko: "언어 변경",
                en: "Change Language",
                ja: "言語変更",
                zh: "更改语言",
                es: "Cambiar idioma"
            )
        case "language.restart.message":
            return languageManager.localize(
                ko: "언어를 변경하면 앱이 다시 시작됩니다. 계속하시겠습니까?",
                en: "Changing the language will restart the app. Do you want to continue?",
                ja: "言語を変更するとアプリが再起動します。続けますか？",
                zh: "更改语言将重新启动应用。是否继续？",
                es: "Cambiar el idioma reiniciará la aplicación. ¿Desea continuar?"
            )
        case "language.restart.confirm":
            return languageManager.localize(
                ko: "변경",
                en: "Change",
                ja: "変更",
                zh: "更改",
                es: "Cambiar"
            )
        default:
            return key
        }
    }
}

struct LanguageRow: View {
    let language: LanguageManager.Language
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(language.displayName)
                        .font(.body)
                        .foregroundColor(.primary)

                    // 현재 설정된 언어와 다른 언어로 설명 표시
                    Text(getAlternativeLanguageName(for: language))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func getAlternativeLanguageName(for language: LanguageManager.Language) -> String {
        switch language {
        case .korean:
            return languageManager.localize(ko: "Korean", en: "Korean", ja: "韓国語", zh: "韩语", es: "Coreano")
        case .english:
            return languageManager.localize(ko: "영어", en: "English", ja: "英語", zh: "英语", es: "Inglés")
        case .japanese:
            return languageManager.localize(ko: "일본어", en: "Japanese", ja: "日本語", zh: "日语", es: "Japonés")
        case .chinese:
            return languageManager.localize(ko: "중국어 (간체)", en: "Chinese (Simplified)", ja: "中国語（簡体字）", zh: "中文（简体）", es: "Chino simplificado")
        case .chineseTraditional:
            return languageManager.localize(ko: "중국어 (번체)", en: "Chinese (Traditional)", ja: "中国語（繁体字）", zh: "中文（繁體）", es: "Chino tradicional")
        case .spanish:
            return languageManager.localize(ko: "스페인어", en: "Spanish", ja: "スペイン語", zh: "西班牙语", es: "Español")
        }
    }
}

#Preview {
    LanguageSettingsView()
        .environmentObject(LanguageManager())
}
