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
    @State private var profileFriendship: Friendship? = nil

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
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.timeStyle = .short
        return f
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateStyle = .short
        f.timeStyle = .short
        return f
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
            let tempContext = try! ModelContainer(for: Message.self).mainContext
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
                .accessibilityLabel("연결 상태")
                .accessibilityIdentifier("connectionStatus")
            
            mainContentView
        }
        .navigationTitle(chatRoom.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        openPhotosAttachment()
                    } label: {
                        Image(systemName: "paperclip")
                    }
                    .accessibilityLabel("첨부")

                    Button {
                        showingFriendProfile = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("프로필 보기")
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear {
            setupViewModelIfNeeded()
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
            .alert("연락처 접근 권한 필요", isPresented: $showingContactsPermissionAlert) {
                Button("취소", role: .cancel) {}
                Button("설정 열기") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            } message: {
                Text("친구를 찾기 위해 연락처 접근 권한이 필요합니다. 설정에서 허용해 주세요.")
            }
            .alert("사진 접근 권한 필요", isPresented: $showingPhotosPermissionAlert) {
                Button("취소", role: .cancel) {}
                Button("설정 열기") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
            } message: {
                Text("사진과 동영상을 첨부하려면 사진 접근 권한이 필요합니다. 설정에서 허용해 주세요.")
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("채팅 화면")
            .accessibilityHint("\(chatRoom.name)과의 채팅 화면입니다")
            .accessibilityIdentifier("chatView")
            .onDisappear {
                viewModel?.stopTyping()
                emergencyTimer?.invalidate()
                emergencyTimer = nil
            }
            // 다이나믹 타입 지원
            .dynamicTypeSize(dynamicTypeSize.isAccessibilitySize ? .accessibility3 : dynamicTypeSize)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "대화 검색")
            .sheet(isPresented: $showingSummarySheet) {
                NavigationStack {
                    ScrollView {
                        Text(summaryText)
                            .font(.body)
                            .foregroundColor(.primary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .navigationTitle("대화 요약")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("완료") { showingSummarySheet = false }
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
                }
            }
            .sheet(isPresented: $showingContactsResult) {
                NavigationStack {
                    List(matchedUsers) { user in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.displayName).font(.body)
                            Text("매칭: \(user.matchedBy)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .navigationTitle("연락처 매칭 결과")
                    .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("닫기") { showingContactsResult = false } } }
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
                            .accessibilityLabel("\(chatRoom.name)이 입력 중입니다")
                            .accessibilityIdentifier("typingIndicator")
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .accessibilityLabel("메시지 목록")
            .accessibilityHint("위아래로 스크롤하여 메시지를 확인할 수 있습니다")
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
                    Button("답장") {
                        replyingToMessage = message
                        isTextFieldFocused = true
                        
                        // 햅틱 피드백
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                    .tint(.blue)
                }
                .contextMenu {
                    if message.messageType == .text {
                        Button("복사", systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = message.text
                            UIAccessibility.post(notification: .announcement, argument: "메시지를 복사했습니다")
                        }
                    }
                    Button("답장", systemImage: "arrowshape.turn.up.left") {
                        replyingToMessage = message
                        isTextFieldFocused = true
                    }
                    Button("반응 추가", systemImage: "face.smiling") {
                        showReactionPicker(for: message)
                    }
                    if message.isFromCurrentUser {
                        Button("편집", systemImage: "pencil") {
                            startEditingMessage(message)
                        }
                        Button("삭제", systemImage: "trash", role: .destructive) {
                            deleteMessage(message)
                        }
                    }
                    if !message.isFromCurrentUser {
                        Button("신고", systemImage: "exclamationmark.bubble") {
                            showingReportAlert = true
                        }
                        Button("차단", systemImage: "hand.raised") {
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
            }
        }
    }
    
    private func containsHangul(_ text: String) -> Bool {
        return text.unicodeScalars.contains { scalar in
            let v = scalar.value
            return (0xAC00...0xD7A3).contains(v) // Hangul Syllables
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
        // Always show if user explicitly enabled translation
        if translationEnabled { return true }
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
        let t = translationTargetLanguage.lowercased()
        if t != "auto" { return t }
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
            viewModel?.loadMessages()
        }
    }
    
    // MARK: - Message Input View
    @ViewBuilder
    private func messageInputView(viewModel: ChatViewModel) -> some View {
        VStack(spacing: 0) {
            if let replyingTo = replyingToMessage {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(replyingTo.isFromCurrentUser ? "나" : chatRoom.name)에게 답장")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(replyingTo.text)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button("취소") {
                        replyingToMessage = nil
                    }
                    .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemGroupedBackground))
            }
            
            HStack(spacing: 12) {
                TextField("메시지 입력", text: $inputText)
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
                        .background(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
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
        let sender = message.isFromCurrentUser ? "나" : chatRoom.name
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
}

// MARK: - Alert Modifiers (to reduce type-checking complexity)
struct EditMessageAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var editingText: String
    @Binding var editingMessage: Message?
    let onSave: (Message, String) -> Void

    func body(content: Content) -> some View {
        content.alert("메시지 편집", isPresented: $isPresented) {
            TextField("메시지", text: $editingText)
            Button("취소", role: .cancel) {
                editingMessage = nil
                editingText = ""
            }
            Button("저장") {
                if let message = editingMessage {
                    let newText = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !newText.isEmpty {
                        onSave(message, newText)
                    }
                }
                editingMessage = nil
                editingText = ""
                UIAccessibility.post(notification: .announcement, argument: "메시지를 편집했습니다")
            }
        } message: {
            Text("메시지를 수정하세요")
        }
    }
}

struct EmergencyAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    func body(content: Content) -> some View {
        content.alert("긴급 호출", isPresented: $isPresented) {
            Button("확인") {}
        } message: {
            Text("긴급 호출이 시작되었습니다")
        }
    }
}

struct LocationPermissionAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let openSettings: () -> Void
    func body(content: Content) -> some View {
        content.alert("위치 권한 필요", isPresented: $isPresented) {
            Button("취소", role: .cancel) {}
            Button("설정 열기") { openSettings() }
        } message: {
            Text("긴급 호출을 위해 위치 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요.")
        }
    }
}

struct ReportAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let name: String
    func body(content: Content) -> some View {
        content.alert("사용자 신고", isPresented: $isPresented) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("\(name)을(를) 신고했습니다. 검토 후 조치하겠습니다.")
        }
    }
}

struct BlockAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let name: String
    func body(content: Content) -> some View {
        content.alert("사용자 차단", isPresented: $isPresented) {
            Button("취소", role: .cancel) {}
            Button("차단", role: .destructive) {
                // TODO: 차단 로직 연동
            }
        } message: {
            Text("\(name)의 메시지를 더 이상 받지 않습니다.")
        }
    }
}

struct SuspiciousLinkAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var linkToVerify: String?
    @Binding var ignoredDomains: Set<String>
    let openURL: (URL) -> Void

    func body(content: Content) -> some View {
        content.alert("검증되지 않은 정보", isPresented: $isPresented) {
            Button("취소", role: .cancel) {}
            if let link = linkToVerify, let url = URL(string: link) {
                Button("열기") { openURL(url) }
                if let host = url.host {
                    Button("항상 허용") {
                        ignoredDomains.insert(host)
                        UserDefaults.standard.set(Array(ignoredDomains), forKey: "ignoredDomains")
                    }
                }
            }
        } message: {
            Text(linkToVerify ?? "의심스러운 링크가 감지되었습니다")
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
    let message: Message?
    let onReactionSelected: (String) -> Void
    
    private let reactions = ["👍", "❤️", "😂", "😮", "😢", "😡", "👏", "🎉"]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("반응 추가")
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
                    .accessibilityLabel("반응: \(emoji)")
                }
            }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .padding()
    }
}

struct LinkPreviewView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> LPLinkView { LPLinkView(url: url) }
    func updateUIView(_ uiView: LPLinkView, context: Context) {}
}

struct TranslatedTextView: View {
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
                Text(isLoading ? "번역 중…" : translated)
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
}

struct OrgRoomSettingsView: View {
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
                Section(header: Text("조직방")) {
                    Toggle("조직방 활성화", isOn: $isOrgRoom)
                    TextField("조직명(선택)", text: $orgName)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }

                if isOrgRoom {
                    Section(header: Text("근무 시간"), footer: Text("간단히 요일과 시작/종료 시간을 설정하세요")) {
                        Picker("근무 요일", selection: $weekdayMode) {
                            ForEach(WeekdayMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        DatePicker("시작", selection: $startTime, displayedComponents: .hourAndMinute)
                        DatePicker("종료", selection: $endTime, displayedComponents: .hourAndMinute)

                        HStack {
                            Text("채널 타임존")
                            Spacer()
                            Text(room.timeZoneIdentifier)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("채널 설정")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") { saveAndDismiss() }
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
        if set == Set([2,3,4,5,6]) { weekdayMode = .weekdays }
        else if set == Set([1,2,3,4,5,6,7]) { weekdayMode = .daily }
        else { weekdayMode = .weekdays }

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
        let s = cal.dateComponents([.hour, .minute], from: startTime)
        let e = cal.dateComponents([.hour, .minute], from: endTime)
        room.workStartHour = s.hour ?? 9
        room.workStartMinute = s.minute ?? 0
        room.workEndHour = e.hour ?? 18
        room.workEndMinute = e.minute ?? 0
    }

    private func syncWeekdaysToRoom(mode: WeekdayMode) {
        switch mode {
        case .weekdays:
            room.workingDays = [2,3,4,5,6]
        case .daily:
            room.workingDays = [1,2,3,4,5,6,7]
        }
    }

    private func saveAndDismiss() {
        do { try modelContext.save() } catch { print("채널 설정 저장 실패: \(error)") }
        dismiss()
    }
}

struct MiniProfileSheet: View {
    let name: String
    let symbol: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
                    .padding(.top, 20)
                Text(name)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("프로필 정보를 불러올 수 없습니다")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("프로필")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("닫기") { dismiss() } } }
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

