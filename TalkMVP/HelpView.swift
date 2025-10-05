import SwiftUI

struct HelpView: View {
    @EnvironmentObject var languageManager: LanguageManager

    private func localizedText(_ key: String) -> String {
        if languageManager.currentLanguage == .korean {
            switch key {
            case "Help": return "도움말"
            case "FAQs": return "자주 묻는 질문"
            case "What is this app about?": return "이 앱은 무엇인가요?"
            case "This app helps you manage tasks efficiently.": return "이 앱은 작업을 효율적으로 관리하도록 도와줍니다."
            case "How to reset my password?": return "비밀번호를 어떻게 재설정하나요?"
            case "Go to settings and select 'Reset Password'.": return "설정으로 가서 '비밀번호 재설정'을 선택하세요."
            case "Contact Support": return "지원 문의"
            case "Send a support request": return "지원 요청 보내기"
            default: return key
            }
        } else {
            switch key {
            case "Help": return "Help"
            case "FAQs": return "FAQs"
            case "What is this app about?": return "What is this app about?"
            case "This app helps you manage tasks efficiently.": return "This app helps you manage tasks efficiently."
            case "How to reset my password?": return "How to reset my password?"
            case "Go to settings and select 'Reset Password'.": return "Go to settings and select 'Reset Password'."
            case "Contact Support": return "Contact Support"
            case "Send a support request": return "Send a support request"
            default: return key
            }
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(localizedText("FAQs"))) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localizedText("What is this app about?"))
                            .fontWeight(.semibold)
                        Text(localizedText("This app helps you manage tasks efficiently."))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localizedText("How to reset my password?"))
                            .fontWeight(.semibold)
                        Text(localizedText("Go to settings and select 'Reset Password'."))
                    }
                }

                Section(header: Text(localizedText("Contact Support"))) {
                    Button(action: {
                        print("Support request button tapped")
                    }) {
                        Text(localizedText("Send a support request"))
                    }
                }
            }
            .navigationTitle(localizedText("Help"))
        }
    }
}

#Preview {
    HelpView()
        .environmentObject(LanguageManager())
}
