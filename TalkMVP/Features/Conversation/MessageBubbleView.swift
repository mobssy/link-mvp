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
    @ScaledMetric(relativeTo: .body) private var playButtonSize: CGFloat = 30
    let message: Message
    /// The code of the sender's language, shown on their avatar, when it isn't the reader's.
    var languageBadge: String?
    /// How to translate a received text message, shown under it in the bubble; nil for none.
    var translation: MessageTranslation?
    /// Hears the translation once it is shown, so the message can be read out with it.
    var onTranslated: ((String) -> Void)?
    var onAvatarTap: (() -> Void)?
    /// A voice message whose words are still being written down.
    var isTranscribing = false
    /// How the reader stands with the sender, worked out once for the whole conversation
    /// rather than fetched by every bubble. Nil shows nothing, as for the reader's own messages.
    var senderStanding: FriendStanding?
    /// Sends the sender a friend request; throws if it couldn't be saved.
    var onAddFriend: (() throws -> Void)?

    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingFullScreenImage = false
    @State private var fullScreenImage: UIImage? = nil
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlayingAudio = false
    @State private var attachmentPreviewURL: URL?

    @Environment(LanguageManager.self) private var languageManager
    @Environment(\.prefersHighContrast) private var highContrast

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
        .alert(localizedText("alert"), isPresented: $showingAlert) {
            Button(localizedText("ok")) {}
        } message: {
            Text(alertMessage)
        }
        .quickLookPreview($attachmentPreviewURL)
        .sheet(isPresented: $showingFullScreenImage) {
            if let uiImage = fullScreenImage {
                FullScreenImageView(image: uiImage)
                    .environment(languageManager)
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
            // Adding the sender as a friend is in the context menu, the chat's banner and their
            // profile, not on every message they sent.
            if !message.isFromCurrentUser {
                Text(message.sender)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            // 메시지 타입에 따른 콘텐츠
            messageContent
                .padding(.horizontal, message.messageType == .image ? 4 : 16)
                .padding(.vertical, message.messageType == .image ? 4 : 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(bubbleBackground)
                )
                .foregroundStyle(message.isFromCurrentUser ? ownBubbleContent : .primary)

            HStack(spacing: 4) {
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)

                if message.isBookmarked {
                    Image(systemName: "bookmark.fill")
                        .font(.caption2)
                        .foregroundStyle(.appPrimaryText)
                }

                if message.isDisappearing && message.disappearAfterSeconds > 0 {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                if message.isPendingScheduled {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                }

                if message.isFromCurrentUser {
                    Image(systemName: message.isRead ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.caption2)
                        .foregroundStyle(message.isRead ? .appPrimary : .secondary)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    private var avatarView: some View {
        Button { onAvatarTap?() } label: {
            SenderAvatarView(avatar: SenderAvatar(name: message.sender), languageBadge: languageBadge)
        }
        .buttonStyle(.plain)
        .minimumHitTarget(visibleSize: 36)
        .contextMenu {
            if !message.isFromCurrentUser {
                switch senderStanding {
                case .stranger:
                    Button(localizedText("add_friend")) { addFriend() }
                case .requested:
                    Label(localizedText("request_pending"), systemImage: "clock")
                default:
                    EmptyView()
                }
            }
        }
        .accessibilityLabel(localizedText("profile_of", message.sender))
    }

    @ViewBuilder
    private var messageContent: some View {
        switch message.messageType {
        case .text:
            if let translation, !message.isFromCurrentUser {
                // A grid, so the divider spans the wider of the two texts without widening the
                // bubble to the screen's edge.
                Grid(alignment: .leading, verticalSpacing: 8) {
                    // A grid cell keeps text to one line unless told to grow downward.
                    Text(message.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Divider()
                        .gridCellUnsizedAxes(.horizontal)
                    TranslatedTextView(
                        text: message.text, autoDetect: translation.autoDetect, target: translation.target,
                        onResult: onTranslated
                    )
                }
            } else {
                Text(message.text)
                    .multilineTextAlignment(message.isFromCurrentUser ? .trailing : .leading)
            }

        case .image:
            if let imageData = message.imageData,
               let uiImage = UIImage(data: imageData) {
                Button {
                    fullScreenImage = uiImage
                    showingFullScreenImage = true
                } label: {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 200, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                // What the photo shows when it has been described, otherwise just that it is one.
                .accessibilityLabel(message.imageDescription ?? localizedText("photo"))
                .accessibilityHint(languageManager.localize(ko: "탭하여 전체화면으로 보기", en: "Tap to view full screen", ja: "タップしてフルスクリーンで表示", zh: "点击全屏查看", es: "Toca para ver en pantalla completa"))
            } else {
                HStack {
                    Image(systemName: "photo")
                    Text(localizedText("image_load_failed"))
                }
                .foregroundStyle(Color.secondary)
            }

        case .video:
            if let videoData = message.videoData {
                Button { openAttachment() } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        ZStack {
                            Rectangle()
                                .fill(Color.black.opacity(0.3))
                                .frame(width: 200, height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.white)
                        }

                        Text("\(languageManager.localize(ko: "동영상", en: "Video", ja: "動画", zh: "视频", es: "Video")) (\(AttachmentHandler.formatFileSize(videoData.count)))")
                            .font(.caption)
                            .foregroundStyle(message.isFromCurrentUser ? ownBubbleContent.opacity(0.9) : .secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(localizedText("open_attachment_hint"))
            } else {
                HStack {
                    Image(systemName: "video")
                    Text(languageManager.localize(ko: "동영상 로드 실패", en: "Unable to load video", ja: "動画を読み込めません", zh: "无法加载视频", es: "No se puede cargar el video"))
                }
                .foregroundStyle(Color.secondary)
            }

        case .file:
            Button { openAttachment() } label: {
                HStack {
                    Image(systemName: AttachmentHandler.fileIcon(for: message.fileExtension ?? ""))
                        .foregroundStyle(message.isFromCurrentUser ? ownBubbleContent : .appPrimaryText)
                    VStack(alignment: .leading) {
                        Text(message.fileName ?? localizedText("file"))
                            .font(.headline)
                        if let fileSize = message.fileSize {
                            Text(AttachmentHandler.formatFileSize(fileSize))
                                .font(.caption)
                                .foregroundStyle(message.isFromCurrentUser ? ownBubbleContent.opacity(0.8) : .secondary)
                        }
                    }
                    Spacer()
                }
                .frame(minWidth: 150)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(localizedText("open_attachment_hint"))

        case .audio:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Button {
                        toggleAudioPlayback()
                    } label: {
                        Image(systemName: isPlayingAudio ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: playButtonSize))
                            .foregroundStyle(message.isFromCurrentUser ? ownBubbleContent : .appPrimaryText)
                    }
                    .accessibilityLabel(isPlayingAudio
                        ? languageManager.localize(ko: "음성 메시지 일시정지", en: "Pause voice message", ja: "音声メッセージを一時停止", zh: "暂停语音消息", es: "Pausar mensaje de voz")
                        : languageManager.localize(ko: "음성 메시지 재생", en: "Play voice message", ja: "音声メッセージを再生", zh: "播放语音消息", es: "Reproducir mensaje de voz"))

                    VStack(alignment: .leading, spacing: 2) {
                        Image(systemName: "waveform")
                            .font(.subheadline)
                            .foregroundStyle(message.isFromCurrentUser ? ownBubbleContent.opacity(0.8) : .secondary)
                        Text(formatAudioDuration(message.audioDuration))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(message.isFromCurrentUser ? ownBubbleContent.opacity(0.7) : .secondary)
                    }
                }
                .frame(minWidth: 120, alignment: .leading)

                // Written down on device after sending.
                if let transcript = message.transcript {
                    Text(transcript)
                        .font(.subheadline)
                        .foregroundStyle(message.isFromCurrentUser ? ownBubbleContent.opacity(0.9) : .primary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if isTranscribing {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(message.isFromCurrentUser ? ownBubbleContent : .secondary)
                        Text(languageManager.localize(ko: "받아쓰는 중…", en: "Transcribing…", ja: "文字起こし中…", zh: "正在转写…", es: "Transcribiendo…"))
                            .font(.caption)
                            .foregroundStyle(message.isFromCurrentUser ? ownBubbleContent.opacity(0.8) : .secondary)
                    }
                }
            }

        case .deleted:
            HStack {
                Image(systemName: "trash")
                    .foregroundStyle(Color.secondary)
                Text(localizedText("message_deleted"))
                    .foregroundStyle(Color.secondary)
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
                            .font(.title3)
                            .foregroundStyle(message.isFromCurrentUser ? ownBubbleContent : .appPrimaryText)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(languageManager.localize(ko: "현재 위치", en: "Current Location", ja: "現在地", zh: "当前位置", es: "Ubicación actual"))
                                .font(.subheadline.bold())
                            Text(String(format: "%.5f, %.5f", lat, lon))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(message.isFromCurrentUser ? ownBubbleContent.opacity(0.8) : .secondary)
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
                .foregroundStyle(Color.secondary)
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
        case "photo": text = languageManager.localize(ko: "사진", en: "Photo", ja: "写真", zh: "照片", es: "Foto")
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

    private func addFriend() {
        do {
            try onAddFriend?()
            alertMessage = localizedText("friend_request_sent")
            showingAlert = true
        } catch {
            // The repository has logged it; the button stays for another try.
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
