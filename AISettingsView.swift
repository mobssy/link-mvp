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
        let isKorean = (languageManager.currentLanguage == .korean)
        switch key {
        case "ai_features": return isKorean ? "AI 기능" : "AI Features"
        case "ai_summary": return isKorean ? "대화 요약" : "Conversation Summary"
        case "ai_search": return isKorean ? "대화 검색" : "Conversation Search"
        case "ai_meeting_notes": return isKorean ? "자동 회의 노트" : "Auto Meeting Notes"
        default: return key
        }
    }
}
