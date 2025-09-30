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
    @Query private var chatRooms: [ChatRoom]
    @State private var searchText = ""
    @StateObject private var chatService: ChatService
    
    init() {
        // 임시 컨텍스트로 초기화, onAppear에서 실제 컨텍스트로 재설정
        let tempContext = try! ModelContainer(for: Message.self).mainContext
        self._chatService = StateObject(wrappedValue: ChatService(modelContext: tempContext))
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
                    NavigationLink(destination: ChatView(chatRoom: room, chatService: chatService)) {
                        ChatRoomRow(room: room)
                    }
                }
                .onDelete(perform: deleteChatRooms)
            }
            .navigationTitle("채팅")
            .searchable(text: $searchText, prompt: "검색")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("새 채팅") {
                            addNewChatRoom()
                        }
                        Button("그룹 채팅") {
                            addGroupChatRoom()
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .onAppear {
            createSampleDataIfNeeded()
            // ChatService의 modelContext 업데이트
            chatService.modelContext = modelContext
        }
    }
    
    private func addNewChatRoom() {
        let newRoom = ChatRoom(name: "새 친구")
        modelContext.insert(newRoom)
        try? modelContext.save()
    }
    
    private func addGroupChatRoom() {
        let groupRoom = ChatRoom(name: "새 그룹", profileImage: "person.3.circle.fill")
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
                ChatRoom(name: "친구"),
                ChatRoom(name: "가족 단톡방"),
                ChatRoom(name: "회사 동료"),
                ChatRoom(name: "스터디 그룹")
            ]
            
            for room in sampleRooms {
                room.lastMessage = "안녕하세요!"
                room.timestamp = Calendar.current.date(byAdding: .hour, value: -Int.random(in: 1...24), to: Date()) ?? Date()
                room.unreadCount = Int.random(in: 0...5)
                modelContext.insert(room)
            }
            
            try? modelContext.save()
        }
    }
}

struct ChatRoomRow: View {
    let room: ChatRoom
    
    var body: some View {
        HStack(spacing: 12) {
            // 프로필 이미지
            Image(systemName: room.profileImage)
                .font(.system(size: 40))
                .foregroundColor(.blue)
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
                    Text(room.lastMessage.isEmpty ? "메시지를 시작해보세요" : room.lastMessage)
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
}

#Preview {
    let container = try! ModelContainer(for: ChatRoom.self, Message.self)
    
    ChatListView()
        .modelContainer(container)
}
