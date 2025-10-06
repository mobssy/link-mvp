//
//  FriendProfileView.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//

import SwiftUI
import SwiftData

struct FriendProfileView: View {
    let friendship: Friendship
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var languageManager: LanguageManager
    @State private var showingChatView = false
    @State private var showingBlockAlert = false
    @State private var showingUnblockAlert = false
    @AppStorage("lastActivityEnabled") private var lastActivityEnabled = true
    @State private var lastActiveText: String? = nil
    @State private var lastActiveIconColor: Color = .gray
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 프로필 헤더
                    VStack(spacing: 16) {
                        // 프로필 이미지
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color.appPrimary.opacity(0.3), Color.appPrimary.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "person.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.appPrimary)
                        }
                        
                        // 이름과 이메일
                        VStack(spacing: 8) {
                            Text(friendship.friendName)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(friendship.friendEmail)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // 상태 배지
                        StatusBadge(status: friendship.status)
                    }
                    .padding(.vertical, 20)
                    
                    // 프로필 정보
                    VStack(spacing: 16) {
                        ProfileInfoCard(
                            title: localizedText("joined"),
                            value: formatDate(friendship.createdAt),
                            icon: "calendar"
                        )
                        
                        if lastActivityEnabled && friendship.status == .accepted {
                            ProfileInfoCard(
                                title: localizedText("last_active"),
                                value: lastActiveText ?? localizedText("no_info"),
                                icon: "circle.fill",
                                iconColor: lastActiveIconColor
                            )
                        }
                        
                        ProfileInfoCard(
                            title: localizedText("mutual_friends"),
                            value: "0명", // 실제 앱에서는 계산
                            icon: "person.2"
                        )
                    }
                    
                    // 액션 버튼들
                    VStack(spacing: 12) {
                        if friendship.status == .accepted {
                            // 채팅하기 버튼
                            Button(action: {
                                showingChatView = true
                            }) {
                                Label(localizedText("start_chat"), systemImage: "bubble.left.and.bubble.right")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.appPrimary)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                        }
                        
                        // 상태별 액션 버튼
                        switch friendship.status {
                        case .accepted:
                            Button(action: {
                                showingBlockAlert = true
                            }) {
                                Label(localizedText("block"), systemImage: "hand.raised")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(.red.opacity(0.1))
                                    .foregroundColor(.red)
                                    .cornerRadius(12)
                            }
                        case .blocked:
                            Button(action: {
                                showingUnblockAlert = true
                            }) {
                                Label(localizedText("unblock"), systemImage: "hand.raised.slash")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(.orange.opacity(0.1))
                                    .foregroundColor(.orange)
                                    .cornerRadius(12)
                            }
                        case .hidden:
                            Button(action: {
                                unhideFriend()
                            }) {
                                Label(localizedText("unhide"), systemImage: "eye")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(.gray.opacity(0.1))
                                    .foregroundColor(.gray)
                                    .cornerRadius(12)
                            }
                        case .pending:
                            Text(localizedText("request_pending"))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.gray.opacity(0.1))
                                .foregroundColor(.gray)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationTitle(localizedText("profile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localizedText("close")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(localizedText("share_profile")) {
                            shareProfile()
                        }
                        
                        if friendship.status == .accepted {
                            Button(localizedText("view_conversation")) {
                                showingChatView = true
                            }
                        }
                        
                        Divider()
                        
                        Button(localizedText("report"), role: .destructive) {
                            reportUser()
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .sheet(isPresented: $showingChatView) {
            ChatViewContainer(friendship: friendship)
        }
        .alert(localizedText("block_friend"), isPresented: $showingBlockAlert) {
            Button(localizedText("cancel"), role: .cancel) { }
            Button(localizedText("block"), role: .destructive) {
                blockFriend()
            }
        } message: {
            Text(String(format: localizedText("block_message"), friendship.friendName))
        }
        .alert(localizedText("unblock_friend"), isPresented: $showingUnblockAlert) {
            Button(localizedText("cancel"), role: .cancel) { }
            Button(localizedText("unblock")) {
                unblockFriend()
            }
        } message: {
            Text(String(format: localizedText("unblock_message"), friendship.friendName))
        }
        .onAppear { computeLastActivity() }
    }
    
    private func computeLastActivity() {
        // Capture dynamic values into local constants for use in #Predicate
        let friendIdString = friendship.friendId
        let friendEmail = friendship.friendEmail
        let senderName = friendship.friendName

        var foundDate: Date? = nil

        // 1) Try to find a User record for this friend by friendId
        if let friendUUID = UUID(uuidString: friendIdString) {
            let descriptorById = FetchDescriptor<User>(
                predicate: #Predicate<User> { user in
                    user.id == friendUUID
                }
            )
            if let users = try? modelContext.fetch(descriptorById), let u = users.first {
                foundDate = u.lastActiveAt
            }
        }

        // 2) If not found, try by email
        if foundDate == nil {
            let descriptorByEmail = FetchDescriptor<User>(
                predicate: #Predicate<User> { user in
                    user.email == friendEmail
                }
            )
            if let users = try? modelContext.fetch(descriptorByEmail), let u = users.first {
                foundDate = u.lastActiveAt
            }
        }

        // 3) Fallback: use the most recent message timestamp from this friend (by sender name)
        if foundDate == nil {
            let descriptorMsg = FetchDescriptor<Message>(
                predicate: #Predicate<Message> { m in
                    m.sender == senderName
                },
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            if let msgs = try? modelContext.fetch(descriptorMsg), let recent = msgs.first {
                foundDate = recent.timestamp
            }
        }

        // Update UI state
        if let date = foundDate {
            let interval = Date().timeIntervalSince(date)
            if interval < 5 * 60 { // within 5 minutes
                lastActiveText = "온라인"
                lastActiveIconColor = .green
            } else {
                lastActiveText = formatRelative(date)
                lastActiveIconColor = .gray
            }
        } else {
            lastActiveText = nil
            lastActiveIconColor = .gray
        }
    }

    private func formatRelative(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)
        let minute: Double = 60
        let hour = 60 * minute
        let day = 24 * hour

        if interval < hour {
            let mins = max(1, Int(interval / minute))
            return "\(mins)분 전"
        } else if interval < day {
            let hours = max(1, Int(interval / hour))
            return "\(hours)시간 전"
        } else {
            let days = Int(interval / day)
            if days == 1 { return "어제" }
            if days < 7 { return "\(days)일 전" }
            // 1주 이상이면 날짜 표기
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func blockFriend() {
        withAnimation {
            friendship.status = .blocked
            try? modelContext.save()
        }
    }
    
    private func unblockFriend() {
        withAnimation {
            friendship.status = .accepted
            try? modelContext.save()
        }
    }
    
    private func unhideFriend() {
        withAnimation {
            friendship.status = .accepted
            try? modelContext.save()
        }
    }
    
    private func shareProfile() {
        // 프로필 공유 기능 (실제 앱에서 구현)
        print("프로필 공유: \(friendship.friendName)")
    }
    
    private func reportUser() {
        // 사용자 신고 기능 (실제 앱에서 구현)
        print("사용자 신고: \(friendship.friendName)")
    }
    
    private func localizedText(_ key: String) -> String {
        switch key {
        case "joined":
            return languageManager.currentLanguage == .korean ? "가입일" : "Joined"
        case "last_active":
            return languageManager.currentLanguage == .korean ? "마지막 활동" : "Last Active"
        case "mutual_friends":
            return languageManager.currentLanguage == .korean ? "공통 친구" : "Mutual Friends"
        case "no_info":
            return languageManager.currentLanguage == .korean ? "정보 없음" : "No Info"
        case "start_chat":
            return languageManager.currentLanguage == .korean ? "채팅하기" : "Start Chat"
        case "block":
            return languageManager.currentLanguage == .korean ? "차단하기" : "Block"
        case "unblock":
            return languageManager.currentLanguage == .korean ? "차단 해제" : "Unblock"
        case "unhide":
            return languageManager.currentLanguage == .korean ? "숨김 해제" : "Unhide"
        case "request_pending":
            return languageManager.currentLanguage == .korean ? "승인 대기" : "Pending"
        case "profile":
            return languageManager.currentLanguage == .korean ? "프로필" : "Profile"
        case "close":
            return languageManager.currentLanguage == .korean ? "닫기" : "Close"
        case "share_profile":
            return languageManager.currentLanguage == .korean ? "프로필 공유" : "Share Profile"
        case "view_conversation":
            return languageManager.currentLanguage == .korean ? "대화 내용 보기" : "View Conversation"
        case "report":
            return languageManager.currentLanguage == .korean ? "신고하기" : "Report"
        case "block_friend":
            return languageManager.currentLanguage == .korean ? "친구 차단" : "Block Friend"
        case "unblock_friend":
            return languageManager.currentLanguage == .korean ? "차단 해제" : "Unblock Friend"
        case "block_message":
            return languageManager.currentLanguage == .korean ? "%@님을 차단하시겠습니까? 차단된 친구는 더 이상 메시지를 보낼 수 없습니다." : "Block %@? Blocked friends can no longer send you messages."
        case "unblock_message":
            return languageManager.currentLanguage == .korean ? "%@님의 차단을 해제하시겠습니까?" : "Unblock %@?"
        case "cancel":
            return languageManager.currentLanguage == .korean ? "취소" : "Cancel"
        case "pending_short":
            return languageManager.currentLanguage == .korean ? "대기" : "Pending"
        default:
            return key
        }
    }
}

// 상태 배지 컴포넌트
struct StatusBadge: View {
    let status: FriendshipStatus
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(status.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.15))
        .foregroundColor(statusColor)
        .cornerRadius(20)
    }
    
    private var statusColor: Color {
        switch status {
        case .accepted:
            return .green
        case .pending:
            return .orange
        case .blocked:
            return .red
        case .hidden:
            return .gray
        }
    }
}

// 프로필 정보 카드
struct ProfileInfoCard: View {
    let title: String
    let value: String
    let icon: String
    var iconColor: Color = .appPrimary
    
    var body: some View {
        HStack(spacing: 16) {
            // 아이콘
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 16, weight: .medium))
            }
            
            // 정보
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(value)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// ChatViewContainer to bridge between Friendship and ChatView
struct ChatViewContainer: View {
    let friendship: Friendship
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationView {
            ChatScreen(room: createChatRoom())
        }
    }
    
    private func createChatRoom() -> ChatRoom {
        // Create a ChatRoom from the Friendship data
        let chatRoom = ChatRoom(name: friendship.friendName, profileImage: "person.circle.fill")
        return chatRoom
    }
}

#Preview {
    let sampleFriendship = Friendship(
        userId: "user1",
        friendId: "user2",
        friendName: "김친구",
        friendEmail: "friend@example.com",
        status: .accepted
    )
    return FriendProfileView(friendship: sampleFriendship)
}
