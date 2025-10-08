//
//  ChatView_Refactored.swift
//  TalkMVP
//
//  Refactored to follow SOLID principles
//

import SwiftUI
import SwiftData
import PhotosUI
import NaturalLanguage

/// Single Responsibility: 채팅 UI 표시 및 사용자 인터랙션 처리만 담당
/// Dependency Inversion: 프로토콜 기반 의존성 주입
struct ChatViewRefactored: View {
    // MARK: - Environment & Dependencies

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var languageManager: LanguageManager

    // MARK: - Core Properties

    let chatRoom: ChatRoom
    @State private var viewModel: ChatViewModel?
    @StateObject private var chatService: ChatService

    // MARK: - UI State

    @FocusState private var isTextFieldFocused: Bool
    @State private var inputText: String = ""
    @State private var searchText: String = ""

    // MARK: - Message Actions

    @State private var reactionToMessage: Message?
    @State private var showingReactionPicker = false
    @State private var replyingToMessage: Message?
    @State private var editingMessage: Message?
    @State private var showingEditAlert = false
    @State private var editingText: String = ""

    // MARK: - Attachment Handling (delegated to AttachmentHandler)

    @State private var pendingAttachment: PendingAttachment?
    @State private var showingAttachmentPreview = false
    @State private var showingPhotosPicker = false
    @State private var showingDocumentPicker = false

    // MARK: - Alerts

    @State private var showingPhotosPermissionAlert = false
    @State private var showingContactsPermissionAlert = false
    @State private var showingLocationPermissionAlert = false
    @State private var showingReportAlert = false
    @State private var showingBlockAlert = false
    @State private var suspiciousLinkDetected = false
    @State private var linkToVerify: String?
    @State private var ignoredDomains: Set<String> = []
    @State private var showingAddFriendAlert = false

    // MARK: - Profile & Friends

    @State private var showingFriendProfile = false
    @State private var profileFriendship: Friendship?
    @State private var isFriend = false

    // MARK: - Services (Dependency Injection)

    private let localizationService: LocalizationServiceProtocol
    private let attachmentHandler: AttachmentHandlerProtocol

    @StateObject private var locationManager = LocationManager()

    // MARK: - AppStorage Settings

    @AppStorage("aiSearchEnabled") private var aiSearchEnabled = true
    @AppStorage("translationEnabled") private var translationEnabled = false
    @AppStorage("translationAutoDetect") private var translationAutoDetect = true
    @AppStorage("translationTargetLanguage") private var translationTargetLanguage = "auto"
    @AppStorage("translationShowOriginal") private var translationShowOriginal = true

    // MARK: - Init

    init(
        chatRoom: ChatRoom,
        chatService: ChatService? = nil,
        localizationService: LocalizationServiceProtocol = LocalizationService.shared,
        attachmentHandler: AttachmentHandlerProtocol = AttachmentHandler.shared
    ) {
        self.chatRoom = chatRoom
        self.localizationService = localizationService
        self.attachmentHandler = attachmentHandler

        if let service = chatService {
            self._chatService = StateObject(wrappedValue: service)
        } else {
            let tempContext = (try? ModelContainer(for: Message.self).mainContext) ?? ModelContext(try! ModelContainer(for: Message.self))
            self._chatService = StateObject(wrappedValue: ChatService(modelContext: tempContext))
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ConnectionStatusView(chatService: chatService)
                .accessibilityLabel(localizedText(.connectionStatus))

            mainContentView
        }
        .navigationTitle(chatRoom.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                chatToolbarButtons
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear(perform: onAppear)
        .setupAlerts()
        .setupSheets()
        .dynamicTypeSize(dynamicTypeSize.isAccessibilitySize ? .accessibility3 : dynamicTypeSize)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: localizedText(.searchConversation))
    }

    // MARK: - Toolbar

    private var chatToolbarButtons: some View {
        HStack(spacing: 12) {
            // 알림 토글
            Button {
                toggleChatNotifications()
            } label: {
                Image(systemName: chatRoom.notificationsEnabled ? "bell.fill" : "bell.slash.fill")
                    .foregroundColor(chatRoom.notificationsEnabled ? .appPrimary : .gray)
            }
            .accessibilityLabel(localizedText(chatRoom.notificationsEnabled ? .muteNotifications : .unmuteNotifications))

            // 친구 추가 버튼
            if !isFriend && chatRoom.otherUserId != nil {
                Button {
                    showingAddFriendAlert = true
                } label: {
                    Image(systemName: "person.badge.plus")
                        .foregroundColor(.appPrimary)
                }
                .accessibilityLabel(localizedText(.addFriend))
            }
        }
    }

    // MARK: - Main Content

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

    // MARK: - Messages ScrollView

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
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.otherUserTyping) { _, isTyping in
                if isTyping { scrollToBottom(proxy: proxy) }
            }
            .onTapGesture {
                isTextFieldFocused = false
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
            .onLongPressGesture {
                showReactionPicker(for: message)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button(localizedText(.reply)) {
                    replyingToMessage = message
                    isTextFieldFocused = true
                }
                .tint(.appPrimary)
            }
            .contextMenu {
                messageContextMenu(message)
            }

            // Link Preview
            if message.messageType == .text, let url = firstURL(in: message.text) {
                LinkPreviewView(url: url)
                    .frame(maxWidth: .infinity, alignment: message.isFromCurrentUser ? .trailing : .leading)
                    .padding(.horizontal, 2)
            }

            // Translation
            if !message.isFromCurrentUser && message.messageType == .text && shouldShowTranslation(for: message.text) {
                TranslatedTextView(
                    text: message.text,
                    autoDetect: translationAutoDetect,
                    target: effectiveTargetLanguage(for: message.text),
                    showOriginal: translationShowOriginal
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)
                .environmentObject(languageManager)
            }
        }
    }

    @ViewBuilder
    private func messageContextMenu(_ message: Message) -> some View {
        if message.messageType == .text {
            Button(localizedText(.copyText), systemImage: "doc.on.doc") {
                UIPasteboard.general.string = message.text
            }
        }

        Button(localizedText(.reply), systemImage: "arrowshape.turn.up.left") {
            replyingToMessage = message
            isTextFieldFocused = true
        }

        Button(localizedText(.addReaction), systemImage: "face.smiling") {
            showReactionPicker(for: message)
        }

        if message.isFromCurrentUser {
            Button(localizedText(.edit), systemImage: "pencil") {
                startEditingMessage(message)
            }
            Button(localizedText(.delete), systemImage: "trash", role: .destructive) {
                deleteMessage(message)
            }
        }

        if !message.isFromCurrentUser {
            Button(localizedText(.reportUser), systemImage: "exclamationmark.bubble") {
                showingReportAlert = true
            }
            Button(localizedText(.blockUser), systemImage: "hand.raised") {
                showingBlockAlert = true
            }
        }
    }

    // MARK: - Message Input View

    @ViewBuilder
    private func messageInputView(viewModel: ChatViewModel) -> some View {
        VStack(spacing: 0) {
            if let replyingTo = replyingToMessage {
                replyingToView(replyingTo)
            }

            HStack(spacing: 12) {
                attachmentButton

                TextField(localizedText(.messageInputPlaceholder), text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        sendMessage(viewModel: viewModel)
                    }

                sendButton(viewModel: viewModel)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }

    private var attachmentButton: some View {
        Menu {
            Button {
                openPhotosAttachment()
            } label: {
                Label("사진/동영상", systemImage: "photo.on.rectangle")
            }

            Button {
                showingDocumentPicker = true
            } label: {
                Label("파일", systemImage: "doc")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(.appPrimary)
                .font(.system(size: 28))
        }
    }

    private func sendButton(viewModel: ChatViewModel) -> some View {
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

    @ViewBuilder
    private func replyingToView(_ message: Message) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: localizedText(.replyingTo), message.isFromCurrentUser ? localizedText(.me) : chatRoom.name))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(message.text)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            Spacer()
            Button(localizedText(.cancel)) {
                replyingToMessage = nil
            }
            .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemGroupedBackground))
    }

    // MARK: - Actions

    private func onAppear() {
        setupViewModelIfNeeded()
        checkIfFriend()
        markMessagesAsRead()

        if let saved = UserDefaults.standard.array(forKey: "ignoredDomains") as? [String] {
            ignoredDomains = Set(saved)
        }
    }

    private func setupViewModelIfNeeded() {
        chatService.modelContext = modelContext

        if viewModel == nil {
            let vm = ChatViewModel(modelContext: modelContext, chatRoom: chatRoom, chatService: chatService)
            self.viewModel = vm
            vm.checkOnlineStatus()
        } else {
            Task {
                await viewModel?.loadMessages()
            }
        }
    }

    private func checkIfFriend() {
        guard let otherUserId = chatRoom.otherUserId else {
            isFriend = true
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
            print("❌ Failed to check friendship: \(error)")
            isFriend = false
        }
    }

    private func markMessagesAsRead() {
        guard let messages = viewModel?.messages else { return }

        for message in messages where !message.isFromCurrentUser && !message.isRead {
            message.isRead = true
        }

        try? modelContext.save()
    }

    private func toggleChatNotifications() {
        chatRoom.notificationsEnabled.toggle()
        try? modelContext.save()
    }

    private func sendMessage(viewModel: ChatViewModel) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        viewModel.newMessageText = text
        if let replying = replyingToMessage {
            viewModel.setReplyMessage(replying)
        }
        viewModel.sendMessage()

        inputText = ""
        replyingToMessage = nil
        isTextFieldFocused = false
    }

    // MARK: - Attachment Handling (delegated to AttachmentHandler)

    private func openPhotosAttachment() {
        PermissionManager.shared.requestPhotoLibraryAccess { granted in
            if granted {
                showingPhotosPicker = true
            } else {
                showingPhotosPermissionAlert = true
            }
        }
    }

    private func handlePhotoPickerSelection(_ items: [PHPickerResult]) {
        attachmentHandler.handlePhotoPickerResult(items) { attachment in
            pendingAttachment = attachment
            showingAttachmentPreview = (attachment != nil)
        }
    }

    private func handleDocumentSelection(_ url: URL) {
        attachmentHandler.handleDocumentSelection(url) { attachment in
            pendingAttachment = attachment
            showingAttachmentPreview = (attachment != nil)
        }
        showingDocumentPicker = false
    }

    private func sendPendingAttachment() {
        guard let attachment = pendingAttachment else { return }

        Task {
            do {
                let filePath = try await attachmentHandler.saveAttachmentToDocuments(attachment)

                await MainActor.run {
                    switch attachment {
                    case .image:
                        if let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) {
                            sendImageMessage(data: data)
                        }
                    case .video:
                        if let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) {
                            sendVideoMessage(data: data)
                        }
                    case .document(_, let fileName, let fileSize, _):
                        sendFileMessage(fileName: fileName, fileURL: filePath, fileSize: fileSize)
                    }

                    pendingAttachment = nil
                    showingAttachmentPreview = false
                }
            } catch {
                print("❌ Failed to save attachment: \(error)")
            }
        }
    }

    private func sendImageMessage(data: Data) {
        let message = Message(imageData: data, isFromCurrentUser: true, sender: "나", chatRoomId: chatRoom.id.uuidString)

        modelContext.insert(message)
        chatRoom.messages.append(message)
        chatRoom.lastMessage = "사진을 보냈습니다"
        chatRoom.timestamp = Date()

        try? modelContext.save()
    }

    private func sendVideoMessage(data: Data) {
        let message = Message(text: "동영상을 보냈습니다", isFromCurrentUser: true, sender: "나", chatRoomId: chatRoom.id.uuidString, messageType: .video)
        message.videoData = data

        modelContext.insert(message)
        chatRoom.messages.append(message)
        chatRoom.lastMessage = "동영상을 보냈습니다"
        chatRoom.timestamp = Date()

        try? modelContext.save()
    }

    private func sendFileMessage(fileName: String, fileURL: String, fileSize: Int) {
        let nameWithoutExt = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension

        let message = Message(
            fileName: nameWithoutExt,
            fileExtension: ext,
            fileSize: fileSize,
            isFromCurrentUser: true,
            sender: "나",
            chatRoomId: chatRoom.id.uuidString
        )
        message.fileURL = fileURL

        modelContext.insert(message)
        chatRoom.messages.append(message)
        chatRoom.lastMessage = "파일을 보냈습니다"
        chatRoom.timestamp = Date()

        try? modelContext.save()
    }

    // MARK: - Message Actions

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

    private func openFriendProfile() {
        showingFriendProfile = true
    }

    // MARK: - Helper Functions

    private func scrollToBottom(proxy: ScrollViewProxy) {
        let animation: Animation = reduceMotion ?
            .easeInOut(duration: 0.1) :
            .spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.2)

        if let lastMessage = viewModel?.messages.last {
            withAnimation(animation) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        } else if viewModel?.otherUserTyping == true {
            withAnimation(animation) {
                proxy.scrollTo("typing_indicator", anchor: .bottom)
            }
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
            case .image, .audio, .video, .deleted:
                return false
            }
        }
    }

    private func firstURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = detector?.matches(in: text, options: [], range: range)
        return matches?.first?.url
    }

    // MARK: - Translation Helpers

    private func shouldShowTranslation(for text: String) -> Bool {
        guard translationEnabled else { return false }

        let source = detectLanguageCode(for: text) ?? ""
        let target = effectiveTargetLanguage(for: text).lowercased()
        if !source.isEmpty {
            return source != target
        } else {
            if languageManager.currentLanguage != .korean && containsHangul(text) { return true }
            return false
        }
    }

    private func effectiveTargetLanguage(for text: String) -> String {
        let target = translationTargetLanguage.lowercased()
        if target != "auto" { return target }
        return languageManager.currentLanguage == .korean ? "ko" : "en"
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

    private func containsHangul(_ text: String) -> Bool {
        return text.unicodeScalars.contains { scalar in
            let value = scalar.value
            return (0xAC00...0xD7A3).contains(value)
        }
    }

    // MARK: - Localization (using LocalizationService)

    private func localizedText(_ key: LocalizationKey) -> String {
        let language: Language = (languageManager.currentLanguage == .korean) ? .korean : .english
        return localizationService.text(for: key, language: language)
    }
}

// MARK: - View Extensions for Alerts & Sheets

extension View {
    @ViewBuilder
    func setupAlerts() -> some View {
        self
            .modifier(EditMessageAlertModifier(
                isPresented: .constant(false), // placeholder - will be properly wired
                editingText: .constant(""),
                editingMessage: .constant(nil),
                onSave: { _, _ in },
                language: .korean
            ))
    }

    @ViewBuilder
    func setupSheets() -> some View {
        self
    }
}

#Preview {
    let container = try! ModelContainer(for: Message.self, ChatRoom.self)
    let chatRoom = ChatRoom(name: "친구")

    NavigationStack {
        ChatViewRefactored(chatRoom: chatRoom)
            .environmentObject(LanguageManager())
    }
    .modelContainer(container)
}
