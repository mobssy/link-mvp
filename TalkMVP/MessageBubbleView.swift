//
//  MessageBubbleView.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//

import SwiftUI
import Combine
import SwiftData

struct MessageBubbleView: View {
    let message: Message
    var avatarSymbolName: String? = nil
    var onAvatarTap: (() -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authManager: AuthManager
    
    @State private var friendState: FriendState = .unknown
    @State private var showingFriendAlert = false
    @State private var friendAlertMessage = ""
    
    private enum FriendState { case unknown, notFriend, pending, isFriend }
    
    @EnvironmentObject private var languageManager: LanguageManager
    
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
                        .fill(message.isFromCurrentUser ? Color.appPrimary : Color.gray.opacity(0.2))
                )
                .foregroundColor(message.isFromCurrentUser ? .white : .primary)
            
            Text(message.timestamp, style: .time)
                .font(.caption2)
                .foregroundColor(.secondary)
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
                        // 이미지 확대 보기 (추후 구현)
                    }
            } else {
                HStack {
                    Image(systemName: "photo")
                    Text(localizedText("image_load_failed"))
                }
                .foregroundColor(.secondary)
            }
            
        case .file:
            HStack {
                Image(systemName: fileIcon(for: message.fileExtension ?? ""))
                    .foregroundColor(.appPrimary)
                VStack(alignment: .leading) {
                    Text(message.fileName ?? localizedText("file"))
                        .font(.headline)
                    if let fileSize = message.fileSize {
                        Text(formatFileSize(fileSize))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .frame(minWidth: 150)
            
        case .audio:
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(.appPrimary)
                Text(localizedText("audio_message"))
                Spacer()
                Button(action: {
                    // 음성 재생 (추후 구현)
                }) {
                    Image(systemName: "play.fill")
                        .foregroundColor(.appPrimary)
                }
            }
            .frame(minWidth: 150)
            
        case .deleted:
            HStack {
                Image(systemName: "trash")
                    .foregroundColor(.secondary)
                Text(localizedText("message_deleted"))
                    .foregroundColor(.secondary)
                    .italic()
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
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    private func localizedText(_ key: String, _ param: String = "") -> String {
        let isKorean = languageManager.currentLanguage == .korean
        
        let text: String
        switch key {
        case "image_load_failed": text = isKorean ? "이미지를 불러올 수 없습니다" : "Unable to load image"
        case "audio_message": text = isKorean ? "음성 메시지" : "Audio Message"
        case "message_deleted": text = isKorean ? "메시지가 삭제되었습니다" : "Message deleted"
        case "file": text = isKorean ? "파일" : "File"
        case "profile_of": text = isKorean ? "\(param) 프로필" : "Profile of \(param)"
        case "add_friend": text = isKorean ? "친구 추가" : "Add Friend"
        case "request_pending": text = isKorean ? "승인 대기" : "Pending"
        case "pending_short": text = isKorean ? "대기" : "Pending"
        case "friend_request_sent": text = isKorean ? "친구 요청을 보냈습니다." : "Friend request sent."
        case "alert": text = isKorean ? "알림" : "Alert"
        case "ok": text = isKorean ? "확인" : "OK"
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

#Preview {
    let container = try! ModelContainer(for: Message.self, ChatRoom.self)
    
    VStack {
        MessageBubbleView(message: Message(text: "안녕하세요!", isFromCurrentUser: false, sender: "친구"))
        MessageBubbleView(message: Message(text: "안녕하세요! 반갑습니다 😊", isFromCurrentUser: true))
    }
    .padding()
    .modelContainer(container)
}

