import SwiftUI

struct AISettingsView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @AppStorage("aiSummaryEnabled") private var aiSummaryEnabled = false
    @AppStorage("aiSearchEnabled") private var aiSearchEnabled = true
    @AppStorage("aiAutoMeetingNotesEnabled") private var aiAutoMeetingNotesEnabled = false
    @AppStorage(ReplySuggestionSettings.key) private var aiReplySuggestionsEnabled = true

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
                Toggle(isOn: $aiReplySuggestionsEnabled) {
                    HStack(spacing: 12) {
                        Image(systemName: "text.bubble")
                            .foregroundColor(.orange)
                        Text(localizedText("ai_reply_suggestions"))
                    }
                }
            } header: {
                Text(localizedText("ai_features"))
            } footer: {
                Text(localizedText("ai_features_footer"))
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
        case "ai_reply_suggestions": return languageManager.localize(ko: "답장 추천", en: "Reply Suggestions", ja: "返信の提案", zh: "回复建议", es: "Respuestas sugeridas")
        case "ai_features_footer": return languageManager.localize(ko: "회의 노트는 대화의 결정 사항, 할 일, 일정, 남은 질문을 정리해 주며 채팅방 메뉴에서 열 수 있어요. 답장 추천은 상대가 메시지를 보내면 입력창 위에 짧은 답장을 띄워 줍니다. 둘 다 기기 안의 Apple Intelligence를 사용해요.", en: "Meeting notes pull the decisions, tasks, dates and open questions out of a chat; open them from the chat's menu. Reply suggestions offer short answers above the message field when someone writes to you. Both use Apple Intelligence on device.", ja: "会議メモは会話の決定事項、タスク、日程、未解決の質問をまとめ、チャットのメニューから開けます。返信の提案は、メッセージが届くと入力欄の上に短い返信を表示します。どちらもデバイス上のApple Intelligenceを使います。", zh: "会议记录会整理聊天中的决定、任务、日程和待解决的问题，可从聊天菜单打开。收到消息时，回复建议会在输入框上方提供简短回复。两者都使用设备上的 Apple Intelligence。", es: "Las notas de reunión reúnen las decisiones, tareas, fechas y preguntas abiertas de un chat; ábrelas desde el menú del chat. Las respuestas sugeridas ofrecen respuestas cortas sobre el campo de mensaje cuando alguien te escribe. Ambas usan Apple Intelligence en el dispositivo.")
        default: return key
        }
    }
}
