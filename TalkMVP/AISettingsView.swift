import SwiftUI

struct AISettingsView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @AppStorage("aiSummaryEnabled") private var aiSummaryEnabled = false
    @AppStorage("aiSearchEnabled") private var aiSearchEnabled = true
    @AppStorage("aiAutoMeetingNotesEnabled") private var aiAutoMeetingNotesEnabled = false

    var body: some View {
        Form {
            Section {
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
            } header: {
                Text(localizedText("ai_features"))
            } footer: {
                Text(localizedText("ai_meeting_notes_footer"))
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
        case "ai_meeting_notes": return languageManager.localize(ko: "회의 노트", en: "Meeting Notes", ja: "会議メモ", zh: "会议记录", es: "Notas de reunión")
        case "ai_meeting_notes_footer": return languageManager.localize(ko: "회의 노트는 대화의 결정 사항, 할 일, 일정, 남은 질문을 정리해 줍니다. 채팅방 메뉴에서 열 수 있어요.", en: "Meeting notes pull the decisions, tasks, dates and open questions out of a chat. Open them from the chat's menu.", ja: "会議メモは会話の決定事項、タスク、日程、未解決の質問をまとめます。チャットのメニューから開けます。", zh: "会议记录会整理聊天中的决定、任务、日程和待解决的问题。可从聊天菜单打开。", es: "Las notas de reunión reúnen las decisiones, tareas, fechas y preguntas abiertas de un chat. Ábrelas desde el menú del chat.")
        default: return key
        }
    }
}
