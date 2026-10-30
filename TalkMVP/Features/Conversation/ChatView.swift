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
import NaturalLanguage
import UIKit

struct ChatView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.prefersReducedMotion) var reduceMotion
    @Environment(\.openURL) private var openURL
    @Environment(LanguageManager.self) var languageManager

    let chatRoom: ChatRoom

    // MARK: - View Model
    // Internal (not private) so the ChatView extensions in other files can install it.
    @State var viewModel: ChatViewModel?
    @State var chatService: ChatService

    // MARK: - Input
    @FocusState var isTextFieldFocused: Bool
    @State var inputText: String = ""
    @State var replyingToMessage: Message?

    // MARK: - Message Actions
    @State var reactionToMessage: Message?
    /// What each translated message's translation says once shown, for reading it out.
    @State var translatedTexts: [UUID: String] = [:]
    @State var showingReactionPicker = false
    @State var editingMessage: Message?
    @State var showingEditAlert = false
    @State var editingText: String = ""

    // MARK: - Attachments
    @State var pendingAttachment: PendingAttachment?
    @State var showingAttachmentPreview = false
    @State var showingPhotosPicker = false
    @State var showingDocumentPicker = false

    // MARK: - Friends
    @State var isFriend = false
    @State var friendRequestSent = false
    @State var isBlocked = false
    @State var showingAddFriendAlert = false
    @State var addFriendEmail = ""
    @State var showingFriendProfile = false
    @State var profileFriendship: Friendship?
    /// The group member whose profile is open, with their friendship if they are a friend.
    @State var profileMember: (name: String, friendship: Friendship?)?
    /// How the user stands with each sender in this conversation, by name: one fetch for
    /// every bubble. Nil until loaded.
    @State var senderStandings: [String: FriendStanding]?

    // MARK: - Search & Summary
    @State var searchText: String = ""
    /// Whether the search field is on screen; it shows only when Search is chosen.
    @State var isSearchShown = false
    @State var showingGroupInfo = false
    @State var showingSummarySheet = false
    @State var showingMeetingNotes = false
    /// The summary and meeting notes, as the two sheets show them.
    @State var aiResults = ChatAIResults()

    // MARK: - Bookmarks
    @State var showingBookmarks = false

    // MARK: - Scheduled Send
    @State var showingSchedulePicker = false
    @State var scheduledSendDate = Date()

    // MARK: - Disappearing Messages
    @State var showingDisappearingPicker = false
    @State var poppingMessageIds: Set<UUID> = []

    // MARK: - Voice Recording
    @State var voiceService = VoiceMessageService()

    // MARK: - Location
    @State var locationManager = LocationManager()
    @State var pendingLocationSend = false

    // MARK: - Moderation
    @State var showingReportAlert = false
    @State var showingBlockAlert = false

    // MARK: - Background & Presentation
    @State var showingBackgroundSettings = false
    @State var showingLocationPermissionAlert = false

    // MARK: - AI Settings
    @AppStorage(AIFeatureSettings.summary.key) var aiSummaryEnabled = AIFeatureSettings.summary.defaultValue
    @AppStorage(AIFeatureSettings.meetingNotes.key) var aiAutoMeetingNotesEnabled = AIFeatureSettings.meetingNotes.defaultValue

    // MARK: - Translation Settings
    @AppStorage(TranslationPreferences.enabledKey) var translationEnabled = TranslationPreferences.enabledByDefault
    @AppStorage("translationAutoDetect") var translationAutoDetect = true
    @AppStorage("translationTargetLanguage") var translationTargetLanguage = "auto"

    // MARK: - Date Formatters (cached, internal so extensions can access via Self.)
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeStyle = .short
        return formatter
    }()

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
        self._chatService = State(initialValue: chatService ?? ChatService(modelContext: Self.initServiceContext))
    }

    // MARK: - Summary Sheet

    @ViewBuilder
    private var summarySheetContent: some View {
        if aiResults.isSummaryLoading {
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text(summaryLoadingText)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // The sheet's title names it; the first line says when it was written and
                    // how much it read, marked as the on-device model's work.
                    if summaryParagraphs.count > 1, let heading = summaryParagraphs.first {
                        Label(heading, systemImage: "apple.intelligence")
                            .font(.footnote)
                            .foregroundStyle(Color.secondary)
                    }
                    ForEach(summaryParagraphs.count > 1 ? Array(summaryParagraphs.dropFirst()) : summaryParagraphs, id: \.self) { paragraph in
                        SummaryParagraphCard(text: paragraph)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
        }
    }

    private var summaryLoadingText: String {
        switch aiResults.summaryProgress {
        case .readingPart(let index, let count):
            String(format: languageManager.localize(ko: "긴 대화를 나눠 읽는 중… (%d/%d)", en: "Reading a long chat in parts… (%d/%d)", ja: "長い会話を分けて読んでいます… (%d/%d)", zh: "正在分段阅读长对话… (%d/%d)", es: "Leyendo un chat largo por partes… (%d/%d)"), index, count)
        case .writing:
            languageManager.localize(ko: "요약 정리 중…", en: "Writing the summary…", ja: "要約をまとめています…", zh: "正在整理摘要…", es: "Redactando el resumen…")
        case nil:
            languageManager.localize(ko: "요약 생성 중...", en: "Generating summary...", ja: "要約を生成中...", zh: "正在生成摘要...", es: "Generando resumen...")
        }
    }

    private var summaryParagraphs: [String] {
        aiResults.summaryText
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Body

    private var baseScaffold: some View {
        VStack(spacing: 0) {
            FriendBannerView(banner: friendBanner, name: chatRoom.name) {
                showingAddFriendAlert = true
            }

            mainContentView
        }
        .navigationTitle(chatRoom.name)
        .navigationBarTitleDisplayMode(.inline)
        // As in Messages, a conversation on a phone has the screen to itself: its bottom edge
        // is the input field. Wide windows keep the tabs beside the chat list.
        .toolbar(horizontalSizeClass == .compact ? .hidden : .automatic, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                // As in Messages, the name at the top opens what the chat is about.
                Button(action: openTitle) { titleView }
                    .buttonStyle(.plain)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        // The message field lets go first, or the two fight over the keyboard
                        // and the search field never gets it.
                        isTextFieldFocused = false
                        isSearchShown = true
                    } label: {
                        Label(languageManager.localize(ko: "검색", en: "Search", ja: "検索", zh: "搜索", es: "Buscar"), systemImage: "magnifyingglass")
                    }

                    Toggle(isOn: translationHereBinding) {
                        Label(languageManager.localize(ko: "메시지 번역", en: "Translate Messages", ja: "メッセージを翻訳", zh: "翻译消息", es: "Traducir mensajes"), systemImage: "translate")
                    }

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

                    if aiAutoMeetingNotesEnabled {
                        Button {
                            generateMeetingNotes()
                        } label: {
                            Label(languageManager.localize(ko: "회의 노트", en: "Meeting Notes", ja: "会議メモ", zh: "会议记录", es: "Notas de reunión"), systemImage: "note.text")
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
                        .foregroundStyle(.appPrimaryText)
                        .accessibilityLabel(localizedText("more_options"))
                }
            }
        }
        .background(chatRoomBackground)
        .onAppear {
            setupViewModelIfNeeded()
            checkIfFriend()
            loadSenderStandings()
            markMessagesAsRead()
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
            showingLocationPermissionAlert: $showingLocationPermissionAlert,
            showingReportAlert: $showingReportAlert,
            showingBlockAlert: $showingBlockAlert,
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
            .alert(localizedText("add_friend_title"), isPresented: $showingAddFriendAlert) {
                Button(localizedText("cancel"), role: .cancel) {}
                Button(localizedText("add")) {
                    requestFriendship()
                }
            } message: {
                Text(String(format: localizedText("add_friend_message"), chatRoom.name))
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(localizedText("chat_screen"))
            .accessibilityHint(String(format: localizedText("chat_screen_hint"), chatRoom.name))
            .accessibilityIdentifier("chatView")
            .alert(
                localizedText("error_title"),
                isPresented: Binding(
                    get: { viewModel?.errorMessage != nil },
                    set: { if !$0 { viewModel?.errorMessage = nil } }
                )
            ) {
                Button(localizedText("ok")) { viewModel?.errorMessage = nil }
            } message: {
                Text(viewModel?.errorMessage ?? "")
            }
            .modifier(SearchWhenShown(text: $searchText, isShown: $isSearchShown, prompt: localizedText("search_conversation")))
            .task(id: searchText) { await viewModel?.expandSearch(for: searchText) }
            .sheet(isPresented: $showingSummarySheet) {
                NavigationStack {
                    summarySheetContent
                        .navigationTitle(localizedText("conversation_summary"))
                        .navigationBarTitleDisplayMode(.large)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(localizedText("done")) { showingSummarySheet = false }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingMeetingNotes) {
                NavigationStack {
                    MeetingNotesView(notes: aiResults.meetingNotes, isLoading: aiResults.isMeetingNotesLoading)
                        .navigationTitle(MeetingNotesView.labels(languageManager).title)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                if let notes = aiResults.meetingNotes, !aiResults.isMeetingNotesLoading, !notes.isEmpty {
                                    ShareLink(item: notes.shareText(labels: MeetingNotesView.labels(languageManager)))
                                }
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(localizedText("done")) { showingMeetingNotes = false }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingFriendProfile) {
                if let profileMember {
                    if let friendship = profileMember.friendship {
                        NavigationStack { FriendProfileView(friendship: friendship, showsCloseButton: true) }
                    } else {
                        MiniProfileSheet(
                            name: profileMember.name,
                            standing: senderStandings?[profileMember.name] ?? .stranger,
                            onAddFriend: { try sendFriendRequest(toSender: profileMember.name) }
                        )
                        .environment(languageManager)
                    }
                } else if let friendship = profileFriendship {
                    NavigationStack { FriendProfileView(friendship: friendship, isInChatWithThisPerson: true, showsCloseButton: true) }
                } else {
                    MiniProfileSheet(
                        name: chatRoom.name,
                        standing: oneToOneStanding,
                        onAddFriend: { try sendFriendRequestToOtherSide() }
                    )
                    .environment(languageManager)
                }
            }
            .sheet(isPresented: $showingGroupInfo) {
                GroupInfoSheet(
                    name: chatRoom.name,
                    members: chatRoom.memberNames,
                    languageBadges: languageBadges(in: viewModel?.messages ?? []),
                    standings: senderStandings ?? [:],
                    onAddFriend: { try sendFriendRequest(toSender: $0) }
                )
                .environment(languageManager)
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
                .environment(languageManager)
            }
            .sheet(isPresented: $showingBackgroundSettings) {
                ChatRoomBackgroundSettings(chatRoom: chatRoom)
                    .environment(languageManager)
            }
            .sheet(isPresented: $showingBookmarks) {
                BookmarkedMessagesSheet(
                    messages: viewModel?.messages.filter { $0.isBookmarked } ?? [],
                    chatRoomName: chatRoom.name,
                    onDismiss: { showingBookmarks = false }
                )
                .environment(languageManager)
            }
            .sheet(isPresented: $showingDisappearingPicker) {
                DisappearingMessagePickerSheet(
                    chatRoom: chatRoom,
                    onDismiss: { showingDisappearingPicker = false }
                )
                .environment(languageManager)
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
                .environment(languageManager)
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
                    viewModel?.sendDueScheduledMessages()
                    try? await Task.sleep(for: .seconds(15))
                }
            }
    }

    // MARK: - Title

    /// The name, and under it what the app knows about the chat: a group's members, or the
    /// language the other person writes in.
    private var titleView: some View {
        VStack(spacing: 1) {
            Text(chatRoom.name)
                .font(.headline)
            if let chatSubtitle {
                Text(chatSubtitle)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var chatSubtitle: String? {
        let received = (viewModel?.messages ?? []).suffix(20).map(SummaryMessage.init)
        return ChatSubtitle.text(
            isGroup: chatRoom.isGroup,
            memberNames: chatRoom.memberNames,
            partnerLanguage: ConversationLanguage.of(sender: nil, in: received)?.rawValue,
            readerLanguage: appLanguageCode(),
            isTranslating: isTranslatingHere,
            translatedLabel: localizedText("translated"),
            originalLabel: localizedText("original")
        )
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
