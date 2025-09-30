import SwiftUI
import SwiftData

struct FriendsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChatRoom.name) private var chatRooms: [ChatRoom]
    
    @State private var searchText: String = ""
    @State private var pinnedIDs: Set<String> = []
    
    private var displayedRooms: [ChatRoom] {
        let filtered = chatRooms.filter { room in
            searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || room.name.localizedCaseInsensitiveContains(searchText)
        }
        return filtered.sorted { lhs, rhs in
            let lPinned = pinnedIDs.contains(lhs.id.uuidString)
            let rPinned = pinnedIDs.contains(rhs.id.uuidString)
            if lPinned != rPinned { return lPinned && !rPinned }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if chatRooms.isEmpty {
                    VStack(spacing: 12) {
                        Text("친구 목록이 비어 있습니다")
                            .foregroundColor(.secondary)
                        Button("샘플 친구 추가") { addSampleFriend() }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    List(displayedRooms) { room in
                        NavigationLink(value: room) {
                            HStack(spacing: 12) {
                                Image(systemName: "person.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                                Text(room.name)
                            }
                            .accessibilityIdentifier("friend_\(room.id.uuidString)")
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            let isPinned = pinnedIDs.contains(room.id.uuidString)
                            Button(isPinned ? "고정 해제" : "상단 고정") {
                                togglePin(for: room)
                            }.tint(.yellow)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                delete(room)
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("친구")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addSampleFriend) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("친구 추가")
                    .accessibilityIdentifier("addFriendButton")
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "친구 검색")
            .onAppear {
                if let saved = UserDefaults.standard.array(forKey: "pinnedChatRooms") as? [String] {
                    pinnedIDs = Set(saved)
                }
                // Auto-populate sample friends if empty so it shows immediately
                if chatRooms.isEmpty {
                    let names = ["할머니", "아버지", "어머니", "성조 삼촌", "소희이모", "소희 이모", "내 동생"]
                    for name in names {
                        let room = ChatRoom(name: name)
                        modelContext.insert(room)
                    }
                    try? modelContext.save()
                }
            }
            .onChange(of: pinnedIDs) { _, newValue in
                UserDefaults.standard.set(Array(newValue), forKey: "pinnedChatRooms")
            }
            .navigationDestination(for: ChatRoom.self) { room in
                ChatView(chatRoom: room)
            }
        }
    }

    private func addSampleFriend() {
        let names = ["엄마", "아빠", "할머니", "친구", "동생"]
        let room = ChatRoom(name: names.randomElement() ?? "친구")
        modelContext.insert(room)
        try? modelContext.save()
    }
    
    private func togglePin(for room: ChatRoom) {
        let id = room.id.uuidString
        if pinnedIDs.contains(id) { pinnedIDs.remove(id) } else { pinnedIDs.insert(id) }
    }

    private func delete(_ room: ChatRoom) {
        modelContext.delete(room)
        try? modelContext.save()
    }
}

#Preview {
    let container = try! ModelContainer(for: ChatRoom.self, Message.self)
    return FriendsListView()
        .modelContainer(container)
}
