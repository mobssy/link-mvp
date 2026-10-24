//
//  ChatListView.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//

import SwiftUI
import Combine
import SwiftData
import os

private let chatListLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "ChatListView")

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
    case "chats":              return manager.localize(ko: "채팅", en: "Chats", ja: "チャット", zh: "聊天", es: "Chats")
    case "search":             return manager.localize(ko: "검색", en: "Search", ja: "検索", zh: "搜索", es: "Buscar")
    case "friend":             return manager.localize(ko: "친구", en: "Friend", ja: "友達", zh: "朋友", es: "Amigo")
    case "new_chat_button":    return manager.localize(ko: "새 채팅 만들기", en: "Create new chat", ja: "新しいチャットを作成", zh: "创建新聊天", es: "Crear nuevo chat")
    case "add_friend":         return manager.localize(ko: "친구 추가", en: "Add Friend", ja: "友達を追加", zh: "添加好友", es: "Agregar amigo")
    case "request_pending":    return manager.localize(ko: "승인 대기", en: "Pending", ja: "承認待ち", zh: "待审批", es: "Pendiente")
    case "alert":              return manager.localize(ko: "알림", en: "Alert", ja: "お知らせ", zh: "通知", es: "Alerta")
    case "ok":                 return manager.localize(ko: "확인", en: "OK", ja: "OK", zh: "确认", es: "Aceptar")
    case "user":               return manager.localize(ko: "사용자", en: "User", ja: "ユーザー", zh: "用户", es: "Usuario")
    case "friend_request_sent":return manager.localize(ko: "친구 요청을 보냈습니다.", en: "Friend request sent.", ja: "友達リクエストを送りました。", zh: "好友请求已发送。", es: "Solicitud de amistad enviada.")
    case "select_chat":        return manager.localize(ko: "채팅을 선택하세요", en: "Select a Chat", ja: "チャットを選択", zh: "选择一个聊天", es: "Selecciona un chat")
    case "select_chat_hint":   return manager.localize(ko: "왼쪽 목록에서 대화를 고르면 여기에 열립니다.", en: "Pick a conversation from the list to open it here.", ja: "リストから会話を選ぶとここに表示されます。", zh: "从列表中选择一个对话，它会在这里打开。", es: "Elige una conversación de la lista para abrirla aquí.")
    default: return key
    }
}

struct ChatListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) private var languageManager
    @Query(sort: \ChatRoom.timestamp, order: .reverse) private var chatRooms: [ChatRoom]
    @State private var searchText = ""
    /// The open conversation. Kept as an id so a room deleted while open simply resolves
    /// to nothing instead of leaving a dangling model in the detail column.
    @State private var selectedRoomID: UUID?
    @State private var chatService: ChatService

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
        self._chatService = State(initialValue: ChatService(modelContext: Self.initServiceContext))
    }

    var filteredChatRooms: [ChatRoom] {
        guard !searchText.isEmpty else { return chatRooms }
        return chatRooms.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var selectedRoom: ChatRoom? {
        guard let selectedRoomID else { return nil }
        return chatRooms.first { $0.id == selectedRoomID }
    }

    // A split view adapts to the window instead of the device: in a regular-width window
    // (iPad, iPhone Duo's inner display, a large iPhone in landscape) the list and the
    // open conversation sit side by side; in a compact one (any iPhone in portrait, the
    // Duo's outer display, a narrow Split View) it collapses into the familiar push.
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedRoomID) {
                ForEach(filteredChatRooms, id: \.id) { room in
                    NavigationLink(value: room.id) {
                        ChatRoomRow(room: room)
                    }
                }
                .onDelete(perform: deleteChatRooms)
            }
            // The selected row is filled with the tint and its text turns white; the
            // regular brand color is too light for that (and hides the row's avatar).
            .tint(.appPrimaryStrong)
            .navigationTitle(localizedText("chats"))
            .searchable(text: $searchText, prompt: localizedText("search"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
        } detail: {
            if let room = selectedRoom {
                // A new identity per room: the chat view builds its view model for the
                // room it first appears with, so switching rooms must not reuse it.
                ChatScreen(room: room)
                    .id(room.id)
            } else {
                ContentUnavailableView(
                    localizedText("select_chat"),
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text(localizedText("select_chat_hint"))
                )
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
        do { try modelContext.save() } catch { chatListLogger.error("Failed to save new chat room: \(error.localizedDescription, privacy: .public)") }
    }

    private func addGroupChatRoom() {
        let groupRoom = ChatRoom(name: localizedText("new_group"), profileImage: "person.3.circle.fill")
        modelContext.insert(groupRoom)
        do { try modelContext.save() } catch { chatListLogger.error("Failed to save group chat room: \(error.localizedDescription, privacy: .public)") }
    }

    private func deleteChatRooms(offsets: IndexSet) {
        // Resolve the rooms now: the offsets refer to the list as currently shown.
        let rooms = offsets.map { filteredChatRooms[$0] }
        if rooms.contains(where: { $0.id == selectedRoomID }) {
            selectedRoomID = nil
        }
        let repository: ChatRoomRepositoryProtocol = LocalChatRoomRepository(modelContext: modelContext)
        Task {
            for room in rooms {
                do {
                    try await repository.deleteChatRoom(room)
                } catch {
                    chatListLogger.error("Failed to delete chat room: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    private func createSampleDataIfNeeded() {
        if chatRooms.isEmpty {
            let sampleRooms = ["friend", "family_group", "work_colleagues", "study_group"].map { key in
                let members = TestData.groupMembers[key] ?? []
                let room = ChatRoom(name: localizedText(key), profileImage: members.isEmpty ? "person.circle.fill" : "person.3.circle.fill")
                room.memberNames = members
                return room
            }

            for room in sampleRooms {
                room.lastMessage = localizedText("hello_message")
                room.timestamp = Calendar.current.date(byAdding: .hour, value: -Int.random(in: 1...24), to: Date()) ?? Date()
                room.unreadCount = Int.random(in: 0...5)
                modelContext.insert(room)
            }

            do { try modelContext.save() } catch { chatListLogger.error("Failed to save sample data: \(error.localizedDescription, privacy: .public)") }
        }
    }

    private func localizedText(_ key: String) -> String {
        chatListLocalized(key, using: languageManager)
    }
}

struct ChatRoomRow: View {
    let room: ChatRoom
    @Environment(LanguageManager.self) private var languageManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// At accessibility text sizes the time goes under the name, so the name has the full width
    /// instead of being cut to a few letters beside a time broken over two lines.
    private var nameAndTimeLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout())
    }

    var body: some View {
        HStack(spacing: 12) {
            // 프로필 이미지
            Image(systemName: room.profileImage)
                .font(.largeTitle)
                .foregroundStyle(.appPrimary)
                .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                nameAndTimeLayout {
                    Text(room.name)
                        .font(.headline)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)

                    if !dynamicTypeSize.isAccessibilitySize {
                        Spacer()
                    }

                    Text(room.timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                }

                HStack {
                    // A hierarchical style rather than the fixed gray, so the text turns
                    // light on a selected (filled) row instead of fading into it.
                    Text(room.lastMessage.isEmpty ? localizedText("start_conversation") : room.lastMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    if room.unreadCount > 0 {
                        Text("\(room.unreadCount)")
                            .font(.caption)
                            .foregroundStyle(.white)
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
    @Environment(AuthManager.self) private var authManager
    @Environment(LanguageManager.self) private var languageManager
    /// Nil until it is known, or when no one is signed in.
    @State private var friendStanding: FriendStanding?
    @State private var showingAlert = false
    @State private var alertMessage = ""

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
        switch friendStanding {
        case .stranger:
            Button {
                addFriend()
            } label: {
                Label(localizedText("add_friend"), systemImage: "person.badge.plus")
            }
        case .requested:
            Label(localizedText("request_pending"), systemImage: "clock")
                .foregroundStyle(Color.secondary)
        case .friend:
            Label(localizedText("friend"), systemImage: "checkmark.seal.fill")
                .foregroundStyle(.green)
        case nil:
            EmptyView()
        }
    }

    private var friendships: FriendshipRepositoryProtocol {
        LocalFriendshipRepository(modelContext: modelContext)
    }

    private func loadFriendState() {
        guard let currentUserId = authManager.currentUser?.id.uuidString else {
            friendStanding = nil
            return
        }
        friendStanding = (try? friendships.statusesByName(ownedBy: currentUserId))
            .map { FriendStanding($0[room.name]) }
    }

    private func addFriend() {
        guard friendStanding == .stranger, let me = authManager.currentUser else { return }
        let senderName = me.displayName
        do {
            try friendships.sendRequest(
                from: FriendRequestParty(id: me.id.uuidString, name: senderName, email: me.email),
                to: FriendRequestParty(id: UUID().uuidString, name: room.name, email: "")
            )
        } catch {
            return
        }
        friendStanding = .requested
        alertMessage = localizedText("friend_request_sent")
        showingAlert = true
        // Local notification to simulate receiver-side alert
        let manager = NotificationManager()
        let senderEmail = me.email
        Task { await manager.scheduleFriendRequestNotification(from: senderName, email: senderEmail) }
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
