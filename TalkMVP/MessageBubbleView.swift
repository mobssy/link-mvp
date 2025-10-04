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
    }
    
    private var messageBubble: some View {
        VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            if !message.isFromCurrentUser {
                Text(message.sender)
                    .font(.caption)
                    .foregroundColor(.secondary)
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
        default: text = key
        }
        
        if !param.isEmpty && text.contains("%@") {
            return text.replacingOccurrences(of: "%@", with: param)
        }
        return text
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

