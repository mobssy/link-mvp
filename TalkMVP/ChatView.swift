//
//  ChatView.swift
//  L!nkMVP
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
    @Environment(\.modelContext) var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var languageManager: LanguageManager

    let chatRoom: ChatRoom

    // MARK: - View Model
    @State var viewModel: ChatViewModel?
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
    @State var showingAddFriendAlert = false
    @State var addFriendEmail = ""
    @State var showingFriendProfile = false
    @State var profileFriendship: Friendship?

    // MARK: - Search & Summary
    @State var searchText: String = ""
    @State var showingSummarySheet = false
    @State var summaryText: String = ""

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

    // MARK: - Emergency / Accessibility Features
    @State var isEmergencyMessage = false
    @State var emergencyButtonPressed = false
    @State var emergencyTimer: Timer?
    @State var emergencyCountdown = 3
    @State var showingEmergencyAlert = false
    @State var healthCondition: HealthCondition = .good
    @State var showingHealthPicker = false
    @State var aiSuggestedReplies: [String] = []
    @State var showingAIReplies = false
    @State var soundAmplificationMode = false
    @State var showingExitConfirmation = false

    // MARK: - AI Settings
    @AppStorage("aiSummaryEnabled") var aiSummaryEnabled = false
    @AppStorage("aiSearchEnabled") var aiSearchEnabled = true
    @AppStorage("aiAutoMeetingNotesEnabled") var aiAutoMeetingNotesEnabled = false

    // MARK: - Translation Settings
    @AppStorage("translationEnabled") var translationEnabled = false
    @AppStorage("translationAutoDetect") var translationAutoDetect = true
    @AppStorage("translationTargetLanguage") var translationTargetLanguage = "auto"
    @AppStorage("translationShowOriginal") var translationShowOriginal = true

    // MARK: - Location
    @StateObject private var locationManager = LocationManager()

    enum HealthCondition: String, CaseIterable {
        case good = "좋음 😊"
        case normal = "보통 😐"
        case tired = "피곤 😴"
        case sick = "아파요 🤒"
    }

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

    init(chatRoom: ChatRoom, chatService: ChatService? = nil) {
        self.chatRoom = chatRoom

        if let service = chatService {
            self._chatService = StateObject(wrappedValue: service)
        } else {
            let tempContext = (try? ModelContainer(for: Message.self).mainContext) ?? ModelContext(try! ModelContainer(for: Message.self))
            self._chatService = StateObject(wrappedValue: ChatService(modelContext: tempContext))
        }
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
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingBackgroundSettings = true
                    } label: {
                        Label(languageManager.currentLanguage == .korean ? "배경 설정" : "Background", systemImage: "photo.fill")
                    }

                    Button {
                        toggleChatNotifications()
                    } label: {
                        Label(
                            chatRoom.notificationsEnabled ?
                                (languageManager.currentLanguage == .korean ? "알림 끄기" : "Mute") :
                                (languageManager.currentLanguage == .korean ? "알림 켜기" : "Unmute"),
                            systemImage: chatRoom.notificationsEnabled ? "bell.slash.fill" : "bell.fill"
                        )
                    }

                    if aiSummaryEnabled {
                        Button {
                            generateSummary()
                        } label: {
                            Label(languageManager.currentLanguage == .korean ? "대화 요약" : "Summarize", systemImage: "text.quote")
                        }
                    }

                    if !isFriend && chatRoom.otherUserId != nil {
                        Button {
                            showingAddFriendAlert = true
                        } label: {
                            Label(languageManager.currentLanguage == .korean ? "친구 추가" : "Add Friend", systemImage: "person.badge.plus")
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
                emergencyTimer?.invalidate()
                emergencyTimer = nil
            }
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
            .sheet(isPresented: $showingBackgroundSettings) {
                ChatRoomBackgroundSettings(chatRoom: chatRoom)
                    .environmentObject(languageManager)
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
