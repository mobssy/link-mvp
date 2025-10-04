//
//  FriendsView_Simple.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//

import SwiftUI
import SwiftData
import UserNotifications

// 간소화된 친구 목록 뷰
struct FriendsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var languageManager: LanguageManager
    @StateObject private var authManager: AuthManager
    @StateObject private var notificationManager = NotificationManager()
    
    enum ActiveSheet: Identifiable {
        case addFriend, blockedList, settings
        var id: Int {
            switch self {
            case .addFriend: return 1
            case .blockedList: return 2
            case .settings: return 3
            }
        }
    }
    
    @State private var activeSheet: ActiveSheet?
    @State private var searchText = ""
    @State private var friendships: [Friendship] = []
    
    init(authManager: AuthManager) {
        self._authManager = StateObject(wrappedValue: authManager)
    }
    
    var acceptedFriends: [Friendship] {
        guard let currentUserId = authManager.currentUser?.id.uuidString else { return [] }
        
        let filtered = friendships.filter { friendship in
            friendship.userId == currentUserId && 
            friendship.status == .accepted
        }
        
        if searchText.isEmpty {
            return filtered
        } else {
            return filtered.filter { friendship in
                friendship.friendName.localizedCaseInsensitiveContains(searchText) ||
                friendship.friendEmail.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var pendingRequests: [Friendship] {
        guard let currentUserId = authManager.currentUser?.id.uuidString else { return [] }
        
        return friendships.filter { friendship in
            friendship.userId == currentUserId && 
            friendship.status == .pending
        }
    }
    
    var receivedRequests: [Friendship] {
        guard let currentUserId = authManager.currentUser?.id.uuidString else { return [] }
        
        return friendships.filter { friendship in
            friendship.friendId == currentUserId && 
            friendship.status == .pending
        }
    }
    
    var blockedFriends: [Friendship] {
        guard let currentUserId = authManager.currentUser?.id.uuidString else { return [] }
        
        return friendships.filter { friendship in
            friendship.userId == currentUserId && 
            friendship.status == .blocked
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // 내 프로필 섹션
                Section {
                    MyProfileRow(authManager: authManager)
                }
                .listRowBackground(Color.appPrimary.opacity(0.05))
                
                // 받은 친구 요청
                if !receivedRequests.isEmpty {
                    Section(localizedText("received_requests", count: receivedRequests.count)) {
                        ForEach(receivedRequests, id: \.id) { friendship in
                            ReceivedRequestRow(
                                friendship: friendship, 
                                modelContext: modelContext,
                                onDataChanged: loadFriendships
                            )
                        }
                    }
                    .headerProminence(.increased)
                }
                
                // 보낸 친구 요청
                if !pendingRequests.isEmpty {
                    Section(localizedText("sent_requests", count: pendingRequests.count)) {
                        ForEach(pendingRequests, id: \.id) { friendship in
                            PendingRequestRow(friendship: friendship)
                        }
                        .onDelete(perform: deletePendingRequest)
                    }
                    .headerProminence(.increased)
                }
                
                // 친구 목록
                Section(localizedText("friends_list", count: acceptedFriends.count)) {
                    if acceptedFriends.isEmpty && !searchText.isEmpty {
                        ContentUnavailableView(
                            localizedText("no_search_results"),
                            systemImage: "magnifyingglass",
                            description: Text(localizedText("no_match_for", searchTerm: searchText))
                        )
                    } else if acceptedFriends.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "person.2")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text(localizedText("no_friends_yet"))
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text(localizedText("add_friends_suggestion"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                activeSheet = .addFriend
                            }) {
                                HStack {
                                    Image(systemName: "person.badge.plus")
                                    Text(localizedText("add_friend_by_email"))
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.appPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.vertical, 40)
                    } else {
                        ForEach(acceptedFriends, id: \.id) { friendship in
                            FriendRow(friendship: friendship, onDataChanged: loadFriendships)
                        }
                        .onDelete(perform: deleteFriend)
                    }
                }
                .headerProminence(.increased)
            }
            .listStyle(.insetGrouped)
            .navigationTitle(localizedText("contacts"))
            .searchable(text: $searchText, prompt: localizedText("search_friends_placeholder"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        activeSheet = .settings
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(localizedText("settings"))
                }
            }
        }
        .sheet(item: $activeSheet, onDismiss: { activeSheet = nil }) { sheet in
            switch sheet {
            case .addFriend:
                AddFriendView(
                    authManager: authManager,
                    notificationManager: notificationManager,
                    onFriendAdded: loadFriendships
                )
            case .blockedList:
                BlockedFriendsView(blockedFriends: blockedFriends)
            case .settings:
                SettingsView(authManager: authManager)
                    .environment(\.modelContext, modelContext)
            }
        }
        .onAppear {
            loadFriendships()
        }
    }
    
    private func localizedText(_ key: String, count: Int = 0, searchTerm: String = "") -> String {
        let isKorean = languageManager.currentLanguage == .korean
        
        var text: String
        switch key {
        case "received_requests": text = isKorean ? "📬 받은 친구 요청 \(count)" : "📬 Received Friend Requests \(count)"
        case "sent_requests": text = isKorean ? "📤 보낸 친구 요청 \(count)" : "📤 Sent Friend Requests \(count)"
        case "friends_list": text = isKorean ? "친구 목록 \(count)" : "Friends List \(count)"
        case "no_search_results": text = isKorean ? "검색 결과 없음" : "No Search Results"
        case "no_match_for": text = isKorean ? "'\(searchTerm)'와 일치하는 친구가 없습니다" : "No friends match '\(searchTerm)'"
        case "no_friends_yet": text = isKorean ? "아직 친구가 없어요" : "No Friends Yet"
        case "add_friends_suggestion": text = isKorean ? "친구를 추가해보세요!" : "Try adding some friends!"
        case "add_friend_by_email": text = isKorean ? "이메일로 친구 추가" : "Add Friend by Email"
        case "contacts": text = isKorean ? "연락처" : "Contacts"
        case "search_friends_placeholder": text = isKorean ? "친구 이름 검색..." : "Search friend names..."
        case "user": text = isKorean ? "사용자" : "User"
        case "status_message": text = isKorean ? "상태 메시지를 설정해보세요" : "Set your status message"
        case "friend_request": text = isKorean ? "친구 요청" : "Friend Request"
        case "accept": text = isKorean ? "수락" : "Accept"
        case "request_pending": text = isKorean ? "요청 대기 중" : "Request Pending"
        case "pending_short": text = isKorean ? "대기" : "Pending"
        case "friend_email_placeholder": text = isKorean ? "친구의 이메일 주소" : "Friend's email address"
        case "search": text = isKorean ? "검색" : "Search"
        case "add_by_email": text = isKorean ? "이메일로 친구 추가" : "Add Friend by Email"
        case "add_by_email_footer": text = isKorean ? "친구의 이메일 주소를 입력하고 검색 버튼을 누르세요." : "Enter your friend's email address and tap Search."
        case "searching": text = isKorean ? "검색 중..." : "Searching..."
        case "searching_users": text = isKorean ? "사용자를 검색하고 있습니다" : "Searching for users"
        case "search_results": text = isKorean ? "검색 결과" : "Search Results"
        case "add_friend": text = isKorean ? "친구 추가" : "Add Friend"
        case "alert": text = isKorean ? "알림" : "Alert"
        case "search_error_prefix": text = isKorean ? "검색 중 오류가 발생했습니다: " : "An error occurred during search: "
        case "friend_request_sent": text = isKorean ? "친구 요청을 보냈습니다." : "Friend request sent."
        case "friend_request_failed": text = isKorean ? "친구 요청 전송에 실패했습니다." : "Failed to send friend request."
        case "error_occurred_prefix": text = isKorean ? "오류가 발생했습니다: " : "An error occurred: "
        case "no_blocked_friends": text = isKorean ? "차단된 친구가 없습니다" : "No blocked friends"
        case "blocked_list": text = isKorean ? "차단 목록" : "Blocked List"
        case "blocked": text = isKorean ? "차단됨" : "Blocked"
        case "unblock": text = isKorean ? "차단 해제" : "Unblock"
        case "unblock_friend": text = isKorean ? "차단 해제" : "Unblock Friend"
        case "unblock_message": text = isKorean ? "\(searchTerm)님의 차단을 해제하시겠습니까?" : "Unblock \(searchTerm)?"
        default: text = key
        }
        
        return text
    }
    
    private func loadFriendships() {
        let fetchDescriptor = FetchDescriptor<Friendship>()
        friendships = (try? modelContext.fetch(fetchDescriptor)) ?? []
    }
    
    private func deleteFriend(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(acceptedFriends[index])
            }
            try? modelContext.save()
            loadFriendships()
        }
    }
    
    private func deletePendingRequest(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(pendingRequests[index])
            }
            try? modelContext.save()
            loadFriendships()
        }
    }
}

// 간소화된 내 프로필 행
struct MyProfileRow: View {
    @ObservedObject var authManager: AuthManager
    @EnvironmentObject private var languageManager: LanguageManager
    @State private var showingProfileEdit = false
    
    var body: some View {
        Button(action: {
            showingProfileEdit = true
        }) {
            HStack(spacing: 16) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.appPrimary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizedDisplayName().capitalized)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(localizedStatusMessage())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Circle()
                    .fill(.green)
                    .frame(width: 12, height: 12)
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingProfileEdit) {
            ProfileEditView(authManager: authManager)
                .environmentObject(languageManager)
        }
    }
    
    private func localizedDisplayName() -> String {
        let isKorean = languageManager.currentLanguage == .korean
        let raw = (authManager.currentUser?.displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            return isKorean ? "사용자" : "User"
        }
        // Map known default test names between languages
        if raw == "테스터" || raw == "Tester" {
            return isKorean ? "테스터" : "Tester"
        }
        return raw
    }

    private func localizedStatusMessage() -> String {
        let isKorean = languageManager.currentLanguage == .korean
        let raw = (authManager.currentUser?.statusMessage ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            return isKorean ? "상태 메시지를 설정해보세요" : "Set your status message"
        }
        // Map known default test status messages between languages
        if raw == "테스트 모드로 체험 중입니다" || raw == "Experiencing in test mode" {
            return isKorean ? "테스트 모드로 체험 중입니다" : "Experiencing in test mode"
        }
        return raw
    }
    
    private func localizedText(_ key: String) -> String {
        let isKorean = languageManager.currentLanguage == .korean
        
        switch key {
        case "friends": return isKorean ? "친구" : "Friends"
        case "add_friend": return isKorean ? "친구 추가" : "Add Friend"
        case "friend_request": return isKorean ? "친구 요청" : "Friend Request"
        case "accept": return isKorean ? "수락" : "Accept"
        case "reject": return isKorean ? "거절" : "Reject"
        case "block": return isKorean ? "차단" : "Block"
        case "unblock": return isKorean ? "차단 해제" : "Unblock"
        case "friend_email_placeholder": return isKorean ? "친구의 이메일 주소" : "Friend's email address"
        case "search": return isKorean ? "검색" : "Search"
        case "add_by_email": return isKorean ? "이메일로 친구 추가" : "Add Friend by Email"
        case "add_by_email_footer": return isKorean ? "친구의 이메일 주소를 입력하고 검색 버튼을 누르세요." : "Enter your friend's email address and tap Search."
        case "searching": return isKorean ? "검색 중..." : "Searching..."
        case "searching_users": return isKorean ? "사용자를 검색하고 있습니다" : "Searching for users"
        case "search_results": return isKorean ? "검색 결과" : "Search Results"
        case "alert": return isKorean ? "알림" : "Alert"
        case "cancel": return isKorean ? "취소" : "Cancel"
        case "ok": return isKorean ? "확인" : "OK"
        case "user": return isKorean ? "사용자" : "User"
        case "status_message": return isKorean ? "상태 메시지를 설정해보세요" : "Set your status message"
        case "no_search_results": return isKorean ? "검색 결과 없음" : "No Search Results"
        case "no_match_for": return isKorean ? "'%@'와 일치하는 친구가 없습니다" : "No friends match '%@'"
        case "no_friends_yet": return isKorean ? "아직 친구가 없어요" : "No Friends Yet"
        case "add_friends_suggestion": return isKorean ? "친구를 추가해보세요!" : "Try adding some friends!"
        case "add_friend_by_email": return isKorean ? "이메일로 친구 추가" : "Add Friend by Email"
        case "search_error_prefix": return isKorean ? "검색 중 오류가 발생했습니다: " : "An error occurred during search: "
        case "friend_request_sent": return isKorean ? "친구 요청을 보냈습니다." : "Friend request sent."
        case "friend_request_failed": return isKorean ? "친구 요청 전송에 실패했습니다." : "Failed to send friend request."
        case "error_occurred_prefix": return isKorean ? "오류가 발생했습니다: " : "An error occurred: "
        case "no_blocked_friends": return isKorean ? "차단된 친구가 없습니다" : "No blocked friends"
        default: return key
        }
    }
}

// 간소화된 친구 행
struct FriendRow: View {
    let friendship: Friendship
    let onDataChanged: () -> Void
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var languageManager: LanguageManager
    @State private var showingProfileView = false
    
    var body: some View {
        Button(action: {
            showingProfileView = true
        }) {
            HStack(spacing: 16) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.appPrimary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(friendship.friendName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(localizedText("online"))
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                Circle()
                    .fill(.green)
                    .frame(width: 10, height: 10)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingProfileView) {
            FriendProfileView(friendship: friendship)
        }
    }
    
    private func localizedText(_ key: String) -> String {
        let isKorean = languageManager.currentLanguage == .korean
        
        switch key {
        case "friends": return isKorean ? "친구" : "Friends"
        case "add_friend": return isKorean ? "친구 추가" : "Add Friend"
        case "friend_request": return isKorean ? "친구 요청" : "Friend Request"
        case "accept": return isKorean ? "수락" : "Accept"
        case "reject": return isKorean ? "거절" : "Reject"
        case "block": return isKorean ? "차단" : "Block"
        case "unblock": return isKorean ? "차단 해제" : "Unblock"
        case "friend_email_placeholder": return isKorean ? "친구의 이메일 주소" : "Friend's email address"
        case "search": return isKorean ? "검색" : "Search"
        case "add_by_email": return isKorean ? "이메일로 친구 추가" : "Add Friend by Email"
        case "add_by_email_footer": return isKorean ? "친구의 이메일 주소를 입력하고 검색 버튼을 누르세요." : "Enter your friend's email address and tap Search."
        case "searching": return isKorean ? "검색 중..." : "Searching..."
        case "searching_users": return isKorean ? "사용자를 검색하고 있습니다" : "Searching for users"
        case "search_results": return isKorean ? "검색 결과" : "Search Results"
        case "alert": return isKorean ? "알림" : "Alert"
        case "cancel": return isKorean ? "취소" : "Cancel"
        case "ok": return isKorean ? "확인" : "OK"
        case "user": return isKorean ? "사용자" : "User"
        case "status_message": return isKorean ? "상태 메시지를 설정해보세요" : "Set your status message"
        case "no_search_results": return isKorean ? "검색 결과 없음" : "No Search Results"
        case "no_match_for": return isKorean ? "'%@'와 일치하는 친구가 없습니다" : "No friends match '%@'"
        case "no_friends_yet": return isKorean ? "아직 친구가 없어요" : "No Friends Yet"
        case "add_friends_suggestion": return isKorean ? "친구를 추가해보세요!" : "Try adding some friends!"
        case "add_friend_by_email": return isKorean ? "이메일로 친구 추가" : "Add Friend by Email"
        case "search_error_prefix": return isKorean ? "검색 중 오류가 발생했습니다: " : "An error occurred during search: "
        case "friend_request_sent": return isKorean ? "친구 요청을 보냈습니다." : "Friend request sent."
        case "friend_request_failed": return isKorean ? "친구 요청 전송에 실패했습니다." : "Failed to send friend request."
        case "error_occurred_prefix": return isKorean ? "오류가 발생했습니다: " : "An error occurred: "
        case "no_blocked_friends": return isKorean ? "차단된 친구가 없습니다" : "No blocked friends"
        default: return key
        }
    }
}

// 간소화된 받은 친구 요청 행
struct ReceivedRequestRow: View {
    let friendship: Friendship
    let modelContext: ModelContext
    let onDataChanged: () -> Void
    @State private var isAccepting = false
    @EnvironmentObject private var languageManager: LanguageManager
    
    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(friendship.friendName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(localizedText("friend_request"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(localizedText("accept")) {
                acceptFriendRequest()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isAccepting)
        }
        .padding(.vertical, 4)
    }
    
    private func acceptFriendRequest() {
        isAccepting = true
        friendship.status = .accepted
        try? modelContext.save()
        onDataChanged()
        isAccepting = false
    }
    
    private func localizedText(_ key: String) -> String {
        let isKorean = languageManager.currentLanguage == .korean
        
        switch key {
        case "friends": return isKorean ? "친구" : "Friends"
        case "add_friend": return isKorean ? "친구 추가" : "Add Friend"
        case "friend_request": return isKorean ? "친구 요청" : "Friend Request"
        case "accept": return isKorean ? "수락" : "Accept"
        case "reject": return isKorean ? "거절" : "Reject"
        case "block": return isKorean ? "차단" : "Block"
        case "unblock": return isKorean ? "차단 해제" : "Unblock"
        case "friend_email_placeholder": return isKorean ? "친구의 이메일 주소" : "Friend's email address"
        case "search": return isKorean ? "검색" : "Search"
        case "add_by_email": return isKorean ? "이메일로 친구 추가" : "Add Friend by Email"
        case "add_by_email_footer": return isKorean ? "친구의 이메일 주소를 입력하고 검색 버튼을 누르세요." : "Enter your friend's email address and tap Search."
        case "searching": return isKorean ? "검색 중..." : "Searching..."
        case "searching_users": return isKorean ? "사용자를 검색하고 있습니다" : "Searching for users"
        case "search_results": return isKorean ? "검색 결과" : "Search Results"
        case "alert": return isKorean ? "알림" : "Alert"
        case "cancel": return isKorean ? "취소" : "Cancel"
        case "ok": return isKorean ? "확인" : "OK"
        case "user": return isKorean ? "사용자" : "User"
        case "status_message": return isKorean ? "상태 메시지를 설정해보세요" : "Set your status message"
        case "no_search_results": return isKorean ? "검색 결과 없음" : "No Search Results"
        case "no_match_for": return isKorean ? "'%@'와 일치하는 친구가 없습니다" : "No friends match '%@'"
        case "no_friends_yet": return isKorean ? "아직 친구가 없어요" : "No Friends Yet"
        case "add_friends_suggestion": return isKorean ? "친구를 추가해보세요!" : "Try adding some friends!"
        case "add_friend_by_email": return isKorean ? "이메일로 친구 추가" : "Add Friend by Email"
        case "search_error_prefix": return isKorean ? "검색 중 오류가 발생했습니다: " : "An error occurred during search: "
        case "friend_request_sent": return isKorean ? "친구 요청을 보냈습니다." : "Friend request sent."
        case "friend_request_failed": return isKorean ? "친구 요청 전송에 실패했습니다." : "Failed to send friend request."
        case "error_occurred_prefix": return isKorean ? "오류가 발생했습니다: " : "An error occurred: "
        case "no_blocked_friends": return isKorean ? "차단된 친구가 없습니다" : "No blocked friends"
        default: return key
        }
    }
}

// 간소화된 보낸 친구 요청 행
struct PendingRequestRow: View {
    let friendship: Friendship
    @EnvironmentObject private var languageManager: LanguageManager
    
    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(friendship.friendName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(localizedText("request_pending"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(localizedText("pending_short"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func localizedText(_ key: String) -> String {
        let isKorean = languageManager.currentLanguage == .korean
        
        switch key {
        case "friends": return isKorean ? "친구" : "Friends"
        case "add_friend": return isKorean ? "친구 추가" : "Add Friend"
        case "friend_request": return isKorean ? "친구 요청" : "Friend Request"
        case "accept": return isKorean ? "수락" : "Accept"
        case "reject": return isKorean ? "거절" : "Reject"
        case "block": return isKorean ? "차단" : "Block"
        case "unblock": return isKorean ? "차단 해제" : "Unblock"
        case "friend_email_placeholder": return isKorean ? "친구의 이메일 주소" : "Friend's email address"
        case "search": return isKorean ? "검색" : "Search"
        case "add_by_email": return isKorean ? "이메일로 친구 추가" : "Add Friend by Email"
        case "add_by_email_footer": return isKorean ? "친구의 이메일 주소를 입력하고 검색 버튼을 누르세요." : "Enter your friend's email address and tap Search."
        case "searching": return isKorean ? "검색 중..." : "Searching..."
        case "searching_users": return isKorean ? "사용자를 검색하고 있습니다" : "Searching for users"
        case "search_results": return isKorean ? "검색 결과" : "Search Results"
        case "alert": return isKorean ? "알림" : "Alert"
        case "cancel": return isKorean ? "취소" : "Cancel"
        case "ok": return isKorean ? "확인" : "OK"
        case "user": return isKorean ? "사용자" : "User"
        case "status_message": return isKorean ? "상태 메시지를 설정해보세요" : "Set your status message"
        case "no_search_results": return isKorean ? "검색 결과 없음" : "No Search Results"
        case "no_match_for": return isKorean ? "'%@'와 일치하는 친구가 없습니다" : "No friends match '%@'"
        case "no_friends_yet": return isKorean ? "아직 친구가 없어요" : "No Friends Yet"
        case "add_friends_suggestion": return isKorean ? "친구를 추가해보세요!" : "Try adding some friends!"
        case "add_friend_by_email": return isKorean ? "이메일로 친구 추가" : "Add Friend by Email"
        case "search_error_prefix": return isKorean ? "검색 중 오류가 발생했습니다: " : "An error occurred during search: "
        case "friend_request_sent": return isKorean ? "친구 요청을 보냈습니다." : "Friend request sent."
        case "friend_request_failed": return isKorean ? "친구 요청 전송에 실패했습니다." : "Failed to send friend request."
        case "error_occurred_prefix": return isKorean ? "오류가 발생했습니다: " : "An error occurred: "
        case "no_blocked_friends": return isKorean ? "차단된 친구가 없습니다" : "No blocked friends"
        default: return key
        }
    }
}

// 간소화된 친구 추가 뷰
struct AddFriendView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var notificationManager: NotificationManager
    let onFriendAdded: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var languageManager: LanguageManager
    
    @State private var friendEmail = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var searchResults: [UserSearchResult] = []
    @State private var isSearching = false
    @State private var lastActionWasSuccess = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField(localizedText("friend_email_placeholder"), text: $friendEmail)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .focused($isTextFieldFocused)
                            .onSubmit {
                                searchForUsers()
                            }
                        
                        Button(localizedText("search")) {
                            searchForUsers()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(friendEmail.isEmpty || isSearching)
                    }
                } header: {
                    Text(localizedText("add_by_email"))
                } footer: {
                    Text(localizedText("add_by_email_footer"))
                }
                
                if isSearching {
                    Section(localizedText("searching")) {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text(localizedText("searching_users"))
                                .foregroundColor(.secondary)
                        }
                    }
                } else if !searchResults.isEmpty {
                    Section(localizedText("search_results")) {
                        ForEach(searchResults, id: \.id) { result in
                            UserSearchResultRow(
                                result: result,
                                authManager: authManager,
                                modelContext: modelContext
                            ) { success, message in
                                lastActionWasSuccess = success
                                alertMessage = message
                                showingAlert = true
                                if success {
                                    searchResults.removeAll()
                                    friendEmail = ""
                                    onFriendAdded()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(localizedText("add_friend"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localizedText("cancel")) {
                        dismiss()
                    }
                }
            }
        }
        .alert(localizedText("alert"), isPresented: $showingAlert) {
            Button(localizedText("ok")) {
                if lastActionWasSuccess {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            // 뷰가 나타날 때 자동으로 키보드 포커스
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }
    
    private func searchForUsers() {
        guard !friendEmail.isEmpty else { 
            print("이메일이 비어있음")
            return 
        }
        
        print("사용자 검색 시작: \(friendEmail)")
        isSearching = true
        searchResults = []
        
        Task {
            do {
                let results = try await FriendSearchService.searchUsers(by: friendEmail)
                await MainActor.run {
                    print("검색 결과: \(results.count)개")
                    self.searchResults = results
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    print("검색 오류: \(error.localizedDescription)")
                    self.alertMessage = localizedText("search_error_prefix") + error.localizedDescription
                    self.showingAlert = true
                    self.isSearching = false
                }
            }
        }
    }
    
    private func localizedText(_ key: String) -> String {
        let isKorean = languageManager.currentLanguage == .korean
        
        switch key {
        case "friends": return isKorean ? "친구" : "Friends"
        case "add_friend": return isKorean ? "친구 추가" : "Add Friend"
        case "friend_request": return isKorean ? "친구 요청" : "Friend Request"
        case "accept": return isKorean ? "수락" : "Accept"
        case "reject": return isKorean ? "거절" : "Reject"
        case "block": return isKorean ? "차단" : "Block"
        case "unblock": return isKorean ? "차단 해제" : "Unblock"
        case "friend_email_placeholder": return isKorean ? "친구의 이메일 주소" : "Friend's email address"
        case "search": return isKorean ? "검색" : "Search"
        case "add_by_email": return isKorean ? "이메일로 친구 추가" : "Add Friend by Email"
        case "add_by_email_footer": return isKorean ? "친구의 이메일 주소를 입력하고 검색 버튼을 누르세요." : "Enter your friend's email address and tap Search."
        case "searching": return isKorean ? "검색 중..." : "Searching..."
        case "searching_users": return isKorean ? "사용자를 검색하고 있습니다" : "Searching for users"
        case "search_results": return isKorean ? "검색 결과" : "Search Results"
        case "alert": return isKorean ? "알림" : "Alert"
        case "cancel": return isKorean ? "취소" : "Cancel"
        case "ok": return isKorean ? "확인" : "OK"
        case "user": return isKorean ? "사용자" : "User"
        case "status_message": return isKorean ? "상태 메시지를 설정해보세요" : "Set your status message"
        case "no_search_results": return isKorean ? "검색 결과 없음" : "No Search Results"
        case "no_match_for": return isKorean ? "'%@'와 일치하는 친구가 없습니다" : "No friends match '%@'"
        case "no_friends_yet": return isKorean ? "아직 친구가 없어요" : "No Friends Yet"
        case "add_friends_suggestion": return isKorean ? "친구를 추가해보세요!" : "Try adding some friends!"
        case "add_friend_by_email": return isKorean ? "이메일로 친구 추가" : "Add Friend by Email"
        case "search_error_prefix": return isKorean ? "검색 중 오류가 발생했습니다: " : "An error occurred during search: "
        case "friend_request_sent": return isKorean ? "친구 요청을 보냈습니다." : "Friend request sent."
        case "friend_request_failed": return isKorean ? "친구 요청 전송에 실패했습니다." : "Failed to send friend request."
        case "error_occurred_prefix": return isKorean ? "오류가 발생했습니다: " : "An error occurred: "
        case "no_blocked_friends": return isKorean ? "차단된 친구가 없습니다" : "No blocked friends"
        default: return key
        }
    }
}

// 간소화된 사용자 검색 결과 행
struct UserSearchResultRow: View {
    let result: UserSearchResult
    @ObservedObject var authManager: AuthManager
    @EnvironmentObject private var languageManager: LanguageManager
    let modelContext: ModelContext
    let onComplete: (Bool, String) -> Void
    
    @State private var isSendingRequest = false
    
    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.appPrimary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(result.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(localizedText("add_friend")) {
                sendFriendRequest()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isSendingRequest)
        }
        .padding(.vertical, 4)
    }
    
    private func sendFriendRequest() {
        isSendingRequest = true
        
        Task {
            do {
                let success = try await FriendSearchService.sendFriendRequest(
                    from: authManager.currentUser?.id.uuidString ?? "",
                    to: result.id
                )
                
                await MainActor.run {
                    if success {
                        onComplete(true, localizedText("friend_request_sent"))
                    } else {
                        onComplete(false, localizedText("friend_request_failed"))
                    }
                    isSendingRequest = false
                }
            } catch {
                await MainActor.run {
                    onComplete(false, localizedText("error_occurred_prefix") + error.localizedDescription)
                    isSendingRequest = false
                }
            }
        }
    }
    
    private func localizedText(_ key: String) -> String {
        let isKorean = languageManager.currentLanguage == .korean
        
        switch key {
        case "friends": return isKorean ? "친구" : "Friends"
        case "add_friend": return isKorean ? "친구 추가" : "Add Friend"
        case "friend_request": return isKorean ? "친구 요청" : "Friend Request"
        case "accept": return isKorean ? "수락" : "Accept"
        case "reject": return isKorean ? "거절" : "Reject"
        case "block": return isKorean ? "차단" : "Block"
        case "unblock": return isKorean ? "차단 해제" : "Unblock"
        case "friend_email_placeholder": return isKorean ? "친구의 이메일 주소" : "Friend's email address"
        case "search": return isKorean ? "검색" : "Search"
        case "add_by_email": return isKorean ? "이메일로 친구 추가" : "Add Friend by Email"
        case "add_by_email_footer": return isKorean ? "친구의 이메일 주소를 입력하고 검색 버튼을 누르세요." : "Enter your friend's email address and tap Search."
        case "searching": return isKorean ? "검색 중..." : "Searching..."
        case "searching_users": return isKorean ? "사용자를 검색하고 있습니다" : "Searching for users"
        case "search_results": return isKorean ? "검색 결과" : "Search Results"
        case "alert": return isKorean ? "알림" : "Alert"
        case "cancel": return isKorean ? "취소" : "Cancel"
        case "ok": return isKorean ? "확인" : "OK"
        case "user": return isKorean ? "사용자" : "User"
        case "status_message": return isKorean ? "상태 메시지를 설정해보세요" : "Set your status message"
        case "no_search_results": return isKorean ? "검색 결과 없음" : "No Search Results"
        case "no_match_for": return isKorean ? "'%@'와 일치하는 친구가 없습니다" : "No friends match '%@'"
        case "no_friends_yet": return isKorean ? "아직 친구가 없어요" : "No Friends Yet"
        case "add_friends_suggestion": return isKorean ? "친구를 추가해보세요!" : "Try adding some friends!"
        case "add_friend_by_email": return isKorean ? "이메일로 친구 추가" : "Add Friend by Email"
        case "search_error_prefix": return isKorean ? "검색 중 오류가 발생했습니다: " : "An error occurred during search: "
        case "friend_request_sent": return isKorean ? "친구 요청을 보냈습니다." : "Friend request sent."
        case "friend_request_failed": return isKorean ? "친구 요청 전송에 실패했습니다." : "Failed to send friend request."
        case "error_occurred_prefix": return isKorean ? "오류가 발생했습니다: " : "An error occurred: "
        case "no_blocked_friends": return isKorean ? "차단된 친구가 없습니다" : "No blocked friends"
        default: return key
        }
    }
}

// 간소화된 차단된 친구 뷰
struct BlockedFriendsView: View {
    let blockedFriends: [Friendship]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var languageManager: LanguageManager
    
    var body: some View {
        NavigationStack {
            List {
                if blockedFriends.isEmpty {
                    ContentUnavailableView(
                        localizedText("no_blocked_friends"),
                        systemImage: "person.slash",
                        description: Text(localizedText("no_blocked_friends"))
                    )
                } else {
                    ForEach(blockedFriends, id: \.id) { friendship in
                        BlockedFriendRow(friendship: friendship, modelContext: modelContext)
                    }
                }
            }
            .navigationTitle(localizedText("blocked_list"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localizedText("close")) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func localizedText(_ key: String) -> String {
        let isKorean = languageManager.currentLanguage == .korean
        
        switch key {
        case "friends": return isKorean ? "친구" : "Friends"
        case "add_friend": return isKorean ? "친구 추가" : "Add Friend"
        case "friend_request": return isKorean ? "친구 요청" : "Friend Request"
        case "accept": return isKorean ? "수락" : "Accept"
        case "reject": return isKorean ? "거절" : "Reject"
        case "block": return isKorean ? "차단" : "Block"
        case "unblock": return isKorean ? "차단 해제" : "Unblock"
        case "friend_email_placeholder": return isKorean ? "친구의 이메일 주소" : "Friend's email address"
        case "search": return isKorean ? "검색" : "Search"
        case "add_by_email": return isKorean ? "이메일로 친구 추가" : "Add Friend by Email"
        case "add_by_email_footer": return isKorean ? "친구의 이메일 주소를 입력하고 검색 버튼을 누르세요." : "Enter your friend's email address and tap Search."
        case "searching": return isKorean ? "검색 중..." : "Searching..."
        case "searching_users": return isKorean ? "사용자를 검색하고 있습니다" : "Searching for users"
        case "search_results": return isKorean ? "검색 결과" : "Search Results"
        case "alert": return isKorean ? "알림" : "Alert"
        case "cancel": return isKorean ? "취소" : "Cancel"
        case "ok": return isKorean ? "확인" : "OK"
        case "user": return isKorean ? "사용자" : "User"
        case "status_message": return isKorean ? "상태 메시지를 설정해보세요" : "Set your status message"
        case "no_search_results": return isKorean ? "검색 결과 없음" : "No Search Results"
        case "no_match_for": return isKorean ? "'%@'와 일치하는 친구가 없습니다" : "No friends match '%@'"
        case "no_friends_yet": return isKorean ? "아직 친구가 없어요" : "No Friends Yet"
        case "add_friends_suggestion": return isKorean ? "친구를 추가해보세요!" : "Try adding some friends!"
        case "add_friend_by_email": return isKorean ? "이메일로 친구 추가" : "Add Friend by Email"
        case "search_error_prefix": return isKorean ? "검색 중 오류가 발생했습니다: " : "An error occurred during search: "
        case "friend_request_sent": return isKorean ? "친구 요청을 보냈습니다." : "Friend request sent."
        case "friend_request_failed": return isKorean ? "친구 요청 전송에 실패했습니다." : "Failed to send friend request."
        case "error_occurred_prefix": return isKorean ? "오류가 발생했습니다: " : "An error occurred: "
        case "no_blocked_friends": return isKorean ? "차단된 친구가 없습니다" : "No blocked friends"
        default: return key
        }
    }
}

// 간소화된 차단된 친구 행
struct BlockedFriendRow: View {
    let friendship: Friendship
    let modelContext: ModelContext
    @State private var showingUnblockAlert = false
    @EnvironmentObject private var languageManager: LanguageManager
    
    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(friendship.friendName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(localizedText("blocked"))
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            Spacer()
            
            Button(localizedText("unblock")) {
                showingUnblockAlert = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
        .alert(localizedText("unblock_friend"), isPresented: $showingUnblockAlert) {
            Button(localizedText("cancel"), role: .cancel) { }
            Button(localizedText("unblock"), role: .destructive) {
                unblockFriend()
            }
        } message: {
            Text(String(format: localizedText("unblock_message"), friendship.friendName))
        }
    }
    
    private func unblockFriend() {
        friendship.status = .accepted
        try? modelContext.save()
    }
    
    private func localizedText(_ key: String) -> String {
        let isKorean = languageManager.currentLanguage == .korean
        
        switch key {
        case "friends": return isKorean ? "친구" : "Friends"
        case "add_friend": return isKorean ? "친구 추가" : "Add Friend"
        case "friend_request": return isKorean ? "친구 요청" : "Friend Request"
        case "accept": return isKorean ? "수락" : "Accept"
        case "reject": return isKorean ? "거절" : "Reject"
        case "block": return isKorean ? "차단" : "Block"
        case "unblock": return isKorean ? "차단 해제" : "Unblock"
        case "friend_email_placeholder": return isKorean ? "친구의 이메일 주소" : "Friend's email address"
        case "search": return isKorean ? "검색" : "Search"
        case "add_by_email": return isKorean ? "이메일로 친구 추가" : "Add Friend by Email"
        case "add_by_email_footer": return isKorean ? "친구의 이메일 주소를 입력하고 검색 버튼을 누르세요." : "Enter your friend's email address and tap Search."
        case "searching": return isKorean ? "검색 중..." : "Searching..."
        case "searching_users": return isKorean ? "사용자를 검색하고 있습니다" : "Searching for users"
        case "search_results": return isKorean ? "검색 결과" : "Search Results"
        case "alert": return isKorean ? "알림" : "Alert"
        case "cancel": return isKorean ? "취소" : "Cancel"
        case "ok": return isKorean ? "확인" : "OK"
        case "user": return isKorean ? "사용자" : "User"
        case "status_message": return isKorean ? "상태 메시지를 설정해보세요" : "Set your status message"
        case "no_search_results": return isKorean ? "검색 결과 없음" : "No Search Results"
        case "no_match_for": return isKorean ? "'%@'와 일치하는 친구가 없습니다" : "No friends match '%@'"
        case "no_friends_yet": return isKorean ? "아직 친구가 없어요" : "No Friends Yet"
        case "add_friends_suggestion": return isKorean ? "친구를 추가해보세요!" : "Try adding some friends!"
        case "add_friend_by_email": return isKorean ? "이메일로 친구 추가" : "Add Friend by Email"
        case "search_error_prefix": return isKorean ? "검색 중 오류가 발생했습니다: " : "An error occurred during search: "
        case "friend_request_sent": return isKorean ? "친구 요청을 보냈습니다." : "Friend request sent."
        case "friend_request_failed": return isKorean ? "친구 요청 전송에 실패했습니다." : "Failed to send friend request."
        case "error_occurred_prefix": return isKorean ? "오류가 발생했습니다: " : "An error occurred: "
        case "no_blocked_friends": return isKorean ? "차단된 친구가 없습니다" : "No blocked friends"
        default: return key
        }
    }
}

// 간소화된 친구 검색 서비스
class FriendSearchService {
    static func searchUsers(by email: String) async throws -> [UserSearchResult] {
        // 성능 개선: 대기 시간을 0.3초로 단축
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3초 대기
        
        print("FriendSearchService: \(email) 검색 중...")
        
        let mockResults = [
            UserSearchResult(
                id: UUID().uuidString,
                username: email.components(separatedBy: "@").first ?? "user",
                displayName: email.components(separatedBy: "@").first?.capitalized ?? "User",
                email: email
            )
        ]
        
        if email.contains("@") && email.contains(".") {
            print("FriendSearchService: 검색 결과 반환")
            return mockResults
        } else {
            print("FriendSearchService: 유효하지 않은 이메일 형식")
            return []
        }
    }
    
    static func sendFriendRequest(from senderId: String, to receiverId: String) async throws -> Bool {
        print("FriendSearchService: 친구 요청 전송 중...")
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2초 대기
        print("FriendSearchService: 친구 요청 전송 완료")
        return true
    }
}

// 간소화된 사용자 검색 결과 데이터 모델
struct UserSearchResult: Identifiable {
    let id: String
    let username: String
    let displayName: String
    let email: String
}
