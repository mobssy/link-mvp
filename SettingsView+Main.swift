//  SettingsView+Main.swift
//  TalkMVP
//
//  Restored main SettingsView definition so the existing extension compiles.

import SwiftUI
import UIKit
import SwiftData

struct SettingsView: View {
    @ObservedObject var authManager: AuthManager
    @EnvironmentObject private var languageManager: LanguageManager
    @Environment(\.modelContext) private var modelContext
    @AppStorage("themeMode") private var themeMode: String = "system"

    // These must be accessible from the extension in another file, so don't mark them private.
    @State var showingDeleteAlert = false
    @State var showingLogoutAlert = false

    // Sheets
    @State private var showingProfileEdit = false

    // App Lock
    @AppStorage("appLockEnabled") private var appLockEnabled = false

    // Notifications
    @StateObject private var notificationManager = NotificationManager()
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    // AI / Translation settings (shared via AppStorage across app)
    @AppStorage("aiSummaryEnabled") private var aiSummaryEnabled = false
    @AppStorage("aiSearchEnabled") private var aiSearchEnabled = true
    @AppStorage("aiAutoMeetingNotesEnabled") private var aiAutoMeetingNotesEnabled = false

    @AppStorage("translationEnabled") private var translationEnabled = false
    @AppStorage("translationAutoDetect") private var translationAutoDetect = true
    @AppStorage("translationTargetLanguage") private var translationTargetLanguage = "auto"
    @AppStorage("translationShowOriginal") private var translationShowOriginal = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    ProfileCardView(
                        title: profileDisplayName().capitalized,
                        subtitle: authManager.currentUser?.statusMessage ?? (languageManager.isKorean ? "테스트 모드로 체험 중입니다" : "Experiencing in test mode"),
                        imageData: authManager.currentUser?.profileImageData,
                        action: { showingProfileEdit = true }
                    )

                    SettingsSectionCard(title: localizedText("settings")) {
                        SettingsToggleRow(
                            systemImage: "bell.fill",
                            tint: .green,
                            title: localizedText("notifications"),
                            isOn: $notificationsEnabled
                        )
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            ThemeSettingsView().environmentObject(languageManager)
                        } label: {
                            SettingsLinkRow(
                                systemImage: "paintpalette.fill",
                                tint: .orange,
                                title: languageManager.isKorean ? "테마" : "Theme"
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            LanguageSettingsView().environmentObject(languageManager)
                        } label: {
                            SettingsLinkRow(
                                systemImage: "globe",
                                tint: .blue,
                                title: localizedText("language_settings")
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            SecuritySettingsView().environmentObject(languageManager)
                        } label: {
                            SettingsLinkRow(
                                systemImage: "lock.fill",
                                tint: .purple,
                                title: localizedText("app_lock")
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            AISettingsView().environmentObject(languageManager)
                        } label: {
                            SettingsLinkRow(
                                systemImage: "sparkles",
                                tint: .pink,
                                title: localizedText("ai_features")
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            TranslationSettingsView().environmentObject(languageManager)
                        } label: {
                            SettingsLinkRow(
                                systemImage: "character.bubble",
                                tint: .teal,
                                title: localizedText("translation")
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            ContactsSettingsView().environmentObject(languageManager)
                        } label: {
                            SettingsLinkRow(
                                systemImage: "person.crop.circle.badge.plus",
                                tint: .green,
                                title: languageManager.isKorean ? "연락처" : "Contacts"
                            )
                        }
                    }

                    SettingsSectionCard(title: languageManager.isKorean ? "정보" : "Info") {
                        NavigationLink {
                            HelpView().environmentObject(languageManager)
                        } label: {
                            SettingsLinkRow(
                                systemImage: "questionmark.circle.fill",
                                tint: .blue,
                                title: languageManager.isKorean ? "도움말" : "Help"
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            AppInfoView().environmentObject(languageManager)
                        } label: {
                            SettingsLinkRow(
                                systemImage: "info.circle.fill",
                                tint: .blue,
                                title: languageManager.isKorean ? "앱 정보" : "App Info"
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            TermsPoliciesView().environmentObject(languageManager)
                        } label: {
                            SettingsLinkRow(
                                systemImage: "doc.text.fill",
                                tint: .blue,
                                title: languageManager.isKorean ? "약관 및 정책" : "Terms & Policies"
                            )
                        }
                    }
                    SettingsSectionCard(title: "") {
                        VStack(spacing: 0) {
                            Button(localizedText("delete_account"), role: .destructive) {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                showingDeleteAlert = true
                            }
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                            .padding(.vertical, 12)

                            Divider()
                                .frame(height: 0.5)
                                .overlay(Color(UIColor.separator))
                                .padding(.horizontal, 16)

                            Button(localizedText("logout")) {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                showingLogoutAlert = true
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                            .padding(.vertical, 12)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .sheet(isPresented: $showingProfileEdit) {
                ProfileEditView(authManager: authManager)
                    .environmentObject(languageManager)
            }
            // Alerts for destructive actions
            .alert(localizedText("delete_account"), isPresented: $showingDeleteAlert) {
                Button(localizedText("cancel"), role: .cancel) {}
                Button(localizedText("delete_account"), role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text(localizedText("delete_account_hint"))
            }
            .alert(localizedText("logout"), isPresented: $showingLogoutAlert) {
                Button(localizedText("cancel"), role: .cancel) {}
                Button(localizedText("logout")) {
                    authManager.currentUser = nil
                    authManager.isAuthenticated = false
                }
            } message: {
                Text(localizedText("logout_hint"))
            }
            .onChange(of: notificationsEnabled) { _, newValue in
                if !newValue {
                    notificationManager.clearAllNotifications()
                } else {
                    // 권한 재요청 (이미 허용된 경우 no-op)
                    Task {
                        await notificationManager.requestPermission()
                    }
                    // 읽지 않은 메시지 총합을 계산하여 배지 복원
                    let descriptor = FetchDescriptor<ChatRoom>()
                    let rooms = (try? modelContext.fetch(descriptor)) ?? []
                    let totalUnread = rooms.map { $0.unreadCount }.reduce(0, +)
                    notificationManager.updateBadgeCount(totalUnread)
                }
            }
            .navigationTitle(localizedText("settings"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(themeMode == "light" ? .light : (themeMode == "dark" ? .dark : nil))
    }

    private var header: some View {
        Text(localizedText("settings"))
            .font(.system(size: 36, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }

    private var testModeBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "wrench.adjustable")
            Text(languageManager.isKorean ? "테스트 모드" : "Test Mode")
        }
        .font(.footnote.weight(.semibold))
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .foregroundStyle(.white)
        .background(Capsule().fill(Color.orange))
        .shadow(color: Color.orange.opacity(0.3), radius: 8, y: 4)
        .padding(.trailing, 20)
        .padding(.top, 8)
    }

    private var bottomActionBar: some View {
        HStack(spacing: 24) {
            Button {
                showingDeleteAlert = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                    Text(localizedText("delete_account"))
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
            }
            .buttonStyle(.plain)

            Button {
                showingLogoutAlert = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text(localizedText("logout"))
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule(style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // Must be accessible from the extension file, so use internal access (default).
    func localizedText(_ key: String) -> String {
        let isKorean = languageManager.isKorean
        switch key {
        // Common
        case "settings": return isKorean ? "설정" : "Settings"
        case "cancel": return isKorean ? "취소" : "Cancel"
        case "user": return isKorean ? "사용자" : "User"

        // Profile
        case "profile": return isKorean ? "프로필" : "Profile"

        // Language
        case "language": return isKorean ? "언어" : "Language"
        case "language_settings": return isKorean ? "언어 설정" : "Language Settings"

        // Security / App Lock
        case "security": return isKorean ? "보안" : "Security"
        case "app_lock": return isKorean ? "앱 잠금" : "App Lock"
        case "app_lock_hint": return isKorean ? "앱을 열 때 Face ID/Touch ID 인증을 요구합니다" : "Require Face ID/Touch ID to unlock the app"
        case "app_lock_title": return isKorean ? "앱 잠금" : "App Lock"
        case "app_lock_desc": return isKorean ? "앱을 열 때 Face ID/Touch ID 인증을 요구합니다" : "Require Face ID/Touch ID to unlock the app"
        case "unlock_reason": return isKorean ? "앱을 잠금 해제하려면 인증이 필요합니다" : "Authentication is required to unlock the app"

        // Notifications
        case "notifications": return isKorean ? "알림" : "Notifications"
        case "push_permission": return isKorean ? "푸시 권한" : "Push Permission"
        case "granted": return isKorean ? "허용됨" : "Granted"
        case "denied": return isKorean ? "거부됨" : "Denied"
        case "request_permission": return isKorean ? "권한 요청" : "Request Permission"

        // AI
        case "ai_features": return isKorean ? "AI 기능" : "AI Features"
        case "ai_summary": return isKorean ? "대화 요약" : "Conversation Summary"
        case "ai_search": return isKorean ? "대화 검색" : "Conversation Search"
        case "ai_meeting_notes": return isKorean ? "자동 회의 노트" : "Auto Meeting Notes"

        // Translation
        case "translation": return isKorean ? "번역" : "Translation"
        case "translation_footer": return isKorean ? "언어 자동 감지 또는 대상 언어를 지정할 수 있습니다" : "Enable auto-detect or choose a target language"
        case "translation_enable": return isKorean ? "번역 활성화" : "Enable Translation"
        case "translation_auto_detect": return isKorean ? "자동 감지" : "Auto Detect"
        case "translation_target": return isKorean ? "대상 언어" : "Target Language"
        case "translation_show_original": return isKorean ? "원문 함께 표시" : "Show Original"
        case "auto": return isKorean ? "자동" : "Auto"

        // Destructive
        case "delete_account": return isKorean ? "계정 삭제" : "Delete Account"
        case "delete_account_hint": return isKorean ? "계정을 영구적으로 삭제합니다." : "Permanently delete your account."
        case "logout": return isKorean ? "로그아웃" : "Sign Out"
        case "logout_hint": return isKorean ? "현재 계정에서 로그아웃합니다." : "Sign out of your current account."

        default:
            // 디버깅을 위해 키가 정의되지 않은 경우를 확인
            print("⚠️ SettingsView: 키 '\(key)'가 정의되지 않음")
            return key
        }
    }

    private func profileDisplayName() -> String {
        let isKorean = (languageManager.currentLanguage == .korean)
        let raw = (authManager.currentUser?.displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            return isKorean ? "사용자" : "User"
        }
        if raw == "테스터" || raw == "Tester" {
            return isKorean ? "테스터" : "Tester"
        }
        return raw
    }

    private func languageDisplayName() -> String {
        switch languageManager.currentLanguage {
        case .korean: return "한국어"
        case .english: return "English"
        }
    }

    private func notificationFooterText() -> String {
        return languageManager.currentLanguage == .korean ?
            "알림 권한은 기기 설정에서 변경할 수 있습니다" :
            "You can change notification permissions in the device Settings"
    }

    private func deleteAccount() {
        // Delete all user data from SwiftData
        do {
            // Delete all messages
            let messageDescriptor = FetchDescriptor<Message>()
            let messages = try modelContext.fetch(messageDescriptor)
            for message in messages {
                modelContext.delete(message)
            }

            // Delete all chat rooms
            let chatRoomDescriptor = FetchDescriptor<ChatRoom>()
            let chatRooms = try modelContext.fetch(chatRoomDescriptor)
            for chatRoom in chatRooms {
                modelContext.delete(chatRoom)
            }

            // Delete all friendships
            let friendshipDescriptor = FetchDescriptor<Friendship>()
            let friendships = try modelContext.fetch(friendshipDescriptor)
            for friendship in friendships {
                modelContext.delete(friendship)
            }

            // Delete all users except current user (or delete all if desired)
            let userDescriptor = FetchDescriptor<User>()
            let users = try modelContext.fetch(userDescriptor)
            for user in users {
                modelContext.delete(user)
            }

            // Save the deletion
            try modelContext.save()

            // Sign out
            authManager.currentUser = nil
            authManager.isAuthenticated = false

            print("✅ [SettingsView] Account and all data deleted successfully")
        } catch {
            print("❌ [SettingsView] Failed to delete account: \(error)")
        }
    }
}
