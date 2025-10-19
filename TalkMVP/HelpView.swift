import SwiftUI

struct HelpView: View {
    @EnvironmentObject var languageManager: LanguageManager

    private func localizedText(_ key: String) -> String {
        if languageManager.currentLanguage == .korean {
            switch key {
            // General
            case "Help": return "도움말"
            case "FAQs": return "자주 묻는 질문"
            case "Contact Support": return "지원 문의"
            case "Send a support request": return "지원 요청 보내기"

            // FAQ 1: 메시지가 안 보내져요.
            case "faq_msg_not_sending_q": return "메시지가 안 보내져요."
            case "faq_msg_not_sending_a1": return "네트워크 연결 상태를 확인한 뒤 다시 시도해보세요."
            case "faq_msg_not_sending_a2": return "Wi-Fi나 데이터가 약하면 전송이 지연될 수 있습니다."

            // FAQ 2: 알림이 오지 않아요.
            case "faq_notifs_not_coming_q": return "알림이 오지 않아요."
            case "faq_notifs_not_coming_a1": return "설정 → 알림 → TalkMVP를 선택해 알림이 켜져 있는지 확인하세요."
            case "faq_notifs_not_coming_a2": return "집중 모드나 절전 모드가 켜져 있으면 알림이 제한됩니다."

            // FAQ 3: 친구 추가
            case "faq_how_to_add_friend_q": return "친구를 추가하려면 어떻게 하나요?"
            case "faq_how_to_add_friend_a": return "친구 탭에서 + 버튼을 눌러 전화번호 또는 이메일로 검색하세요."

            // FAQ 4: 비밀번호 재설정
            case "faq_forgot_password_q": return "비밀번호를 잊었어요."
            case "faq_forgot_password_a1": return "로그인 화면에서 ‘비밀번호 재설정’을 눌러 이메일을 입력하세요."
            case "faq_forgot_password_a2": return "등록된 주소로 재설정 링크가 발송됩니다."

            // FAQ 5: 계정 삭제
            case "faq_delete_account_q": return "내 계정을 삭제하고 싶어요."
            case "faq_delete_account_a1": return "설정 → 계정 관리 → ‘계정 삭제’를 선택하면 삭제할 수 있습니다."
            case "faq_delete_account_a2": return "삭제 시 모든 대화 내용은 복구되지 않아요."

            default: return key
            }
        } else {
            switch key {
            // General
            case "Help": return "Help"
            case "FAQs": return "FAQs"
            case "Contact Support": return "Contact Support"
            case "Send a support request": return "Send a support request"

            // FAQ 1: Messages not sending
            case "faq_msg_not_sending_q": return "Messages aren't sending."
            case "faq_msg_not_sending_a1": return "Check your network connection and try again."
            case "faq_msg_not_sending_a2": return "If Wi‑Fi or cellular data is weak, sending may be delayed."

            // FAQ 2: Notifications not coming
            case "faq_notifs_not_coming_q": return "I'm not receiving notifications."
            case "faq_notifs_not_coming_a1": return "Go to Settings → Notifications → TalkMVP and make sure notifications are enabled."
            case "faq_notifs_not_coming_a2": return "Focus or Low Power Mode may limit notifications."

            // FAQ 3: Add friend
            case "faq_how_to_add_friend_q": return "How do I add friends?"
            case "faq_how_to_add_friend_a": return "In the Friends tab, tap the + button and search by phone number or email."

            // FAQ 4: Forgot password
            case "faq_forgot_password_q": return "I forgot my password."
            case "faq_forgot_password_a1": return "On the login screen, tap ‘Reset Password’ and enter your email."
            case "faq_forgot_password_a2": return "A reset link will be sent to your registered address."

            // FAQ 5: Delete account
            case "faq_delete_account_q": return "I want to delete my account."
            case "faq_delete_account_a1": return "Go to Settings → Account Management → ‘Delete Account’."
            case "faq_delete_account_a2": return "Deleting your account permanently removes all conversations and cannot be undone."

            default: return key
            }
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(localizedText("FAQs"))) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Q. \(localizedText("faq_msg_not_sending_q"))").fontWeight(.semibold)
                        Text(localizedText("faq_msg_not_sending_a1"))
                        Text(localizedText("faq_msg_not_sending_a2"))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Q. \(localizedText("faq_notifs_not_coming_q"))").fontWeight(.semibold)
                        Text(localizedText("faq_notifs_not_coming_a1"))
                        Text(localizedText("faq_notifs_not_coming_a2"))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Q. \(localizedText("faq_how_to_add_friend_q"))").fontWeight(.semibold)
                        Text(localizedText("faq_how_to_add_friend_a"))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Q. \(localizedText("faq_forgot_password_q"))").fontWeight(.semibold)
                        Text(localizedText("faq_forgot_password_a1"))
                        Text(localizedText("faq_forgot_password_a2"))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Q. \(localizedText("faq_delete_account_q"))").fontWeight(.semibold)
                        Text(localizedText("faq_delete_account_a1"))
                        Text(localizedText("faq_delete_account_a2"))
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
