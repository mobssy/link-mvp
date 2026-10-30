//
//  ContentView.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(LanguageManager.self) private var languageManager
    @State private var router = AppRouter()
    @State private var showTestModeAlert = false
    @AppStorage("contactsOnboardingShown") private var contactsOnboardingShown = false
    @State private var showContactsOnboarding = false

    var body: some View {
        mainContent()
            .environment(router)
            .alert(languageManager.localizedText("test_mode_title"), isPresented: $showTestModeAlert) {
                Button(languageManager.localizedText("cancel"), role: .cancel) { }
                Button(languageManager.localizedText("start_test")) { enterTestMode() }
            } message: {
                Text(languageManager.localizedText("test_mode_message"))
            }
            .tint(.appPrimaryText)
            .sheet(isPresented: $showContactsOnboarding, onDismiss: {
                contactsOnboardingShown = true
            }) {
                OnboardingContactsView()
                    .environment(languageManager)
            }
            .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated {
                    if !contactsOnboardingShown {
                        showContactsOnboarding = true
                    }
                } else {
                    // Signed out or account deleted: next session starts fresh on the first tab.
                    router.selectedTab = .friends
                }
            }
    }

    @ViewBuilder
    private func mainContent() -> some View {
        if authManager.isAuthenticated {
            AuthenticatedTabsView()
        } else {
            UnauthenticatedView(
                showTestModeAlert: $showTestModeAlert
            )
        }
    }

    private func enterTestMode() {
        authManager.startTestSession(
            displayName: languageManager.localize(ko: "테스터", en: "Tester", ja: "テスター", zh: "测试用户", es: "Tester"),
            statusMessage: languageManager.localize(ko: "테스트 모드로 체험 중입니다", en: "Experiencing in test mode", ja: "テストモードを体験中", zh: "正在体验测试模式", es: "Explorando en modo de prueba"),
            friends: TestData.friends
        )
    }
}

struct AuthenticatedTabsView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(LanguageManager.self) private var languageManager
    @Environment(AppRouter.self) private var router
    @Query var chatRooms: [ChatRoom]
    @State private var notificationManager = NotificationManager()
    @Environment(\.scenePhase) private var scenePhase
    private var totalUnread: Int { chatRooms.map { $0.unreadCount }.reduce(0, +) }

    var body: some View {
        TabView(selection: Bindable(router).selectedTab) {
            FriendsTab()
                .tabItem {
                    Label(languageManager.localizedText("friends"), systemImage: "person.fill")
                }
                .tag(AppTab.friends)

            ChatTab()
                .tabItem {
                    Label(languageManager.localizedText("chat"), systemImage: "message.fill")
                }
                .badge(totalUnread)
                .tag(AppTab.chats)

            SettingsTab()
                .tabItem {
                    Label(languageManager.localizedText("settings"), systemImage: "gearshape.fill")
                }
                .tag(AppTab.settings)
        }
        // Test mode puts nothing on these screens; Settings' profile card says it is on.
        .tint(.appPrimaryText)
        // The app icon shows the same unread count as the Chats tab (none with notifications off).
        .onChange(of: totalUnread, initial: true) { _, count in
            notificationManager.updateBadgeCount(count)
        }
        // Again on the way to the Home Screen, where the badge shows: a count set before
        // notifications were allowed didn't take.
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { notificationManager.updateBadgeCount(totalUnread) }
        }
    }
}

private struct FriendsTab: View {
    @Environment(AuthManager.self) private var authManager
    var body: some View { FriendsView(authManager: authManager) }
}

private struct ChatTab: View {
    var body: some View { ChatListView() }
}

private struct SettingsTab: View {
    @Environment(AuthManager.self) private var authManager
    var body: some View { SettingsView(authManager: authManager) }
}

struct UnauthenticatedView: View {
    @Binding var showTestModeAlert: Bool

    var body: some View {
        AuthView {
            TestModeButtonView(showTestModeAlert: $showTestModeAlert)
        }
    }
}

struct TestModeButtonView: View {
    @Environment(LanguageManager.self) private var languageManager
    @Binding var showTestModeAlert: Bool

    var body: some View {
        // A secondary action beside signing in, so it is styled as one.
        Button(languageManager.localizedText("test_experience"), systemImage: "wrench.and.screwdriver") {
            showTestModeAlert = true
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityIdentifier("testModeButton")
    }
}

// MARK: - Test Data

enum TestData {
    static let friends: [(name: String, email: String)] = [
        ("권지용", "peaceminusone@example.com"),
        ("한소희", "sohee@example.com"),
        ("강호동", "kang@example.com"),
        ("유재석", "youquiz@example.com"),
        ("조세호", "cabbage@example.com")
    ]

    /// Who is in each sample group chat, by the group's localization key. Most are test-mode
    /// friends, so their messages carry a name the chat already knows; the study group's are
    /// people abroad, so one sample chat is written in several languages.
    static let groupMembers: [String: [String]] = [
        "family_group": ["강호동", "한소희"],
        "work_colleagues": ["유재석", "조세호"],
        "study_group": ["佐藤ゆき", "Lucía García"]
    ]

    /// The language each sample person writes in, whatever language the chat is in: they answer
    /// in theirs, and the reader sees it translated.
    static let memberLanguages: [String: String] = [
        "강호동": "ko", "한소희": "ko", "유재석": "ko", "조세호": "ko", "권지용": "ko", "김민지": "ko",
        "佐藤ゆき": "ja",
        "Lucía García": "es"
    ]

    static func language(of member: String) -> String? {
        memberLanguages[member]
    }
}

// MARK: - Shared Localization

fileprivate extension LanguageManager {
    func localizedText(_ key: String) -> String {
        switch key {
        case "friends":
            return localize(ko: "친구", en: "Friends", ja: "友だち", zh: "朋友", es: "Amigos")
        case "chat":
            return localize(ko: "채팅", en: "Chats", ja: "チャット", zh: "聊天", es: "Chats")
        case "settings":
            return localize(ko: "설정", en: "Settings", ja: "設定", zh: "设置", es: "Configuración")
        case "test_mode_title":
            return localize(ko: "테스트 모드", en: "Test Mode", ja: "テストモード", zh: "测试模式", es: "Modo de prueba")
        case "start_test":
            return localize(ko: "테스트 시작", en: "Start Test", ja: "テスト開始", zh: "开始测试", es: "Iniciar prueba")
        case "test_mode_message":
            return localize(
                ko: "로그인 없이 앱의 모든 기능을 체험할 수 있습니다.\n테스트 모드로 진입하시겠습니까?",
                en: "You can experience all app features without logging in.\nWould you like to enter test mode?",
                ja: "ログインなしですべての機能を体験できます。\nテストモードに入りますか？",
                zh: "无需登录即可体验所有功能。\n是否进入测试模式？",
                es: "Puedes explorar todas las funciones sin iniciar sesión.\n¿Deseas entrar al modo de prueba?"
            )
        case "test_experience":
            return localize(ko: "테스트 모드로 체험하기", en: "Try Test Mode", ja: "テストモードを体験", zh: "体验测试模式", es: "Probar modo de prueba")
        case "cancel":
            return localize(ko: "취소", en: "Cancel", ja: "キャンセル", zh: "取消", es: "Cancelar")
        default:
            return key
        }
    }
}

#Preview {
    if let container = try? ModelContainer(
        for: Message.self, ChatRoom.self, User.self, Friendship.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    ) {
        ContentView()
            .environment(AuthManager(modelContext: container.mainContext))
            .environment(LanguageManager())
            .modelContainer(container)
    } else {
        Text("Preview unavailable")
    }
}
