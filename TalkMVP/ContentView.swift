//
//  ContentView.swift
//  TalkMVP
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
        GeometryReader { geometry in
            mainContent()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .ignoresSafeArea(.all, edges: .all)
        }
        .onAppear {
            authManager.modelContext = modelContext
        }
        .alert(localizedText("test_mode_title"), isPresented: $showTestModeAlert) {
            Button(localizedText("cancel"), role: .cancel) { }
            Button(localizedText("start_test")) { enterTestMode() }
        } message: {
            Text(localizedText("test_mode_message"))
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
        // 테스트용 사용자 생성
        let testUser = User(
            username: "tester",
            displayName: languageManager.currentLanguage == .korean ? "테스터" : "Tester",
            email: "test@example.com",
            statusMessage: languageManager.currentLanguage == .korean ? "테스트 모드로 체험 중입니다" : "Experiencing in test mode",
            isCurrentUser: true
        )

        // 기존 현재 사용자 해제
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

        // 테스트 사용자 삽입
        modelContext.insert(testUser)
        try? modelContext.save()

        // AuthManager 업데이트
        authManager.currentUser = testUser
        authManager.isAuthenticated = true

        // 테스트 모드 활성화
        isTestMode = true

        // 테스트용 친구들 생성
        createTestFriends(for: testUser)
    }

    private func createTestFriends(for user: User) {
        let testFriends = [
            ("권지용", "peaceminusone@example.com"),
            ("한소희", "sohee@example.com"),
            ("강호동", "kang@example.com"),
            ("유재석", "youquiz@example.com"),
            ("조세호", "cabbage@example.com")
        ]

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

    private func localizedText(_ key: String) -> String {
        let isKorean = languageManager.currentLanguage == .korean

        switch key {
        case "friends": return isKorean ? "친구" : "Friends"
        case "chat": return isKorean ? "채팅" : "Chat"
        case "settings": return isKorean ? "설정" : "Settings"
        case "test_mode_title": return isKorean ? "테스트 모드" : "Test Mode"
        case "start_test": return isKorean ? "테스트 시작" : "Start Test"
        case "test_mode_message": return isKorean ?
            "로그인 없이 앱의 모든 기능을 체험할 수 있습니다.\n테스트 모드로 진입하시겠습니까?" :
            "You can experience all app features without logging in.\nWould you like to enter test mode?"
        case "test_experience": return isKorean ? "테스트 모드로 체험하기" : "Try Test Mode"
        case "test_mode": return isKorean ? "테스트 모드" : "Test Mode"
        case "cancel": return isKorean ? "취소" : "Cancel"
        default: return key
        }
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
        GeometryReader { geometry in
            TabView(selection: $selectedTab) {
                FriendsTab()
                    .tabItem {
                        Label(localizedText("friends"), systemImage: "person.fill")
                    }
                    .tag(0)

                if totalUnread > 0 {
                    ChatTab()
                        .tabItem {
                            Label(localizedText("chat"), systemImage: "message.fill")
                        }
                        .badge(totalUnread)
                        .tag(1)
                } else {
                    ChatTab()
                        .tabItem {
                            Label(localizedText("chat"), systemImage: "message.fill")
                        }
                        .tag(1)
                }

                SettingsTab()
                    .tabItem {
                        Label(localizedText("settings"), systemImage: "gearshape.fill")
                    }
                    .tag(2)
            }
            .tint(.appPrimary)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .ignoresSafeArea(.all, edges: .all)
            .overlay(alignment: .bottom) {
                if showTestModeIndicator {
                    VStack {
                        Spacer()
                        TestModeIndicatorView(languageManager: languageManager)
                            .padding(.bottom, 100) // 탭바 위쪽에 위치
                            .padding(.horizontal, 16)
                    }
                }
            }
        }
    }

    private func localizedText(_ key: String) -> String {
        let isKorean = languageManager.currentLanguage == .korean

        switch key {
        case "friends": return isKorean ? "친구" : "Friends"
        case "chat": return isKorean ? "채팅" : "Chat"
        case "settings": return isKorean ? "설정" : "Settings"
        case "test_mode_title": return isKorean ? "테스트 모드" : "Test Mode"
        case "start_test": return isKorean ? "테스트 시작" : "Start Test"
        case "test_mode_message": return isKorean ?
            "로그인 없이 앱의 모든 기능을 체험할 수 있습니다.\n테스트 모드로 진입하시겠습니까?" :
            "You can experience all app features without logging in.\nWould you like to enter test mode?"
        case "test_experience": return isKorean ? "테스트 모드로 체험하기" : "Try Test Mode"
        case "test_mode": return isKorean ? "테스트 모드" : "Test Mode"
        default: return key
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
        GeometryReader { geometry in
            ZStack {
                AuthView()
                VStack {
                    Spacer()
                    TestModeButtonView(showTestModeAlert: $showTestModeAlert)
                        .padding(.bottom, 50)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .ignoresSafeArea(.all, edges: .all)
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
                Text(localizedText("test_experience"))
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

    private func localizedText(_ key: String) -> String {
        let isKorean = languageManager.currentLanguage == .korean

        switch key {
        case "friends": return isKorean ? "친구" : "Friends"
        case "chat": return isKorean ? "채팅" : "Chat"
        case "settings": return isKorean ? "설정" : "Settings"
        case "test_mode_title": return isKorean ? "테스트 모드" : "Test Mode"
        case "start_test": return isKorean ? "테스트 시작" : "Start Test"
        case "test_mode_message": return isKorean ?
            "로그인 없이 앱의 모든 기능을 체험할 수 있습니다.\n테스트 모드로 진입하시겠습니까?" :
            "You can experience all app features without logging in.\nWould you like to enter test mode?"
        case "test_experience": return isKorean ? "테스트 모드로 체험하기" : "Try Test Mode"
        case "test_mode": return isKorean ? "테스트 모드" : "Test Mode"
        default: return key
        }
    }
}

struct TestModeIndicatorView: View {
    let languageManager: LanguageManager

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.caption)
            Text(localizedText("test_mode"))
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

    private func localizedText(_ key: String) -> String {
        let isKorean = languageManager.currentLanguage == .korean

        switch key {
        case "friends": return isKorean ? "친구" : "Friends"
        case "chat": return isKorean ? "채팅" : "Chat"
        case "settings": return isKorean ? "설정" : "Settings"
        case "test_mode_title": return isKorean ? "테스트 모드" : "Test Mode"
        case "start_test": return isKorean ? "테스트 시작" : "Start Test"
        case "test_mode_message": return isKorean ?
            "로그인 없이 앱의 모든 기능을 체험할 수 있습니다.\n테스트 모드로 진입하시겠습니까?" :
            "You can experience all app features without logging in.\nWould you like to enter test mode?"
        case "test_experience": return isKorean ? "테스트 모드로 체험하기" : "Try Test Mode"
        case "test_mode": return isKorean ? "테스트 모드" : "Test Mode"
        default: return key
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
