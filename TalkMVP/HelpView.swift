import SwiftUI
import MessageUI

struct HelpView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingSupportSheet = false
    @State private var showingMailComposer = false
    @State private var expandedSections: Set<String> = []

    // MARK: - FAQ Categories
    enum FAQCategory: String, CaseIterable {
        case gettingStarted
        case messaging
        case friends
        case notifications
        case accountSettings
        case troubleshooting

        func title(isKorean: Bool) -> String {
            switch self {
            case .gettingStarted: return isKorean ? "시작하기" : "Getting Started"
            case .messaging: return isKorean ? "메시지" : "Messaging"
            case .friends: return isKorean ? "친구" : "Friends"
            case .notifications: return isKorean ? "알림" : "Notifications"
            case .accountSettings: return isKorean ? "계정 및 설정" : "Account & Settings"
            case .troubleshooting: return isKorean ? "문제 해결" : "Troubleshooting"
            }
        }

        func icon() -> String {
            switch self {
            case .gettingStarted: return "star.fill"
            case .messaging: return "message.fill"
            case .friends: return "person.2.fill"
            case .notifications: return "bell.fill"
            case .accountSettings: return "gearshape.fill"
            case .troubleshooting: return "wrench.and.screwdriver.fill"
            }
        }
    }

    struct FAQItem: Identifiable {
        let id = UUID()
        let category: FAQCategory
        let questionKey: String
        let answerKeys: [String]
    }

    private var allFAQs: [FAQItem] {
        [
            // Getting Started
            FAQItem(category: .gettingStarted, questionKey: "faq_first_steps_q", answerKeys: ["faq_first_steps_a1", "faq_first_steps_a2", "faq_first_steps_a3"]),
            FAQItem(category: .gettingStarted, questionKey: "faq_profile_setup_q", answerKeys: ["faq_profile_setup_a"]),

            // Messaging
            FAQItem(category: .messaging, questionKey: "faq_msg_not_sending_q", answerKeys: ["faq_msg_not_sending_a1", "faq_msg_not_sending_a2"]),
            FAQItem(category: .messaging, questionKey: "faq_send_photos_q", answerKeys: ["faq_send_photos_a"]),
            FAQItem(category: .messaging, questionKey: "faq_delete_msg_q", answerKeys: ["faq_delete_msg_a"]),
            FAQItem(category: .messaging, questionKey: "faq_search_msg_q", answerKeys: ["faq_search_msg_a"]),

            // Friends
            FAQItem(category: .friends, questionKey: "faq_how_to_add_friend_q", answerKeys: ["faq_how_to_add_friend_a"]),
            FAQItem(category: .friends, questionKey: "faq_block_friend_q", answerKeys: ["faq_block_friend_a"]),
            FAQItem(category: .friends, questionKey: "faq_favorite_friend_q", answerKeys: ["faq_favorite_friend_a"]),

            // Notifications
            FAQItem(category: .notifications, questionKey: "faq_notifs_not_coming_q", answerKeys: ["faq_notifs_not_coming_a1", "faq_notifs_not_coming_a2"]),
            FAQItem(category: .notifications, questionKey: "faq_mute_chat_q", answerKeys: ["faq_mute_chat_a"]),

            // Account & Settings
            FAQItem(category: .accountSettings, questionKey: "faq_change_language_q", answerKeys: ["faq_change_language_a"]),
            FAQItem(category: .accountSettings, questionKey: "faq_change_theme_q", answerKeys: ["faq_change_theme_a"]),
            FAQItem(category: .accountSettings, questionKey: "faq_forgot_password_q", answerKeys: ["faq_forgot_password_a1", "faq_forgot_password_a2"]),
            FAQItem(category: .accountSettings, questionKey: "faq_delete_account_q", answerKeys: ["faq_delete_account_a1", "faq_delete_account_a2"]),

            // Troubleshooting
            FAQItem(category: .troubleshooting, questionKey: "faq_app_slow_q", answerKeys: ["faq_app_slow_a1", "faq_app_slow_a2"]),
            FAQItem(category: .troubleshooting, questionKey: "faq_crash_q", answerKeys: ["faq_crash_a"]),
        ]
    }

    private func localizedText(_ key: String) -> String {
        if languageManager.currentLanguage == .korean {
            switch key {
            // General
            case "help": return "도움말"
            case "faqs": return "자주 묻는 질문"
            case "contact_support": return "지원 문의"
            case "send_feedback": return "피드백 보내기"
            case "email_support": return "이메일로 문의하기"
            case "app_version": return "앱 버전"
            case "quick_guides": return "빠른 가이드"
            case "tips_tricks": return "유용한 팁"

            // Getting Started
            case "faq_first_steps_q": return "앱을 처음 사용해요. 어떻게 시작하나요?"
            case "faq_first_steps_a1": return "1. 프로필을 설정하세요 (이름, 프로필 사진)"
            case "faq_first_steps_a2": return "2. 친구 탭에서 친구를 추가하세요"
            case "faq_first_steps_a3": return "3. 채팅 탭에서 대화를 시작하세요"
            case "faq_profile_setup_q": return "프로필을 어떻게 설정하나요?"
            case "faq_profile_setup_a": return "친구 탭 → 내 프로필을 탭하면 이름, 상태 메시지, 프로필 사진을 변경할 수 있습니다."

            // Messaging
            case "faq_msg_not_sending_q": return "메시지가 전송되지 않아요"
            case "faq_msg_not_sending_a1": return "네트워크 연결을 확인하세요 (Wi-Fi 또는 데이터)"
            case "faq_msg_not_sending_a2": return "앱을 다시 시작해보세요"
            case "faq_send_photos_q": return "사진/동영상을 어떻게 보내나요?"
            case "faq_send_photos_a": return "채팅 입력창 왼쪽의 + 버튼을 눌러 사진/동영상을 선택하세요."
            case "faq_delete_msg_q": return "보낸 메시지를 삭제할 수 있나요?"
            case "faq_delete_msg_a": return "메시지를 길게 눌러 '삭제'를 선택하세요. 자신이 보낸 메시지만 삭제할 수 있습니다."
            case "faq_search_msg_q": return "이전 메시지를 검색하려면?"
            case "faq_search_msg_a": return "채팅방 상단의 검색 아이콘을 탭하여 키워드로 검색하세요."

            // Friends
            case "faq_how_to_add_friend_q": return "친구를 추가하려면?"
            case "faq_how_to_add_friend_a": return "친구 탭 → + 버튼 → 이메일로 검색하여 친구 요청을 보내세요."
            case "faq_block_friend_q": return "친구를 차단하려면?"
            case "faq_block_friend_a": return "친구 목록에서 친구를 왼쪽으로 스와이프하여 '차단'을 선택하세요."
            case "faq_favorite_friend_q": return "즐겨찾기 친구는 무엇인가요?"
            case "faq_favorite_friend_a": return "친구를 오른쪽으로 스와이프하여 별표를 추가하면 즐겨찾기 섹션에 표시됩니다."

            // Notifications
            case "faq_notifs_not_coming_q": return "알림이 오지 않아요"
            case "faq_notifs_not_coming_a1": return "설정 → 알림에서 L!nkMVP 알림이 허용되어 있는지 확인하세요."
            case "faq_notifs_not_coming_a2": return "집중 모드나 방해 금지 모드를 확인하세요."
            case "faq_mute_chat_q": return "특정 채팅방 알림을 끄려면?"
            case "faq_mute_chat_a": return "채팅방 우측 상단의 종 아이콘을 탭하여 알림을 끄거나 켤 수 있습니다."

            // Account & Settings
            case "faq_change_language_q": return "언어를 변경하려면?"
            case "faq_change_language_a": return "설정 → 언어 설정에서 한국어/English를 선택하세요."
            case "faq_change_theme_q": return "테마를 변경하려면?"
            case "faq_change_theme_a": return "설정 → 테마에서 라이트/다크/시스템 모드를 선택하세요."
            case "faq_forgot_password_q": return "비밀번호를 잊었어요"
            case "faq_forgot_password_a1": return "로그인 화면에서 '비밀번호 재설정'을 선택하세요."
            case "faq_forgot_password_a2": return "등록된 이메일로 재설정 링크가 전송됩니다."
            case "faq_delete_account_q": return "계정을 삭제하려면?"
            case "faq_delete_account_a1": return "설정 → 계정 삭제를 선택하세요."
            case "faq_delete_account_a2": return "⚠️ 삭제된 계정은 복구할 수 없으며, 모든 대화 내용이 영구 삭제됩니다."

            // Troubleshooting
            case "faq_app_slow_q": return "앱이 느려요"
            case "faq_app_slow_a1": return "앱을 완전히 종료한 후 다시 실행해보세요."
            case "faq_app_slow_a2": return "기기를 재시작해보세요."
            case "faq_crash_q": return "앱이 자주 종료돼요"
            case "faq_crash_a": return "최신 버전으로 업데이트했는지 확인하세요. 문제가 지속되면 지원팀에 문의하세요."

            // Quick Guides
            case "guide_reactions": return "반응 추가하기"
            case "guide_reactions_desc": return "메시지를 길게 눌러 이모지 반응을 추가할 수 있습니다."
            case "guide_reply": return "답장하기"
            case "guide_reply_desc": return "메시지를 왼쪽으로 스와이프하여 답장할 수 있습니다."
            case "guide_translation": return "메시지 번역"
            case "guide_translation_desc": return "설정 → 번역에서 자동 번역을 활성화하세요."

            default: return key
            }
        } else {
            switch key {
            // General
            case "help": return "Help"
            case "faqs": return "FAQs"
            case "contact_support": return "Contact Support"
            case "send_feedback": return "Send Feedback"
            case "email_support": return "Email Support"
            case "app_version": return "App Version"
            case "quick_guides": return "Quick Guides"
            case "tips_tricks": return "Tips & Tricks"

            // Getting Started
            case "faq_first_steps_q": return "I'm new to the app. How do I get started?"
            case "faq_first_steps_a1": return "1. Set up your profile (name, photo)"
            case "faq_first_steps_a2": return "2. Add friends from the Friends tab"
            case "faq_first_steps_a3": return "3. Start chatting from the Chats tab"
            case "faq_profile_setup_q": return "How do I set up my profile?"
            case "faq_profile_setup_a": return "Tap your profile in the Friends tab to change your name, status message, and profile photo."

            // Messaging
            case "faq_msg_not_sending_q": return "Messages aren't sending"
            case "faq_msg_not_sending_a1": return "Check your network connection (Wi-Fi or cellular data)"
            case "faq_msg_not_sending_a2": return "Try restarting the app"
            case "faq_send_photos_q": return "How do I send photos/videos?"
            case "faq_send_photos_a": return "Tap the + button on the left of the message input to select photos/videos."
            case "faq_delete_msg_q": return "Can I delete sent messages?"
            case "faq_delete_msg_a": return "Long press a message and select 'Delete'. You can only delete your own messages."
            case "faq_search_msg_q": return "How do I search previous messages?"
            case "faq_search_msg_a": return "Tap the search icon at the top of the chat to search by keyword."

            // Friends
            case "faq_how_to_add_friend_q": return "How do I add friends?"
            case "faq_how_to_add_friend_a": return "Friends tab → + button → Search by email and send a friend request."
            case "faq_block_friend_q": return "How do I block a friend?"
            case "faq_block_friend_a": return "Swipe left on a friend in the list and select 'Block'."
            case "faq_favorite_friend_q": return "What are favorite friends?"
            case "faq_favorite_friend_a": return "Swipe right on a friend and add a star to show them in the favorites section."

            // Notifications
            case "faq_notifs_not_coming_q": return "I'm not receiving notifications"
            case "faq_notifs_not_coming_a1": return "Check Settings → Notifications and ensure L!nkMVP notifications are enabled."
            case "faq_notifs_not_coming_a2": return "Check Focus mode or Do Not Disturb settings."
            case "faq_mute_chat_q": return "How do I mute a specific chat?"
            case "faq_mute_chat_a": return "Tap the bell icon at the top right of the chat to toggle notifications."

            // Account & Settings
            case "faq_change_language_q": return "How do I change the language?"
            case "faq_change_language_a": return "Settings → Language Settings → Select Korean/English."
            case "faq_change_theme_q": return "How do I change the theme?"
            case "faq_change_theme_a": return "Settings → Theme → Select Light/Dark/System mode."
            case "faq_forgot_password_q": return "I forgot my password"
            case "faq_forgot_password_a1": return "Select 'Reset Password' on the login screen."
            case "faq_forgot_password_a2": return "A reset link will be sent to your registered email."
            case "faq_delete_account_q": return "How do I delete my account?"
            case "faq_delete_account_a1": return "Settings → Delete Account."
            case "faq_delete_account_a2": return "⚠️ Deleted accounts cannot be recovered, and all conversations are permanently deleted."

            // Troubleshooting
            case "faq_app_slow_q": return "The app is slow"
            case "faq_app_slow_a1": return "Force quit the app and restart it."
            case "faq_app_slow_a2": return "Restart your device."
            case "faq_crash_q": return "The app crashes frequently"
            case "faq_crash_a": return "Make sure you're on the latest version. If the problem persists, contact support."

            // Quick Guides
            case "guide_reactions": return "Add Reactions"
            case "guide_reactions_desc": return "Long press a message to add emoji reactions."
            case "guide_reply": return "Reply to Messages"
            case "guide_reply_desc": return "Swipe left on a message to reply."
            case "guide_translation": return "Message Translation"
            case "guide_translation_desc": return "Enable auto-translation in Settings → Translation."

            default: return key
            }
        }
    }

    private func faqsByCategory(_ category: FAQCategory) -> [FAQItem] {
        allFAQs.filter { $0.category == category }
    }

    var body: some View {
        List {
            // Quick Guides Section
            Section {
                QuickGuideRow(
                    icon: "hand.tap.fill",
                    title: localizedText("guide_reactions"),
                    description: localizedText("guide_reactions_desc")
                )
                QuickGuideRow(
                    icon: "arrowshape.turn.up.left.fill",
                    title: localizedText("guide_reply"),
                    description: localizedText("guide_reply_desc")
                )
                QuickGuideRow(
                    icon: "character.bubble.fill",
                    title: localizedText("guide_translation"),
                    description: localizedText("guide_translation_desc")
                )
            } header: {
                Text(localizedText("quick_guides"))
            }

            // FAQ Categories
            Section {
                ForEach(FAQCategory.allCases, id: \.self) { category in
                    FAQCategoryView(
                        category: category,
                        faqs: faqsByCategory(category),
                        isExpanded: expandedSections.contains(category.rawValue),
                        localizedText: localizedText,
                        isKorean: languageManager.currentLanguage == .korean
                    ) {
                        toggleSection(category.rawValue)
                    }
                }
            } header: {
                Text(localizedText("faqs"))
            }

            // Support Section
            Section {
                Button {
                    sendEmail()
                } label: {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.appPrimary)
                        Text(localizedText("email_support"))
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }

                Button {
                    showingSupportSheet = true
                } label: {
                    HStack {
                        Image(systemName: "message.fill")
                            .foregroundColor(.appPrimary)
                        Text(localizedText("send_feedback"))
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            } header: {
                Text(localizedText("contact_support"))
            }

            // App Version
            Section {
                HStack {
                    Text(localizedText("app_version"))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(getAppVersion())
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(localizedText("help"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingSupportSheet) {
            FeedbackView()
                .environmentObject(languageManager)
        }
    }

    private func toggleSection(_ sectionId: String) {
        if expandedSections.contains(sectionId) {
            expandedSections.remove(sectionId)
        } else {
            expandedSections.insert(sectionId)
        }
    }

    private func sendEmail() {
        let email = "support@linkmvp.com"
        let subject = languageManager.currentLanguage == .korean ? "L!nkMVP 지원 요청" : "L!nkMVP Support Request"
        let body = languageManager.currentLanguage == .korean ?
            "문의 내용을 입력해주세요:\n\n앱 버전: \(getAppVersion())" :
            "Please describe your issue:\n\nApp Version: \(getAppVersion())"

        let urlString = "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    private func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Quick Guide Row
struct QuickGuideRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.appPrimary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - FAQ Category View
struct FAQCategoryView: View {
    let category: HelpView.FAQCategory
    let faqs: [HelpView.FAQItem]
    let isExpanded: Bool
    let localizedText: (String) -> String
    let isKorean: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Image(systemName: category.icon())
                        .foregroundColor(.appPrimary)
                        .frame(width: 24)

                    Text(category.title(isKorean: isKorean))
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(faqs) { faq in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Q. \(localizedText(faq.questionKey))")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            ForEach(faq.answerKeys, id: \.self) { answerKey in
                                Text("• \(localizedText(answerKey))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.leading, 36)

                        if faq.id != faqs.last?.id {
                            Divider()
                                .padding(.leading, 36)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Feedback View
struct FeedbackView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackText = ""
    @State private var showingConfirmation = false

    private func localizedText(_ key: String) -> String {
        let isKorean = languageManager.currentLanguage == .korean
        switch key {
        case "send_feedback": return isKorean ? "피드백 보내기" : "Send Feedback"
        case "feedback_placeholder": return isKorean ? "의견을 들려주세요..." : "Share your feedback..."
        case "send": return isKorean ? "보내기" : "Send"
        case "cancel": return isKorean ? "취소" : "Cancel"
        case "feedback_sent": return isKorean ? "피드백 전송 완료" : "Feedback Sent"
        case "feedback_thanks": return isKorean ? "소중한 의견 감사합니다!" : "Thank you for your feedback!"
        case "ok": return isKorean ? "확인" : "OK"
        default: return key
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextEditor(text: $feedbackText)
                    .padding()
                    .overlay(alignment: .topLeading) {
                        if feedbackText.isEmpty {
                            Text(localizedText("feedback_placeholder"))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 24)
                                .allowsHitTesting(false)
                        }
                    }

                Spacer()
            }
            .navigationTitle(localizedText("send_feedback"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedText("cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizedText("send")) {
                        sendFeedback()
                    }
                    .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert(localizedText("feedback_sent"), isPresented: $showingConfirmation) {
                Button(localizedText("ok")) {
                    dismiss()
                }
            } message: {
                Text(localizedText("feedback_thanks"))
            }
        }
    }

    private func sendFeedback() {
        // TODO: Implement actual feedback submission to backend
        print("📝 Feedback submitted: \(feedbackText)")
        showingConfirmation = true
    }
}

#Preview {
    NavigationStack {
        HelpView()
            .environmentObject(LanguageManager())
    }
}
