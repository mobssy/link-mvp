//
//  ContentView.swift
//  L!nkMVP
//
//  Created by David Song on 9/26/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var languageManager: LanguageManager
    @State private var selectedTab = 0
    @State private var showTestModeAlert = false
    @AppStorage("contactsOnboardingShown") private var contactsOnboardingShown = false
    @State private var showContactsOnboarding = false

    // 테스트 모드 플래그
    @State private var isTestMode = false

    var body: some View {
        mainContent()
            .onAppear {
                authManager.modelContext = modelContext
            }
            .alert(languageManager.localizedText("test_mode_title"), isPresented: $showTestModeAlert) {
                Button(languageManager.localizedText("cancel"), role: .cancel) { }
                Button(languageManager.localizedText("start_test")) { enterTestMode() }
            } message: {
                Text(languageManager.localizedText("test_mode_message"))
            }
            .tint(.appPrimary)
            .sheet(isPresented: $showContactsOnboarding, onDismiss: {
                contactsOnboardingShown = true
            }) {
                OnboardingContactsView()
                    .environmentObject(languageManager)
            }
            .onChange(of: authManager.isAuthenticated) { _, newValue in
                if newValue && !contactsOnboardingShown {
                    showContactsOnboarding = true
                }
            }
    }

    @ViewBuilder
    private func mainContent() -> some View {
        if isTestMode {
            AuthenticatedTabsView(
                selectedTab: $selectedTab,
                showTestModeIndicator: true
            )
        } else {
            UnauthenticatedView(
                showTestModeAlert: $showTestModeAlert
            )
        }
    }

    private func enterTestMode() {
        let testUser = User(
            username: "tester",
            displayName: languageManager.localize(ko: "테스터", en: "Tester", ja: "テスター", zh: "测试用户", es: "Tester"),
            email: "test@example.com",
            statusMessage: languageManager.localize(ko: "테스트 모드로 체험 중입니다", en: "Experiencing in test mode", ja: "テストモードを体験中", zh: "正在体验测试模式", es: "Explorando en modo de prueba"),
            isCurrentUser: true
        )

        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in
                user.isCurrentUser == true
            }
        )

        do {
            let users = try modelContext.fetch(descriptor)
            for user in users {
                user.isCurrentUser = false
            }
        } catch {
            print("Failed to clear current users: \(error)")
        }

        modelContext.insert(testUser)
        try? modelContext.save()

        authManager.currentUser = testUser
        authManager.isAuthenticated = true
        isTestMode = true

        createTestFriends(for: testUser)
    }

    private func createTestFriends(for user: User) {
        let testFriends = TestData.friends

        for (name, email) in testFriends {
            let friendship = Friendship(
                userId: user.id.uuidString,
                friendId: UUID().uuidString,
                friendName: name,
                friendEmail: email,
                status: .accepted
            )

            modelContext.insert(friendship)
        }

        try? modelContext.save()
    }
}

struct AuthenticatedTabsView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var languageManager: LanguageManager
    @Binding var selectedTab: Int
    let showTestModeIndicator: Bool
    @Query var chatRooms: [ChatRoom]
    private var totalUnread: Int { chatRooms.map { $0.unreadCount }.reduce(0, +) }

    var body: some View {
        TabView(selection: $selectedTab) {
            FriendsTab()
                .tabItem {
                    Label(languageManager.localizedText("friends"), systemImage: "person.fill")
                }
                .tag(0)

            ChatTab()
                .tabItem {
                    Label(languageManager.localizedText("chat"), systemImage: "message.fill")
                }
                .badge(totalUnread)
                .tag(1)

            SettingsTab()
                .tabItem {
                    Label(languageManager.localizedText("settings"), systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .tint(.appPrimary)
        .overlay(alignment: .bottom) {
            if showTestModeIndicator {
                VStack {
                    Spacer()
                    TestModeIndicatorView(languageManager: languageManager)
                        .padding(.bottom, 100)
                        .padding(.horizontal, 16)
                }
            }
        }
    }
}

private struct FriendsTab: View {
    @EnvironmentObject private var authManager: AuthManager
    var body: some View { FriendsView(authManager: authManager) }
}

private struct ChatTab: View {
    var body: some View { ChatListView() }
}

private struct SettingsTab: View {
    @EnvironmentObject private var authManager: AuthManager
    var body: some View { SettingsView(authManager: authManager) }
}

struct UnauthenticatedView: View {
    @Binding var showTestModeAlert: Bool

    var body: some View {
        ZStack {
            AuthView()
            VStack {
                Spacer()
                TestModeButtonView(showTestModeAlert: $showTestModeAlert)
                    .padding(.bottom, 50)
            }
        }
    }
}

struct TestModeButtonView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @Binding var showTestModeAlert: Bool

    var body: some View {
        Button(action: { showTestModeAlert = true }) {
            HStack {
                Image(systemName: "wrench.and.screwdriver")
                Text(languageManager.localizedText("test_experience"))
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.orange, Color.red]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
        }
    }
}

struct TestModeIndicatorView: View {
    let languageManager: LanguageManager

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.caption)
            Text(languageManager.localizedText("test_mode"))
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        )
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }
}

// MARK: - Test Data

enum TestData {
    static let friends: [(String, String)] = [
        ("권지용", "peaceminusone@example.com"),
        ("한소희", "sohee@example.com"),
        ("강호동", "kang@example.com"),
        ("유재석", "youquiz@example.com"),
        ("조세호", "cabbage@example.com")
    ]
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
        case "test_mode":
            return localize(ko: "테스트 모드", en: "Test Mode", ja: "テストモード", zh: "测试模式", es: "Modo de prueba")
        case "cancel":
            return localize(ko: "취소", en: "Cancel", ja: "キャンセル", zh: "取消", es: "Cancelar")
        default:
            return key
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: Message.self, ChatRoom.self, User.self, Friendship.self)
    let context = ModelContext(container)
    let auth = AuthManager(modelContext: context)
    ContentView()
        .environmentObject(auth)
        .modelContainer(container)
}
