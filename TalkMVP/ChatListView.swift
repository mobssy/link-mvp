//
//  ChatListView.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//

import SwiftUI
import Combine
import SwiftData

struct ChatListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var languageManager: LanguageManager
    @Query private var chatRooms: [ChatRoom]
    @State private var searchText = ""
    @StateObject private var chatService: ChatService
    
    init() {
        // 임시 컨텍스트로 초기화, onAppear에서 실제 컨텍스트로 재설정
        let tempContainer = try! ModelContainer(for: Message.self, ChatRoom.self, User.self, Friendship.self)
        self._chatService = StateObject(wrappedValue: ChatService(modelContext: tempContainer.mainContext))
    }
    
    var filteredChatRooms: [ChatRoom] {
        if searchText.isEmpty {
            return chatRooms.sorted { $0.timestamp > $1.timestamp }
        } else {
            return chatRooms.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
                .sorted { $0.timestamp > $1.timestamp }
        }
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
                }
            }
            .navigationDestination(for: ChatRoom.self) { room in
                ChatScreen(room: room)
            }
        }
        .onAppear {
            createSampleDataIfNeeded()
            // ChatService의 modelContext는 init에서 설정되므로 여기서 변경하지 않음
        }
    }
    
    private func addNewChatRoom() {
        let newRoom = ChatRoom(name: localizedText("new_friend"))
        modelContext.insert(newRoom)
        try? modelContext.save()
    }
    
    private func addGroupChatRoom() {
        let groupRoom = ChatRoom(name: localizedText("new_group"), profileImage: "person.3.circle.fill")
        modelContext.insert(groupRoom)
        try? modelContext.save()
    }
    
    private func deleteChatRooms(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(filteredChatRooms[index])
            }
            try? modelContext.save()
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
            
            try? modelContext.save()
        }
    }
    
    private func localizedText(_ key: String) -> String {
        let isKorean = languageManager.currentLanguage == .korean
        
        switch key {
        case "new_chat": return isKorean ? "새 채팅" : "New Chat"
        case "group_chat": return isKorean ? "그룹 채팅" : "Group Chat"
        case "new_friend": return isKorean ? "새 친구" : "New Friend"
        case "new_group": return isKorean ? "새 그룹" : "New Group"
        case "family_group": return isKorean ? "가족 단톡방" : "Family Group"
        case "work_colleagues": return isKorean ? "회사 동료" : "Work Colleagues"
        case "study_group": return isKorean ? "스터디 그룹" : "Study Group"
        case "hello_message": return isKorean ? "안녕하세요!" : "Hello!"
        case "start_conversation": return isKorean ? "메시지를 시작해보세요" : "Start a conversation"
        case "chat": return isKorean ? "채팅" : "Chat"
        case "search": return isKorean ? "검색" : "Search"
        case "friend": return isKorean ? "친구" : "Friend"
        default: return key
        }
    }
}

struct ChatRoomRow: View {
    let room: ChatRoom
    @EnvironmentObject private var languageManager: LanguageManager
    
    var body: some View {
        HStack(spacing: 12) {
            // 프로필 이미지
            Image(systemName: room.profileImage)
                .font(.system(size: 40))
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
    }
    
    private func localizedText(_ key: String) -> String {
        let isKorean = languageManager.currentLanguage == .korean
        
        switch key {
        case "new_chat": return isKorean ? "새 채팅" : "New Chat"
        case "group_chat": return isKorean ? "그룹 채팅" : "Group Chat"
        case "new_friend": return isKorean ? "새 친구" : "New Friend"
        case "new_group": return isKorean ? "새 그룹" : "New Group"
        case "family_group": return isKorean ? "가족 단톡방" : "Family Group"
        case "work_colleagues": return isKorean ? "회사 동료" : "Work Colleagues"
        case "study_group": return isKorean ? "스터디 그룹" : "Study Group"
        case "hello_message": return isKorean ? "안녕하세요!" : "Hello!"
        case "start_conversation": return isKorean ? "메시지를 시작해보세요" : "Start a conversation"
        default: return key
        }
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
            Label(localizedText("friend"), systemImage: "checkmark.seal")
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
            f.ownerUserId == currentUserId && f.userId == currentUserId && f.friendName == name
        })
        do {
            let results = try modelContext.fetch(descriptor)
            if let existing = results.first {
                switch existing.status {
                case .accepted: friendState = .isFriend
                case .pending: friendState = .pending
                case .blocked: friendState = .notFriend
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
        let isKorean = languageManager.currentLanguage == .korean
        switch key {
        case "add_friend": return isKorean ? "친구 추가" : "Add Friend"
        case "request_pending": return isKorean ? "승인 대기" : "Pending"
        case "friend": return isKorean ? "친구" : "Friend"
        case "alert": return isKorean ? "알림" : "Alert"
        case "ok": return isKorean ? "확인" : "OK"
        case "pending_short": return isKorean ? "대기" : "Pending"
        default: return key
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: ChatRoom.self, Message.self)
    
    ChatListView()
        .modelContainer(container)
}

