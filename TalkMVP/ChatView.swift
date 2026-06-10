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
import LinkPresentation
import UIKit
import Contacts

// Wraps ChatViewModel as @StateObject so ChatView re-renders on every @Published change.
// Direct @StateObject for an optional is not supported in SwiftUI — this box bridges the gap.
@MainActor
final class ChatViewModelContainer: ObservableObject {
    @Published private(set) var viewModel: ChatViewModel?
    private var cancellable: AnyCancellable?

    func install(_ vm: ChatViewModel) {
        viewModel = vm
        // Forward the viewModel's objectWillChange into this container so
        // any @Published mutation in ChatViewModel triggers a ChatView redraw.
        cancellable = vm.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
    }
}

struct ChatView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var languageManager: LanguageManager

    let chatRoom: ChatRoom

    // MARK: - View Model
    // box is internal (not private) so ChatView extensions in other files can call box.install()
    @StateObject var box = ChatViewModelContainer()
    var viewModel: ChatViewModel? { box.viewModel }
    @StateObject var chatService: ChatService

    // MARK: - Input
    @FocusState var isTextFieldFocused: Bool
    @State var inputText: String = ""
    @State var replyingToMessage: Message?

    // MARK: - Message Actions
    @State var reactionToMessage: Message?
    @State var showingReactionPicker = false
    @State var editingMessage: Message?
    @State var showingEditAlert = false
    @State var editingText: String = ""

    // MARK: - Attachments
    @State var pendingAttachment: PendingAttachment?
    @State var showingAttachmentPreview = false
    @State var showingPhotosPicker = false
    @State var showingPhotosPermissionAlert = false
    @State var showingDocumentPicker = false

    // MARK: - Friends
    @State var isFriend = false
    @State var friendRequestSent = false
    @State var isBlocked = false
    @State var showingAddFriendAlert = false
    @State var addFriendEmail = ""
    @State var showingFriendProfile = false
    @State var profileFriendship: Friendship?

    // MARK: - Search & Summary
    @State var searchText: String = ""
    @State var showingSummarySheet = false
    @State var summaryText: String = ""
    @State var isSummaryLoading = false

    // MARK: - Bookmarks
    @State var showingBookmarks = false

    // MARK: - Scheduled Send
    @State var showingSchedulePicker = false
    @State var scheduledSendDate = Date()

    // MARK: - Disappearing Messages
    @State var showingDisappearingPicker = false
    @State var poppingMessageIds: Set<UUID> = []

    // MARK: - Voice Recording
    @StateObject var voiceService = VoiceMessageService()

    // MARK: - Location
    @StateObject var locationManager = LocationManager()
    @State var pendingLocationSend = false

    // MARK: - Contacts Sync
    @StateObject private var contactsSync = ContactsSyncService()
    @State var showingContactsResult = false
    @State var matchedUsers: [MatchedUser] = []
    @State var showingContactsPermissionAlert = false

    // MARK: - Moderation
    @State var showingReportAlert = false
    @State var showingBlockAlert = false
    @State var suspiciousLinkDetected = false
    @State var linkToVerify: String?
    @State var ignoredDomains: Set<String> = []

    // MARK: - Background & Presentation
    @State var showingBackgroundSettings = false
    @State var showingLocationPermissionAlert = false

    // MARK: - Emergency Alert
    @State var showingEmergencyAlert = false

    // MARK: - AI Settings
    @AppStorage("aiSummaryEnabled") var aiSummaryEnabled = false
    @AppStorage("aiSearchEnabled") var aiSearchEnabled = true
    @AppStorage("aiAutoMeetingNotesEnabled") var aiAutoMeetingNotesEnabled = false

    // MARK: - Translation Settings
    @AppStorage("translationEnabled") var translationEnabled = false
    @AppStorage("translationAutoDetect") var translationAutoDetect = true
    @AppStorage("translationTargetLanguage") var translationTargetLanguage = "auto"
    @AppStorage("translationShowOriginal") var translationShowOriginal = true

    // MARK: - Date Formatters (cached, internal so extensions can access via Self.)
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeStyle = .short
        return formatter
    }()

    static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    static let safeDomains: Set<String> = [
        "apple.com", "google.com", "naver.com", "daum.net", "kakao.com", "youtube.com", "icloud.com"
    ]

    // Shared in-memory context used only during init — replaced by the environment's
    // shared context in setupViewModelIfNeeded() before any real I/O happens.
    private static let initServiceContext: ModelContext = {
        let schema = Schema([Message.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
            fatalError("Cannot create ChatService initialization container")
        }
        return container.mainContext
    }()

    init(chatRoom: ChatRoom, chatService: ChatService? = nil) {
        self.chatRoom = chatRoom
        self._chatService = StateObject(wrappedValue: chatService ?? ChatService(modelContext: Self.initServiceContext))
    }

    // MARK: - Summary Sheet

    @ViewBuilder
    private var summarySheetContent: some View {
        if isSummaryLoading {
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text(languageManager.localize(ko: "요약 생성 중...", en: "Generating summary...", ja: "要約を生成中...", zh: "正在生成摘要...", es: "Generando resumen..."))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(summaryParagraphs, id: \.self) { paragraph in
                        SummaryParagraphCard(text: paragraph)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
        }
    }

    private var summaryParagraphs: [String] {
        summaryText
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Body

    private var baseScaffold: some View {
        VStack(spacing: 0) {
            ConnectionStatusView(chatService: chatService)
                .accessibilityLabel(localizedText("connection_status"))
                .accessibilityIdentifier("connectionStatus")

            mainContentView
        }
        .navigationTitle(chatRoom.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                onlineStatusTitleView
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingBackgroundSettings = true
                    } label: {
                        Label(languageManager.localize(ko: "배경 설정", en: "Background", ja: "背景設定", zh: "背景设置", es: "Fondo"), systemImage: "photo.fill")
                    }

                    Button {
                        toggleChatNotifications()
                    } label: {
                        Label(
                            chatRoom.notificationsEnabled ?
                                languageManager.localize(ko: "알림 끄기", en: "Mute", ja: "通知オフ", zh: "静音", es: "Silenciar") :
                                languageManager.localize(ko: "알림 켜기", en: "Unmute", ja: "通知オン", zh: "取消静音", es: "Activar"),
                            systemImage: chatRoom.notificationsEnabled ? "bell.slash.fill" : "bell.fill"
                        )
                    }

                    Button {
                        showingBookmarks = true
                    } label: {
                        Label(languageManager.localize(ko: "북마크", en: "Bookmarks", ja: "ブックマーク", zh: "书签", es: "Marcadores"), systemImage: "bookmark")
                    }

                    Button {
                        showingDisappearingPicker = true
                    } label: {
                        Label(languageManager.localize(ko: "자폭 메시지", en: "Disappearing", ja: "消えるメッセージ", zh: "阅后即焚", es: "Mensajes efímeros"), systemImage: "flame")
                    }

                    if aiSummaryEnabled {
                        Button {
                            generateSummary()
                        } label: {
                            Label(languageManager.localize(ko: "대화 요약", en: "Summarize", ja: "会話要約", zh: "对话摘要", es: "Resumir"), systemImage: "text.quote")
                        }
                    }

                    if !isFriend && !friendRequestSent && chatRoom.otherUserId != nil {
                        Button {
                            showingAddFriendAlert = true
                        } label: {
                            Label(languageManager.localize(ko: "친구 추가", en: "Add Friend", ja: "友達追加", zh: "添加好友", es: "Agregar amigo"), systemImage: "person.badge.plus")
                        }
                    }

                    if isBlocked && chatRoom.otherUserId != nil {
                        Button {
                            unblockUser()
                        } label: {
                            Label(languageManager.localize(ko: "차단 해제", en: "Unblock", ja: "ブロック解除", zh: "解除屏蔽", es: "Desbloquear"), systemImage: "hand.raised.slash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.appPrimary)
                        .accessibilityLabel(localizedText("more_options"))
                }
            }
        }
        .background(chatRoomBackground)
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
            },
            onBlock: {
                blockUser()
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
                viewModel?.stopOnlineStatusPolling()
            }
            .alert(
                localizedText("error_title"),
                isPresented: Binding(
                    get: { box.viewModel?.errorMessage != nil },
                    set: { if !$0 { box.viewModel?.errorMessage = nil } }
                )
            ) {
                Button(localizedText("ok")) { box.viewModel?.errorMessage = nil }
            } message: {
                Text(box.viewModel?.errorMessage ?? "")
            }
            .dynamicTypeSize(dynamicTypeSize.isAccessibilitySize ? .accessibility3 : dynamicTypeSize)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: localizedText("search_conversation"))
            .sheet(isPresented: $showingSummarySheet) {
                NavigationStack {
                    summarySheetContent
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
            .sheet(isPresented: $showingBackgroundSettings) {
                ChatRoomBackgroundSettings(chatRoom: chatRoom)
                    .environmentObject(languageManager)
            }
            .sheet(isPresented: $showingBookmarks) {
                BookmarkedMessagesSheet(
                    messages: viewModel?.messages.filter { $0.isBookmarked } ?? [],
                    chatRoomName: chatRoom.name,
                    onDismiss: { showingBookmarks = false }
                )
                .environmentObject(languageManager)
            }
            .sheet(isPresented: $showingDisappearingPicker) {
                DisappearingMessagePickerSheet(
                    chatRoom: chatRoom,
                    onDismiss: { showingDisappearingPicker = false }
                )
                .environmentObject(languageManager)
            }
            .sheet(isPresented: $showingSchedulePicker) {
                ScheduledSendSheet(
                    scheduledDate: $scheduledSendDate,
                    onConfirm: { date in
                        if let vm = viewModel {
                            scheduleMessage(viewModel: vm, sendAt: date)
                        }
                        showingSchedulePicker = false
                    },
                    onCancel: { showingSchedulePicker = false }
                )
                .environmentObject(languageManager)
            }
            .onChange(of: locationManager.currentLocation) { _, location in
                guard pendingLocationSend, let location else { return }
                pendingLocationSend = false
                viewModel?.sendLocationMessage(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            }
            .task {
                while !Task.isCancelled {
                    checkDisappearingMessages()
                    if let vm = viewModel { checkAndSendScheduled(viewModel: vm) }
                    try? await Task.sleep(for: .seconds(15))
                }
            }
    }

    // MARK: - Online Status Title

    @ViewBuilder
    private var onlineStatusTitleView: some View {
        if let vm = box.viewModel {
            VStack(spacing: 1) {
                Text(chatRoom.name)
                    .font(.headline)

                HStack(spacing: 4) {
                    Circle()
                        .fill(vm.isOnline ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(vm.isOnline
                        ? languageManager.localize(ko: "온라인", en: "Online", ja: "オンライン", zh: "在线", es: "En línea")
                        : languageManager.localize(ko: "오프라인", en: "Offline", ja: "オフライン", zh: "离线", es: "Sin conexión"))
                        .font(.caption)
                        .foregroundColor(vm.isOnline ? .green : .secondary)
                }
                .animation(.easeInOut(duration: 0.4), value: vm.isOnline)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(chatRoom.name), \(vm.isOnline ? languageManager.localize(ko: "온라인", en: "Online", ja: "オンライン", zh: "在线", es: "En línea") : languageManager.localize(ko: "오프라인", en: "Offline", ja: "オフライン", zh: "离线", es: "Sin conexión"))")
        } else {
            Text(chatRoom.name)
                .font(.headline)
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var chatRoomBackground: some View {
        switch chatRoom.backgroundType {
        case "color":
            if let hexColor = chatRoom.backgroundColor,
               let color = Color(hex: hexColor) {
                color.ignoresSafeArea()
            } else {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            }

        case "gradient":
            if let startHex = chatRoom.gradientStartColor,
               let endHex = chatRoom.gradientEndColor,
               let startColor = Color(hex: startHex),
               let endColor = Color(hex: endHex) {
                LinearGradient(
                    colors: [startColor, endColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            } else {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            }

        case "image":
            if let imageData = chatRoom.backgroundImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            }

        default:
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var mainContentView: some View {
        if let viewModel = viewModel {
            chatContentView(viewModel: viewModel)
        } else {
            ProgressView(localizedText("loading"))
        }
    }
}
