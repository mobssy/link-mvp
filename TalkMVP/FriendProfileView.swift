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
    @State private var lastActiveText: String?
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
                            value: languageManager.localize(ko: "0명", en: "0", ja: "0人", zh: "0人", es: "0"),
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

        var foundDate: Date?

        // 1) Try to find a User record for this friend by friendId
        if let friendUUID = UUID(uuidString: friendIdString) {
            let descriptorById = FetchDescriptor<User>(
                predicate: #Predicate<User> { user in
                    user.id == friendUUID
                }
            )
            if let users = try? modelContext.fetch(descriptorById), let user = users.first {
                foundDate = user.lastActiveAt
            }
        }

        // 2) If not found, try by email
        if foundDate == nil {
            let descriptorByEmail = FetchDescriptor<User>(
                predicate: #Predicate<User> { user in
                    user.email == friendEmail
                }
            )
            if let users = try? modelContext.fetch(descriptorByEmail), let user = users.first {
                foundDate = user.lastActiveAt
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
                lastActiveText = languageManager.localize(ko: "온라인", en: "Online", ja: "オンライン", zh: "在线", es: "En línea")
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
            return languageManager.localize(ko: "\(mins)분 전", en: "\(mins)m ago", ja: "\(mins)分前", zh: "\(mins)分钟前", es: "hace \(mins)m")
        } else if interval < day {
            let hours = max(1, Int(interval / hour))
            return languageManager.localize(ko: "\(hours)시간 전", en: "\(hours)h ago", ja: "\(hours)時間前", zh: "\(hours)小时前", es: "hace \(hours)h")
        } else {
            let days = Int(interval / day)
            if days == 1 {
                return languageManager.localize(ko: "어제", en: "Yesterday", ja: "昨日", zh: "昨天", es: "Ayer")
            }
            if days < 7 {
                return languageManager.localize(ko: "\(days)일 전", en: "\(days)d ago", ja: "\(days)日前", zh: "\(days)天前", es: "hace \(days)d")
            }
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
            return languageManager.localize(ko: "가입일", en: "Joined", ja: "参加日", zh: "加入日期", es: "Fecha de registro")
        case "last_active":
            return languageManager.localize(ko: "마지막 활동", en: "Last Active", ja: "最終アクティブ", zh: "最后活跃", es: "Última actividad")
        case "mutual_friends":
            return languageManager.localize(ko: "공통 친구", en: "Mutual Friends", ja: "共通の友だち", zh: "共同好友", es: "Amigos en común")
        case "no_info":
            return languageManager.localize(ko: "정보 없음", en: "No Info", ja: "情報なし", zh: "无信息", es: "Sin información")
        case "start_chat":
            return languageManager.localize(ko: "채팅하기", en: "Start Chat", ja: "チャットを始める", zh: "开始聊天", es: "Iniciar chat")
        case "block":
            return languageManager.localize(ko: "차단하기", en: "Block", ja: "ブロック", zh: "屏蔽", es: "Bloquear")
        case "unblock":
            return languageManager.localize(ko: "차단 해제", en: "Unblock", ja: "ブロック解除", zh: "解除屏蔽", es: "Desbloquear")
        case "unhide":
            return languageManager.localize(ko: "숨김 해제", en: "Unhide", ja: "非表示解除", zh: "取消隐藏", es: "Mostrar")
        case "request_pending":
            return languageManager.localize(ko: "승인 대기", en: "Pending", ja: "承認待ち", zh: "待确认", es: "Pendiente")
        case "profile":
            return languageManager.localize(ko: "프로필", en: "Profile", ja: "プロフィール", zh: "个人资料", es: "Perfil")
        case "close":
            return languageManager.localize(ko: "닫기", en: "Close", ja: "閉じる", zh: "关闭", es: "Cerrar")
        case "share_profile":
            return languageManager.localize(ko: "프로필 공유", en: "Share Profile", ja: "プロフィールを共有", zh: "分享资料", es: "Compartir perfil")
        case "view_conversation":
            return languageManager.localize(ko: "대화 내용 보기", en: "View Conversation", ja: "会話を見る", zh: "查看对话", es: "Ver conversación")
        case "report":
            return languageManager.localize(ko: "신고하기", en: "Report", ja: "報告", zh: "举报", es: "Reportar")
        case "block_friend":
            return languageManager.localize(ko: "친구 차단", en: "Block Friend", ja: "友だちをブロック", zh: "屏蔽朋友", es: "Bloquear amigo")
        case "unblock_friend":
            return languageManager.localize(ko: "차단 해제", en: "Unblock Friend", ja: "ブロック解除", zh: "解除屏蔽", es: "Desbloquear amigo")
        case "block_message":
            return languageManager.localize(
                ko: "%@님을 차단하시겠습니까? 차단된 친구는 더 이상 메시지를 보낼 수 없습니다.",
                en: "Block %@? Blocked friends can no longer send you messages.",
                ja: "%@さんをブロックしますか？ブロックした友だちはメッセージを送れなくなります。",
                zh: "屏蔽%@？被屏蔽的朋友将无法再向您发送消息。",
                es: "¿Bloquear a %@? Los amigos bloqueados ya no podrán enviarte mensajes."
            )
        case "unblock_message":
            return languageManager.localize(
                ko: "%@님의 차단을 해제하시겠습니까?",
                en: "Unblock %@?",
                ja: "%@さんのブロックを解除しますか？",
                zh: "解除对%@的屏蔽？",
                es: "¿Desbloquear a %@?"
            )
        case "cancel":
            return languageManager.localize(ko: "취소", en: "Cancel", ja: "キャンセル", zh: "取消", es: "Cancelar")
        case "pending_short":
            return languageManager.localize(ko: "대기", en: "Pending", ja: "保留中", zh: "待处理", es: "Pendiente")
        default:
            return key
        }
    }
}

// 상태 배지 컴포넌트
struct StatusBadge: View {
    let status: FriendshipStatus
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(statusDisplayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.15))
        .foregroundColor(statusColor)
        .cornerRadius(20)
    }

    private var statusDisplayName: String {
        switch status {
        case .pending:
            return languageManager.localize(ko: "대기중", en: "Pending", ja: "保留中", zh: "待处理", es: "Pendiente")
        case .accepted:
            return languageManager.localize(ko: "친구", en: "Friend", ja: "友だち", zh: "朋友", es: "Amigo")
        case .hidden:
            return languageManager.localize(ko: "숨김", en: "Hidden", ja: "非表示", zh: "已隐藏", es: "Oculto")
        case .blocked:
            return languageManager.localize(ko: "차단됨", en: "Blocked", ja: "ブロック済み", zh: "已屏蔽", es: "Bloqueado")
        }
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
