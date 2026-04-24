import SwiftUI

struct AISettingsView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @AppStorage("aiSummaryEnabled") private var aiSummaryEnabled = false
    @AppStorage("aiSearchEnabled") private var aiSearchEnabled = true
    @AppStorage("aiAutoMeetingNotesEnabled") private var aiAutoMeetingNotesEnabled = false

    var body: some View {
        Form {
            Section(header: Text(localizedText("ai_features"))) {
                Toggle(isOn: $aiSummaryEnabled) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.pink)
                        Text(localizedText("ai_summary"))
                    }
                }
                Toggle(isOn: $aiSearchEnabled) {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.blue)
                        Text(localizedText("ai_search"))
                    }
                }
                Toggle(isOn: $aiAutoMeetingNotesEnabled) {
                    HStack(spacing: 12) {
                        Image(systemName: "note.text")
                            .foregroundColor(.green)
                        Text(localizedText("ai_meeting_notes"))
                    }
                }
            }
        }
        .navigationTitle(localizedText("ai_features"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func localizedText(_ key: String) -> String {
        switch key {
        case "ai_features": return languageManager.localize(ko: "AI 기능", en: "AI Features", ja: "AI機能", zh: "AI功能", es: "Funciones de IA")
        case "ai_summary": return languageManager.localize(ko: "대화 요약", en: "Conversation Summary", ja: "会話要約", zh: "对话摘要", es: "Resumen de conversación")
        case "ai_search": return languageManager.localize(ko: "대화 검색", en: "Conversation Search", ja: "会話検索", zh: "对话搜索", es: "Búsqueda de conversación")
        case "ai_meeting_notes": return languageManager.localize(ko: "자동 회의 노트", en: "Auto Meeting Notes", ja: "自動会議メモ", zh: "自动会议记录", es: "Notas de reunión automáticas")
        default: return key
        }
    }
}
