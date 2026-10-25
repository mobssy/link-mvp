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
import os

private let friendsLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "FriendsView")

// MARK: - Friends View
struct FriendsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) private var languageManager
    var authManager: AuthManager
    @State private var notificationManager = NotificationManager()

    @AppStorage("newFriendIDs") private var newFriendIDsStorage: String = ""
    @AppStorage("hasSeededNewFriends") private var hasSeededNewFriends: Bool = false

    private var newFriendIDs: Set<String> {
        get { Set(newFriendIDsStorage.split(separator: ",").map { String($0) }) }
        set { newFriendIDsStorage = newValue.joined(separator: ",") }
    }

    enum ActiveSheet: Identifiable {
        case addFriend, blockedList, manageHiddenBlocked
        var id: Int {
            switch self {
            case .addFriend: return 1
            case .blockedList: return 2
            case .manageHiddenBlocked: return 4
            }
        }
    }

    @State private var activeSheet: ActiveSheet?
    /// The friend whose profile is open: beside the list in a regular-width window, pushed in
    /// a compact one.
    @State private var selectedFriendID: UUID?
    @State private var searchText = ""
    @State private var friendships: [Friendship] = []
    @State private var showNewFriendsSection: Bool = true

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

    private var selectedFriend: Friendship? {
        guard let selectedFriendID else { return nil }
        return allAccepted.first { $0.id == selectedFriendID }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedFriendID) {
                // My Profile Section
                Section {
                    MyProfileRow(authManager: authManager)
                }

                if showNewFriendsSection && newFriendsCount > 0 {
                    Section(header: Text(String(format: L10n.text("new_friends", languageManager.currentLanguage), newFriendsCount))) {
                        ForEach(newFriends, id: \.id) { friendship in
                            FriendRow(friendship: friendship, onDataChanged: loadFriendships)
                        }
                    }
                    .headerProminence(.increased)
                }

                // Received Friend Requests
                if !receivedRequests.isEmpty {
                    Section(String(format: L10n.text("received_requests", languageManager.currentLanguage), receivedRequests.count)) {
                        ForEach(receivedRequests, id: \.id) { friendship in
                            ReceivedRequestRow(
                                friendship: friendship,
                                repository: friendshipRepository,
                                onDataChanged: loadFriendships,
                                onAccepted: { accepted in
                                    insertNewFriendID(accepted.id.uuidString)
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
                            Text(String(format: L10n.text("sent_requests", languageManager.currentLanguage), pendingRequests.count))
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
                                .foregroundStyle(.yellow)
                            Text(L10n.text("favorites", languageManager.currentLanguage))
                        }
                    }
                    .headerProminence(.increased)
                }

                // Friends List
                Section(String(format: L10n.text("friends_list", languageManager.currentLanguage), regularFriends.count)) {
                    if regularFriends.isEmpty && !searchText.isEmpty {
                        ContentUnavailableView(
                            L10n.text("no_search_results", languageManager.currentLanguage),
                            systemImage: "magnifyingglass",
                            description: Text(String(format: L10n.text("no_match_for", languageManager.currentLanguage), searchText))
                        )
                    } else if regularFriends.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "person.2")
                                .font(.system(size: 60))
                                .foregroundStyle(Color.secondary)

                            Text(L10n.text("no_friends_yet", languageManager.currentLanguage))
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.primary)

                            Text(L10n.text("add_friends_suggestion", languageManager.currentLanguage))
                                .font(.subheadline)
                                .foregroundStyle(Color.secondary)

                            Button(action: {
                                activeSheet = .addFriend
                            }) {
                                HStack {
                                    Image(systemName: "person.badge.plus")
                                    Text(L10n.text("add_friend_by_email", languageManager.currentLanguage))
                                }
                                .font(.headline)
                                .foregroundStyle(.onAppPrimary)
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
                                        setStatus(.hidden, of: friendship)
                                    } label: {
                                        Label(L10n.text("hide", languageManager.currentLanguage), systemImage: "eye.slash")
                                    }.tint(.gray)

                                    Button(role: .destructive) {
                                        setStatus(.blocked, of: friendship)
                                    } label: {
                                        Label(L10n.text("block", languageManager.currentLanguage), systemImage: "person.fill.xmark")
                                    }
                                }
                        }
                        .onDelete(perform: deleteFriend)
                    }
                }
                .headerProminence(.increased)
            }
            .listStyle(.insetGrouped)
            // As in the chat list: the regular brand color is too light for a selected row.
            .tint(.appPrimaryStrong)
            .navigationTitle(L10n.text("friends", languageManager.currentLanguage))
            .searchable(text: $searchText, prompt: L10n.text("search_friends_placeholder", languageManager.currentLanguage))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        activeSheet = .addFriend
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(L10n.text("add_friend", languageManager.currentLanguage))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            activeSheet = .manageHiddenBlocked
                        } label: {
                            Label(L10n.text("manage_hidden_blocked", languageManager.currentLanguage), systemImage: "eye.slash")
                        }
                    } label: {
                        // A "more" button, not a gear: the Settings tab already shows the gear.
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel(LocalizationService.shared.text(for: .moreOptions, language: languageManager.currentLanguage.asLocalizationLanguage))
                }
            }
        } detail: {
            if let friend = selectedFriend {
                // A new identity per friend, like the chat list's conversations.
                FriendProfileView(friendship: friend)
                    .id(friend.id)
            } else {
                ContentUnavailableView(
                    L10n.text("select_friend", languageManager.currentLanguage),
                    systemImage: "person.2",
                    description: Text(L10n.text("select_friend_hint", languageManager.currentLanguage))
                )
            }
        }
        .onChange(of: selectedFriendID) {
            if let friend = selectedFriend {
                markFriendAsSeen(friend)
            }
        }
        // Blocked or hidden from the open profile: it leaves the list, and the column empties.
        .onChange(of: selectedFriend == nil) { _, isGone in
            if isGone { selectedFriendID = nil }
        }
        .badge(newFriendsCount)
        .sheet(item: $activeSheet, onDismiss: {
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
            case .manageHiddenBlocked:
                ManageFriendsView(hiddenFriends: hiddenFriends, blockedFriends: blockedFriends)
                    .environment(\.modelContext, modelContext)
            }
        }
        .onAppear {
            loadFriendships()
            attemptSeedAfterLoad()
        }
        .task {
            // A request sent from elsewhere (a chat, a bubble) shows up here; the loop ends on its
            // own when the view goes away.
            for await _ in NotificationCenter.default.notifications(named: .friendshipPendingCreated) {
                try? await Task.sleep(for: .milliseconds(200))
                loadFriendships()
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
        guard newFriendIDs.contains(friendship.id.uuidString) else { return }
        removeNewFriendID(friendship.id.uuidString)
        NotificationCenter.default.post(name: .friendsBadgeUpdated, object: nil, userInfo: ["count": newFriendsCount])
    }

    private func markLatestPendingAsNew() {
        guard let newest = allAccepted.first(where: { !newFriendIDs.contains($0.id.uuidString) }) else { return }
        insertNewFriendID(newest.id.uuidString)
        NotificationCenter.default.post(name: .friendsBadgeUpdated, object: nil, userInfo: ["count": newFriendsCount])
    }

    private func insertNewFriendID(_ id: String) {
        var ids = newFriendIDs
        ids.insert(id)
        newFriendIDsStorage = ids.sorted().joined(separator: ",")
    }

    private func removeNewFriendID(_ id: String) {
        var ids = newFriendIDs
        ids.remove(id)
        newFriendIDsStorage = ids.sorted().joined(separator: ",")
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

        let created = samples.map { s in
            Friendship(
                userId: currentUserId,
                friendId: UUID().uuidString,
                friendName: s.0,
                friendEmail: s.1,
                status: .accepted
            )
        }
        guard (try? friendshipRepository.addFriendships(created)) != nil else { return }

        newFriendIDsStorage = created.map(\.id.uuidString).joined(separator: ",")
        hasSeededNewFriends = true
        loadFriendships()
    }

    private var friendshipRepository: FriendshipRepositoryProtocol {
        LocalFriendshipRepository(modelContext: modelContext)
    }

    private func loadFriendships() {
        guard let currentUserId = authManager.currentUser?.id.uuidString else {
            friendships = []
            return
        }
        friendships = (try? friendshipRepository.friendships(involving: currentUserId)) ?? []
        friendsLogger.info("Loaded \(self.friendships.count) friendships (accepted: \(self.allAccepted.count), pending: \(self.pendingRequests.count), received: \(self.receivedRequests.count))")
        NotificationCenter.default.post(name: .friendsBadgeUpdated, object: nil, userInfo: ["count": newFriendsCount])
    }

    private func setStatus(_ status: FriendshipStatus, of friendship: Friendship) {
        try? friendshipRepository.setStatus(status, of: friendship)
        loadFriendships()
    }

    private func deleteFriend(offsets: IndexSet) {
        withAnimation {
            try? friendshipRepository.delete(offsets.map { regularFriends[$0] })
            loadFriendships()
        }
    }

    private func deletePendingRequest(offsets: IndexSet) {
        withAnimation {
            try? friendshipRepository.delete(offsets.map { pendingRequests[$0] })
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
