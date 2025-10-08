//
//  ChatView.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//

import SwiftUI
import Combine
import SwiftData
import PhotosUI
import Photos
import UniformTypeIdentifiers
import CoreLocation
import LinkPresentation
import UIKit
import Contacts
import NaturalLanguage

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var languageManager: LanguageManager

    let chatRoom: ChatRoom
    @State private var viewModel: ChatViewModel?
    @StateObject private var chatService: ChatService
    @FocusState private var isTextFieldFocused: Bool
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingPhotosPicker = false
    @State private var showingPhotosPermissionAlert = false
    @State private var showingDocumentPicker = false
    // @State private var showingMediaMenu = false  // Removed as per instructions
    @State private var reactionToMessage: Message?
    @State private var showingReactionPicker = false
    @State private var replyingToMessage: Message?
    @State private var editingMessage: Message?
    @State private var showingEditAlert = false
    @State private var editingText: String = ""
    @State private var inputText: String = ""

    // 필살기 기능 상태들
    @State private var emergencyButtonPressed = false
    @State private var emergencyTimer: Timer?
    @State private var emergencyCountdown = 3
    @State private var showingEmergencyAlert = false
    @State private var healthCondition: HealthCondition = .good
    @State private var showingHealthPicker = false
    @State private var aiSuggestedReplies: [String] = []
    @State private var showingAIReplies = false
    @State private var soundAmplificationMode = false
    @State private var showingExitConfirmation = false
    @State private var suspiciousLinkDetected = false
    @State private var linkToVerify: String?
    @State private var showingLocationPermissionAlert = false
    @State private var ignoredDomains: Set<String> = []
    @State private var showingReportAlert = false
    @State private var showingBlockAlert = false

    @State private var showingFriendProfile = false
    @State private var profileFriendship: Friendship?

    // 친구 추가 관련
    @State private var isFriend = false
    @State private var showingAddFriendAlert = false
    @State private var addFriendEmail = ""

    // 긴급 메시지 토글 상태
    @State private var isEmergencyMessage = false

    // AI/번역 설정 바인딩 (AppStorage)
    @AppStorage("aiSummaryEnabled") private var aiSummaryEnabled = false
    @AppStorage("aiSearchEnabled") private var aiSearchEnabled = true
    @AppStorage("aiAutoMeetingNotesEnabled") private var aiAutoMeetingNotesEnabled = false

    @AppStorage("translationEnabled") private var translationEnabled = false
    @AppStorage("translationAutoDetect") private var translationAutoDetect = true
    @AppStorage("translationTargetLanguage") private var translationTargetLanguage = "auto"
    @AppStorage("translationShowOriginal") private var translationShowOriginal = true

    // 검색 및 요약 상태
    @State private var searchText: String = ""
    @State private var showingSummarySheet = false
    @State private var summaryText: String = ""

    // 위치 서비스
    @StateObject private var locationManager = LocationManager()

    // 연락처 동기화
    @StateObject private var contactsSync = ContactsSyncService()
    @State private var showingContactsResult = false
    @State private var matchedUsers: [MatchedUser] = []
    @State private var showingContactsPermissionAlert = false

    enum HealthCondition: String, CaseIterable {
        case good = "좋음 😊"
        case normal = "보통 😐"
        case tired = "피곤 😴"
        case sick = "아파요 🤒"
    }

    // MARK: - Date Formatters (cached)
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeStyle = .short
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    private static let safeDomains: Set<String> = [
        "apple.com", "google.com", "naver.com", "daum.net", "kakao.com", "youtube.com", "icloud.com"
    ]

    init(chatRoom: ChatRoom, chatService: ChatService? = nil) {
        self.chatRoom = chatRoom

        // ChatService 초기화
        if let service = chatService {
            self._chatService = StateObject(wrappedValue: service)
        } else {
            // 임시 컨텍스트로 초기화, onAppear에서 실제 컨텍스트로 재설정
            let tempContext = (try? ModelContainer(for: Message.self).mainContext) ?? ModelContext(try! ModelContainer(for: Message.self))
            self._chatService = StateObject(wrappedValue: ChatService(modelContext: tempContext))
        }
    }

    private func openPhotosAttachment() {
        // If NSPhotoLibraryUsageDescription is missing, avoid calling PHPhotoLibrary APIs to prevent a crash; use PHPicker directly.
        let hasPhotoUsageDescription = Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryUsageDescription") != nil
        if !hasPhotoUsageDescription {
            showingPhotosPicker = true
            return
        }

        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            showingPhotosPicker = true
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        self.showingPhotosPicker = true
                    } else {
                        self.showingPhotosPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showingPhotosPermissionAlert = true
        @unknown default:
            showingPhotosPermissionAlert = true
        }
    }

    private func handlePhotoSelectionChange(_ newValue: PhotosPickerItem?) {
        guard let item = newValue else { return }
        Task {
            do {
                // Attempt to load the selected media as raw Data (works for images/videos via Transferable)
                if let data = try await item.loadTransferable(type: Data.self) {
                    // TODO: Integrate with your sending pipeline (e.g., via viewModel or chatService)
                    // Example: viewModel?.sendAttachment(data: data, fileName: "attachment")
                    print("Loaded selected photo/video, size: \(data.count) bytes")
                } else {
                    print("No transferable data found for selected item.")
                }
            } catch {
                print("Failed to load selected photo: \(error)")
            }
            await MainActor.run {
                // Clear selection so the same item can be picked again later
                selectedPhoto = nil
            }
        }
    }

    private func handleDocumentSelection(_ url: URL) {
        // Securely access the file selected via UIDocumentPicker (security-scoped URL)
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing { url.stopAccessingSecurityScopedResource() }
            // Dismiss the picker
            showingDocumentPicker = false
        }

        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .nameKey, .contentTypeKey])
            let fileName = resourceValues.name ?? url.lastPathComponent
            let fileSize = resourceValues.fileSize ?? 0
            let typeDescription = resourceValues.contentType?.description ?? "unknown"
            print("Picked document: \(fileName) (\(fileSize) bytes), type: \(typeDescription)")

            // TODO: Integrate with your sending pipeline if available.
            // Example:
            // try viewModel?.sendFile(at: url, fileName: fileName, contentType: resourceValues.contentType)

            // If you need to manage your own copy, uncomment and adjust:
            // let tempURL = FileManager.default.temporaryDirectory
            //     .appendingPathComponent(UUID().uuidString)
            //     .appendingPathExtension(url.pathExtension)
            // if FileManager.default.fileExists(atPath: tempURL.path) {
            //     try? FileManager.default.removeItem(at: tempURL)
            // }
            // try FileManager.default.copyItem(at: url, to: tempURL)
        } catch {
            print("Failed to read picked document: \(error)")
        }
    }

    private var baseScaffold: some View {
        VStack(spacing: 0) {
            ConnectionStatusView(chatService: chatService)
                .accessibilityLabel(localizedText("connection_status"))
                .accessibilityIdentifier("connectionStatus")

            mainContentView
        }
        .navigationTitle(chatRoom.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // 알림 토글 버튼
                    Button {
                        toggleChatNotifications()
                    } label: {
                        Image(systemName: chatRoom.notificationsEnabled ? "bell.fill" : "bell.slash.fill")
                            .foregroundColor(chatRoom.notificationsEnabled ? .appPrimary : .gray)
                    }
                    .accessibilityLabel(localizedText(chatRoom.notificationsEnabled ? "mute_notifications" : "unmute_notifications"))

                    // 친구가 아닌 경우 친구 추가 버튼 표시
                    if !isFriend && chatRoom.otherUserId != nil {
                        Button {
                            showingAddFriendAlert = true
                        } label: {
                            Image(systemName: "person.badge.plus")
                                .foregroundColor(.appPrimary)
                        }
                        .accessibilityLabel(localizedText("add_friend"))
                    }

                    Button {
                        openPhotosAttachment()
                    } label: {
                        Image(systemName: "paperclip")
                    }
                    .accessibilityLabel(localizedText("attach"))

                    Button {
                        showingFriendProfile = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel(localizedText("view_profile"))
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear {
            setupViewModelIfNeeded()
            checkIfFriend()
            if let saved = UserDefaults.standard.array(forKey: "ignoredDomains") as? [String] {
                ignoredDomains = Set(saved)
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            handlePhotoSelectionChange(newValue)
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker { url in
                self.handleDocumentSelection(url)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingReactionPicker) {
            ReactionPickerView(message: reactionToMessage) { emoji in
                if let message = reactionToMessage {
                    addReaction(emoji: emoji, to: message)
                }
                showingReactionPicker = false
            }
            .presentationDetents([.height(200)])
            .presentationDragIndicator(.visible)
        }
    }

    var body: some View {
        baseScaffold
            .modifier(EditMessageAlertModifier(
                isPresented: $showingEditAlert,
                editingText: $editingText,
                editingMessage: $editingMessage,
                onSave: { message, newText in
                    viewModel?.editMessage(message, newText: newText)
                }
            ))
            .modifier(EmergencyAlertModifier(isPresented: $showingEmergencyAlert))
            .modifier(LocationPermissionAlertModifier(
                isPresented: $showingLocationPermissionAlert,
                openSettings: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
            ))
            .modifier(ReportAlertModifier(isPresented: $showingReportAlert, name: chatRoom.name))
            .modifier(BlockAlertModifier(isPresented: $showingBlockAlert, name: chatRoom.name))
            .modifier(SuspiciousLinkAlertModifier(
                isPresented: $suspiciousLinkDetected,
                linkToVerify: $linkToVerify,
                ignoredDomains: $ignoredDomains,
                openURL: { url in openURL(url) }
            ))
            .alert(localizedText("contacts_permission_title"), isPresented: $showingContactsPermissionAlert) {
                Button(localizedText("cancel"), role: .cancel) {}
                Button(localizedText("open_settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            } message: {
                Text(localizedText("contacts_permission_message"))
            }
            .alert(localizedText("photo_permission_title"), isPresented: $showingPhotosPermissionAlert) {
                Button(localizedText("cancel"), role: .cancel) {}
                Button(localizedText("open_settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
            } message: {
                Text(localizedText("photo_permission_message"))
            }
            .alert(localizedText("add_friend_title"), isPresented: $showingAddFriendAlert) {
                Button(localizedText("cancel"), role: .cancel) {}
                Button(localizedText("add")) {
                    addFriendToChatRoom()
                }
            } message: {
                Text(String(format: localizedText("add_friend_message"), chatRoom.name))
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(localizedText("chat_screen"))
            .accessibilityHint(String(format: localizedText("chat_screen_hint"), chatRoom.name))
            .accessibilityIdentifier("chatView")
            .onDisappear {
                viewModel?.stopTyping()
                emergencyTimer?.invalidate()
                emergencyTimer = nil
            }
            // 다이나믹 타입 지원
            .dynamicTypeSize(dynamicTypeSize.isAccessibilitySize ? .accessibility3 : dynamicTypeSize)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: localizedText("search_conversation"))
            .sheet(isPresented: $showingSummarySheet) {
                NavigationStack {
                    ScrollView {
                        Text(summaryText)
                            .font(.body)
                            .foregroundColor(.primary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .navigationTitle(localizedText("conversation_summary"))
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(localizedText("done")) { showingSummarySheet = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingFriendProfile) {
                if let friendship = profileFriendship {
                    FriendProfileView(friendship: friendship)
                } else {
                    MiniProfileSheet(name: chatRoom.name, symbol: chatRoom.profileImage)
                        .environmentObject(languageManager)
                }
            }
            .sheet(isPresented: $showingContactsResult) {
                NavigationStack {
                    List(matchedUsers) { user in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.displayName).font(.body)
                            Text(localizedText("match_prefix") + user.matchedBy)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .navigationTitle(localizedText("contacts_match_results"))
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(localizedText("close")) { showingContactsResult = false }
                        }
                    }
                }
            }
            .photosPicker(isPresented: $showingPhotosPicker, selection: $selectedPhoto, matching: .any(of: [.images, .videos]))
    }

    @ViewBuilder
    private var mainContentView: some View {
        if let viewModel = viewModel {
            chatContentView(viewModel: viewModel)
        } else {
            ProgressView("Loading...")
        }
    }

    @ViewBuilder
    private func chatContentView(viewModel: ChatViewModel) -> some View {
        VStack(spacing: 0) {
            messagesScrollView(viewModel: viewModel)
            Divider()
            messageInputView(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private func messagesScrollView(viewModel: ChatViewModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    messagesList(viewModel: viewModel)

                    if viewModel.otherUserTyping {
                        TypingIndicatorView(senderName: chatRoom.name)
                            .id("typing_indicator")
                            .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                            .accessibilityLabel(String(format: localizedText("typing_indicator"), chatRoom.name))
                            .accessibilityIdentifier("typingIndicator")
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .accessibilityLabel(localizedText("message_list"))
            .accessibilityHint(localizedText("scroll_messages_hint"))
            .accessibilityIdentifier("messagesScrollView")
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottomInline(proxy: proxy)
            }
            .onChange(of: viewModel.otherUserTyping) { _, isTyping in
                if isTyping {
                    scrollToBottomInline(proxy: proxy)
                }
            }
            .onTapGesture {
                // 스크롤뷰 탭하면 키보드 숨기기
                isTextFieldFocused = false
            }
        }
    }

    private func scrollToBottomInline(proxy: ScrollViewProxy) {
        let animation: Animation = reduceMotion ?
            .easeInOut(duration: 0.1) :
            .spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.2)

        if let lastMessage = viewModel?.messages.last {
            withAnimation(animation) {
                proxy.scrollTo(lastMessage.id, anchor: UnitPoint.bottom)
            }
        } else if viewModel?.otherUserTyping == true {
            withAnimation(animation) {
                proxy.scrollTo("typing_indicator", anchor: UnitPoint.bottom)
            }
        }
    }

    @ViewBuilder
    private func messagesList(viewModel: ChatViewModel) -> some View {
        ForEach(filteredMessages(viewModel: viewModel), id: \.id) { message in
            MessageBubbleView(
                message: message,
                avatarSymbolName: chatRoom.profileImage,
                onAvatarTap: { openFriendProfile() }
            )
                .id(message.id)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("message_\(message.id)")
                // 메시지별 접근성 정보 추가
                .accessibilityLabel(accessibilityLabelForMessage(message))
                .accessibilityHint("두 번 탭하여 메시지 옵션을 확인할 수 있습니다")
                .onLongPressGesture {
                    showReactionPicker(for: message)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button(localizedText("reply")) {
                        replyingToMessage = message
                        isTextFieldFocused = true

                        // 햅틱 피드백
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                    .tint(.appPrimary)
                }
                .contextMenu {
                    if message.messageType == .text {
                        Button(localizedText("copy"), systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = message.text
                            UIAccessibility.post(notification: .announcement, argument: "메시지를 복사했습니다")
                        }
                    }
                    Button(localizedText("reply"), systemImage: "arrowshape.turn.up.left") {
                        replyingToMessage = message
                        isTextFieldFocused = true
                    }
                    Button(localizedText("add_reaction"), systemImage: "face.smiling") {
                        showReactionPicker(for: message)
                    }
                    if message.isFromCurrentUser {
                        Button(localizedText("edit"), systemImage: "pencil") {
                            startEditingMessage(message)
                        }
                        Button(localizedText("delete"), systemImage: "trash", role: .destructive) {
                            deleteMessage(message)
                        }
                    }
                    if !message.isFromCurrentUser {
                        Button(localizedText("report"), systemImage: "exclamationmark.bubble") {
                            showingReportAlert = true
                        }
                        Button(localizedText("block"), systemImage: "hand.raised") {
                            showingBlockAlert = true
                        }
                    }
                }
            if message.messageType == .text, let url = firstURL(in: message.text) {
                LinkPreviewView(url: url)
                    .frame(maxWidth: .infinity, alignment: message.isFromCurrentUser ? Alignment.trailing : Alignment.leading)
                    .padding(.horizontal, 2)
            }
            if !message.isFromCurrentUser && message.messageType == .text && shouldShowTranslation(for: message.text) {
                TranslatedTextView(
                    text: message.text,
                    autoDetect: translationAutoDetect,
                    target: effectiveTargetLanguage(for: message.text),
                    showOriginal: translationShowOriginal
                )
                .frame(maxWidth: .infinity, alignment: message.isFromCurrentUser ? .trailing : .leading)
                .padding(.horizontal, 2)
                .environmentObject(languageManager)
            }
        }
    }

    private func containsHangul(_ text: String) -> Bool {
        return text.unicodeScalars.contains { scalar in
            let value = scalar.value
            return (0xAC00...0xD7A3).contains(value) // Hangul Syllables
        }
    }

    private func detectLanguageCode(for text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        if let lang = recognizer.dominantLanguage {
            return normalizeLanguageCode(lang.rawValue.lowercased())
        }
        return nil
    }

    private func normalizeLanguageCode(_ code: String) -> String {
        switch code {
        case "zh-hans", "zh_cn", "zh": return "zh-Hans"
        case "zh-hant", "zh_tw": return "zh-Hant"
        default: return code
        }
    }

    private func appLanguageCode() -> String {
        return languageManager.currentLanguage == .korean ? "ko" : "en"
    }

    private func shouldShowTranslation(for text: String) -> Bool {
        // Only show translation if user explicitly enabled it
        guard translationEnabled else { return false }

        // Compare detected source language with target
        let source = detectLanguageCode(for: text) ?? ""
        let target = effectiveTargetLanguage(for: text).lowercased()
        if !source.isEmpty {
            return source != target
        } else {
            // Fallback heuristic when detection is unavailable
            if languageManager.currentLanguage != .korean && containsHangul(text) { return true }
            return false
        }
    }

    private func filteredMessages(viewModel: ChatViewModel) -> [Message] {
        guard aiSearchEnabled, !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return viewModel.messages
        }
        let query = searchText.lowercased()
        return viewModel.messages.filter { msg in
            switch msg.messageType {
            case .text, .file:
                return msg.text.lowercased().contains(query)
            case .image, .audio:
                return false
            case .deleted:
                return false
            }
        }
    }

    private func effectiveTargetLanguage(for text: String) -> String {
        let target = translationTargetLanguage.lowercased()
        if target != "auto" { return target }
        // Auto: use app language code as the target language
        return appLanguageCode()
    }

    // MARK: - 타임락(근무시간) 헬퍼
    private func isWithinWorkingHours(for room: ChatRoom, now: Date = Date()) -> Bool {
        // 조직방이 아니면 항상 가능
        guard room.isOrganizationRoom else { return true }
        let tz = TimeZone(identifier: room.timeZoneIdentifier) ?? .current
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let comps = cal.dateComponents([.weekday, .hour, .minute], from: now)
        guard let weekday = comps.weekday, let hour = comps.hour, let minute = comps.minute else { return true }
        // 요일 체크
        if !room.workingDays.contains(weekday) { return false }
        // 시간 범위 체크
        let start = room.workStartHour * 60 + room.workStartMinute
        let end = room.workEndHour * 60 + room.workEndMinute
        let current = hour * 60 + minute
        return current >= start && current < end
    }

    private func setupViewModelIfNeeded() {
        // Bind ChatService to the real ModelContext so its connection can start.
        // ChatService starts its connection the first time a proper modelContext is set (via didSet).
        chatService.modelContext = modelContext

        // Initialize the ViewModel once and reuse it.
        if viewModel == nil {
            let vm = ChatViewModel(modelContext: modelContext, chatRoom: chatRoom, chatService: chatService)
            self.viewModel = vm
            // Optionally kick off online status checks.
            vm.checkOnlineStatus()
        } else {
            // Ensure messages are up to date if returning to this view.
            Task {
                await viewModel?.loadMessages()
            }
        }
    }

    // MARK: - Friend Management

    private func checkIfFriend() {
        guard let otherUserId = chatRoom.otherUserId else {
            isFriend = true // 조직방이거나 상대방 정보 없으면 친구 추가 버튼 안 보임
            return
        }

        let descriptor = FetchDescriptor<Friendship>(
            predicate: #Predicate { friendship in
                friendship.friendId == otherUserId && friendship.status.rawValue == "accepted"
            }
        )

        do {
            let friendships = try modelContext.fetch(descriptor)
            isFriend = !friendships.isEmpty
        } catch {
            print("❌ [ChatView] Failed to check friendship: \(error)")
            isFriend = false
        }
    }

    private func addFriendToChatRoom() {
        guard let otherUserId = chatRoom.otherUserId,
              let otherUserEmail = chatRoom.otherUserEmail,
              let currentUserId = getCurrentUserId() else {
            print("❌ [ChatView] Missing user information for friend request")
            return
        }

        let friendship = Friendship(
            userId: currentUserId,
            friendId: otherUserId,
            friendName: chatRoom.name,
            friendEmail: otherUserEmail,
            status: .pending
        )

        modelContext.insert(friendship)

        do {
            try modelContext.save()
            print("✅ [ChatView] Friend request sent to \(chatRoom.name)")
            // 친구 추가 후 상태 업데이트
            isFriend = true
        } catch {
            print("❌ [ChatView] Failed to send friend request: \(error)")
        }
    }

    private func getCurrentUserId() -> String? {
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.isCurrentUser == true }
        )
        do {
            return try modelContext.fetch(descriptor).first?.id.uuidString
        } catch {
            print("❌ [ChatView] Failed to get current user: \(error)")
            return nil
        }
    }

    private func toggleChatNotifications() {
        chatRoom.notificationsEnabled.toggle()
        try? modelContext.save()
        print("🔔 [ChatView] Notifications \(chatRoom.notificationsEnabled ? "enabled" : "disabled") for \(chatRoom.name)")
    }

    // MARK: - Message Input View
    @ViewBuilder
    private func messageInputView(viewModel: ChatViewModel) -> some View {
        VStack(spacing: 0) {
            if let replyingTo = replyingToMessage {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(format: localizedText("replying_to"), replyingTo.isFromCurrentUser ? localizedText("me") : chatRoom.name))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(replyingTo.text)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button(localizedText("cancel")) {
                        replyingToMessage = nil
                    }
                    .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemGroupedBackground))
            }

            HStack(spacing: 12) {
                TextField(localizedText("message_input_placeholder"), text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        sendMessage(viewModel: viewModel)
                    }

                Button {
                    sendMessage(viewModel: viewModel)
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.appPrimary)
                        .clipShape(Circle())
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }

    private func sendMessage(viewModel: ChatViewModel) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Pass the text and reply state to the ViewModel, then send
        viewModel.newMessageText = text
        if let replying = replyingToMessage {
            viewModel.setReplyMessage(replying)
        }
        viewModel.sendMessage()

        // Clear local UI states
        inputText = ""
        replyingToMessage = nil
        isTextFieldFocused = false
    }

    // MARK: - Helper Functions
    private func openFriendProfile() {
        showingFriendProfile = true
    }

    private func accessibilityLabelForMessage(_ message: Message) -> String {
        let sender = message.isFromCurrentUser ? localizedText("me") : chatRoom.name
        let time = Self.timeFormatter.string(from: message.timestamp)
        return "\(sender): \(message.text), \(time)"
    }

    private func showReactionPicker(for message: Message) {
        reactionToMessage = message
        showingReactionPicker = true
    }

    private func startEditingMessage(_ message: Message) {
        editingMessage = message
        editingText = message.text
        showingEditAlert = true
    }

    private func deleteMessage(_ message: Message) {
        viewModel?.deleteMessage(message)
    }

    private func firstURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = detector?.matches(in: text, options: [], range: range)
        return matches?.first?.url
    }

    // MARK: - Reactions
    private func addReaction(emoji: String, to message: Message) {
        // TODO: Integrate with ChatViewModel/ChatService to persist reactions
        print("Add reaction \(emoji) to message \(message.id)")
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        UIAccessibility.post(notification: .announcement, argument: "반응 \(emoji)를 추가했습니다")
    }

    private func localizedText(_ key: String) -> String {
        let isKorean = languageManager.currentLanguage == .korean

        switch key {
        case "cancel": return isKorean ? "취소" : "Cancel"
        case "save": return isKorean ? "저장" : "Save"
        case "ok": return isKorean ? "확인" : "OK"
        case "done": return isKorean ? "완료" : "Done"
        case "close": return isKorean ? "닫기" : "Close"
        case "delete": return isKorean ? "삭제" : "Delete"
        case "edit": return isKorean ? "편집" : "Edit"
        case "add": return isKorean ? "추가" : "Add"
        case "search": return isKorean ? "검색" : "Search"
        case "settings": return isKorean ? "설정" : "Settings"
        case "profile": return isKorean ? "프로필" : "Profile"
        case "logout": return isKorean ? "로그아웃" : "Sign Out"
        case "signin": return isKorean ? "로그인" : "Sign In"
        case "signup": return isKorean ? "회원가입" : "Sign Up"
        case "chat": return isKorean ? "채팅" : "Chat"
        case "message": return isKorean ? "메시지" : "Message"
        case "message_input_placeholder": return isKorean ? "메시지 입력" : "Type a message"
        case "send": return isKorean ? "전송" : "Send"
        case "typing": return isKorean ? "입력 중" : "Typing"
        case "online": return isKorean ? "온라인" : "Online"
        case "offline": return isKorean ? "오프라인" : "Offline"
        case "friends": return isKorean ? "친구" : "Friends"
        case "add_friend": return isKorean ? "친구 추가" : "Add Friend"
        case "friend_request": return isKorean ? "친구 요청" : "Friend Request"
        case "accept": return isKorean ? "수락" : "Accept"
        case "reject": return isKorean ? "거절" : "Reject"
        case "block": return isKorean ? "차단" : "Block"
        case "unblock": return isKorean ? "차단 해제" : "Unblock"
        case "error_occurred": return isKorean ? "오류가 발생했습니다" : "An error occurred"
        case "network_error": return isKorean ? "네트워크 오류" : "Network Error"
        case "try_again": return isKorean ? "다시 시도해주세요" : "Please try again"
        case "notification": return isKorean ? "알림" : "Notification"
        case "permission_required": return isKorean ? "권한이 필요합니다" : "Permission Required"
        case "open_settings": return isKorean ? "설정 열기" : "Open Settings"
        case "contacts_permission_title": return isKorean ? "연락처 접근 권한 필요" : "Contacts Permission Required"
        case "contacts_permission_message": return isKorean ? "친구를 찾기 위해 연락처 접근 권한이 필요합니다. 설정에서 허용해 주세요." : "Contacts access is required to find friends. Please allow it in Settings."
        case "photo_permission_title": return isKorean ? "사진 접근 권한 필요" : "Photos Permission Required"
        case "photo_permission_message": return isKorean ? "사진과 동영상을 첨부하려면 사진 접근 권한이 필요합니다. 설정에서 허용해 주세요." : "Photos access is required to attach images and videos. Please allow it in Settings."
        case "chat_screen": return isKorean ? "채팅 화면" : "Chat Screen"
        case "chat_screen_hint": return isKorean ? "%@과의 채팅 화면입니다" : "Chat with %@"
        case "message_list": return isKorean ? "메시지 목록" : "Messages"
        case "scroll_messages_hint": return isKorean ? "위아래로 스크롤하여 메시지를 확인할 수 있습니다" : "Scroll up and down to review messages"
        case "contacts_match_results": return isKorean ? "연락처 매칭 결과" : "Contacts Match Results"
        case "edited_message_announcement": return isKorean ? "메시지를 편집했습니다" : "Message edited"
        case "edit_message_prompt": return isKorean ? "메시지를 수정하세요" : "Edit your message"
        case "location_permission_title": return isKorean ? "위치 권한 필요" : "Location Permission Required"
        case "location_permission_message": return isKorean ? "긴급 호출을 위해 위치 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요." : "Location access is required for emergency calls. Please allow it in Settings."
        case "reported_user_message": return isKorean ? "%@을(를) 신고했습니다" : "Reported %@"
        case "blocked_user_message": return isKorean ? "%@을(를) 차단했습니다" : "Blocked %@"
        case "suspicious_link_detected": return isKorean ? "의심스러운 링크가 감지되었습니다" : "A suspicious link was detected"
        case "organization_room": return isKorean ? "조직방" : "Organization Room"
        case "enable_org_room": return isKorean ? "조직방 활성화" : "Enable Organization Room"
        case "org_name_optional": return isKorean ? "조직명(선택)" : "Organization Name (Optional)"
        case "working_hours": return isKorean ? "근무 시간" : "Working Hours"
        case "working_hours_footer": return isKorean ? "간단히 요일과 시작/종료 시간을 설정하세요" : "Quickly set weekdays and start/end times"
        case "profile_info_unavailable": return isKorean ? "프로필 정보를 불러올 수 없습니다" : "Profile information is unavailable"
        case "search_conversation": return isKorean ? "대화 검색" : "Search conversation"
        default: return key
        }
    }
}

// MARK: - Alert Modifiers (to reduce type-checking complexity)
struct EditMessageAlertModifier: ViewModifier {
    @EnvironmentObject private var languageManager: LanguageManager

    @Binding var isPresented: Bool
    @Binding var editingText: String
    @Binding var editingMessage: Message?
    let onSave: (Message, String) -> Void

    func body(content: Content) -> some View {
        content.alert(localizedText("edit_message"), isPresented: $isPresented) {
            TextField(localizedText("message"), text: $editingText)
            Button(localizedText("cancel"), role: .cancel) {
                editingMessage = nil
                editingText = ""
            }
            Button(localizedText("save")) {
                if let message = editingMessage {
                    let newText = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !newText.isEmpty {
                        onSave(message, newText)
                    }
                }
                editingMessage = nil
                editingText = ""
                UIAccessibility.post(notification: .announcement, argument: localizedText("edited_message_announcement"))
            }
        } message: {
            Text(localizedText("edit_message_prompt"))
        }
    }

    private func localizedText(_ key: String) -> String {
        let isKorean = languageManager.currentLanguage == .korean

        switch key {
        case "cancel": return isKorean ? "취소" : "Cancel"
        case "save": return isKorean ? "저장" : "Save"
        case "ok": return isKorean ? "확인" : "OK"
        case "done": return isKorean ? "완료" : "Done"
        case "close": return isKorean ? "닫기" : "Close"
        case "delete": return isKorean ? "삭제" : "Delete"
        case "edit": return isKorean ? "편집" : "Edit"
        case "add": return isKorean ? "추가" : "Add"
        case "search": return isKorean ? "검색" : "Search"
        case "settings": return isKorean ? "설정" : "Settings"
        case "profile": return isKorean ? "프로필" : "Profile"
        case "logout": return isKorean ? "로그아웃" : "Sign Out"
        case "signin": return isKorean ? "로그인" : "Sign In"
        case "signup": return isKorean ? "회원가입" : "Sign Up"
        case "chat": return isKorean ? "채팅" : "Chat"
        case "message": return isKorean ? "메시지" : "Message"
        case "message_input_placeholder": return isKorean ? "메시지 입력" : "Type a message"
        case "send": return isKorean ? "전송" : "Send"
        case "typing": return isKorean ? "입력 중" : "Typing"
        case "online": return isKorean ? "온라인" : "Online"
        case "offline": return isKorean ? "오프라인" : "Offline"
        case "friends": return isKorean ? "친구" : "Friends"
        case "add_friend": return isKorean ? "친구 추가" : "Add Friend"
        case "friend_request": return isKorean ? "친구 요청" : "Friend Request"
        case "accept": return isKorean ? "수락" : "Accept"
        case "reject": return isKorean ? "거절" : "Reject"
        case "block": return isKorean ? "차단" : "Block"
        case "unblock": return isKorean ? "차단 해제" : "Unblock"
        case "error_occurred": return isKorean ? "오류가 발생했습니다" : "An error occurred"
        case "network_error": return isKorean ? "네트워크 오류" : "Network Error"
        case "try_again": return isKorean ? "다시 시도해주세요" : "Please try again"
        case "notification": return isKorean ? "알림" : "Notification"
        case "permission_required": return isKorean ? "권한이 필요합니다" : "Permission Required"
        case "open_settings": return isKorean ? "설정 열기" : "Open Settings"
        case "contacts_permission_title": return isKorean ? "연락처 접근 권한 필요" : "Contacts Permission Required"
        case "contacts_permission_message": return isKorean ? "친구를 찾기 위해 연락처 접근 권한이 필요합니다. 설정에서 허용해 주세요." : "Contacts access is required to find friends. Please allow it in Settings."
        case "photo_permission_title": return isKorean ? "사진 접근 권한 필요" : "Photos Permission Required"
        case "photo_permission_message": return isKorean ? "사진과 동영상을 첨부하려면 사진 접근 권한이 필요합니다. 설정에서 허용해 주세요." : "Photos access is required to attach images and videos. Please allow it in Settings."
        case "chat_screen": return isKorean ? "채팅 화면" : "Chat Screen"
        case "chat_screen_hint": return isKorean ? "%@과의 채팅 화면입니다" : "Chat with %@"
        case "message_list": return isKorean ? "메시지 목록" : "Messages"
        case "scroll_messages_hint": return isKorean ? "위아래로 스크롤하여 메시지를 확인할 수 있습니다" : "Scroll up and down to review messages"
        case "contacts_match_results": return isKorean ? "연락처 매칭 결과" : "Contacts Match Results"
        case "edited_message_announcement": return isKorean ? "메시지를 편집했습니다" : "Message edited"
        case "edit_message_prompt": return isKorean ? "메시지를 수정하세요" : "Edit your message"
        case "location_permission_title": return isKorean ? "위치 권한 필요" : "Location Permission Required"
        case "location_permission_message": return isKorean ? "긴급 호출을 위해 위치 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요." : "Location access is required for emergency calls. Please allow it in Settings."
        case "reported_user_message": return isKorean ? "%@을(를) 신고했습니다" : "Reported %@"
        case "blocked_user_message": return isKorean ? "%@을(를) 차단했습니다" : "Blocked %@"
        case "suspicious_link_detected": return isKorean ? "의심스러운 링크가 감지되었습니다" : "A suspicious link was detected"
        case "organization_room": return isKorean ? "조직방" : "Organization Room"
        case "enable_org_room": return isKorean ? "조직방 활성화" : "Enable Organization Room"
        case "org_name_optional": return isKorean ? "조직명(선택)" : "Organization Name (Optional)"
        case "working_hours": return isKorean ? "근무 시간" : "Working Hours"
        case "working_hours_footer": return isKorean ? "간단히 요일과 시작/종료 시간을 설정하세요" : "Quickly set weekdays and start/end times"
        case "profile_info_unavailable": return isKorean ? "프로필 정보를 불러올 수 없습니다" : "Profile information is unavailable"
        default: return key
        }
    }
}

struct EmergencyAlertModifier: ViewModifier {
    @EnvironmentObject private var languageManager: LanguageManager

    @Binding var isPresented: Bool
    func body(content: Content) -> some View {
        content.alert(localizedText("emergency_call"), isPresented: $isPresented) {
            Button(localizedText("ok")) {}
        } message: {
            Text(localizedText("emergency_started"))
        }
    }

    private func localizedText(_ key: String) -> String {
        let isKorean = languageManager.currentLanguage == .korean

        switch key {
        case "cancel": return isKorean ? "취소" : "Cancel"
        case "save": return isKorean ? "저장" : "Save"
        case "ok": return isKorean ? "확인" : "OK"
        case "done": return isKorean ? "완료" : "Done"
        case "close": return isKorean ? "닫기" : "Close"
        case "delete": return isKorean ? "삭제" : "Delete"
        case "edit": return isKorean ? "편집" : "Edit"
        case "add": return isKorean ? "추가" : "Add"
        case "search": return isKorean ? "검색" : "Search"
        case "settings": return isKorean ? "설정" : "Settings"
        case "profile": return isKorean ? "프로필" : "Profile"
        case "logout": return isKorean ? "로그아웃" : "Sign Out"
        case "signin": return isKorean ? "로그인" : "Sign In"
        case "signup": return isKorean ? "회원가입" : "Sign Up"
        case "chat": return isKorean ? "채팅" : "Chat"
        case "message": return isKorean ? "메시지" : "Message"
        case "message_input_placeholder": return isKorean ? "메시지 입력" : "Type a message"
        case "send": return isKorean ? "전송" : "Send"
        case "typing": return isKorean ? "입력 중" : "Typing"
        case "online": return isKorean ? "온라인" : "Online"
        case "offline": return isKorean ? "오프라인" : "Offline"
        case "friends": return isKorean ? "친구" : "Friends"
        case "add_friend": return isKorean ? "친구 추가" : "Add Friend"
        case "friend_request": return isKorean ? "친구 요청" : "Friend Request"
        case "accept": return isKorean ? "수락" : "Accept"
        case "reject": return isKorean ? "거절" : "Reject"
        case "block": return isKorean ? "차단" : "Block"
        case "unblock": return isKorean ? "차단 해제" : "Unblock"
        case "error_occurred": return isKorean ? "오류가 발생했습니다" : "An error occurred"
        case "network_error": return isKorean ? "네트워크 오류" : "Network Error"
        case "try_again": return isKorean ? "다시 시도해주세요" : "Please try again"
        case "notification": return isKorean ? "알림" : "Notification"
        case "permission_required": return isKorean ? "권한이 필요합니다" : "Permission Required"
        case "open_settings": return isKorean ? "설정 열기" : "Open Settings"
        case "contacts_permission_title": return isKorean ? "연락처 접근 권한 필요" : "Contacts Permission Required"
        case "contacts_permission_message": return isKorean ? "친구를 찾기 위해 연락처 접근 권한이 필요합니다. 설정에서 허용해 주세요." : "Contacts access is required to find friends. Please allow it in Settings."
        case "photo_permission_title": return isKorean ? "사진 접근 권한 필요" : "Photos Permission Required"
        case "photo_permission_message": return isKorean ? "사진과 동영상을 첨부하려면 사진 접근 권한이 필요합니다. 설정에서 허용해 주세요." : "Photos access is required to attach images and videos. Please allow it in Settings."
        case "chat_screen": return isKorean ? "채팅 화면" : "Chat Screen"
        case "chat_screen_hint": return isKorean ? "%@과의 채팅 화면입니다" : "Chat with %@"
        case "message_list": return isKorean ? "메시지 목록" : "Messages"
        case "scroll_messages_hint": return isKorean ? "위아래로 스크롤하여 메시지를 확인할 수 있습니다" : "Scroll up and down to review messages"
        case "contacts_match_results": return isKorean ? "연락처 매칭 결과" : "Contacts Match Results"
        case "edited_message_announcement": return isKorean ? "메시지를 편집했습니다" : "Message edited"
        case "edit_message_prompt": return isKorean ? "메시지를 수정하세요" : "Edit your message"
        case "location_permission_title": return isKorean ? "위치 권한 필요" : "Location Permission Required"
        case "location_permission_message": return isKorean ? "긴급 호출을 위해 위치 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요." : "Location access is required for emergency calls. Please allow it in Settings."
        case "reported_user_message": return isKorean ? "%@을(를) 신고했습니다" : "Reported %@"
        case "blocked_user_message": return isKorean ? "%@을(를) 차단했습니다" : "Blocked %@"
        case "suspicious_link_detected": return isKorean ? "의심스러운 링크가 감지되었습니다" : "A suspicious link was detected"
        case "organization_room": return isKorean ? "조직방" : "Organization Room"
        case "enable_org_room": return isKorean ? "조직방 활성화" : "Enable Organization Room"
        case "org_name_optional": return isKorean ? "조직명(선택)" : "Organization Name (Optional)"
        case "working_hours": return isKorean ? "근무 시간" : "Working Hours"
        case "working_hours_footer": return isKorean ? "간단히 요일과 시작/종료 시간을 설정하세요" : "Quickly set weekdays and start/end times"
        case "profile_info_unavailable": return isKorean ? "프로필 정보를 불러올 수 없습니다" : "Profile information is unavailable"
        default: return key
        }
    }
}

struct LocationPermissionAlertModifier: ViewModifier {
    @EnvironmentObject private var languageManager: LanguageManager

    @Binding var isPresented: Bool
    let openSettings: () -> Void
    func body(content: Content) -> some View {
        content.alert(localizedText("location_permission_title"), isPresented: $isPresented) {
            Button(localizedText("cancel"), role: .cancel) {}
            Button(localizedText("open_settings")) { openSettings() }
        } message: {
            Text(localizedText("location_permission_message"))
        }
    }

    private func localizedText(_ key: String) -> String {
        let isKorean = languageManager.currentLanguage == .korean

        switch key {
        case "cancel": return isKorean ? "취소" : "Cancel"
        case "save": return isKorean ? "저장" : "Save"
        case "ok": return isKorean ? "확인" : "OK"
        case "done": return isKorean ? "완료" : "Done"
        case "close": return isKorean ? "닫기" : "Close"
        case "delete": return isKorean ? "삭제" : "Delete"
        case "edit": return isKorean ? "편집" : "Edit"
        case "add": return isKorean ? "추가" : "Add"
        case "search": return isKorean ? "검색" : "Search"
        case "settings": return isKorean ? "설정" : "Settings"
        case "profile": return isKorean ? "프로필" : "Profile"
        case "logout": return isKorean ? "로그아웃" : "Sign Out"
        case "signin": return isKorean ? "로그인" : "Sign In"
        case "signup": return isKorean ? "회원가입" : "Sign Up"
        case "chat": return isKorean ? "채팅" : "Chat"
        case "message": return isKorean ? "메시지" : "Message"
        case "message_input_placeholder": return isKorean ? "메시지 입력" : "Type a message"
        case "send": return isKorean ? "전송" : "Send"
        case "typing": return isKorean ? "입력 중" : "Typing"
        case "online": return isKorean ? "온라인" : "Online"
        case "offline": return isKorean ? "오프라인" : "Offline"
        case "friends": return isKorean ? "친구" : "Friends"
        case "add_friend": return isKorean ? "친구 추가" : "Add Friend"
        case "friend_request": return isKorean ? "친구 요청" : "Friend Request"
        case "accept": return isKorean ? "수락" : "Accept"
        case "reject": return isKorean ? "거절" : "Reject"
        case "block": return isKorean ? "차단" : "Block"
        case "unblock": return isKorean ? "차단 해제" : "Unblock"
        case "error_occurred": return isKorean ? "오류가 발생했습니다" : "An error occurred"
        case "network_error": return isKorean ? "네트워크 오류" : "Network Error"
        case "try_again": return isKorean ? "다시 시도해주세요" : "Please try again"
        case "notification": return isKorean ? "알림" : "Notification"
        case "permission_required": return isKorean ? "권한이 필요합니다" : "Permission Required"
        case "open_settings": return isKorean ? "설정 열기" : "Open Settings"
        case "contacts_permission_title": return isKorean ? "연락처 접근 권한 필요" : "Contacts Permission Required"
        case "contacts_permission_message": return isKorean ? "친구를 찾기 위해 연락처 접근 권한이 필요합니다. 설정에서 허용해 주세요." : "Contacts access is required to find friends. Please allow it in Settings."
        case "photo_permission_title": return isKorean ? "사진 접근 권한 필요" : "Photos Permission Required"
        case "photo_permission_message": return isKorean ? "사진과 동영상을 첨부하려면 사진 접근 권한이 필요합니다. 설정에서 허용해 주세요." : "Photos access is required to attach images and videos. Please allow it in Settings."
        case "chat_screen": return isKorean ? "채팅 화면" : "Chat Screen"
        case "chat_screen_hint": return isKorean ? "%@과의 채팅 화면입니다" : "Chat with %@"
        case "message_list": return isKorean ? "메시지 목록" : "Messages"
        case "scroll_messages_hint": return isKorean ? "위아래로 스크롤하여 메시지를 확인할 수 있습니다" : "Scroll up and down to review messages"
        case "contacts_match_results": return isKorean ? "연락처 매칭 결과" : "Contacts Match Results"
        case "edited_message_announcement": return isKorean ? "메시지를 편집했습니다" : "Message edited"
        case "edit_message_prompt": return isKorean ? "메시지를 수정하세요" : "Edit your message"
        case "location_permission_title": return isKorean ? "위치 권한 필요" : "Location Permission Required"
        case "location_permission_message": return isKorean ? "긴급 호출을 위해 위치 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요." : "Location access is required for emergency calls. Please allow it in Settings."
        case "reported_user_message": return isKorean ? "%@을(를) 신고했습니다" : "Reported %@"
        case "blocked_user_message": return isKorean ? "%@을(를) 차단했습니다" : "Blocked %@"
        case "suspicious_link_detected": return isKorean ? "의심스러운 링크가 감지되었습니다" : "A suspicious link was detected"
        case "organization_room": return isKorean ? "조직방" : "Organization Room"
        case "enable_org_room": return isKorean ? "조직방 활성화" : "Enable Organization Room"
        case "org_name_optional": return isKorean ? "조직명(선택)" : "Organization Name (Optional)"
        case "working_hours": return isKorean ? "근무 시간" : "Working Hours"
        case "working_hours_footer": return isKorean ? "간단히 요일과 시작/종료 시간을 설정하세요" : "Quickly set weekdays and start/end times"
        case "profile_info_unavailable": return isKorean ? "프로필 정보를 불러올 수 없습니다" : "Profile information is unavailable"
        default: return key
        }
    }
}

struct ReportAlertModifier: ViewModifier {
    @EnvironmentObject private var languageManager: LanguageManager

    @Binding var isPresented: Bool
    let name: String
    func body(content: Content) -> some View {
        content.alert(localizedText("report_user"), isPresented: $isPresented) {
            Button(localizedText("ok"), role: .cancel) {}
        } message: {
            Text(String(format: localizedText("reported_user_message"), name))
        }
    }

    private func localizedText(_ key: String) -> String {
        let isKorean = languageManager.currentLanguage == .korean

        switch key {
        case "cancel": return isKorean ? "취소" : "Cancel"
        case "save": return isKorean ? "저장" : "Save"
        case "ok": return isKorean ? "확인" : "OK"
        case "done": return isKorean ? "완료" : "Done"
        case "close": return isKorean ? "닫기" : "Close"
        case "delete": return isKorean ? "삭제" : "Delete"
        case "edit": return isKorean ? "편집" : "Edit"
        case "add": return isKorean ? "추가" : "Add"
        case "search": return isKorean ? "검색" : "Search"
        case "settings": return isKorean ? "설정" : "Settings"
        case "profile": return isKorean ? "프로필" : "Profile"
        case "logout": return isKorean ? "로그아웃" : "Sign Out"
        case "signin": return isKorean ? "로그인" : "Sign In"
        case "signup": return isKorean ? "회원가입" : "Sign Up"
        case "chat": return isKorean ? "채팅" : "Chat"
        case "message": return isKorean ? "메시지" : "Message"
        case "message_input_placeholder": return isKorean ? "메시지 입력" : "Type a message"
        case "send": return isKorean ? "전송" : "Send"
        case "typing": return isKorean ? "입력 중" : "Typing"
        case "online": return isKorean ? "온라인" : "Online"
        case "offline": return isKorean ? "오프라인" : "Offline"
        case "friends": return isKorean ? "친구" : "Friends"
        case "add_friend": return isKorean ? "친구 추가" : "Add Friend"
        case "friend_request": return isKorean ? "친구 요청" : "Friend Request"
        case "accept": return isKorean ? "수락" : "Accept"
        case "reject": return isKorean ? "거절" : "Reject"
        case "block": return isKorean ? "차단" : "Block"
        case "unblock": return isKorean ? "차단 해제" : "Unblock"
        case "error_occurred": return isKorean ? "오류가 발생했습니다" : "An error occurred"
        case "network_error": return isKorean ? "네트워크 오류" : "Network Error"
        case "try_again": return isKorean ? "다시 시도해주세요" : "Please try again"
        case "notification": return isKorean ? "알림" : "Notification"
        case "permission_required": return isKorean ? "권한이 필요합니다" : "Permission Required"
        case "open_settings": return isKorean ? "설정 열기" : "Open Settings"
        case "contacts_permission_title": return isKorean ? "연락처 접근 권한 필요" : "Contacts Permission Required"
        case "contacts_permission_message": return isKorean ? "친구를 찾기 위해 연락처 접근 권한이 필요합니다. 설정에서 허용해 주세요." : "Contacts access is required to find friends. Please allow it in Settings."
        case "photo_permission_title": return isKorean ? "사진 접근 권한 필요" : "Photos Permission Required"
        case "photo_permission_message": return isKorean ? "사진과 동영상을 첨부하려면 사진 접근 권한이 필요합니다. 설정에서 허용해 주세요." : "Photos access is required to attach images and videos. Please allow it in Settings."
        case "chat_screen": return isKorean ? "채팅 화면" : "Chat Screen"
        case "chat_screen_hint": return isKorean ? "%@과의 채팅 화면입니다" : "Chat with %@"
        case "message_list": return isKorean ? "메시지 목록" : "Messages"
        case "scroll_messages_hint": return isKorean ? "위아래로 스크롤하여 메시지를 확인할 수 있습니다" : "Scroll up and down to review messages"
        case "contacts_match_results": return isKorean ? "연락처 매칭 결과" : "Contacts Match Results"
        case "edited_message_announcement": return isKorean ? "메시지를 편집했습니다" : "Message edited"
        case "edit_message_prompt": return isKorean ? "메시지를 수정하세요" : "Edit your message"
        case "location_permission_title": return isKorean ? "위치 권한 필요" : "Location Permission Required"
        case "location_permission_message": return isKorean ? "긴급 호출을 위해 위치 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요." : "Location access is required for emergency calls. Please allow it in Settings."
        case "reported_user_message": return isKorean ? "%@을(를) 신고했습니다" : "Reported %@"
        case "blocked_user_message": return isKorean ? "%@을(를) 차단했습니다" : "Blocked %@"
        case "suspicious_link_detected": return isKorean ? "의심스러운 링크가 감지되었습니다" : "A suspicious link was detected"
        case "organization_room": return isKorean ? "조직방" : "Organization Room"
        case "enable_org_room": return isKorean ? "조직방 활성화" : "Enable Organization Room"
        case "org_name_optional": return isKorean ? "조직명(선택)" : "Organization Name (Optional)"
        case "working_hours": return isKorean ? "근무 시간" : "Working Hours"
        case "working_hours_footer": return isKorean ? "간단히 요일과 시작/종료 시간을 설정하세요" : "Quickly set weekdays and start/end times"
        case "profile_info_unavailable": return isKorean ? "프로필 정보를 불러올 수 없습니다" : "Profile information is unavailable"
        default: return key
        }
    }
}

struct BlockAlertModifier: ViewModifier {
    @EnvironmentObject private var languageManager: LanguageManager

    @Binding var isPresented: Bool
    let name: String
    func body(content: Content) -> some View {
        content.alert(localizedText("block_user"), isPresented: $isPresented) {
            Button(localizedText("cancel"), role: .cancel) {}
            Button(localizedText("block"), role: .destructive) {
                // TODO: 차단 로직 연동
            }
        } message: {
            Text(String(format: localizedText("blocked_user_message"), name))
        }
    }

    private func localizedText(_ key: String) -> String {
        let isKorean = languageManager.currentLanguage == .korean

        switch key {
        case "cancel": return isKorean ? "취소" : "Cancel"
        case "save": return isKorean ? "저장" : "Save"
        case "ok": return isKorean ? "확인" : "OK"
        case "done": return isKorean ? "완료" : "Done"
        case "close": return isKorean ? "닫기" : "Close"
        case "delete": return isKorean ? "삭제" : "Delete"
        case "edit": return isKorean ? "편집" : "Edit"
        case "add": return isKorean ? "추가" : "Add"
        case "search": return isKorean ? "검색" : "Search"
        case "settings": return isKorean ? "설정" : "Settings"
        case "profile": return isKorean ? "프로필" : "Profile"
        case "logout": return isKorean ? "로그아웃" : "Sign Out"
        case "signin": return isKorean ? "로그인" : "Sign In"
        case "signup": return isKorean ? "회원가입" : "Sign Up"
        case "chat": return isKorean ? "채팅" : "Chat"
        case "message": return isKorean ? "메시지" : "Message"
        case "message_input_placeholder": return isKorean ? "메시지 입력" : "Type a message"
        case "send": return isKorean ? "전송" : "Send"
        case "typing": return isKorean ? "입력 중" : "Typing"
        case "online": return isKorean ? "온라인" : "Online"
        case "offline": return isKorean ? "오프라인" : "Offline"
        case "friends": return isKorean ? "친구" : "Friends"
        case "add_friend": return isKorean ? "친구 추가" : "Add Friend"
        case "friend_request": return isKorean ? "친구 요청" : "Friend Request"
        case "accept": return isKorean ? "수락" : "Accept"
        case "reject": return isKorean ? "거절" : "Reject"
        case "block": return isKorean ? "차단" : "Block"
        case "unblock": return isKorean ? "차단 해제" : "Unblock"
        case "error_occurred": return isKorean ? "오류가 발생했습니다" : "An error occurred"
        case "network_error": return isKorean ? "네트워크 오류" : "Network Error"
        case "try_again": return isKorean ? "다시 시도해주세요" : "Please try again"
        case "notification": return isKorean ? "알림" : "Notification"
        case "permission_required": return isKorean ? "권한이 필요합니다" : "Permission Required"
        case "open_settings": return isKorean ? "설정 열기" : "Open Settings"
        case "contacts_permission_title": return isKorean ? "연락처 접근 권한 필요" : "Contacts Permission Required"
        case "contacts_permission_message": return isKorean ? "친구를 찾기 위해 연락처 접근 권한이 필요합니다. 설정에서 허용해 주세요." : "Contacts access is required to find friends. Please allow it in Settings."
        case "photo_permission_title": return isKorean ? "사진 접근 권한 필요" : "Photos Permission Required"
        case "photo_permission_message": return isKorean ? "사진과 동영상을 첨부하려면 사진 접근 권한이 필요합니다. 설정에서 허용해 주세요." : "Photos access is required to attach images and videos. Please allow it in Settings."
        case "chat_screen": return isKorean ? "채팅 화면" : "Chat Screen"
        case "chat_screen_hint": return isKorean ? "%@과의 채팅 화면입니다" : "Chat with %@"
        case "message_list": return isKorean ? "메시지 목록" : "Messages"
        case "scroll_messages_hint": return isKorean ? "위아래로 스크롤하여 메시지를 확인할 수 있습니다" : "Scroll up and down to review messages"
        case "contacts_match_results": return isKorean ? "연락처 매칭 결과" : "Contacts Match Results"
        case "edited_message_announcement": return isKorean ? "메시지를 편집했습니다" : "Message edited"
        case "edit_message_prompt": return isKorean ? "메시지를 수정하세요" : "Edit your message"
        case "location_permission_title": return isKorean ? "위치 권한 필요" : "Location Permission Required"
        case "location_permission_message": return isKorean ? "긴급 호출을 위해 위치 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요." : "Location access is required for emergency calls. Please allow it in Settings."
        case "reported_user_message": return isKorean ? "%@을(를) 신고했습니다" : "Reported %@"
        case "blocked_user_message": return isKorean ? "%@을(를) 차단했습니다" : "Blocked %@"
        case "suspicious_link_detected": return isKorean ? "의심스러운 링크가 감지되었습니다" : "A suspicious link was detected"
        case "organization_room": return isKorean ? "조직방" : "Organization Room"
        case "enable_org_room": return isKorean ? "조직방 활성화" : "Enable Organization Room"
        case "org_name_optional": return isKorean ? "조직명(선택)" : "Organization Name (Optional)"
        case "working_hours": return isKorean ? "근무 시간" : "Working Hours"
        case "working_hours_footer": return isKorean ? "간단히 요일과 시작/종료 시간을 설정하세요" : "Quickly set weekdays and start/end times"
        case "profile_info_unavailable": return isKorean ? "프로필 정보를 불러올 수 없습니다" : "Profile information is unavailable"
        default: return key
        }
    }
}

struct SuspiciousLinkAlertModifier: ViewModifier {
    @EnvironmentObject private var languageManager: LanguageManager

    @Binding var isPresented: Bool
    @Binding var linkToVerify: String?
    @Binding var ignoredDomains: Set<String>
    let openURL: (URL) -> Void

    func body(content: Content) -> some View {
        content.alert(localizedText("unverified_info"), isPresented: $isPresented) {
            Button(localizedText("cancel"), role: .cancel) {}
            if let link = linkToVerify, let url = URL(string: link) {
                Button(localizedText("open")) { openURL(url) }
                if let host = url.host {
                    Button(localizedText("always_allow")) {
                        ignoredDomains.insert(host)
                        UserDefaults.standard.set(Array(ignoredDomains), forKey: "ignoredDomains")
                    }
                }
            }
        } message: {
            Text(linkToVerify ?? localizedText("suspicious_link_detected"))
        }
    }

    private func localizedText(_ key: String) -> String {
        let isKorean = languageManager.currentLanguage == .korean

        switch key {
        case "cancel": return isKorean ? "취소" : "Cancel"
        case "save": return isKorean ? "저장" : "Save"
        case "ok": return isKorean ? "확인" : "OK"
        case "done": return isKorean ? "완료" : "Done"
        case "close": return isKorean ? "닫기" : "Close"
        case "delete": return isKorean ? "삭제" : "Delete"
        case "edit": return isKorean ? "편집" : "Edit"
        case "add": return isKorean ? "추가" : "Add"
        case "search": return isKorean ? "검색" : "Search"
        case "settings": return isKorean ? "설정" : "Settings"
        case "profile": return isKorean ? "프로필" : "Profile"
        case "logout": return isKorean ? "로그아웃" : "Sign Out"
        case "signin": return isKorean ? "로그인" : "Sign In"
        case "signup": return isKorean ? "회원가입" : "Sign Up"
        case "chat": return isKorean ? "채팅" : "Chat"
        case "message": return isKorean ? "메시지" : "Message"
        case "message_input_placeholder": return isKorean ? "메시지 입력" : "Type a message"
        case "send": return isKorean ? "전송" : "Send"
        case "typing": return isKorean ? "입력 중" : "Typing"
        case "online": return isKorean ? "온라인" : "Online"
        case "offline": return isKorean ? "오프라인" : "Offline"
        case "friends": return isKorean ? "친구" : "Friends"
        case "add_friend": return isKorean ? "친구 추가" : "Add Friend"
        case "friend_request": return isKorean ? "친구 요청" : "Friend Request"
        case "accept": return isKorean ? "수락" : "Accept"
        case "reject": return isKorean ? "거절" : "Reject"
        case "block": return isKorean ? "차단" : "Block"
        case "unblock": return isKorean ? "차단 해제" : "Unblock"
        case "error_occurred": return isKorean ? "오류가 발생했습니다" : "An error occurred"
        case "network_error": return isKorean ? "네트워크 오류" : "Network Error"
        case "try_again": return isKorean ? "다시 시도해주세요" : "Please try again"
        case "notification": return isKorean ? "알림" : "Notification"
        case "permission_required": return isKorean ? "권한이 필요합니다" : "Permission Required"
        case "open_settings": return isKorean ? "설정 열기" : "Open Settings"
        case "contacts_permission_title": return isKorean ? "연락처 접근 권한 필요" : "Contacts Permission Required"
        case "contacts_permission_message": return isKorean ? "친구를 찾기 위해 연락처 접근 권한이 필요합니다. 설정에서 허용해 주세요." : "Contacts access is required to find friends. Please allow it in Settings."
        case "photo_permission_title": return isKorean ? "사진 접근 권한 필요" : "Photos Permission Required"
        case "photo_permission_message": return isKorean ? "사진과 동영상을 첨부하려면 사진 접근 권한이 필요합니다. 설정에서 허용해 주세요." : "Photos access is required to attach images and videos. Please allow it in Settings."
        case "chat_screen": return isKorean ? "채팅 화면" : "Chat Screen"
        case "chat_screen_hint": return isKorean ? "%@과의 채팅 화면입니다" : "Chat with %@"
        case "message_list": return isKorean ? "메시지 목록" : "Messages"
        case "scroll_messages_hint": return isKorean ? "위아래로 스크롤하여 메시지를 확인할 수 있습니다" : "Scroll up and down to review messages"
        case "contacts_match_results": return isKorean ? "연락처 매칭 결과" : "Contacts Match Results"
        case "edited_message_announcement": return isKorean ? "메시지를 편집했습니다" : "Message edited"
        case "edit_message_prompt": return isKorean ? "메시지를 수정하세요" : "Edit your message"
        case "location_permission_title": return isKorean ? "위치 권한 필요" : "Location Permission Required"
        case "location_permission_message": return isKorean ? "긴급 호출을 위해 위치 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요." : "Location access is required for emergency calls. Please allow it in Settings."
        case "reported_user_message": return isKorean ? "%@을(를) 신고했습니다" : "Reported %@"
        case "blocked_user_message": return isKorean ? "%@을(를) 차단했습니다" : "Blocked %@"
        case "suspicious_link_detected": return isKorean ? "의심스러운 링크가 감지되었습니다" : "A suspicious link was detected"
        case "organization_room": return isKorean ? "조직방" : "Organization Room"
        case "enable_org_room": return isKorean ? "조직방 활성화" : "Enable Organization Room"
        case "org_name_optional": return isKorean ? "조직명(선택)" : "Organization Name (Optional)"
        case "working_hours": return isKorean ? "근무 시간" : "Working Hours"
        case "working_hours_footer": return isKorean ? "간단히 요일과 시작/종료 시간을 설정하세요" : "Quickly set weekdays and start/end times"
        case "profile_info_unavailable": return isKorean ? "프로필 정보를 불러올 수 없습니다" : "Profile information is unavailable"
        default: return key
        }
    }
}

// DocumentPicker 구조체
struct DocumentPicker: UIViewControllerRepresentable {
    let onDocumentPicked: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            .pdf, .plainText, .image, .audio, .video, .data
        ])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDocumentPicked: onDocumentPicked)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onDocumentPicked: (URL) -> Void

        init(onDocumentPicked: @escaping (URL) -> Void) {
            self.onDocumentPicked = onDocumentPicked
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onDocumentPicked(url)
        }
    }
}

// MARK: - ReactionPickerView

struct ReactionPickerView: View {
    @EnvironmentObject private var languageManager: LanguageManager

    let message: Message?
    let onReactionSelected: (String) -> Void

    private let reactions = ["👍", "❤️", "😂", "😮", "😢", "😡", "👏", "🎉"]

    var body: some View {
        VStack(spacing: 16) {
            Text(localizedText("add_reaction"))
                .font(.headline)
                .foregroundColor(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                ForEach(reactions, id: \.self) { emoji in
                    Button(action: {
                        onReactionSelected(emoji)
                    }) {
                        Text(emoji)
                            .font(.system(size: 32))
                            .frame(width: 60, height: 60)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel((languageManager.currentLanguage == .korean ? "반응: " : "Reaction: ") + emoji)
                }
            }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .padding()
    }

    private func localizedText(_ key: String) -> String {
        let isKorean = languageManager.currentLanguage == .korean

        switch key {
        case "cancel": return isKorean ? "취소" : "Cancel"
        case "save": return isKorean ? "저장" : "Save"
        case "ok": return isKorean ? "확인" : "OK"
        case "done": return isKorean ? "완료" : "Done"
        case "close": return isKorean ? "닫기" : "Close"
        case "delete": return isKorean ? "삭제" : "Delete"
        case "edit": return isKorean ? "편집" : "Edit"
        case "add": return isKorean ? "추가" : "Add"
        case "search": return isKorean ? "검색" : "Search"
        case "settings": return isKorean ? "설정" : "Settings"
        case "profile": return isKorean ? "프로필" : "Profile"
        case "logout": return isKorean ? "로그아웃" : "Sign Out"
        case "signin": return isKorean ? "로그인" : "Sign In"
        case "signup": return isKorean ? "회원가입" : "Sign Up"
        case "chat": return isKorean ? "채팅" : "Chat"
        case "message": return isKorean ? "메시지" : "Message"
        case "message_input_placeholder": return isKorean ? "메시지 입력" : "Type a message"
        case "send": return isKorean ? "전송" : "Send"
        case "typing": return isKorean ? "입력 중" : "Typing"
        case "online": return isKorean ? "온라인" : "Online"
        case "offline": return isKorean ? "오프라인" : "Offline"
        case "friends": return isKorean ? "친구" : "Friends"
        case "add_friend": return isKorean ? "친구 추가" : "Add Friend"
        case "friend_request": return isKorean ? "친구 요청" : "Friend Request"
        case "accept": return isKorean ? "수락" : "Accept"
        case "reject": return isKorean ? "거절" : "Reject"
        case "block": return isKorean ? "차단" : "Block"
        case "unblock": return isKorean ? "차단 해제" : "Unblock"
        case "error_occurred": return isKorean ? "오류가 발생했습니다" : "An error occurred"
        case "network_error": return isKorean ? "네트워크 오류" : "Network Error"
        case "try_again": return isKorean ? "다시 시도해주세요" : "Please try again"
        case "notification": return isKorean ? "알림" : "Notification"
        case "permission_required": return isKorean ? "권한이 필요합니다" : "Permission Required"
        case "open_settings": return isKorean ? "설정 열기" : "Open Settings"
        case "contacts_permission_title": return isKorean ? "연락처 접근 권한 필요" : "Contacts Permission Required"
        case "contacts_permission_message": return isKorean ? "친구를 찾기 위해 연락처 접근 권한이 필요합니다. 설정에서 허용해 주세요." : "Contacts access is required to find friends. Please allow it in Settings."
        case "photo_permission_title": return isKorean ? "사진 접근 권한 필요" : "Photos Permission Required"
        case "photo_permission_message": return isKorean ? "사진과 동영상을 첨부하려면 사진 접근 권한이 필요합니다. 설정에서 허용해 주세요." : "Photos access is required to attach images and videos. Please allow it in Settings."
        case "chat_screen": return isKorean ? "채팅 화면" : "Chat Screen"
        case "chat_screen_hint": return isKorean ? "%@과의 채팅 화면입니다" : "Chat with %@"
        case "message_list": return isKorean ? "메시지 목록" : "Messages"
        case "scroll_messages_hint": return isKorean ? "위아래로 스크롤하여 메시지를 확인할 수 있습니다" : "Scroll up and down to review messages"
        case "contacts_match_results": return isKorean ? "연락처 매칭 결과" : "Contacts Match Results"
        case "edited_message_announcement": return isKorean ? "메시지를 편집했습니다" : "Message edited"
        case "edit_message_prompt": return isKorean ? "메시지를 수정하세요" : "Edit your message"
        case "location_permission_title": return isKorean ? "위치 권한 필요" : "Location Permission Required"
        case "location_permission_message": return isKorean ? "긴급 호출을 위해 위치 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요." : "Location access is required for emergency calls. Please allow it in Settings."
        case "reported_user_message": return isKorean ? "%@을(를) 신고했습니다" : "Reported %@"
        case "blocked_user_message": return isKorean ? "%@을(를) 차단했습니다" : "Blocked %@"
        case "suspicious_link_detected": return isKorean ? "의심스러운 링크가 감지되었습니다" : "A suspicious link was detected"
        case "organization_room": return isKorean ? "조직방" : "Organization Room"
        case "enable_org_room": return isKorean ? "조직방 활성화" : "Enable Organization Room"
        case "org_name_optional": return isKorean ? "조직명(선택)" : "Organization Name (Optional)"
        case "working_hours": return isKorean ? "근무 시간" : "Working Hours"
        case "working_hours_footer": return isKorean ? "간단히 요일과 시작/종료 시간을 설정하세요" : "Quickly set weekdays and start/end times"
        case "profile_info_unavailable": return isKorean ? "프로필 정보를 불러올 수 없습니다" : "Profile information is unavailable"
        default: return key
        }
    }
}

struct LinkPreviewView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> LPLinkView { LPLinkView(url: url) }
    func updateUIView(_ uiView: LPLinkView, context: Context) {}
}

struct TranslatedTextView: View {
    @EnvironmentObject private var languageManager: LanguageManager

    let text: String
    let autoDetect: Bool
    let target: String
    let showOriginal: Bool

    @State private var translated: String = ""
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(isLoading ? localizedText("translating_ellipsis") : translated)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if showOriginal {
                Text(text)
                    .font(.footnote)
                    .foregroundColor(.tertiaryLabel)
            }
        }
        .onAppear(perform: translate)
        .onChange(of: text) { _, _ in translate() }
    }

    private func translate() {
        isLoading = true
        Task {
            let result = await AIService.shared.translate(text, autoDetect: autoDetect, target: target)
            await MainActor.run {
                self.translated = result
                self.isLoading = false
            }
        }
    }

    private func localizedText(_ key: String) -> String {
        let isKorean = languageManager.currentLanguage == .korean

        switch key {
        case "cancel": return isKorean ? "취소" : "Cancel"
        case "save": return isKorean ? "저장" : "Save"
        case "ok": return isKorean ? "확인" : "OK"
        case "done": return isKorean ? "완료" : "Done"
        case "close": return isKorean ? "닫기" : "Close"
        case "delete": return isKorean ? "삭제" : "Delete"
        case "edit": return isKorean ? "편집" : "Edit"
        case "add": return isKorean ? "추가" : "Add"
        case "search": return isKorean ? "검색" : "Search"
        case "settings": return isKorean ? "설정" : "Settings"
        case "profile": return isKorean ? "프로필" : "Profile"
        case "logout": return isKorean ? "로그아웃" : "Sign Out"
        case "signin": return isKorean ? "로그인" : "Sign In"
        case "signup": return isKorean ? "회원가입" : "Sign Up"
        case "chat": return isKorean ? "채팅" : "Chat"
        case "message": return isKorean ? "메시지" : "Message"
        case "message_input_placeholder": return isKorean ? "메시지 입력" : "Type a message"
        case "send": return isKorean ? "전송" : "Send"
        case "typing": return isKorean ? "입력 중" : "Typing"
        case "online": return isKorean ? "온라인" : "Online"
        case "offline": return isKorean ? "오프라인" : "Offline"
        case "friends": return isKorean ? "친구" : "Friends"
        case "add_friend": return isKorean ? "친구 추가" : "Add Friend"
        case "friend_request": return isKorean ? "친구 요청" : "Friend Request"
        case "accept": return isKorean ? "수락" : "Accept"
        case "reject": return isKorean ? "거절" : "Reject"
        case "block": return isKorean ? "차단" : "Block"
        case "unblock": return isKorean ? "차단 해제" : "Unblock"
        case "error_occurred": return isKorean ? "오류가 발생했습니다" : "An error occurred"
        case "network_error": return isKorean ? "네트워크 오류" : "Network Error"
        case "try_again": return isKorean ? "다시 시도해주세요" : "Please try again"
        case "notification": return isKorean ? "알림" : "Notification"
        case "permission_required": return isKorean ? "권한이 필요합니다" : "Permission Required"
        case "open_settings": return isKorean ? "설정 열기" : "Open Settings"
        case "contacts_permission_title": return isKorean ? "연락처 접근 권한 필요" : "Contacts Permission Required"
        case "contacts_permission_message": return isKorean ? "친구를 찾기 위해 연락처 접근 권한이 필요합니다. 설정에서 허용해 주세요." : "Contacts access is required to find friends. Please allow it in Settings."
        case "photo_permission_title": return isKorean ? "사진 접근 권한 필요" : "Photos Permission Required"
        case "photo_permission_message": return isKorean ? "사진과 동영상을 첨부하려면 사진 접근 권한이 필요합니다. 설정에서 허용해 주세요." : "Photos access is required to attach images and videos. Please allow it in Settings."
        case "chat_screen": return isKorean ? "채팅 화면" : "Chat Screen"
        case "chat_screen_hint": return isKorean ? "%@과의 채팅 화면입니다" : "Chat with %@"
        case "message_list": return isKorean ? "메시지 목록" : "Messages"
        case "scroll_messages_hint": return isKorean ? "위아래로 스크롤하여 메시지를 확인할 수 있습니다" : "Scroll up and down to review messages"
        case "contacts_match_results": return isKorean ? "연락처 매칭 결과" : "Contacts Match Results"
        case "edited_message_announcement": return isKorean ? "메시지를 편집했습니다" : "Message edited"
        case "edit_message_prompt": return isKorean ? "메시지를 수정하세요" : "Edit your message"
        case "location_permission_title": return isKorean ? "위치 권한 필요" : "Location Permission Required"
        case "location_permission_message": return isKorean ? "긴급 호출을 위해 위치 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요." : "Location access is required for emergency calls. Please allow it in Settings."
        case "reported_user_message": return isKorean ? "%@을(를) 신고했습니다" : "Reported %@"
        case "blocked_user_message": return isKorean ? "%@을(를) 차단했습니다" : "Blocked %@"
        case "suspicious_link_detected": return isKorean ? "의심스러운 링크가 감지되었습니다" : "A suspicious link was detected"
        case "organization_room": return isKorean ? "조직방" : "Organization Room"
        case "enable_org_room": return isKorean ? "조직방 활성화" : "Enable Organization Room"
        case "org_name_optional": return isKorean ? "조직명(선택)" : "Organization Name (Optional)"
        case "working_hours": return isKorean ? "근무 시간" : "Working Hours"
        case "working_hours_footer": return isKorean ? "간단히 요일과 시작/종료 시간을 설정하세요" : "Quickly set weekdays and start/end times"
        case "profile_info_unavailable": return isKorean ? "프로필 정보를 불러올 수 없습니다" : "Profile information is unavailable"
        default: return key
        }
    }
}

struct OrgRoomSettingsView: View {
    @EnvironmentObject private var languageManager: LanguageManager

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    var room: ChatRoom

    @State private var isOrgRoom: Bool = false
    @State private var orgName: String = ""

    enum WeekdayMode: String, CaseIterable { case weekdays = "평일", daily = "매일" }
    @State private var weekdayMode: WeekdayMode = .weekdays

    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text(localizedText("organization_room"))) {
                    Toggle(localizedText("enable_org_room"), isOn: $isOrgRoom)
                    TextField(localizedText("org_name_optional"), text: $orgName)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }

                if isOrgRoom {
                    Section(header: Text(localizedText("working_hours")), footer: Text(localizedText("working_hours_footer"))) {
                        Picker("근무 요일", selection: $weekdayMode) {
                            ForEach(WeekdayMode.allCases, id: \.self) { mode in
                                Text(localizedText(mode == .weekdays ? "weekdays" : "daily")).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        DatePicker(localizedText("start"), selection: $startTime, displayedComponents: .hourAndMinute)
                        DatePicker(localizedText("end"), selection: $endTime, displayedComponents: .hourAndMinute)

                        HStack {
                            Text(localizedText("channel_timezone"))
                            Spacer()
                            Text(room.timeZoneIdentifier)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(localizedText("channel_settings"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localizedText("cancel")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizedText("save")) { saveAndDismiss() }
                        .bold()
                }
            }
            .onAppear(perform: loadFromRoom)
            .onChange(of: startTime) { _, _ in syncTimesToRoom() }
            .onChange(of: endTime) { _, _ in syncTimesToRoom() }
            .onChange(of: weekdayMode) { _, newValue in syncWeekdaysToRoom(mode: newValue) }
            .onChange(of: isOrgRoom) { _, newValue in room.isOrganizationRoom = newValue }
            .onChange(of: orgName) { _, newValue in room.orgName = newValue.isEmpty ? nil : newValue }
        }
    }

    private func loadFromRoom() {
        isOrgRoom = room.isOrganizationRoom
        orgName = room.orgName ?? ""

        // Weekday mode 추정
        let set = Set(room.workingDays)
        if set == Set([2, 3, 4, 5, 6]) { weekdayMode = .weekdays } else if set == Set([1, 2, 3, 4, 5, 6, 7]) { weekdayMode = .daily } else { weekdayMode = .weekdays }

        // 시간 초기화
        var cal = Calendar.current
        if let tz = TimeZone(identifier: room.timeZoneIdentifier) { cal.timeZone = tz }
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.hour = room.workStartHour
        comps.minute = room.workStartMinute
        startTime = cal.date(from: comps) ?? Date()
        comps.hour = room.workEndHour
        comps.minute = room.workEndMinute
        endTime = cal.date(from: comps) ?? Date()
    }

    private func syncTimesToRoom() {
        let cal = Calendar.current
        let startComponents = cal.dateComponents([.hour, .minute], from: startTime)
        let endComponents = cal.dateComponents([.hour, .minute], from: endTime)
        room.workStartHour = startComponents.hour ?? 9
        room.workStartMinute = startComponents.minute ?? 0
        room.workEndHour = endComponents.hour ?? 18
        room.workEndMinute = endComponents.minute ?? 0
    }

    private func syncWeekdaysToRoom(mode: WeekdayMode) {
        switch mode {
        case .weekdays:
            room.workingDays = [2, 3, 4, 5, 6]
        case .daily:
            room.workingDays = [1, 2, 3, 4, 5, 6, 7]
        }
    }

    private func saveAndDismiss() {
        do { try modelContext.save() } catch { print("채널 설정 저장 실패: \(error)") }
        dismiss()
    }

    private func localizedText(_ key: String) -> String {
        let isKorean = languageManager.currentLanguage == .korean

        switch key {
        case "cancel": return isKorean ? "취소" : "Cancel"
        case "save": return isKorean ? "저장" : "Save"
        case "ok": return isKorean ? "확인" : "OK"
        case "done": return isKorean ? "완료" : "Done"
        case "close": return isKorean ? "닫기" : "Close"
        case "delete": return isKorean ? "삭제" : "Delete"
        case "edit": return isKorean ? "편집" : "Edit"
        case "add": return isKorean ? "추가" : "Add"
        case "search": return isKorean ? "검색" : "Search"
        case "settings": return isKorean ? "설정" : "Settings"
        case "profile": return isKorean ? "프로필" : "Profile"
        case "logout": return isKorean ? "로그아웃" : "Sign Out"
        case "signin": return isKorean ? "로그인" : "Sign In"
        case "signup": return isKorean ? "회원가입" : "Sign Up"
        case "chat": return isKorean ? "채팅" : "Chat"
        case "message": return isKorean ? "메시지" : "Message"
        case "message_input_placeholder": return isKorean ? "메시지 입력" : "Type a message"
        case "send": return isKorean ? "전송" : "Send"
        case "typing": return isKorean ? "입력 중" : "Typing"
        case "online": return isKorean ? "온라인" : "Online"
        case "offline": return isKorean ? "오프라인" : "Offline"
        case "friends": return isKorean ? "친구" : "Friends"
        case "add_friend": return isKorean ? "친구 추가" : "Add Friend"
        case "friend_request": return isKorean ? "친구 요청" : "Friend Request"
        case "accept": return isKorean ? "수락" : "Accept"
        case "reject": return isKorean ? "거절" : "Reject"
        case "block": return isKorean ? "차단" : "Block"
        case "unblock": return isKorean ? "차단 해제" : "Unblock"
        case "error_occurred": return isKorean ? "오류가 발생했습니다" : "An error occurred"
        case "network_error": return isKorean ? "네트워크 오류" : "Network Error"
        case "try_again": return isKorean ? "다시 시도해주세요" : "Please try again"
        case "notification": return isKorean ? "알림" : "Notification"
        case "permission_required": return isKorean ? "권한이 필요합니다" : "Permission Required"
        case "open_settings": return isKorean ? "설정 열기" : "Open Settings"
        case "contacts_permission_title": return isKorean ? "연락처 접근 권한 필요" : "Contacts Permission Required"
        case "contacts_permission_message": return isKorean ? "친구를 찾기 위해 연락처 접근 권한이 필요합니다. 설정에서 허용해 주세요." : "Contacts access is required to find friends. Please allow it in Settings."
        case "photo_permission_title": return isKorean ? "사진 접근 권한 필요" : "Photos Permission Required"
        case "photo_permission_message": return isKorean ? "사진과 동영상을 첨부하려면 사진 접근 권한이 필요합니다. 설정에서 허용해 주세요." : "Photos access is required to attach images and videos. Please allow it in Settings."
        case "chat_screen": return isKorean ? "채팅 화면" : "Chat Screen"
        case "chat_screen_hint": return isKorean ? "%@과의 채팅 화면입니다" : "Chat with %@"
        case "message_list": return isKorean ? "메시지 목록" : "Messages"
        case "scroll_messages_hint": return isKorean ? "위아래로 스크롤하여 메시지를 확인할 수 있습니다" : "Scroll up and down to review messages"
        case "contacts_match_results": return isKorean ? "연락처 매칭 결과" : "Contacts Match Results"
        case "edited_message_announcement": return isKorean ? "메시지를 편집했습니다" : "Message edited"
        case "edit_message_prompt": return isKorean ? "메시지를 수정하세요" : "Edit your message"
        case "location_permission_title": return isKorean ? "위치 권한 필요" : "Location Permission Required"
        case "location_permission_message": return isKorean ? "긴급 호출을 위해 위치 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요." : "Location access is required for emergency calls. Please allow it in Settings."
        case "reported_user_message": return isKorean ? "%@을(를) 신고했습니다" : "Reported %@"
        case "blocked_user_message": return isKorean ? "%@을(를) 차단했습니다" : "Blocked %@"
        case "suspicious_link_detected": return isKorean ? "의심스러운 링크가 감지되었습니다" : "A suspicious link was detected"
        case "organization_room": return isKorean ? "조직방" : "Organization Room"
        case "enable_org_room": return isKorean ? "조직방 활성화" : "Enable Organization Room"
        case "org_name_optional": return isKorean ? "조직명(선택)" : "Organization Name (Optional)"
        case "working_hours": return isKorean ? "근무 시간" : "Working Hours"
        case "working_hours_footer": return isKorean ? "간단히 요일과 시작/종료 시간을 설정하세요" : "Quickly set weekdays and start/end times"
        case "profile_info_unavailable": return isKorean ? "프로필 정보를 불러올 수 없습니다" : "Profile information is unavailable"
        default: return key
        }
    }
}

struct MiniProfileSheet: View {
    @EnvironmentObject private var languageManager: LanguageManager

    let name: String
    let symbol: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 64))
                    .foregroundColor(.appPrimary)
                    .padding(.top, 20)
                Text(name)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(localizedText("profile_info_unavailable"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle(localizedText("profile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button(localizedText("close")) { dismiss() } } }
        }
    }

    private func localizedText(_ key: String) -> String {
        let isKorean = languageManager.currentLanguage == .korean

        switch key {
        case "cancel": return isKorean ? "취소" : "Cancel"
        case "save": return isKorean ? "저장" : "Save"
        case "ok": return isKorean ? "확인" : "OK"
        case "done": return isKorean ? "완료" : "Done"
        case "close": return isKorean ? "닫기" : "Close"
        case "delete": return isKorean ? "삭제" : "Delete"
        case "edit": return isKorean ? "편집" : "Edit"
        case "add": return isKorean ? "추가" : "Add"
        case "search": return isKorean ? "검색" : "Search"
        case "settings": return isKorean ? "설정" : "Settings"
        case "profile": return isKorean ? "프로필" : "Profile"
        case "logout": return isKorean ? "로그아웃" : "Sign Out"
        case "signin": return isKorean ? "로그인" : "Sign In"
        case "signup": return isKorean ? "회원가입" : "Sign Up"
        case "chat": return isKorean ? "채팅" : "Chat"
        case "message": return isKorean ? "메시지" : "Message"
        case "message_input_placeholder": return isKorean ? "메시지 입력" : "Type a message"
        case "send": return isKorean ? "전송" : "Send"
        case "typing": return isKorean ? "입력 중" : "Typing"
        case "online": return isKorean ? "온라인" : "Online"
        case "offline": return isKorean ? "오프라인" : "Offline"
        case "friends": return isKorean ? "친구" : "Friends"
        case "add_friend": return isKorean ? "친구 추가" : "Add Friend"
        case "friend_request": return isKorean ? "친구 요청" : "Friend Request"
        case "accept": return isKorean ? "수락" : "Accept"
        case "reject": return isKorean ? "거절" : "Reject"
        case "block": return isKorean ? "차단" : "Block"
        case "unblock": return isKorean ? "차단 해제" : "Unblock"
        case "error_occurred": return isKorean ? "오류가 발생했습니다" : "An error occurred"
        case "network_error": return isKorean ? "네트워크 오류" : "Network Error"
        case "try_again": return isKorean ? "다시 시도해주세요" : "Please try again"
        case "notification": return isKorean ? "알림" : "Notification"
        case "permission_required": return isKorean ? "권한이 필요합니다" : "Permission Required"
        case "open_settings": return isKorean ? "설정 열기" : "Open Settings"
        case "contacts_permission_title": return isKorean ? "연락처 접근 권한 필요" : "Contacts Permission Required"
        case "contacts_permission_message": return isKorean ? "친구를 찾기 위해 연락처 접근 권한이 필요합니다. 설정에서 허용해 주세요." : "Contacts access is required to find friends. Please allow it in Settings."
        case "photo_permission_title": return isKorean ? "사진 접근 권한 필요" : "Photos Permission Required"
        case "photo_permission_message": return isKorean ? "사진과 동영상을 첨부하려면 사진 접근 권한이 필요합니다. 설정에서 허용해 주세요." : "Photos access is required to attach images and videos. Please allow it in Settings."
        case "chat_screen": return isKorean ? "채팅 화면" : "Chat Screen"
        case "chat_screen_hint": return isKorean ? "%@과의 채팅 화면입니다" : "Chat with %@"
        case "message_list": return isKorean ? "메시지 목록" : "Messages"
        case "scroll_messages_hint": return isKorean ? "위아래로 스크롤하여 메시지를 확인할 수 있습니다" : "Scroll up and down to review messages"
        case "contacts_match_results": return isKorean ? "연락처 매칭 결과" : "Contacts Match Results"
        case "edited_message_announcement": return isKorean ? "메시지를 편집했습니다" : "Message edited"
        case "edit_message_prompt": return isKorean ? "메시지를 수정하세요" : "Edit your message"
        case "location_permission_title": return isKorean ? "위치 권한 필요" : "Location Permission Required"
        case "location_permission_message": return isKorean ? "긴급 호출을 위해 위치 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요." : "Location access is required for emergency calls. Please allow it in Settings."
        case "reported_user_message": return isKorean ? "%@을(를) 신고했습니다" : "Reported %@"
        case "blocked_user_message": return isKorean ? "%@을(를) 차단했습니다" : "Blocked %@"
        case "suspicious_link_detected": return isKorean ? "의심스러운 링크가 감지되었습니다" : "A suspicious link was detected"
        case "organization_room": return isKorean ? "조직방" : "Organization Room"
        case "enable_org_room": return isKorean ? "조직방 활성화" : "Enable Organization Room"
        case "org_name_optional": return isKorean ? "조직명(선택)" : "Organization Name (Optional)"
        case "working_hours": return isKorean ? "근무 시간" : "Working Hours"
        case "working_hours_footer": return isKorean ? "간단히 요일과 시작/종료 시간을 설정하세요" : "Quickly set weekdays and start/end times"
        case "profile_info_unavailable": return isKorean ? "프로필 정보를 불러올 수 없습니다" : "Profile information is unavailable"
        case "add_friend_title": return isKorean ? "친구 추가" : "Add Friend"
        case "add_friend_message": return isKorean ? "%@님을 친구로 추가하시겠습니까?" : "Add %@ as a friend?"
        case "attach": return isKorean ? "첨부" : "Attach"
        case "view_profile": return isKorean ? "프로필 보기" : "View Profile"
        default: return key
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: Message.self, ChatRoom.self)
    let chatRoom = ChatRoom(name: "친구")

    NavigationStack {
        ChatView(chatRoom: chatRoom)
            .environmentObject(LanguageManager())
    }
    .modelContainer(container)
}

// MARK: - LocationManager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            print("위치 권한이 거부되었습니다")
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.currentLocation = location
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("위치 정보 가져오기 실패: \(error)")
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
        }

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        default:
            break
        }
    }
}
