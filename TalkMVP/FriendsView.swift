//
//  FriendsView_Simple.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//

import SwiftUI
import UIKit
import SwiftData
import UserNotifications

// 간소화된 친구 목록 뷰
struct FriendsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var languageManager: LanguageManager
    @StateObject private var authManager: AuthManager
    @StateObject private var notificationManager = NotificationManager()
    @AppStorage("themeMode") private var themeMode: String = "system"

    @AppStorage("newFriendIDs") private var newFriendIDsStorage: String = "" // comma-separated UUID strings
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
        // Received requests: where I am the friendId (recipient) and status is pending
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
                // 내 프로필 섹션
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

                // 받은 친구 요청
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

                // 보낸 친구 요청
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

                // 즐겨찾기 친구 목록
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

                // 친구 목록
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

            // Observer를 제대로 등록하고 token 저장
            if notificationObserver == nil {
                notificationObserver = NotificationCenter.default.addObserver(
                    forName: .friendshipPendingCreated,
                    object: nil,
                    queue: .main
                ) { notification in
                    print("🔔 Received friendshipPendingCreated notification: \(notification)")
                    // 약간의 지연을 주어 SwiftData 저장이 완료되도록 함
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        print("🔄 Reloading friendships after notification...")
                        loadFriendships()
                    }
                }
            }
        }
        .onDisappear {
            print("🔴 FriendsView disappeared")
            // Observer 제거
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
        // After sending a request, when it becomes accepted, we will mark it. For now, mark the most recent accepted friend not yet tracked.
        // Find any accepted friendship not present in newFriendIDs and add it.
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

        // If we already have any friendships for this user, don't auto-create duplicates
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

        // Mark all 5 as new friends
        newFriendIDsStorage = createdIDs.joined(separator: ",")
        hasSeededNewFriends = true
        loadFriendships()
    }

    private func loadFriendships() {
        let fetchDescriptor = FetchDescriptor<Friendship>()
        friendships = (try? modelContext.fetch(fetchDescriptor)) ?? []

        // Debug logging
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

// 간소화된 내 프로필 행
struct MyProfileRow: View {
    @ObservedObject var authManager: AuthManager
    @EnvironmentObject private var languageManager: LanguageManager
    @State private var showingProfileEdit = false

    var body: some View {
        Button(action: {
            showingProfileEdit = true
        }) {
            HStack(spacing: 16) {
                if let data = authManager.currentUser?.profileImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.appPrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(localizedDisplayName().capitalized)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(localizedStatusMessage())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Circle()
                    .fill(.green)
                    .frame(width: 12, height: 12)
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingProfileEdit) {
            ProfileEditView(authManager: authManager)
                .environmentObject(languageManager)
        }
    }

    private func localizedDisplayName() -> String {
        let isKorean = languageManager.isKorean
        let raw = (authManager.currentUser?.displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            return NSLocalizedString("user", comment: "")
        }
        // Map known default test names between languages
        if raw == "테스터" || raw == "Tester" {
            return isKorean ? "테스터" : "Tester"
        }
        return raw
    }

    private func localizedStatusMessage() -> String {
        let isKorean = languageManager.isKorean
        let raw = (authManager.currentUser?.statusMessage ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            return NSLocalizedString("status_message", comment: "")
        }
        // Map known default test status messages between languages
        if raw == "테스트 모드로 체험 중입니다" || raw == "Experiencing in test mode" {
            return isKorean ? "테스트 모드로 체험 중입니다" : "Experiencing in test mode"
        }
        return raw
    }
}

// 간소화된 친구 행
struct FriendRow: View {
    let friendship: Friendship
    let onDataChanged: () -> Void
    var onOpened: (() -> Void)?
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var languageManager: LanguageManager
    @State private var showingProfileView = false

    var body: some View {
        Button(action: {
            onOpened?()
            showingProfileView = true
        }) {
            HStack(spacing: 16) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.appPrimary)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(friendship.friendName)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        if friendship.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    }

                    Text(L10n.text("online", languageManager.currentLanguage == .korean ? .korean : .english))
                        .font(.subheadline)
                        .foregroundColor(.green)
                }

                Spacer()

                Circle()
                    .fill(.green)
                    .frame(width: 10, height: 10)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                toggleFavorite()
            } label: {
                Label(
                    friendship.isFavorite ? L10n.text("unfavorite", languageManager.currentLanguage == .korean ? .korean : .english) : L10n.text("favorite", languageManager.currentLanguage == .korean ? .korean : .english),
                    systemImage: friendship.isFavorite ? "star.slash.fill" : "star.fill"
                )
            }
            .tint(friendship.isFavorite ? .gray : .yellow)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                toggleNotifications()
            } label: {
                Label(
                    friendship.notificationsEnabled ? L10n.text("mute_notifications", languageManager.currentLanguage == .korean ? .korean : .english) : L10n.text("unmute_notifications", languageManager.currentLanguage == .korean ? .korean : .english),
                    systemImage: friendship.notificationsEnabled ? "bell.slash.fill" : "bell.fill"
                )
            }
            .tint(friendship.notificationsEnabled ? .gray : .blue)
        }
        .sheet(isPresented: $showingProfileView) {
            FriendProfileView(friendship: friendship)
        }
    }

    private func toggleFavorite() {
        friendship.isFavorite.toggle()
        try? modelContext.save()
        onDataChanged()
    }

    private func toggleNotifications() {
        friendship.notificationsEnabled.toggle()
        try? modelContext.save()
        onDataChanged()
    }
}

// 간소화된 받은 친구 요청 행
struct ReceivedRequestRow: View {
    let friendship: Friendship
    let modelContext: ModelContext
    let onDataChanged: () -> Void
    var onAccepted: ((Friendship) -> Void)?
    @State private var isAccepting = false
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(friendship.friendName)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(L10n.text("friend_request", languageManager.currentLanguage == .korean ? .korean : .english))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(L10n.text("accept", languageManager.currentLanguage == .korean ? .korean : .english)) {
                acceptFriendRequest()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isAccepting)
        }
        .padding(.vertical, 4)
    }

    private func acceptFriendRequest() {
        isAccepting = true
        friendship.status = .accepted
        try? modelContext.save()
        onDataChanged()
        onAccepted?(friendship)
        isAccepting = false
    }
}

// 간소화된 보낸 친구 요청 행
struct PendingRequestRow: View {
    let friendship: Friendship
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.gray)

            VStack(alignment: .leading, spacing: 4) {
                Text(friendship.friendName)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(L10n.text("request_pending", languageManager.currentLanguage == .korean ? .korean : .english))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(L10n.text("pending_short", languageManager.currentLanguage == .korean ? .korean : .english))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// 간소화된 친구 추가 뷰
struct AddFriendView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var notificationManager: NotificationManager
    let onFriendAdded: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var languageManager: LanguageManager

    @State private var friendEmail = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var searchResults: [UserSearchResult] = []
    @State private var isSearching = false
    @State private var lastActionWasSuccess = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField(L10n.text("friend_email_placeholder", languageManager.currentLanguage == .korean ? .korean : .english), text: $friendEmail)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .focused($isTextFieldFocused)
                            .onSubmit {
                                searchForUsers()
                            }

                        Button(L10n.text("search", languageManager.currentLanguage == .korean ? .korean : .english)) {
                            searchForUsers()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(friendEmail.isEmpty || isSearching)
                    }
                } header: {
                    Text(L10n.text("add_by_email", languageManager.currentLanguage == .korean ? .korean : .english))
                } footer: {
                    Text(L10n.text("add_by_email_footer", languageManager.currentLanguage == .korean ? .korean : .english))
                }

                if isSearching {
                    Section(L10n.text("searching", languageManager.currentLanguage == .korean ? .korean : .english)) {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text(L10n.text("searching_users", languageManager.currentLanguage == .korean ? .korean : .english))
                                .foregroundColor(.secondary)
                        }
                    }
                } else if !searchResults.isEmpty {
                    Section(L10n.text("search_results", languageManager.currentLanguage == .korean ? .korean : .english)) {
                        ForEach(searchResults, id: \.id) { result in
                            UserSearchResultRow(
                                result: result,
                                authManager: authManager,
                                notificationManager: notificationManager,
                                modelContext: modelContext
                            ) { success, message in
                                print("📝 UserSearchResultRow onComplete: success=\(success), message=\(message)")
                                lastActionWasSuccess = success
                                alertMessage = message
                                showingAlert = true
                                if success {
                                    searchResults.removeAll()
                                    friendEmail = ""
                                    print("📝 Calling onFriendAdded callback...")
                                    onFriendAdded()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.text("add_friend", languageManager.currentLanguage == .korean ? .korean : .english))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.text("cancel", languageManager.currentLanguage == .korean ? .korean : .english)) {
                        dismiss()
                    }
                }
            }
        }
        .alert(L10n.text("alert", languageManager.currentLanguage == .korean ? .korean : .english), isPresented: $showingAlert) {
            Button(L10n.text("ok", languageManager.currentLanguage == .korean ? .korean : .english)) {
                if lastActionWasSuccess {
                    print("✅ Alert OK pressed, dismissing AddFriendView...")
                    // Give time for data to propagate
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        dismiss()
                    }
                }
            }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            // 뷰가 나타날 때 자동으로 키보드 포커스
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }

    private func searchForUsers() {
        let email = friendEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else {
            alertMessage = NSLocalizedString("enter_email_message", comment: "")
            showingAlert = true
            return
        }
        guard isValidEmail(email) else {
            alertMessage = NSLocalizedString("invalid_email_format", comment: "")
            showingAlert = true
            return
        }

        print("사용자 검색 시작: \(email)")
        isSearching = true
        searchResults = []

        Task {
            do {
                let results = try await FriendSearchService.searchUsers(by: email)
                await MainActor.run {
                    print("검색 결과: \(results.count)개")
                    self.searchResults = results
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    print("검색 오류: \(error.localizedDescription)")
                    self.alertMessage = NSLocalizedString("search_error_prefix", comment: "") + error.localizedDescription
                    self.showingAlert = true
                    self.isSearching = false
                }
            }
        }
    }
}

// 간소화된 사용자 검색 결과 행
struct UserSearchResultRow: View {
    let result: UserSearchResult
    @ObservedObject var authManager: AuthManager
    @EnvironmentObject private var languageManager: LanguageManager
    let notificationManager: NotificationManager
    let modelContext: ModelContext
    let onComplete: (Bool, String) -> Void

    @State private var isSendingRequest = false

    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.appPrimary)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(result.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(L10n.text("add_friend", languageManager.currentLanguage == .korean ? .korean : .english)) {
                sendFriendRequest()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isSendingRequest)
        }
        .padding(.vertical, 4)
    }

    private func sendFriendRequest() {
        isSendingRequest = true

        Task {
            do {
                let success = try await FriendSearchService.sendFriendRequest(
                    from: authManager.currentUser?.id.uuidString ?? "",
                    to: result.id
                )

                await MainActor.run {
                    defer { isSendingRequest = false }

                    guard success else {
                        onComplete(false, L10n.text("friend_request_failed", languageManager.currentLanguage == .korean ? .korean : .english))
                        return
                    }

                    // Create outgoing (sender) friendship record
                    guard let senderId = authManager.currentUser?.id.uuidString else {
                        onComplete(false, L10n.text("error_occurred_prefix", languageManager.currentLanguage == .korean ? .korean : .english) + "User not found")
                        return
                    }

                    let outgoing = Friendship(
                        userId: senderId,
                        friendId: result.id,
                        friendName: result.displayName,
                        friendEmail: result.email,
                        status: .pending
                    )
                    outgoing.ownerUserId = senderId
                    modelContext.insert(outgoing)

                    // Create incoming (receiver) mirror record for backend readiness
                    let mirror = Friendship(
                        userId: result.id,
                        friendId: senderId,
                        friendName: authManager.currentUser?.displayName ?? L10n.text("user", languageManager.currentLanguage == .korean ? .korean : .english),
                        friendEmail: authManager.currentUser?.email ?? "",
                        status: .pending
                    )
                    mirror.ownerUserId = result.id
                    modelContext.insert(mirror)

                    // Try to save - if it fails, we'll still notify (data is in memory)
                    do {
                        try modelContext.save()
                        print("✅ Friendship saved successfully to persistent store")
                    } catch let error as NSError {
                        print("⚠️ Save to persistent store failed: \(error)")
                        print("⚠️ Error domain: \(error.domain), code: \(error.code)")
                        print("⚠️ Data remains in memory context and will be used")
                    }

                    // Schedule a local notification to simulate receiver-side alert
                    let senderName = authManager.currentUser?.displayName ?? L10n.text("user", languageManager.currentLanguage == .korean ? .korean : .english)
                    let senderEmail = authManager.currentUser?.email ?? ""
                    notificationManager.scheduleFriendRequestNotification(from: senderName, email: senderEmail)

                    // Post notification AFTER insert (data is in modelContext even if save failed)
                    NotificationCenter.default.post(name: .friendshipPendingCreated, object: nil, userInfo: ["friendId": result.id])
                    print("✅ Notification posted, data available in memory")

                    onComplete(true, L10n.text("friend_request_sent", languageManager.currentLanguage == .korean ? .korean : .english))
                }
            } catch {
                await MainActor.run {
                    print("❌ sendFriendRequest error: \(error)")
                    onComplete(false, L10n.text("error_occurred_prefix", languageManager.currentLanguage == .korean ? .korean : .english) + error.localizedDescription)
                    isSendingRequest = false
                }
            }
        }
    }
}

// 간소화된 차단된 친구 뷰
struct BlockedFriendsView: View {
    let blockedFriends: [Friendship]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        NavigationStack {
            List {
                if blockedFriends.isEmpty {
                    ContentUnavailableView(
                        L10n.text("no_blocked_friends", languageManager.currentLanguage == .korean ? .korean : .english),
                        systemImage: "person.slash",
                        description: Text(L10n.text("no_blocked_friends", languageManager.currentLanguage == .korean ? .korean : .english))
                    )
                } else {
                    ForEach(blockedFriends, id: \.id) { friendship in
                        BlockedFriendRow(friendship: friendship, modelContext: modelContext)
                    }
                }
            }
            .navigationTitle(L10n.text("blocked_list", languageManager.currentLanguage == .korean ? .korean : .english))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.text("close", languageManager.currentLanguage == .korean ? .korean : .english)) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// 간소화된 차단된 친구 행
struct BlockedFriendRow: View {
    let friendship: Friendship
    let modelContext: ModelContext
    @State private var showingUnblockAlert = false
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)

            VStack(alignment: .leading, spacing: 4) {
                Text(friendship.friendName)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(L10n.text("blocked", languageManager.currentLanguage == .korean ? .korean : .english))
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Spacer()

            Button(L10n.text("unblock", languageManager.currentLanguage == .korean ? .korean : .english)) {
                showingUnblockAlert = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
        .alert(L10n.text("unblock_friend", languageManager.currentLanguage == .korean ? .korean : .english), isPresented: $showingUnblockAlert) {
            Button(L10n.text("cancel", languageManager.currentLanguage == .korean ? .korean : .english), role: .cancel) { }
            Button(L10n.text("unblock", languageManager.currentLanguage == .korean ? .korean : .english), role: .destructive) {
                unblockFriend()
            }
        } message: {
            Text(String(format: L10n.text("unblock_message", languageManager.currentLanguage == .korean ? .korean : .english), friendship.friendName))
        }
    }

    private func unblockFriend() {
        friendship.status = .accepted
        try? modelContext.save()
    }
}

// 새로 추가된 숨김/차단 관리 뷰
struct ManageFriendsView: View {
    let hiddenFriends: [Friendship]
    let blockedFriends: [Friendship]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text(L10n.text("hidden_list", languageManager.currentLanguage == .korean ? .korean : .english))) {
                    if hiddenFriends.isEmpty {
                        ContentUnavailableView(
                            L10n.text("no_hidden_friends", languageManager.currentLanguage == .korean ? .korean : .english),
                            systemImage: "eye.slash",
                            description: Text(L10n.text("no_hidden_friends", languageManager.currentLanguage == .korean ? .korean : .english))
                        )
                    } else {
                        ForEach(hiddenFriends, id: \.id) { friendship in
                            HiddenFriendRow(friendship: friendship, modelContext: modelContext)
                        }
                    }
                }

                Section(header: Text(L10n.text("blocked_list", languageManager.currentLanguage == .korean ? .korean : .english))) {
                    if blockedFriends.isEmpty {
                        ContentUnavailableView(
                            L10n.text("no_blocked_friends", languageManager.currentLanguage == .korean ? .korean : .english),
                            systemImage: "hand.raised.slash",
                            description: Text(L10n.text("no_blocked_friends", languageManager.currentLanguage == .korean ? .korean : .english))
                        )
                    } else {
                        ForEach(blockedFriends, id: \.id) { friendship in
                            BlockedFriendRow(friendship: friendship, modelContext: modelContext)
                        }
                    }
                }
            }
            .navigationTitle(L10n.text("manage_hidden_blocked", languageManager.currentLanguage == .korean ? .korean : .english))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.text("close", languageManager.currentLanguage == .korean ? .korean : .english)) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// 새로 추가된 숨김 친구 행
struct HiddenFriendRow: View {
    let friendship: Friendship
    let modelContext: ModelContext
    @State private var showingUnhideAlert = false
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.gray)

            VStack(alignment: .leading, spacing: 4) {
                Text(friendship.friendName)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(L10n.text("hidden", languageManager.currentLanguage == .korean ? .korean : .english))
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Button(L10n.text("unhide", languageManager.currentLanguage == .korean ? .korean : .english)) {
                showingUnhideAlert = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
        .alert(L10n.text("unhide_friend", languageManager.currentLanguage == .korean ? .korean : .english), isPresented: $showingUnhideAlert) {
            Button(L10n.text("cancel", languageManager.currentLanguage == .korean ? .korean : .english), role: .cancel) { }
            Button(L10n.text("unhide", languageManager.currentLanguage == .korean ? .korean : .english), role: .destructive) {
                unhideFriend()
            }
        } message: {
            Text(String(format: L10n.text("unhide_message", languageManager.currentLanguage == .korean ? .korean : .english), friendship.friendName))
        }
    }

    private func unhideFriend() {
        friendship.status = .accepted
        try? modelContext.save()
    }
}

// email validation helper
private func isValidEmail(_ email: String) -> Bool {
    let pattern = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
    return email.range(of: pattern, options: .regularExpression) != nil
}

// 간소화된 친구 검색 서비스
class FriendSearchService {
    static func searchUsers(by email: String) async throws -> [UserSearchResult] {
        // 성능 개선: 대기 시간을 0.3초로 단축
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3초 대기

        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidEmail(trimmed) else {
            return []
        }

        print("FriendSearchService: \(trimmed) 검색 중...")

        let mockResults = [
            UserSearchResult(
                id: UUID().uuidString,
                username: trimmed.components(separatedBy: "@").first ?? "user",
                displayName: trimmed.components(separatedBy: "@").first?.capitalized ?? "User",
                email: trimmed
            )
        ]

        if trimmed.contains("@") && trimmed.contains(".") {
            print("FriendSearchService: 검색 결과 반환")
            return mockResults
        } else {
            print("FriendSearchService: 유효하지 않은 이메일 형식")
            return []
        }
    }

    static func sendFriendRequest(from senderId: String, to receiverId: String) async throws -> Bool {
        print("FriendSearchService: 친구 요청 전송 중...")
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2초 대기
        print("FriendSearchService: 친구 요청 전송 완료")
        return true
    }
}

// 간소화된 사용자 검색 결과 데이터 모델
struct UserSearchResult: Identifiable {
    let id: String
    let username: String
    let displayName: String
    let email: String
}

extension Notification.Name {
    static let friendshipPendingCreated = Notification.Name("friendshipPendingCreated")
    static let friendsBadgeUpdated = Notification.Name("friendsBadgeUpdated")
}

