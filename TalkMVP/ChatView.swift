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

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    
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
                toolbarContent
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
                handleDocumentSelection(url)
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
            if translationEnabled && !message.isFromCurrentUser && message.messageType == .text {
                TranslatedTextView(
                    text: message.text,
                    autoDetect: translationAutoDetect,
                    target: translationTargetLanguage,
                    showOriginal: translationShowOriginal
                )
                .frame(maxWidth: .infinity, alignment: message.isFromCurrentUser ? .trailing : .leading)
                .padding(.horizontal, 2)
            }
        }
    }
    
    @ViewBuilder
    private var toolbarContent: some View {
        HStack(spacing: 12) {
            if aiSummaryEnabled, let viewModel = viewModel {
                Button("요약") {
                    Task {
                        summaryText = await AIService.shared.summarize(messages: viewModel.messages)
                        showingSummarySheet = true
                    }
                }
                .font(.subheadline)
                .foregroundColor(.blue)
                .accessibilityLabel("대화 요약")
                .accessibilityHint("최근 대화를 요약해서 보여줍니다")
                .accessibilityIdentifier("summaryButton")
            }
            
            Button("연락처") {
                Task { await handleContactsSyncTapped() }
            }
            .font(.subheadline)
            .foregroundColor(.blue)
            .accessibilityLabel("연락처 동기화")
            .accessibilityHint("연락처를 서버와 매칭합니다")
            .accessibilityIdentifier("contactsSyncButton")
        }
    }
    
    private var mediaMenuButton: some View {
        Menu {
            Button(action: {
                openPhotosAttachment()
            }) {
                Label("사진/영상", systemImage: "photo")
                    .foregroundColor(.primary)
            }
            .accessibilityIdentifier("photoPickerOption")
            
            Button(action: {
                showingDocumentPicker = true
            }) {
                Label("파일", systemImage: "doc")
                    .foregroundColor(.primary)
            }
            .accessibilityIdentifier("documentPickerOption")
        } label: {
            Image(systemName: "plus.circle")
                .font(.title2)
                .foregroundColor(.secondary)
        }
        .accessibilityLabel("미디어 첨부")
        .accessibilityHint("사진, 파일 또는 음성 메시지를 첨부할 수 있습니다")
        .accessibilityIdentifier("mediaMenuButton")
    }
    
    private func setupViewModelIfNeeded() {
        if viewModel == nil {
            chatService.modelContext = modelContext
            viewModel = ChatViewModel(modelContext: modelContext, chatRoom: chatRoom, chatService: chatService)
            // Removed line: viewModel?.checkOnlineStatus()
        }
    }
    
    private func handlePhotoSelectionChange(_ newValue: PhotosPickerItem?) {
        if let newValue {
            Task {
                await handlePhotoSelection(newValue)
            }
        }
    }
    

    private func messageInputView(viewModel: ChatViewModel) -> some View {
        // 조직방/근무시간 상태 계산
        let isOrg = chatRoom.isOrganizationRoom
        let within = isWithinWorkingHours(for: chatRoom)
        let userId = "currentUser" // TODO: AuthManager에서 실제 사용자 ID 연동
        let userRole = chatRoom.role(for: userId)
        let emergencyAllowed = chatRoom.emergencyAllowedRoles.contains(userRole.rawValue)
        let canSendNow = !isOrg || within || (isEmergencyMessage && emergencyAllowed)

        return VStack(spacing: 8) {
            // 근무 시간 외 배너
            if isOrg && !within {
                Text("퇴근 시간 – 읽기 전용 (채널 타임존: \(chatRoom.timeZoneIdentifier))")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(Color(UIColor.systemGray6))
                    .accessibilityLabel("퇴근 시간. 읽기 전용")
            }

            // 답장 중일 때 표시되는 영역
            if let replyMessage = replyingToMessage {
                replyPreviewView(message: replyMessage)
            }

            // 근무 시간 외 긴급 토글 (권한 있는 역할만 활성화)
            if isOrg && !within {
                HStack {
                    Toggle("긴급", isOn: $isEmergencyMessage)
                        .disabled(!emergencyAllowed)
                    if !emergencyAllowed {
                        Text("관리자/온콜만 가능")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
            }

            HStack(spacing: 12) {
                // 미디어 메뉴 버튼
                mediaMenuButton

                // 텍스트 입력 필드 (권한/시간에 따라 비활성화)
                textInputField(viewModel: viewModel, isEnabled: canSendNow)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Color(UIColor.systemBackground)
                    .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: -1)
            )
            .animation(.easeInOut(duration: 0.2), value: viewModel.newMessageText.isEmpty)
        }
        .accessibilityAction(.magicTap) {
            sendCurrentMessage(with: viewModel)
        }
    }
    
    // 공통 전송 로직 추출
    private func sendCurrentMessage(with viewModel: ChatViewModel) {
        let trimmed = viewModel.newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // 조직방/근무시간 검사 및 긴급 권한 확인
        let isOrg = chatRoom.isOrganizationRoom
        let within = isWithinWorkingHours(for: chatRoom)
        let userId = "currentUser" // TODO: AuthManager 연동
        let userRole = chatRoom.role(for: userId)
        let emergencyAllowed = chatRoom.emergencyAllowedRoles.contains(userRole.rawValue)
        let canSendNow = !isOrg || within || (isEmergencyMessage && emergencyAllowed)
        guard canSendNow else {
            let impactFeedback = UINotificationFeedbackGenerator()
            impactFeedback.notificationOccurred(.warning)
            UIAccessibility.post(notification: .announcement, argument: "근무 시간 외에는 읽기 전용입니다")
            return
        }

        if let replyMessage = replyingToMessage {
            viewModel.setReplyMessage(replyMessage)
        }
        viewModel.sendMessage()
        replyingToMessage = nil
        isEmergencyMessage = false // 전송 후 긴급 토글 초기화
        UIAccessibility.post(notification: .announcement, argument: "메시지가 전송되었습니다")
    }
    
    @ViewBuilder
    private func replyPreviewView(message: Message) -> some View {
        HStack {
            Rectangle()
                .fill(Color.blue)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(message.isFromCurrentUser ? "나" : chatRoom.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
                Text(message.text)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: {
                replyingToMessage = nil
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.title3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .padding(.horizontal, 16)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity.combined(with: .move(edge: .top))
        ))
    }
    

    private func textInputField(viewModel: ChatViewModel, isEnabled: Bool) -> some View {
        let textBinding = Binding(
            get: { viewModel.newMessageText },
            set: { newValue in 
                viewModel.newMessageText = newValue
                if !newValue.isEmpty {
                    viewModel.startTyping()
                } else {
                    viewModel.stopTyping()
                }
            }
        )
        
        return HStack {
            TextField("메시지를 입력하세요", text: textBinding)
                .submitLabel(.send)
                .focused($isTextFieldFocused)
                .onSubmit {
                    sendCurrentMessage(with: viewModel)
                }
                .onChange(of: isTextFieldFocused) { _, isFocused in
                    if !isFocused {
                        viewModel.stopTyping()
                    }
                }
                .accessibilityLabel("메시지 입력")
                .accessibilityHint("메시지를 입력한 후 전송 버튼을 누르거나 Enter 키를 누르면 전송됩니다")
                .accessibilityIdentifier("messageTextField")
                // 다이나믹 타입 지원
                .font(.body)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 0.8 : 1.0)
            
            if !viewModel.newMessageText.isEmpty {
                Button(action: {
                    sendCurrentMessage(with: viewModel)
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .scaleEffect(1.0)
                        .animation(
                            reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.8), 
                            value: !viewModel.newMessageText.isEmpty
                        )
                }
                .glassEffect(.regular.tint(.blue).interactive())
                .accessibilityLabel("메시지 전송")
                .accessibilityHint("현재 입력된 메시지를 전송합니다")
                .accessibilityIdentifier("sendButton")
                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    isTextFieldFocused ? Color.blue.opacity(0.5) : Color.clear,
                    lineWidth: 2
                )
        )
        .animation(
            reduceMotion ? .none : .easeInOut(duration: 0.2), 
            value: isTextFieldFocused
        )
        .disabled(!isEnabled)
    }
    
    private func handlePhotoSelection(_ item: PhotosPickerItem) async {
        guard let viewModel = viewModel else { return }
        // Try to load a file URL first (videos are best handled as files)
        if let url = try? await item.loadTransferable(type: URL.self) {
            do {
                let fileName = url.deletingPathExtension().lastPathComponent
                let fileExtension = url.pathExtension
                let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
                let fileSize = resourceValues.fileSize ?? 0
                await MainActor.run {
                    viewModel.sendFile(fileName: fileName, fileExtension: fileExtension, fileSize: fileSize)
                    selectedPhoto = nil
                }
                return
            } catch {
                // Fallback to trying data below
            }
        }
        // If not a file URL, try loading as image data
        if let data = try? await item.loadTransferable(type: Data.self) {
            await MainActor.run {
                viewModel.sendImage(data)
                selectedPhoto = nil
            }
        }
    }
    
    private func handleDocumentSelection(_ url: URL) {
        guard let viewModel = viewModel else { return }
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

        let fileName = url.deletingPathExtension().lastPathComponent
        let fileExtension = url.pathExtension

        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
            let fileSize = resourceValues.fileSize ?? 0
            
            viewModel.sendFile(fileName: fileName, fileExtension: fileExtension, fileSize: fileSize)
        } catch {
            print("파일 정보를 읽을 수 없습니다: \(error)")
        }
    }
    
    @MainActor
    private func handleContactsSyncTapped() async {
        switch contactsSync.checkAuthorizationStatus() {
        case .notDetermined:
            let granted = await contactsSync.requestAccess()
            if !granted {
                showingContactsPermissionAlert = true
                return
            }
        case .denied:
            showingContactsPermissionAlert = true
            return
        case .authorized:
            break
        }
        do {
            let matched = try await contactsSync.syncAndMatch()
            self.matchedUsers = matched
            self.showingContactsResult = true
        } catch {
            // Present a lightweight error as an announcement; could be improved to an alert if desired
            UIAccessibility.post(notification: .announcement, argument: "연락처 동기화에 실패했습니다")
        }
    }
    
    private func openFriendProfile() {
        let targetName = chatRoom.name
        let descriptor = FetchDescriptor<Friendship>(
            predicate: #Predicate<Friendship> { f in
                f.friendName == targetName
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        if let results = try? modelContext.fetch(descriptor),
           let fs = results.first(where: { $0.status == .accepted }) {
            profileFriendship = fs
        } else {
            profileFriendship = nil
        }
        showingFriendProfile = true
    }
    
    // MARK: - 접근성 헬퍼 함수들
    
    /// 첫 번째 URL 추출 헬퍼
    private func firstURL(in text: String) -> URL? {
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = detector.firstMatch(in: text, options: [], range: range), let url = match.url {
                return url
            }
        }
        return nil
    }
    
    /// 반응 선택기 표시
    private func showReactionPicker(for message: Message) {
        reactionToMessage = message
        showingReactionPicker = true
        
        // 햅틱 피드백
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    /// 메시지에 반응 추가
    private func addReaction(emoji: String, to message: Message) {
        viewModel?.toggleReaction(emoji, for: message)
        
        // 접근성 공지
        UIAccessibility.post(notification: .announcement, argument: "메시지에 \(emoji) 반응을 추가했습니다")
    }
    
    /// 메시지 편집 시작
    private func startEditingMessage(_ message: Message) {
        editingMessage = message
        editingText = message.text
        showingEditAlert = true
    }
    
    /// 메시지 삭제
    private func deleteMessage(_ message: Message) {
        viewModel?.deleteMessage(message)
        
        // 햅틱 피드백
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // 접근성 공지
        UIAccessibility.post(notification: .announcement, argument: "메시지를 삭제했습니다")
    }
    
    /// 메시지별 접근성 레이블 생성
    private func accessibilityLabelForMessage(_ message: Message) -> String {
        let senderInfo = message.isFromCurrentUser ? "내가 보낸 메시지" : "\(chatRoom.name)이 보낸 메시지"
        let timeInfo = formatMessageTime(message.timestamp)
        
        switch message.messageType {
        case .text:
            return "\(senderInfo), \(timeInfo), \(message.text)"
        case .image:
            return "\(senderInfo), \(timeInfo), 이미지 메시지"
        case .file:
            return "\(senderInfo), \(timeInfo), 파일 메시지: \(message.text)"
        case .audio:
            return "\(senderInfo), \(timeInfo), 음성 메시지"
        case .deleted:
            return "\(senderInfo), \(timeInfo), 삭제된 메시지"
        }
    }
    
    /// 메시지 시간 포맷팅
    private func formatMessageTime(_ timestamp: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(timestamp, inSameDayAs: Date()) {
            return "오늘 \(ChatView.timeFormatter.string(from: timestamp))"
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()),
                  calendar.isDate(timestamp, inSameDayAs: yesterday) {
            return "어제 \(ChatView.timeFormatter.string(from: timestamp))"
        } else {
            return ChatView.dateTimeFormatter.string(from: timestamp)
        }
    }
    
    private func detectSuspiciousLinkInLastMessage(viewModel: ChatViewModel) {
        guard let last = viewModel.messages.last, last.messageType == .text else { return }
        let text = last.text
        if let url = firstURL(in: text), let host = url.host?.lowercased() {
            if ChatView.safeDomains.contains(where: { host.hasSuffix($0) }) { return }
            if ignoredDomains.contains(where: { host.hasSuffix($0) }) { return }
            linkToVerify = url.absoluteString
            suspiciousLinkDetected = true
        }
    }
    
    private func callGuardianAndShareLocation() {
        if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
            showingLocationPermissionAlert = true
            return
        }
        locationManager.requestLocation()
        // 이후 위치 전달 및 긴급 호출 기능 구현
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

