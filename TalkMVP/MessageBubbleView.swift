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

struct MessageBubbleView: View {
    let message: Message
    var avatarSymbolName: String?
    var onAvatarTap: (() -> Void)?
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authManager: AuthManager

    @State private var friendState: FriendState = .unknown
    @State private var showingFriendAlert = false
    @State private var friendAlertMessage = ""
    @State private var showingFullScreenImage = false
    @State private var fullScreenImage: UIImage? = nil
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlayingAudio = false

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
        .alert(localizedText("alert"), isPresented: $showingFriendAlert) {
            Button(localizedText("ok")) {}
        } message: {
            Text(friendAlertMessage)
        }
        .sheet(isPresented: $showingFullScreenImage) {
            if let uiImage = fullScreenImage {
                FullScreenImageView(image: uiImage)
            }
        }
    }

    private var bubbleBackground: Color {
        if message.isFromCurrentUser {
            return highContrast ? Color(UIColor.label) : Color.appPrimary
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
                            .tint(.appPrimary)
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
                .foregroundColor(message.isFromCurrentUser ? Color(UIColor.systemBackground) : .primary)

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
                    .allowsHitTesting(false)

                    Text("\(languageManager.localize(ko: "동영상", en: "Video", ja: "動画", zh: "视频", es: "Video")) (\(formatFileSize(videoData.count)))")
                        .font(.caption)
                        .foregroundColor(message.isFromCurrentUser ? .white.opacity(0.9) : .secondary)
                }
            } else {
                HStack {
                    Image(systemName: "video")
                    Text(languageManager.localize(ko: "동영상 로드 실패", en: "Unable to load video", ja: "動画を読み込めません", zh: "无法加载视频", es: "No se puede cargar el video"))
                }
                .foregroundColor(.secondary)
            }

        case .file:
            HStack {
                Image(systemName: fileIcon(for: message.fileExtension ?? ""))
                    .foregroundColor(message.isFromCurrentUser ? .white : .appPrimary)
                VStack(alignment: .leading) {
                    Text(message.fileName ?? localizedText("file"))
                        .font(.headline)
                    if let fileSize = message.fileSize {
                        Text(formatFileSize(fileSize))
                            .font(.caption)
                            .foregroundColor(message.isFromCurrentUser ? .white.opacity(0.8) : .secondary)
                    }
                }
                Spacer()
            }
            .frame(minWidth: 150)

        case .audio:
            HStack(spacing: 10) {
                Button {
                    toggleAudioPlayback()
                } label: {
                    Image(systemName: isPlayingAudio ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(message.isFromCurrentUser ? .white : .appPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Image(systemName: "waveform")
                        .font(.system(size: 14))
                        .foregroundColor(message.isFromCurrentUser ? .white.opacity(0.8) : .secondary)
                    Text(formatAudioDuration(message.audioDuration))
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(message.isFromCurrentUser ? .white.opacity(0.7) : .secondary)
                }
            }
            .frame(minWidth: 120)

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
                            .foregroundColor(message.isFromCurrentUser ? .white : .appPrimary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(languageManager.localize(ko: "현재 위치", en: "Current Location", ja: "現在地", zh: "当前位置", es: "Ubicación actual"))
                                .font(.subheadline.bold())
                            Text(String(format: "%.5f, %.5f", lat, lon))
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(message.isFromCurrentUser ? .white.opacity(0.8) : .secondary)
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

    private func fileIcon(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "pdf":
            return "doc.text.fill"
        case "doc", "docx":
            return "doc.fill"
        case "txt":
            return "text.justify"
        case "zip", "rar":
            return "doc.zipper"
        case "mp3", "wav":
            return "music.note"
        case "mp4", "mov":
            return "video.fill"
        default:
            return "doc.fill"
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
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        audioPlayer = player
        player.play()
        isPlayingAudio = true
        Task {
            try? await Task.sleep(for: .seconds(player.duration + 0.2))
            await MainActor.run { isPlayingAudio = false }
        }
    }

    private func formatAudioDuration(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func localizedText(_ key: String, _ param: String = "") -> String {
        let text: String
        switch key {
        case "image_load_failed": text = languageManager.localize(ko: "이미지를 불러올 수 없습니다", en: "Unable to load image", ja: "画像を読み込めません", zh: "无法加载图片", es: "No se puede cargar la imagen")
        case "audio_message": text = languageManager.localize(ko: "음성 메시지", en: "Audio Message", ja: "音声メッセージ", zh: "语音消息", es: "Mensaje de audio")
        case "message_deleted": text = languageManager.localize(ko: "메시지가 삭제되었습니다", en: "Message deleted", ja: "削除されたメッセージ", zh: "已删除的消息", es: "Mensaje eliminado")
        case "file": text = languageManager.localize(ko: "파일", en: "File", ja: "ファイル", zh: "文件", es: "Archivo")
        case "profile_of": text = languageManager.localize(ko: "\(param) 프로필", en: "Profile of \(param)", ja: "\(param)のプロフィール", zh: "\(param)的资料", es: "Perfil de \(param)")
        case "add_friend": text = languageManager.localize(ko: "친구 추가", en: "Add Friend", ja: "友だちを追加", zh: "添加朋友", es: "Agregar amigo")
        case "request_pending": text = languageManager.localize(ko: "승인 대기", en: "Pending", ja: "承認待ち", zh: "待确认", es: "Pendiente")
        case "pending_short": text = languageManager.localize(ko: "대기", en: "Pending", ja: "保留中", zh: "待处理", es: "Pendiente")
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
            print("Failed to load friendship state: \(error)")
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
            friendAlertMessage = localizedText("friend_request_sent")
            showingFriendAlert = true

            // Fire a local notification to simulate receiver-side alert
            let manager = NotificationManager()
            let senderName = authManager.currentUser?.displayName ?? localizedText("user")
            let senderEmail = authManager.currentUser?.email ?? ""
            manager.scheduleFriendRequestNotification(from: senderName, email: senderEmail)
        } catch {
            print("Failed to save friend request: \(error)")
        }
    }
}

struct FullScreenImageView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

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
            .accessibilityLabel(Text(NSLocalizedString("close", comment: "Close button")))
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
