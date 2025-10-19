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

    // 첨부파일 미리보기 관련
    @State private var pendingAttachment: PendingAttachment?
    @State private var showingAttachmentPreview = false

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

    // MARK: - Media Sending

    private func sendImageMessage(data: Data) async {
        let message = Message(imageData: data, isFromCurrentUser: true, sender: "나", chatRoomId: chatRoom.id.uuidString)

        await MainActor.run {
            modelContext.insert(message)
            chatRoom.messages.append(message)
            chatRoom.lastMessage = localizedText("sent_photo")
            chatRoom.timestamp = Date()

            do {
                try modelContext.save()
                print("✅ [ChatView] Image message sent")
            } catch {
                print("❌ [ChatView] Failed to send image: \(error)")
            }
        }
    }

    private func sendVideoMessage(data: Data) async {
        let sentVideoText = localizedText("sent_video")
        let message = Message(text: sentVideoText, isFromCurrentUser: true, sender: "나", chatRoomId: chatRoom.id.uuidString, messageType: .video)
        message.videoData = data

        await MainActor.run {
            modelContext.insert(message)
            chatRoom.messages.append(message)
            chatRoom.lastMessage = sentVideoText
            chatRoom.timestamp = Date()

            do {
                try modelContext.save()
                print("✅ [ChatView] Video message sent")
            } catch {
                print("❌ [ChatView] Failed to send video: \(error)")
            }
        }
    }

    private func handleDocumentSelection(_ url: URL) {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing { url.stopAccessingSecurityScopedResource() }
            showingDocumentPicker = false
        }

        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .nameKey, .contentTypeKey])
            let fileName = resourceValues.name ?? url.lastPathComponent
            let fileSize = resourceValues.fileSize ?? 0

            // 파일 데이터 읽기
            let data = try Data(contentsOf: url)
            let fileExtension = url.pathExtension

            // 미리보기 표시
            pendingAttachment = .document(data, fileName, fileSize, fileExtension)
            showingAttachmentPreview = true

            print("📎 [ChatView] Document selected for preview: \(fileName)")
        } catch {
            print("❌ [ChatView] Failed to handle document: \(error)")
        }
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
        chatRoom.lastMessage = localizedText("sent_file")
        chatRoom.timestamp = Date()

        do {
            try modelContext.save()
            print("✅ [ChatView] File message saved")
        } catch {
            print("❌ [ChatView] Failed to save file message: \(error)")
        }
    }

    private func sendPendingAttachment() {
        guard let attachment = pendingAttachment else { return }

        Task {
            switch attachment {
            case .image(let image):
                if let data = image.jpegData(compressionQuality: 0.8) {
                    await sendImageMessage(data: data)
                }
            case .video(let data, _):
                await sendVideoMessage(data: data)
            case .document(let data, let fileName, let fileSize, _):
                // 파일을 앱 Documents 폴더에 저장
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let destinationURL = documentsPath
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension((fileName as NSString).pathExtension)

                do {
                    try data.write(to: destinationURL)
                    await MainActor.run {
                        sendFileMessage(fileName: fileName, fileURL: destinationURL.path, fileSize: fileSize)
                    }
                } catch {
                    print("❌ Failed to save file: \(error)")
                }
            }

            // 전송 후 미리보기 닫기
            await MainActor.run {
                pendingAttachment = nil
                showingAttachmentPreview = false
            }
        }
    }

    private func cancelPendingAttachment() {
        pendingAttachment = nil
        showingAttachmentPreview = false
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
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear {
            setupViewModelIfNeeded()
            checkIfFriend()
            markMessagesAsRead()
            if let saved = UserDefaults.standard.array(forKey: "ignoredDomains") as? [String] {
                ignoredDomains = Set(saved)
            }
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

    private var allAlertModifiers: some ViewModifier {
        CompoundAlertModifier(
            showingEditAlert: $showingEditAlert,
            editingText: $editingText,
            editingMessage: $editingMessage,
            showingEmergencyAlert: $showingEmergencyAlert,
            showingLocationPermissionAlert: $showingLocationPermissionAlert,
            showingReportAlert: $showingReportAlert,
            showingBlockAlert: $showingBlockAlert,
            suspiciousLinkDetected: $suspiciousLinkDetected,
            linkToVerify: $linkToVerify,
            ignoredDomains: $ignoredDomains,
            chatRoomName: chatRoom.name,
            openURL: { url in openURL(url) },
            onEditSave: { message, newText in
                viewModel?.editMessage(message, newText: newText)
            }
        )
    }

    var body: some View {
        baseScaffold
            .modifier(allAlertModifiers)
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
            .sheet(isPresented: $showingPhotosPicker) {
                PhotoPickerView { selectedItems in
                    handlePhotoPickerSelection(selectedItems)
                }
            }
            .fullScreenCover(isPresented: $showingAttachmentPreview) {
                AttachmentPreviewView(
                    attachment: pendingAttachment,
                    onSend: sendPendingAttachment,
                    onCancel: cancelPendingAttachment
                )
                .environmentObject(languageManager)
            }
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
            case .image, .audio, .video:
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

    // MARK: - Read Status Management

    private func markMessagesAsRead() {
        guard let messages = viewModel?.messages else { return }

        for message in messages where !message.isFromCurrentUser && !message.isRead {
            message.isRead = true
        }

        do {
            try modelContext.save()
            print("✅ [ChatView] Marked \(messages.filter { !$0.isFromCurrentUser && $0.isRead }.count) messages as read")
        } catch {
            print("❌ [ChatView] Failed to mark messages as read: \(error)")
        }
    }

    private func addFriendToChatRoom() {
        guard let otherUserId = chatRoom.otherUserId,
              let otherUserEmail = chatRoom.otherUserEmail,
              let currentUserId = getCurrentUserId() else {
            print("❌ [ChatView] Missing user information for friend request")
            return
        }

        // Create outgoing (sender) friendship record
        let outgoing = Friendship(
            userId: currentUserId,
            friendId: otherUserId,
            friendName: chatRoom.name,
            friendEmail: otherUserEmail,
            status: .pending
        )
        outgoing.ownerUserId = currentUserId
        modelContext.insert(outgoing)

        // Create incoming (receiver) mirror record for backend readiness
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.isCurrentUser == true }
        )
        if let currentUser = try? modelContext.fetch(descriptor).first {
            let mirror = Friendship(
                userId: otherUserId,
                friendId: currentUserId,
                friendName: currentUser.displayName,
                friendEmail: currentUser.email,
                status: .pending
            )
            mirror.ownerUserId = otherUserId
            modelContext.insert(mirror)
        }

        do {
            try modelContext.save()
            print("✅ [ChatView] Friend request sent to \(chatRoom.name)")
            // 친구 추가 후 상태 업데이트
            isFriend = true
            // FriendsView에 알림을 보내서 UI 업데이트
            NotificationCenter.default.post(name: .friendshipPendingCreated, object: nil, userInfo: ["friendId": otherUserId])
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

    // MARK: - Photo Picker Handler

    private func handlePhotoPickerSelection(_ items: [PHPickerResult]) {
        guard let item = items.first else { return }

        // 동영상 먼저 체크
        if item.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            item.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                guard let url = url, error == nil else {
                    print("❌ Failed to load video: \(error?.localizedDescription ?? "unknown error")")
                    return
                }

                do {
                    let data = try Data(contentsOf: url)
                    Task { @MainActor in
                        // 미리보기 표시
                        self.pendingAttachment = .video(data, url)
                        self.showingAttachmentPreview = true
                        print("🎥 [ChatView] Video selected for preview")
                    }
                } catch {
                    print("❌ Failed to read video data: \(error)")
                }
            }
        } else {
            // 이미지 처리
            item.itemProvider.loadObject(ofClass: UIImage.self) { reading, error in
                if let error = error {
                    print("❌ Failed to load image: \(error.localizedDescription)")
                    return
                }

                if let image = reading as? UIImage {
                    Task { @MainActor in
                        // 미리보기 표시
                        self.pendingAttachment = .image(image)
                        self.showingAttachmentPreview = true
                        print("🖼️ [ChatView] Image selected for preview")
                    }
                }
            }
        }
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
                // 첨부 파일 버튼
                Menu {
                    Button {
                        openPhotosAttachment()
                    } label: {
                        Label(localizedText("photos_videos"), systemImage: "photo.on.rectangle")
                    }

                    Button {
                        showingDocumentPicker = true
                    } label: {
                        Label(localizedText("file"), systemImage: "doc")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.appPrimary)
                        .font(.system(size: 28))
                }

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

    // MARK: - Localization (delegated to LocalizationService)
    private func localizedText(_ key: String) -> String {
        // Try to convert string key to LocalizationKey enum
        guard let locKey = LocalizationKey(rawValue: key) else {
            return key // Fallback for unknown keys
        }
        let language: Language = (languageManager.currentLanguage == .korean) ? .korean : .english
        return LocalizationService.shared.text(for: locKey, language: language)
    }
}

// MARK: - Alert Modifiers
// Note: Alert Modifiers have been moved to ChatViewAlertModifiers.swift for better modularity


// MARK: - Supporting Components
// Note: PendingAttachment, PhotoPickerView, AttachmentPreviewView, LocationManager, etc.
// have been moved to ChatViewSupportingViews.swift and AttachmentHandler.swift
