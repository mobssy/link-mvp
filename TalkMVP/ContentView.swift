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
    @State private var selectedTab = 0
    @State private var showTestModeAlert = false
    
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
        .alert("테스트 모드", isPresented: $showTestModeAlert) {
            Button("취소", role: .cancel) { }
            Button("테스트 시작") { enterTestMode() }
        } message: {
            Text("로그인 없이 앱의 모든 기능을 체험할 수 있습니다.\n테스트 모드로 진입하시겠습니까?")
        }
    }
    
    @ViewBuilder
    private func mainContent() -> some View {
        if authManager.isAuthenticated || isTestMode {
            AuthenticatedTabsView(
                selectedTab: $selectedTab,
                showTestModeIndicator: isTestMode
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
            displayName: "테스터",
            email: "test@example.com",
            statusMessage: "테스트 모드로 체험 중입니다",
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
            ("김친구", "kim@example.com"),
            ("이동료", "lee@example.com"),
            ("박가족", "park@example.com"),
            ("최스터디", "choi@example.com"),
            ("정개발자", "jung@example.com")
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
}

struct AuthenticatedTabsView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Binding var selectedTab: Int
    let showTestModeIndicator: Bool

    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $selectedTab) {
                FriendsTab()
                    .tabItem { 
                        Label("친구", systemImage: "person.fill") 
                    }
                    .tag(0)

                ChatTab()
                    .tabItem { 
                        Label("채팅", systemImage: "message.fill") 
                    }
                    .tag(1)

                SettingsTab()
                    .tabItem { 
                        Label("설정", systemImage: "gearshape.fill") 
                    }
                    .tag(2)
            }
            .tint(.blue)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .ignoresSafeArea(.all, edges: .all)
            .overlay(alignment: .bottom) {
                if showTestModeIndicator {
                    VStack {
                        Spacer()
                        TestModeIndicatorView()
                            .padding(.bottom, 100) // 탭바 위쪽에 위치
                            .padding(.horizontal, 16)
                    }
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
    @Binding var showTestModeAlert: Bool

    var body: some View {
        Button(action: { showTestModeAlert = true }) {
            HStack {
                Image(systemName: "wrench.and.screwdriver")
                Text("테스트 모드로 체험하기")
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
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.caption)
            Text("테스트 모드")
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

#Preview {
    let container = try! ModelContainer(for: Message.self, ChatRoom.self, User.self, Friendship.self)
    let context = ModelContext(container)
    let auth = AuthManager(modelContext: context)
    return ContentView()
        .environmentObject(auth)
        .modelContainer(container)
}
