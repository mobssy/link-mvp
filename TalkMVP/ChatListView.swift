//
//  ChatListView.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//

import SwiftUI
import Combine
import SwiftData

// MARK: - Shared localization (fileprivate — used by ChatListView, ChatRoomRow, ChatScreen)
fileprivate func chatListLocalized(_ key: String, using manager: LanguageManager) -> String {
    switch key {
    case "new_chat":           return manager.localize(ko: "새 채팅", en: "New Chat", ja: "新しいチャット", zh: "新聊天", es: "Nuevo chat")
    case "group_chat":         return manager.localize(ko: "그룹 채팅", en: "Group Chat", ja: "グループチャット", zh: "群聊", es: "Chat grupal")
    case "new_friend":         return manager.localize(ko: "새 친구", en: "New Friend", ja: "新しい友達", zh: "新朋友", es: "Nuevo amigo")
    case "new_group":          return manager.localize(ko: "새 그룹", en: "New Group", ja: "新しいグループ", zh: "新群组", es: "Nuevo grupo")
    case "family_group":       return manager.localize(ko: "가족 단톡방", en: "Family Group", ja: "家族グループ", zh: "家庭群组", es: "Grupo familiar")
    case "work_colleagues":    return manager.localize(ko: "회사 동료", en: "Work Colleagues", ja: "職場の同僚", zh: "工作同事", es: "Colegas de trabajo")
    case "study_group":        return manager.localize(ko: "스터디 그룹", en: "Study Group", ja: "スタディグループ", zh: "学习小组", es: "Grupo de estudio")
    case "hello_message":      return manager.localize(ko: "안녕하세요!", en: "Hello!", ja: "こんにちは！", zh: "你好！", es: "¡Hola!")
    case "start_conversation": return manager.localize(ko: "메시지를 시작해보세요", en: "Start a conversation", ja: "会話を始めましょう", zh: "开始对话", es: "Inicia una conversación")
    case "chat":               return manager.localize(ko: "채팅", en: "Chat", ja: "チャット", zh: "聊天", es: "Chat")
    case "search":             return manager.localize(ko: "검색", en: "Search", ja: "検索", zh: "搜索", es: "Buscar")
    case "friend":             return manager.localize(ko: "친구", en: "Friend", ja: "友達", zh: "朋友", es: "Amigo")
    case "new_chat_button":    return manager.localize(ko: "새 채팅 만들기", en: "Create new chat", ja: "新しいチャットを作成", zh: "创建新聊天", es: "Crear nuevo chat")
    case "add_friend":         return manager.localize(ko: "친구 추가", en: "Add Friend", ja: "友達を追加", zh: "添加好友", es: "Agregar amigo")
    case "request_pending":    return manager.localize(ko: "승인 대기", en: "Pending", ja: "承認待ち", zh: "待审批", es: "Pendiente")
    case "alert":              return manager.localize(ko: "알림", en: "Alert", ja: "お知らせ", zh: "通知", es: "Alerta")
    case "ok":                 return manager.localize(ko: "확인", en: "OK", ja: "OK", zh: "确认", es: "Aceptar")
    case "user":               return manager.localize(ko: "사용자", en: "User", ja: "ユーザー", zh: "用户", es: "Usuario")
    case "friend_request_sent":return manager.localize(ko: "친구 요청을 보냈습니다.", en: "Friend request sent.", ja: "友達リクエストを送りました。", zh: "好友请求已发送。", es: "Solicitud de amistad enviada.")
    default: return key
    }
}

struct ChatListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var languageManager: LanguageManager
    @Query(sort: \ChatRoom.timestamp, order: .reverse) private var chatRooms: [ChatRoom]
    @State private var searchText = ""
    @StateObject private var chatService: ChatService

    // Shared in-memory context used only during init — replaced by the environment's
    // shared context in onAppear before any real I/O happens.
    private static let initServiceContext: ModelContext = {
        let schema = Schema([Message.self, ChatRoom.self, User.self, Friendship.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
            fatalError("Cannot create ChatService initialization container")
        }
        return container.mainContext
    }()

    init() {
        self._chatService = StateObject(wrappedValue: ChatService(modelContext: Self.initServiceContext))
    }

    var filteredChatRooms: [ChatRoom] {
        guard !searchText.isEmpty else { return chatRooms }
        return chatRooms.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredChatRooms, id: \.id) { room in
                    NavigationLink(value: room) {
                        ChatRoomRow(room: room)
                    }
                }
                .onDelete(perform: deleteChatRooms)
            }
            .navigationTitle(localizedText("chat"))
            .searchable(text: $searchText, prompt: localizedText("search"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(localizedText("new_chat")) {
                            addNewChatRoom()
                        }
                        Button(localizedText("group_chat")) {
                            addGroupChatRoom()
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(localizedText("new_chat_button"))
                }
            }
            .navigationDestination(for: ChatRoom.self) { room in
                ChatScreen(room: room)
            }
        }
        .onAppear {
            chatService.modelContext = modelContext
            createSampleDataIfNeeded()
        }
    }

    private func addNewChatRoom() {
        let newRoom = ChatRoom(name: localizedText("new_friend"))
        modelContext.insert(newRoom)
        do { try modelContext.save() } catch { print("❌ [ChatListView] Failed to save new chat room: \(error)") }
    }

    private func addGroupChatRoom() {
        let groupRoom = ChatRoom(name: localizedText("new_group"), profileImage: "person.3.circle.fill")
        modelContext.insert(groupRoom)
        do { try modelContext.save() } catch { print("❌ [ChatListView] Failed to save group chat room: \(error)") }
    }

    private func deleteChatRooms(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(filteredChatRooms[index])
            }
            do { try modelContext.save() } catch { print("❌ [ChatListView] Failed to delete chat rooms: \(error)") }
        }
    }

    private func createSampleDataIfNeeded() {
        if chatRooms.isEmpty {
            let sampleRooms = [
                ChatRoom(name: localizedText("friend")),
                ChatRoom(name: localizedText("family_group")),
                ChatRoom(name: localizedText("work_colleagues")),
                ChatRoom(name: localizedText("study_group"))
            ]

            for room in sampleRooms {
                room.lastMessage = localizedText("hello_message")
                room.timestamp = Calendar.current.date(byAdding: .hour, value: -Int.random(in: 1...24), to: Date()) ?? Date()
                room.unreadCount = Int.random(in: 0...5)
                modelContext.insert(room)
            }

            do { try modelContext.save() } catch { print("❌ [ChatListView] Failed to save sample data: \(error)") }
        }
    }

    private func localizedText(_ key: String) -> String {
        chatListLocalized(key, using: languageManager)
    }
}

struct ChatRoomRow: View {
    let room: ChatRoom
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        HStack(spacing: 12) {
            // 프로필 이미지
            Image(systemName: room.profileImage)
                .font(.largeTitle)
                .foregroundColor(.appPrimary)
                .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(room.name)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    Text(room.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text(room.lastMessage.isEmpty ? localizedText("start_conversation") : room.lastMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Spacer()

                    if room.unreadCount > 0 {
                        Text("\(room.unreadCount)")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(combinedAccessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var combinedAccessibilityLabel: String {
        let lastMsg = room.lastMessage.isEmpty
            ? languageManager.localize(ko: "메시지를 시작해보세요", en: "Start a conversation", ja: "会話を始めましょう", zh: "开始对话", es: "Inicia una conversación")
            : room.lastMessage
        var label = "\(room.name), \(lastMsg)"
        if room.unreadCount > 0 {
            label += languageManager.localize(
                ko: ", 읽지 않은 메시지 \(room.unreadCount)개",
                en: ", \(room.unreadCount) unread messages",
                ja: ", 未読メッセージ \(room.unreadCount)件",
                zh: ", \(room.unreadCount) 条未读消息",
                es: ", \(room.unreadCount) mensajes no leídos"
            )
        }
        return label
    }

    private func localizedText(_ key: String) -> String {
        chatListLocalized(key, using: languageManager)
    }
}

struct ChatScreen: View {
    let room: ChatRoom
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var languageManager: LanguageManager
    @State private var friendState: FriendState = .unknown
    @State private var showingAlert = false
    @State private var alertMessage = ""

    private enum FriendState { case unknown, notFriend, pending, isFriend }

    var body: some View {
        ChatView(chatRoom: room)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    friendToolbarItem
                }
            }
            .onAppear { loadFriendState() }
            .alert(localizedText("alert"), isPresented: $showingAlert) {
                Button(localizedText("ok")) {}
            } message: {
                Text(alertMessage)
            }
    }

    @ViewBuilder
    private var friendToolbarItem: some View {
        switch friendState {
        case .notFriend:
            Button {
                addFriend()
            } label: {
                Label(localizedText("add_friend"), systemImage: "person.badge.plus")
            }
        case .pending:
            Label(localizedText("request_pending"), systemImage: "clock")
                .foregroundColor(.secondary)
        case .isFriend:
            Label(localizedText("friend"), systemImage: "checkmark.seal.fill")
                .foregroundColor(.green)
        default:
            EmptyView()
        }
    }

    private func loadFriendState() {
        guard let currentUserId = authManager.currentUser?.id.uuidString else {
            friendState = .unknown
            return
        }
        let name = room.name
        let descriptor = FetchDescriptor<Friendship>(predicate: #Predicate<Friendship> { f in
            f.ownerUserId == currentUserId && f.friendName == name
        })
        do {
            let results = try modelContext.fetch(descriptor)
            if let existing = results.first {
                switch existing.status {
                case .accepted:
                    friendState = .isFriend
                case .pending:
                    friendState = .pending
                case .blocked:
                    friendState = .notFriend
                default:
                    friendState = .notFriend
                }
            } else {
                friendState = .notFriend
            }
        } catch {
            print("Failed to load friend state: \(error)")
            friendState = .unknown
        }
    }

    private func addFriend() {
        guard friendState == .notFriend, let currentUserId = authManager.currentUser?.id.uuidString else { return }
        // Outgoing record for current user
        let outgoing = Friendship(
            userId: currentUserId,
            friendId: UUID().uuidString,
            friendName: room.name,
            friendEmail: "",
            status: .pending
        )
        modelContext.insert(outgoing)

        // Mirror record for receiver (backend readiness)
        let mirror = Friendship(
            userId: outgoing.friendId,
            friendId: currentUserId,
            friendName: authManager.currentUser?.displayName ?? localizedText("user"),
            friendEmail: authManager.currentUser?.email ?? "",
            status: .pending
        )
        modelContext.insert(mirror)

        do {
            try modelContext.save()
            friendState = .pending
            alertMessage = localizedText("friend_request_sent")
            showingAlert = true
            // Local notification to simulate receiver-side alert
            let manager = NotificationManager()
            let senderName = authManager.currentUser?.displayName ?? localizedText("user")
            let senderEmail = authManager.currentUser?.email ?? ""
            manager.scheduleFriendRequestNotification(from: senderName, email: senderEmail)
        } catch {
            print("Failed to save friend request: \(error)")
        }
    }

    private func localizedText(_ key: String) -> String {
        chatListLocalized(key, using: languageManager)
    }
}

#Preview {
    if let container = try? ModelContainer(
        for: ChatRoom.self, Message.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    ) {
        ChatListView()
            .modelContainer(container)
    } else {
        Text("Preview unavailable")
    }
}
