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
                        .fill(message.isFromCurrentUser ? Color.blue : Color.gray.opacity(0.2))
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
                    .foregroundColor(.blue)
                    .frame(width: 36, height: 36)
            } else {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                    Image(systemName: "person.fill")
                        .foregroundColor(.blue)
                }
                .frame(width: 36, height: 36)
            }
        }
        .onTapGesture { onAvatarTap?() }
        .accessibilityLabel("\(message.sender) 프로필")
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
                    Text("이미지를 불러올 수 없습니다")
                }
                .foregroundColor(.secondary)
            }
            
        case .file:
            HStack {
                Image(systemName: fileIcon(for: message.fileExtension ?? ""))
                    .foregroundColor(.blue)
                VStack(alignment: .leading) {
                    Text(message.fileName ?? "파일")
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
                    .foregroundColor(.blue)
                Text("음성 메시지")
                Spacer()
                Button(action: {
                    // 음성 재생 (추후 구현)
                }) {
                    Image(systemName: "play.fill")
                        .foregroundColor(.blue)
                }
            }
            .frame(minWidth: 150)
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
}

#Preview {
    let container = try! ModelContainer(for: Message.self, ChatRoom.self)
    
    VStack {
        MessageBubbleView(message: Message(text: "안녕하세요!", isFromCurrentUser: false, sender: "친구"), avatarSymbolName: "person.circle.fill")
        MessageBubbleView(message: Message(text: "안녕하세요! 반갑습니다 😊", isFromCurrentUser: true))
    }
    .padding()
    .modelContainer(container)
}
