//  SettingsView+Main.swift
//  TalkMVP
//
//  Restored main SettingsView definition so the existing extension compiles.

import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject var authManager: AuthManager
    @EnvironmentObject private var languageManager: LanguageManager

    // These must be accessible from the extension in another file, so don't mark them private.
    @State var showingDeleteAlert = false
    @State var showingLogoutAlert = false

    // Sheets
    @State private var showingProfileEdit = false

    // App Lock
    @AppStorage("appLockEnabled") private var appLockEnabled = false

    // Notifications
    @StateObject private var notificationManager = NotificationManager()

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
            List {
                // Profile
                Section(header: Text(localizedText("profile"))) {
                    Button {
                        showingProfileEdit = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.appPrimary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profileDisplayName().capitalized)
                                if let email = authManager.currentUser?.email, !email.isEmpty {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .headerProminence(.increased)

                // Language (navigate to detail screen)
                Section(header: Text(localizedText("language"))) {
                    NavigationLink {
                        LanguageSettingsView()
                            .environmentObject(languageManager)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                            Text(localizedText("language_settings"))
                            Spacer()
                            Text(languageDisplayName())
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .headerProminence(.increased)

                // Security (navigate)
                Section(header: Text(localizedText("security"))) {
                    NavigationLink {
                        SecuritySettingsView()
                            .environmentObject(languageManager)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.purple)
                            Text(localizedText("app_lock"))
                        }
                    }
                }
                .headerProminence(.increased)

                // Notifications (navigate)
                Section(header: Text(localizedText("notifications"))) {
                    NavigationLink {
                        NotificationSettingsView()
                            .environmentObject(languageManager)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.orange)
                            Text(localizedText("notifications"))
                        }
                    }
                }
                .headerProminence(.increased)

                // AI features (navigate)
                Section(header: Text(localizedText("ai_features"))) {
                    NavigationLink {
                        AISettingsView()
                            .environmentObject(languageManager)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 18))
                                .foregroundColor(.pink)
                            Text(localizedText("ai_features"))
                        }
                    }
                }
                .headerProminence(.increased)

                // Translation (navigate)
                Section(header: Text(localizedText("translation"))) {
                    NavigationLink {
                        TranslationSettingsView()
                            .environmentObject(languageManager)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "character.bubble")
                                .font(.system(size: 18))
                                .foregroundColor(.teal)
                            Text(localizedText("translation"))
                        }
                    }
                }
                .headerProminence(.increased)

                // Destructive actions remain as-is
                destructiveSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(localizedText("settings"))
            .navigationBarTitleDisplayMode(.large)
            .tint(.appPrimary)
            .sheet(isPresented: $showingProfileEdit) {
                ProfileEditView(authManager: authManager)
                    .environmentObject(languageManager)
            }
            .alert(localizedText("delete_account"), isPresented: $showingDeleteAlert) {
                Button(localizedText("cancel"), role: .cancel) {}
                Button(localizedText("delete_account"), role: .destructive) {
                    // TODO: Implement account deletion logic
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
        }
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
}

