import SwiftUI
import SwiftData
import Foundation

struct FriendsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChatRoom.name) private var chatRooms: [ChatRoom]
    @EnvironmentObject private var languageManager: LanguageManager

    @State private var searchText: String = ""
    @State private var pinnedIDs: Set<String> = []

    private var displayedRooms: [ChatRoom] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Filter first with a simple, early-exit check
        let filtered: [ChatRoom]
        if trimmedQuery.isEmpty {
            filtered = chatRooms
        } else {
            filtered = chatRooms.filter { room in
                room.name.localizedCaseInsensitiveContains(trimmedQuery)
            }
        }

        let sorted = filtered.sorted(by: roomSortComparator)
        return sorted
    }

    private func roomSortComparator(_ lhs: ChatRoom, _ rhs: ChatRoom) -> Bool {
        // Pinning takes precedence
        let lPinned: Bool = pinnedIDs.contains(lhs.id.uuidString)
        let rPinned: Bool = pinnedIDs.contains(rhs.id.uuidString)
        if lPinned != rPinned {
            return lPinned && !rPinned
        }

        // Normalize names for a stable, locale-aware comparison
        let lName: String = lhs.name
        let rName: String = rhs.name

        let lKey: String = lName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let rKey: String = rName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        if lKey != rKey {
            return lKey < rKey
        }

        // If keys are equal, fall back to original strings to keep order stable
        return lName < rName
    }

    private var trailingAddFriend: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            let appLanguage: AppLanguage = languageManager.currentLanguage == .korean ? .korean : .english
            let label = L10n.text("add_friend", appLanguage)
            Button(action: addSampleFriend) {
                Image(systemName: "plus")
            }
            .accessibilityLabel(label)
            .accessibilityIdentifier("addFriendButton")
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            let appLanguage: AppLanguage = languageManager.currentLanguage == .korean ? .korean : .english
            Text(L10n.text("friends_empty", appLanguage))
                .foregroundColor(.secondary)
            Button(L10n.text("add_sample_friend", appLanguage)) { addSampleFriend() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var roomsList: some View {
        List(displayedRooms) { room in
            NavigationLink(value: room) {
                FriendsListRow(name: room.name, idString: room.id.uuidString)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                let appLanguage: AppLanguage = languageManager.currentLanguage == .korean ? .korean : .english
                let isPinned = pinnedIDs.contains(room.id.uuidString)
                Button(L10n.text(isPinned ? "unpin" : "pin_to_top", appLanguage)) {
                    togglePin(for: room)
                }.tint(.yellow)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                let appLanguage: AppLanguage = languageManager.currentLanguage == .korean ? .korean : .english
                Button(role: .destructive) {
                    delete(room)
                } label: {
                    Label(L10n.text("delete", appLanguage), systemImage: "trash")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    var body: some View {
        NavigationStack {
            Group {
                if chatRooms.isEmpty {
                    emptyStateView
                } else {
                    roomsList
                }
            }
            .navigationTitle({
                let appLanguage: AppLanguage = languageManager.currentLanguage == .korean ? .korean : .english
                return L10n.text("friends", appLanguage)
            }())
            .toolbar {
                trailingAddFriend
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: {
                let appLanguage: AppLanguage = languageManager.currentLanguage == .korean ? .korean : .english
                return L10n.text("search_friends_placeholder", appLanguage)
            }())
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

private struct FriendsListRow: View {
    let name: String
    let idString: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)
            Text(name)
        }
        .accessibilityIdentifier("friend_\(idString)")
    }
}

#Preview {
    let container = (try? ModelContainer(for: ChatRoom.self, Message.self)) ?? (try! ModelContainer(for: ChatRoom.self, Message.self))
    FriendsListView()
        .modelContainer(container)
        .environmentObject(LanguageManager())
}
