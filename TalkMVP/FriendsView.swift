//
//  FriendsView.swift
//  TalkMVP
//
//  Main friends view orchestration following SOLID principles
//

import SwiftUI
import UIKit
import SwiftData
import UserNotifications

// MARK: - Friends View
struct FriendsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var languageManager: LanguageManager
    @StateObject private var authManager: AuthManager
    @StateObject private var notificationManager = NotificationManager()
    @AppStorage("themeMode") private var themeMode: String = "system"

    @AppStorage("newFriendIDs") private var newFriendIDsStorage: String = ""
    @AppStorage("hasSeededNewFriends") private var hasSeededNewFriends: Bool = false

    private var newFriendIDs: Set<String> {
        get { Set(newFriendIDsStorage.split(separator: ",").map { String($0) }) }
        set { newFriendIDsStorage = newValue.joined(separator: ",") }
    }

    enum ActiveSheet: Identifiable {
        case addFriend, blockedList, settings, manageHiddenBlocked
        var id: Int {
            switch self {
            case .addFriend: return 1
            case .blockedList: return 2
            case .settings: return 3
            case .manageHiddenBlocked: return 4
            }
        }
    }

    @State private var activeSheet: ActiveSheet?
    @State private var searchText = ""
    @State private var friendships: [Friendship] = []
    @State private var showNewFriendsSection: Bool = true
    @State private var notificationObserver: NSObjectProtocol?

    var allAccepted: [Friendship] {
        guard let currentUserId = authManager.currentUser?.id.uuidString else { return [] }
        let base = friendships.filter { f in
            f.ownerUserId == currentUserId && f.status == .accepted
        }
        if searchText.isEmpty {
            return base
        } else {
            return base.filter { friendship in
                friendship.friendName.localizedCaseInsensitiveContains(searchText) ||
                friendship.friendEmail.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private var newFriends: [Friendship] {
        allAccepted.filter { newFriendIDs.contains($0.id.uuidString) }
    }

    private var favoriteFriends: [Friendship] {
        allAccepted
            .filter { $0.isFavorite && !newFriendIDs.contains($0.id.uuidString) }
            .sorted { $0.friendName < $1.friendName }
    }

    private var regularFriends: [Friendship] {
        allAccepted
            .filter { !newFriendIDs.contains($0.id.uuidString) && !$0.isFavorite }
            .sorted { $0.friendName < $1.friendName }
    }

    private var newFriendsCount: Int { newFriends.count }

    init(authManager: AuthManager) {
        self._authManager = StateObject(wrappedValue: authManager)
    }

    var pendingRequests: [Friendship] {
        guard let currentUserId = authManager.currentUser?.id.uuidString else { return [] }

        return friendships.filter { friendship in
            friendship.ownerUserId == currentUserId && friendship.status == .pending
        }
    }

    var receivedRequests: [Friendship] {
        guard let currentUserId = authManager.currentUser?.id.uuidString else { return [] }
        return friendships.filter { friendship in
            friendship.friendId == currentUserId && friendship.status == .pending
        }
    }

    var blockedFriends: [Friendship] {
        guard let currentUserId = authManager.currentUser?.id.uuidString else { return [] }

        return friendships.filter { friendship in
            friendship.ownerUserId == currentUserId && friendship.status == .blocked
        }
    }

    var hiddenFriends: [Friendship] {
        guard let currentUserId = authManager.currentUser?.id.uuidString else { return [] }
        return friendships.filter { f in
            f.ownerUserId == currentUserId && f.status == .hidden
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // My Profile Section
                Section {
                    MyProfileRow(authManager: authManager)
                }

                if showNewFriendsSection && newFriendsCount > 0 {
                    Section(header: Text(String(format: L10n.text("new_friends", languageManager.currentLanguage == .korean ? .korean : .english), newFriendsCount))) {
                        ForEach(newFriends, id: \.id) { friendship in
                            FriendRow(friendship: friendship, onDataChanged: loadFriendships, onOpened: { markFriendAsSeen(friendship) })
                        }
                    }
                    .headerProminence(.increased)
                }

                // Received Friend Requests
                if !receivedRequests.isEmpty {
                    Section(String(format: L10n.text("received_requests", languageManager.currentLanguage == .korean ? .korean : .english), receivedRequests.count)) {
                        ForEach(receivedRequests, id: \.id) { friendship in
                            ReceivedRequestRow(
                                friendship: friendship,
                                modelContext: modelContext,
                                onDataChanged: loadFriendships,
                                onAccepted: { accepted in
                                    var ids = Set(newFriendIDsStorage.split(separator: ",").map { String($0) })
                                    ids.insert(accepted.id.uuidString)
                                    newFriendIDsStorage = ids.joined(separator: ",")
                                    NotificationCenter.default.post(name: .friendsBadgeUpdated, object: nil, userInfo: ["count": newFriendsCount])
                                }
                            )
                        }
                    }
                    .headerProminence(.increased)
                }

                // Sent Friend Requests
                if !pendingRequests.isEmpty {
                    Section {
                        ForEach(pendingRequests, id: \.id) { friendship in
                            PendingRequestRow(friendship: friendship)
                        }
                        .onDelete(perform: deletePendingRequest)
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.badge.plus")
                            Text(String(format: L10n.text("sent_requests", languageManager.currentLanguage == .korean ? .korean : .english), pendingRequests.count))
                        }
                    }
                    .headerProminence(.increased)
                }

                // Favorite Friends
                if !favoriteFriends.isEmpty {
                    Section {
                        ForEach(favoriteFriends, id: \.id) { friendship in
                            FriendRow(friendship: friendship, onDataChanged: loadFriendships)
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text(L10n.text("favorites", languageManager.currentLanguage == .korean ? .korean : .english))
                        }
                    }
                    .headerProminence(.increased)
                }

                // Friends List
                Section(String(format: L10n.text("friends_list", languageManager.currentLanguage == .korean ? .korean : .english), regularFriends.count)) {
                    if regularFriends.isEmpty && !searchText.isEmpty {
                        ContentUnavailableView(
                            NSLocalizedString("no_search_results", comment: ""),
                            systemImage: "magnifyingglass",
                            description: Text(String(format: NSLocalizedString("no_match_for", comment: ""), searchText))
                        )
                    } else if regularFriends.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "person.2")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)

                            Text(L10n.text("no_friends_yet", languageManager.currentLanguage == .korean ? .korean : .english))
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Text(L10n.text("add_friends_suggestion", languageManager.currentLanguage == .korean ? .korean : .english))
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Button(action: {
                                activeSheet = .addFriend
                            }) {
                                HStack {
                                    Image(systemName: "person.badge.plus")
                                    Text(L10n.text("add_friend_by_email", languageManager.currentLanguage == .korean ? .korean : .english))
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
                        ForEach(regularFriends, id: \.id) { friendship in
                            FriendRow(friendship: friendship, onDataChanged: loadFriendships)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button {
                                        let mutable = friendship
                                        mutable.status = .hidden
                                        try? modelContext.save()
                                        loadFriendships()
                                    } label: {
                                        Label(NSLocalizedString("hide", comment: ""), systemImage: "eye.slash")
                                    }.tint(.gray)

                                    Button(role: .destructive) {
                                        let mutable = friendship
                                        mutable.status = .blocked
                                        try? modelContext.save()
                                        loadFriendships()
                                    } label: {
                                        Label(NSLocalizedString("block", comment: ""), systemImage: "person.fill.xmark")
                                    }
                                }
                        }
                        .onDelete(perform: deleteFriend)
                    }
                }
                .headerProminence(.increased)
            }
            .listStyle(.insetGrouped)
            .navigationTitle(L10n.text("friends", languageManager.currentLanguage == .korean ? .korean : .english))
            .searchable(text: $searchText, prompt: L10n.text("search_friends_placeholder", languageManager.currentLanguage == .korean ? .korean : .english))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        activeSheet = .addFriend
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(L10n.text("add_friend", languageManager.currentLanguage == .korean ? .korean : .english))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            activeSheet = .manageHiddenBlocked
                        } label: {
                            Label(L10n.text("manage_hidden_blocked", languageManager.currentLanguage == .korean ? .korean : .english), systemImage: "eye.slash")
                        }
                        Button {
                            activeSheet = .settings
                        } label: {
                            Label(L10n.text("settings", languageManager.currentLanguage == .korean ? .korean : .english), systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .badge(newFriendsCount)
        .sheet(item: $activeSheet, onDismiss: {
            print("📋 Sheet dismissed, reloading friendships...")
            loadFriendships()
            activeSheet = nil
        }) { sheet in
            switch sheet {
            case .addFriend:
                AddFriendView(
                    authManager: authManager,
                    notificationManager: notificationManager,
                    onFriendAdded: {
                        loadFriendships()
                        markLatestPendingAsNew()
                    }
                )
            case .blockedList:
                BlockedFriendsView(blockedFriends: blockedFriends)
            case .settings:
                SettingsView(authManager: authManager)
                    .environment(\.modelContext, modelContext)
                    .preferredColorScheme(themeMode == "light" ? .light : (themeMode == "dark" ? .dark : nil))
            case .manageHiddenBlocked:
                ManageFriendsView(hiddenFriends: hiddenFriends, blockedFriends: blockedFriends)
                    .environment(\.modelContext, modelContext)
            }
        }
        .onAppear {
            print("🔵 FriendsView appeared")
            loadFriendships()
            attemptSeedAfterLoad()

            if notificationObserver == nil {
                notificationObserver = NotificationCenter.default.addObserver(
                    forName: .friendshipPendingCreated,
                    object: nil,
                    queue: .main
                ) { notification in
                    print("🔔 Received friendshipPendingCreated notification: \(notification)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        print("🔄 Reloading friendships after notification...")
                        loadFriendships()
                    }
                }
            }
        }
        .onDisappear {
            print("🔴 FriendsView disappeared")
            if let observer = notificationObserver {
                NotificationCenter.default.removeObserver(observer)
                notificationObserver = nil
            }
        }
        .onChange(of: newFriendsCount) { _, newValue in
            NotificationCenter.default.post(name: .friendsBadgeUpdated, object: nil, userInfo: ["count": newValue])
        }
        .onChange(of: friendships) { _, _ in
            attemptSeedAfterLoad()
        }
    }

    private func markFriendAsSeen(_ friendship: Friendship) {
        var ids = Set(newFriendIDsStorage.split(separator: ",").map { String($0) })
        if ids.remove(friendship.id.uuidString) != nil {
            newFriendIDsStorage = ids.joined(separator: ",")
            NotificationCenter.default.post(name: .friendsBadgeUpdated, object: nil, userInfo: ["count": newFriendsCount])
        }
    }

    private func markLatestPendingAsNew() {
        if let newest = allAccepted.first(where: { !newFriendIDs.contains($0.id.uuidString) }) {
            var ids = Set(newFriendIDsStorage.split(separator: ",").map { String($0) })
            ids.insert(newest.id.uuidString)
            newFriendIDsStorage = ids.joined(separator: ",")
            NotificationCenter.default.post(name: .friendsBadgeUpdated, object: nil, userInfo: ["count": newFriendsCount])
        }
    }

    private func attemptSeedAfterLoad() {
        guard !hasSeededNewFriends else { return }
        #if DEBUG
        seedFiveNewFriendsIfNeeded()
        #endif
        NotificationCenter.default.post(name: .friendsBadgeUpdated, object: nil, userInfo: ["count": newFriendsCount])
    }

    private func seedFiveNewFriendsIfNeeded() {
        guard let currentUserId = authManager.currentUser?.id.uuidString else { return }
        guard !hasSeededNewFriends else { return }

        let existingMine = friendships.filter { $0.ownerUserId == currentUserId }
        guard existingMine.isEmpty else { hasSeededNewFriends = true; return }

        let samples: [(String, String)] = [
            ("강호동", "kanghodong@example.com"),
            ("원빈", "wonbin@example.com"),
            ("유재석", "yoojaeseok@example.com"),
            ("아이유", "iu@example.com"),
            ("손흥민", "son7@example.com")
        ]

        var createdIDs: [String] = []
        for s in samples {
            let friendship = Friendship(
                userId: currentUserId,
                friendId: UUID().uuidString,
                friendName: s.0,
                friendEmail: s.1,
                status: .accepted
            )
            friendship.ownerUserId = currentUserId
            modelContext.insert(friendship)
            createdIDs.append(friendship.id.uuidString)
        }
        try? modelContext.save()

        newFriendIDsStorage = createdIDs.joined(separator: ",")
        hasSeededNewFriends = true
        loadFriendships()
    }

    private func loadFriendships() {
        let fetchDescriptor = FetchDescriptor<Friendship>()
        friendships = (try? modelContext.fetch(fetchDescriptor)) ?? []

        print("📱 [FriendsView] Loaded \(friendships.count) friendships")
        print("   - Accepted: \(allAccepted.count)")
        print("   - Pending: \(pendingRequests.count)")
        print("   - Received: \(receivedRequests.count)")
        print("   - Favorites: \(favoriteFriends.count)")

        NotificationCenter.default.post(name: .friendsBadgeUpdated, object: nil, userInfo: ["count": newFriendsCount])
    }

    private func deleteFriend(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(regularFriends[index])
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

// MARK: - Notification Names
extension Notification.Name {
    static let friendshipPendingCreated = Notification.Name("friendshipPendingCreated")
    static let friendsBadgeUpdated = Notification.Name("friendsBadgeUpdated")
    static let friendshipStatusChanged = Notification.Name("friendshipStatusChanged")
}
