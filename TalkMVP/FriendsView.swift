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
                .listRowBackground(Color.blue.opacity(0.05))
                
                // 받은 친구 요청
                if !receivedRequests.isEmpty {
                    Section("📬 받은 친구 요청 \(receivedRequests.count)") {
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
                    Section("📤 보낸 친구 요청 \(pendingRequests.count)") {
                        ForEach(pendingRequests, id: \.id) { friendship in
                            PendingRequestRow(friendship: friendship)
                        }
                        .onDelete(perform: deletePendingRequest)
                    }
                    .headerProminence(.increased)
                }
                
                // 친구 목록
                Section("친구 목록 \(acceptedFriends.count)") {
                    if acceptedFriends.isEmpty && !searchText.isEmpty {
                        ContentUnavailableView(
                            "검색 결과 없음",
                            systemImage: "magnifyingglass",
                            description: Text("'\(searchText)'와 일치하는 친구가 없습니다")
                        )
                    } else if acceptedFriends.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "person.2")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("아직 친구가 없어요")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("친구를 추가해보세요!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                activeSheet = .addFriend
                            }) {
                                HStack {
                                    Image(systemName: "person.badge.plus")
                                    Text("이메일로 친구 추가")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(.blue)
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
            .navigationTitle("연락처")
            .searchable(text: $searchText, prompt: "친구 이름 검색...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        activeSheet = .settings
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("설정")
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
    @State private var showingProfileEdit = false
    
    var body: some View {
        Button(action: {
            showingProfileEdit = true
        }) {
            HStack(spacing: 16) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(authManager.currentUser?.displayName ?? "사용자")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(authManager.currentUser?.statusMessage ?? "상태 메시지")
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
        }
    }
}

// 간소화된 친구 행
struct FriendRow: View {
    let friendship: Friendship
    let onDataChanged: () -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var showingProfileView = false
    
    var body: some View {
        Button(action: {
            showingProfileView = true
        }) {
            HStack(spacing: 16) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(friendship.friendName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("온라인")
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
}

// 간소화된 받은 친구 요청 행
struct ReceivedRequestRow: View {
    let friendship: Friendship
    let modelContext: ModelContext
    let onDataChanged: () -> Void
    @State private var isAccepting = false
    
    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(friendship.friendName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("친구 요청")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("수락") {
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
}

// 간소화된 보낸 친구 요청 행
struct PendingRequestRow: View {
    let friendship: Friendship
    
    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(friendship.friendName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("요청 대기 중")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("대기")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// 간소화된 친구 추가 뷰
struct AddFriendView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var notificationManager: NotificationManager
    let onFriendAdded: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var friendEmail = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var searchResults: [UserSearchResult] = []
    @State private var isSearching = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("친구의 이메일 주소", text: $friendEmail)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .focused($isTextFieldFocused)
                            .onSubmit {
                                searchForUsers()
                            }
                        
                        Button("검색") {
                            searchForUsers()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(friendEmail.isEmpty || isSearching)
                    }
                } header: {
                    Text("이메일로 친구 추가")
                } footer: {
                    Text("친구의 이메일 주소를 입력하고 검색 버튼을 누르세요.")
                }
                
                if isSearching {
                    Section("검색 중...") {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("사용자를 검색하고 있습니다")
                                .foregroundColor(.secondary)
                        }
                    }
                } else if !searchResults.isEmpty {
                    Section("검색 결과") {
                        ForEach(searchResults, id: \.id) { result in
                            UserSearchResultRow(
                                result: result,
                                authManager: authManager,
                                modelContext: modelContext
                            ) { success, message in
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
            .navigationTitle("친구 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }
            }
        }
        .alert("알림", isPresented: $showingAlert) {
            Button("확인") {
                if alertMessage.contains("성공") {
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
                    self.alertMessage = "검색 중 오류가 발생했습니다: \(error.localizedDescription)"
                    self.showingAlert = true
                    self.isSearching = false
                }
            }
        }
    }
}

// 간소화된 사용자 검색 결과 행
struct UserSearchResultRow: View {
    let result: UserSearchResult
    @ObservedObject var authManager: AuthManager
    let modelContext: ModelContext
    let onComplete: (Bool, String) -> Void
    
    @State private var isSendingRequest = false
    
    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(result.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("친구 추가") {
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
                        onComplete(true, "친구 요청을 보냈습니다.")
                    } else {
                        onComplete(false, "친구 요청 전송에 실패했습니다.")
                    }
                    isSendingRequest = false
                }
            } catch {
                await MainActor.run {
                    onComplete(false, "오류가 발생했습니다: \(error.localizedDescription)")
                    isSendingRequest = false
                }
            }
        }
    }
}

// 간소화된 차단된 친구 뷰
struct BlockedFriendsView: View {
    let blockedFriends: [Friendship]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationStack {
            List {
                if blockedFriends.isEmpty {
                    ContentUnavailableView(
                        "차단된 친구가 없습니다",
                        systemImage: "person.slash",
                        description: Text("차단된 친구가 없습니다")
                    )
                } else {
                    ForEach(blockedFriends, id: \.id) { friendship in
                        BlockedFriendRow(friendship: friendship, modelContext: modelContext)
                    }
                }
            }
            .navigationTitle("차단 목록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// 간소화된 차단된 친구 행
struct BlockedFriendRow: View {
    let friendship: Friendship
    let modelContext: ModelContext
    @State private var showingUnblockAlert = false
    
    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(friendship.friendName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("차단됨")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            Spacer()
            
            Button("차단 해제") {
                showingUnblockAlert = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
        .alert("차단 해제", isPresented: $showingUnblockAlert) {
            Button("취소", role: .cancel) { }
            Button("차단 해제", role: .destructive) {
                unblockFriend()
            }
        } message: {
            Text("\(friendship.friendName)님의 차단을 해제하시겠습니까?")
        }
    }
    
    private func unblockFriend() {
        friendship.status = .accepted
        try? modelContext.save()
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
