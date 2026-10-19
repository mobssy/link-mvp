//
//  MessageBubbleView.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//

import SwiftUI
import Combine
import SwiftData
import AVFoundation
import QuickLook
import os

private let bubbleLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "MessageBubbleView")

struct MessageBubbleView: View {
    let message: Message
    var avatarSymbolName: String?
    var onAvatarTap: (() -> Void)?
    /// A voice message whose words are still being written down.
    var isTranscribing = false
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authManager: AuthManager

    @State private var friendState: FriendState = .unknown
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingFullScreenImage = false
    @State private var fullScreenImage: UIImage? = nil
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlayingAudio = false
    @State private var attachmentPreviewURL: URL?

    private enum FriendState { case unknown, notFriend, pending, isFriend }

    @EnvironmentObject private var languageManager: LanguageManager
    @AppStorage("inAppHighContrast") private var highContrast = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isFromCurrentUser {
                Spacer()
                messageBubble
            } else {
                avatarView
                messageBubble
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
        .onAppear {
            if !message.isFromCurrentUser { loadFriendState() }
        }
        .alert(localizedText("alert"), isPresented: $showingAlert) {
            Button(localizedText("ok")) {}
        } message: {
            Text(alertMessage)
        }
        .quickLookPreview($attachmentPreviewURL)
        .sheet(isPresented: $showingFullScreenImage) {
            if let uiImage = fullScreenImage {
                FullScreenImageView(image: uiImage)
                    .environmentObject(languageManager)
            }
        }
    }

    /// Text and icons on your own bubbles, dark on the light brand color.
    private var ownBubbleContent: Color {
        Color.onOwnBubble(highContrast: highContrast)
    }

    private var bubbleBackground: Color {
        if message.isFromCurrentUser {
            return Color.ownBubble(highContrast: highContrast)
        } else {
            return highContrast ? Color(UIColor.systemGray4) : Color.gray.opacity(0.2)
        }
    }

    private var messageBubble: some View {
        VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            if !message.isFromCurrentUser {
                HStack(spacing: 8) {
                    Text(message.sender)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    switch friendState {
                    case .notFriend:
                        Button(localizedText("add_friend")) { addFriend() }
                            .font(.caption2)
                            .buttonStyle(.bordered)
                            .tint(.appPrimaryText)
                    case .pending:
                        Text(localizedText("request_pending"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    default:
                        EmptyView()
                    }
                }
            }

            // 메시지 타입에 따른 콘텐츠
            messageContent
                .padding(.horizontal, message.messageType == .image ? 4 : 16)
                .padding(.vertical, message.messageType == .image ? 4 : 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(bubbleBackground)
                )
                .foregroundColor(message.isFromCurrentUser ? ownBubbleContent : .primary)

            HStack(spacing: 4) {
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if message.isBookmarked {
                    Image(systemName: "bookmark.fill")
                        .font(.caption2)
                        .foregroundColor(.appPrimary)
                }

                if message.isDisappearing && message.disappearAfterSeconds > 0 {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }

                if message.isPendingScheduled {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if message.isFromCurrentUser {
                    Image(systemName: message.isRead ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.caption2)
                        .foregroundColor(message.isRead ? .appPrimary : .secondary)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    private var avatarView: some View {
        Group {
            if let symbol = avatarSymbolName {
                Image(systemName: symbol)
                    .font(.system(size: 28))
                    .foregroundColor(.appPrimary)
                    .frame(width: 36, height: 36)
            } else {
                ZStack {
                    Circle()
                        .fill(Color.appPrimary.opacity(0.15))
                    Image(systemName: "person.fill")
                        .foregroundColor(.appPrimary)
                }
                .frame(width: 36, height: 36)
            }
        }
        .onTapGesture { onAvatarTap?() }
        .contextMenu {
            if !message.isFromCurrentUser {
                switch friendState {
                case .notFriend:
                    Button(localizedText("add_friend")) { addFriend() }
                case .pending:
                    Label(localizedText("request_pending"), systemImage: "clock")
                default:
                    EmptyView()
                }
            }
        }
        .accessibilityLabel(localizedText("profile_of", message.sender))
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var messageContent: some View {
        switch message.messageType {
        case .text:
            Text(message.text)
                .multilineTextAlignment(message.isFromCurrentUser ? .trailing : .leading)

        case .image:
            if let imageData = message.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 200, maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture {
                        fullScreenImage = uiImage
                        showingFullScreenImage = true
                    }
                    .accessibilityLabel(localizedText("image_load_failed"))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint(languageManager.localize(ko: "탭하여 전체화면으로 보기", en: "Tap to view full screen", ja: "タップしてフルスクリーンで表示", zh: "点击全屏查看", es: "Toca para ver en pantalla completa"))
            } else {
                HStack {
                    Image(systemName: "photo")
                    Text(localizedText("image_load_failed"))
                }
                .foregroundColor(.secondary)
            }

        case .video:
            if let videoData = message.videoData {
                VStack(alignment: .leading, spacing: 4) {
                    ZStack {
                        Rectangle()
                            .fill(Color.black.opacity(0.3))
                            .frame(width: 200, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                    }

                    Text("\(languageManager.localize(ko: "동영상", en: "Video", ja: "動画", zh: "视频", es: "Video")) (\(AttachmentHandler.formatFileSize(videoData.count)))")
                        .font(.caption)
                        .foregroundColor(message.isFromCurrentUser ? ownBubbleContent.opacity(0.9) : .secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture { openAttachment() }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(localizedText("open_attachment_hint"))
            } else {
                HStack {
                    Image(systemName: "video")
                    Text(languageManager.localize(ko: "동영상 로드 실패", en: "Unable to load video", ja: "動画を読み込めません", zh: "无法加载视频", es: "No se puede cargar el video"))
                }
                .foregroundColor(.secondary)
            }

        case .file:
            HStack {
                Image(systemName: AttachmentHandler.fileIcon(for: message.fileExtension ?? ""))
                    .foregroundColor(message.isFromCurrentUser ? ownBubbleContent : .appPrimary)
                VStack(alignment: .leading) {
                    Text(message.fileName ?? localizedText("file"))
                        .font(.headline)
                    if let fileSize = message.fileSize {
                        Text(AttachmentHandler.formatFileSize(fileSize))
                            .font(.caption)
                            .foregroundColor(message.isFromCurrentUser ? ownBubbleContent.opacity(0.8) : .secondary)
                    }
                }
                Spacer()
            }
            .frame(minWidth: 150)
            .contentShape(Rectangle())
            .onTapGesture { openAttachment() }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(localizedText("open_attachment_hint"))

        case .audio:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Button {
                        toggleAudioPlayback()
                    } label: {
                        Image(systemName: isPlayingAudio ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(message.isFromCurrentUser ? ownBubbleContent : .appPrimary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Image(systemName: "waveform")
                            .font(.system(size: 14))
                            .foregroundColor(message.isFromCurrentUser ? ownBubbleContent.opacity(0.8) : .secondary)
                        Text(formatAudioDuration(message.audioDuration))
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(message.isFromCurrentUser ? ownBubbleContent.opacity(0.7) : .secondary)
                    }
                }
                .frame(minWidth: 120, alignment: .leading)

                // Written down on device after sending.
                if let transcript = message.transcript {
                    Text(transcript)
                        .font(.subheadline)
                        .foregroundColor(message.isFromCurrentUser ? ownBubbleContent.opacity(0.9) : .primary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if isTranscribing {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(message.isFromCurrentUser ? ownBubbleContent : .secondary)
                        Text(languageManager.localize(ko: "받아쓰는 중…", en: "Transcribing…", ja: "文字起こし中…", zh: "正在转写…", es: "Transcribiendo…"))
                            .font(.caption)
                            .foregroundColor(message.isFromCurrentUser ? ownBubbleContent.opacity(0.8) : .secondary)
                    }
                }
            }

        case .deleted:
            HStack {
                Image(systemName: "trash")
                    .foregroundColor(.secondary)
                Text(localizedText("message_deleted"))
                    .foregroundColor(.secondary)
                    .italic()
            }

        case .location:
            if let lat = message.locationLatitude, let lon = message.locationLongitude {
                Button {
                    if let url = URL(string: "maps://?ll=\(lat),\(lon)&q=\(lat),\(lon)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 20))
                            .foregroundColor(message.isFromCurrentUser ? ownBubbleContent : .appPrimary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(languageManager.localize(ko: "현재 위치", en: "Current Location", ja: "現在地", zh: "当前位置", es: "Ubicación actual"))
                                .font(.subheadline.bold())
                            Text(String(format: "%.5f, %.5f", lat, lon))
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(message.isFromCurrentUser ? ownBubbleContent.opacity(0.8) : .secondary)
                        }
                    }
                    .frame(minWidth: 160)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(languageManager.localize(ko: "위치 공유 - 탭하여 지도 열기", en: "Location shared — tap to open map", ja: "位置情報共有 — タップして地図を開く", zh: "位置共享 — 点击打开地图", es: "Ubicación compartida — toca para abrir el mapa"))
            } else {
                HStack {
                    Image(systemName: "location.slash")
                    Text(languageManager.localize(ko: "위치 정보 없음", en: "Location unavailable", ja: "位置情報なし", zh: "位置不可用", es: "Ubicación no disponible"))
                }
                .foregroundColor(.secondary)
            }
        }
    }

    private func toggleAudioPlayback() {
        if isPlayingAudio {
            audioPlayer?.stop()
            isPlayingAudio = false
            return
        }
        guard let data = message.audioData,
              let player = try? AVAudioPlayer(data: data) else { return }
        audioPlayer = player
        isPlayingAudio = true
        Task {
            // The session is switched on away from the main thread, which it can block.
            try? await SharedAudioSession().activate(for: .playback)
            // Stopped, or another playback started, while the session was switching on.
            guard isPlayingAudio, audioPlayer === player else { return }
            player.play()
            try? await Task.sleep(for: .seconds(player.duration + 0.2))
            if audioPlayer === player { isPlayingAudio = false }
        }
    }

    private func openAttachment() {
        do {
            if let url = try AttachmentPreviewer().previewURL(for: message) {
                attachmentPreviewURL = url
                return
            }
        } catch {
            bubbleLogger.error("Failed to prepare attachment preview: \(error.localizedDescription, privacy: .public)")
        }
        alertMessage = localizedText("attachment_unavailable")
        showingAlert = true
    }

    private func formatAudioDuration(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func localizedText(_ key: String, _ param: String = "") -> String {
        let text: String
        switch key {
        case "image_load_failed": text = languageManager.localize(ko: "이미지를 불러올 수 없습니다", en: "Unable to load image", ja: "画像を読み込めません", zh: "无法加载图片", es: "No se puede cargar la imagen")
        case "message_deleted": text = languageManager.localize(ko: "메시지가 삭제되었습니다", en: "Message deleted", ja: "削除されたメッセージ", zh: "已删除的消息", es: "Mensaje eliminado")
        case "file": text = languageManager.localize(ko: "파일", en: "File", ja: "ファイル", zh: "文件", es: "Archivo")
        case "open_attachment_hint": text = languageManager.localize(ko: "탭하여 열기", en: "Tap to open", ja: "タップして開く", zh: "点击打开", es: "Toca para abrir")
        case "attachment_unavailable": text = languageManager.localize(ko: "이 첨부 파일을 더 이상 열 수 없습니다.", en: "This attachment can no longer be opened.", ja: "この添付ファイルは開けなくなりました。", zh: "此附件已无法打开。", es: "Este archivo adjunto ya no se puede abrir.")
        case "profile_of": text = languageManager.localize(ko: "\(param) 프로필", en: "Profile of \(param)", ja: "\(param)のプロフィール", zh: "\(param)的资料", es: "Perfil de \(param)")
        case "add_friend": text = languageManager.localize(ko: "친구 추가", en: "Add Friend", ja: "友だちを追加", zh: "添加朋友", es: "Agregar amigo")
        case "request_pending": text = languageManager.localize(ko: "승인 대기", en: "Pending", ja: "承認待ち", zh: "待确认", es: "Pendiente")
        case "friend_request_sent": text = languageManager.localize(ko: "친구 요청을 보냈습니다.", en: "Friend request sent.", ja: "友だちリクエストを送りました。", zh: "好友请求已发送。", es: "Solicitud de amistad enviada.")
        case "alert": text = languageManager.localize(ko: "알림", en: "Alert", ja: "通知", zh: "提示", es: "Alerta")
        case "ok": text = languageManager.localize(ko: "확인", en: "OK", ja: "OK", zh: "确认", es: "Aceptar")
        case "user": text = languageManager.localize(ko: "사용자", en: "User", ja: "ユーザー", zh: "用户", es: "Usuario")
        default: text = key
        }

        if !param.isEmpty && text.contains("%@") {
            return text.replacingOccurrences(of: "%@", with: param)
        }
        return text
    }

    private func loadFriendState() {
        guard let currentUserId = authManager.currentUser?.id.uuidString else {
            friendState = .unknown
            return
        }
        // Skip for own messages
        guard !message.isFromCurrentUser else {
            friendState = .unknown
            return
        }
        // Fetch friendship by current user and sender name
        let senderName = message.sender
        let descriptor = FetchDescriptor<Friendship>(predicate: #Predicate<Friendship> { f in
            f.userId == currentUserId && f.friendName == senderName
        })
        do {
            let results = try modelContext.fetch(descriptor)
            if let existing = results.first {
                switch existing.status {
                case .accepted:
                    friendState = .isFriend
                case .pending:
                    friendState = .pending
                case .blocked, .hidden:
                    friendState = .notFriend
                }
            } else {
                friendState = .notFriend
            }
        } catch {
            bubbleLogger.error("Failed to load friendship state: \(error.localizedDescription, privacy: .public)")
            friendState = .unknown
        }
    }

    private func addFriend() {
        guard friendState == .notFriend, let currentUserId = authManager.currentUser?.id.uuidString else { return }
        // Outgoing request (current user perspective)
        let outgoing = Friendship(
            userId: currentUserId,
            friendId: UUID().uuidString,
            friendName: message.sender,
            friendEmail: "",
            status: .pending
        )
        modelContext.insert(outgoing)

        // Mirror incoming request (receiver perspective) for backend readiness
        let mirror = Friendship(
            userId: outgoing.friendId,
            friendId: currentUserId,
            friendName: authManager.currentUser?.displayName ?? localizedText("user"),
            friendEmail: authManager.currentUser?.email ?? "",
            status: .pending
        )
        modelContext.insert(mirror)

        do {
            try modelContext.save()
            friendState = .pending
            alertMessage = localizedText("friend_request_sent")
            showingAlert = true

            // Fire a local notification to simulate receiver-side alert
            let manager = NotificationManager()
            let senderName = authManager.currentUser?.displayName ?? localizedText("user")
            let senderEmail = authManager.currentUser?.email ?? ""
            Task { await manager.scheduleFriendRequestNotification(from: senderName, email: senderEmail) }
        } catch {
            bubbleLogger.error("Failed to save friend request: \(error.localizedDescription, privacy: .public)")
        }
    }
}

struct FullScreenImageView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white, .black.opacity(0.5))
                    .padding(16)
            }
            .accessibilityLabel(L10n.text("close", languageManager.currentLanguage))
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: Message.self, ChatRoom.self)

    VStack {
        MessageBubbleView(message: Message(text: "안녕하세요!", isFromCurrentUser: false, sender: "친구"))
        MessageBubbleView(message: Message(text: "안녕하세요! 반갑습니다 😊", isFromCurrentUser: true))
    }
    .padding()
    .modelContainer(container)
}
