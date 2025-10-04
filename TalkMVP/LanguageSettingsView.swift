//
//  LanguageSettingsView.swift
//  TalkMVP
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
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
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
            return languageManager.isKorean ? "언어 선택" : "Language Selection"
        case "language.settings.footer":
            return languageManager.isKorean ? 
                "언어를 변경하면 앱이 다시 시작됩니다." : 
                "The app will restart when you change the language."
        case "language.title":
            return languageManager.isKorean ? "언어" : "Language"
        case "common.done":
            return languageManager.isKorean ? "완료" : "Done"
        case "common.cancel":
            return languageManager.isKorean ? "취소" : "Cancel"
        case "language.restart.title":
            return languageManager.isKorean ? "언어 변경" : "Change Language"
        case "language.restart.message":
            return languageManager.isKorean ? 
                "언어를 변경하면 앱이 다시 시작됩니다. 계속하시겠습니까?" : 
                "Changing the language will restart the app. Do you want to continue?"
        case "language.restart.confirm":
            return languageManager.isKorean ? "변경" : "Change"
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
            // 현재 언어가 영어면 "Korean"으로, 한국어면 "Korean"으로 표시
            return languageManager.currentLanguage == .korean ? "Korean" : "Korean"
        case .english:
            // 현재 언어가 한국어면 "영어"로, 영어면 "English"로 표시
            return languageManager.currentLanguage == .korean ? "영어" : "English"
        }
    }
}

#Preview {
    LanguageSettingsView()
        .environmentObject(LanguageManager())
}

