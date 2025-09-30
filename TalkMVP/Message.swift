//
//  Message.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//

import Foundation
import SwiftData

enum MessageType: String, Codable {
    case text
    case image
    case file
    case audio
}

@Model
class Message {
    @Attribute(.unique) var id: UUID
    var text: String
    var isFromCurrentUser: Bool
    var timestamp: Date
    var sender: String
    var chatRoomId: String
    var messageType: MessageType
    var imageData: Data? // 이미지 데이터
    var fileName: String? // 파일명
    var fileExtension: String? // 파일 확장자
    var fileSize: Int? // 파일 크기 (바이트)
    
    // 새로운 필드들
    var reactions: [String: [String]] = [:] // [이모지: [사용자ID]]
    var replyToMessageId: UUID? // 답장하는 메시지의 ID
    var isEdited: Bool = false // 편집 여부
    var editedAt: Date? // 편집 시간
    
    init(text: String, isFromCurrentUser: Bool, sender: String = "나", chatRoomId: String = "default", messageType: MessageType = .text, replyToMessageId: UUID? = nil) {
        self.id = UUID()
        self.text = text
        self.isFromCurrentUser = isFromCurrentUser
        self.timestamp = Date()
        self.sender = sender
        self.chatRoomId = chatRoomId
        self.messageType = messageType
        self.imageData = nil
        self.fileName = nil
        self.fileExtension = nil
        self.fileSize = nil
        self.reactions = [:]
        self.replyToMessageId = replyToMessageId
        self.isEdited = false
        self.editedAt = nil
    }
    
    // 이미지 메시지용 초기화
    init(imageData: Data, isFromCurrentUser: Bool, sender: String = "나", chatRoomId: String = "default") {
        self.id = UUID()
        self.text = "사진을 보냈습니다"
        self.isFromCurrentUser = isFromCurrentUser
        self.timestamp = Date()
        self.sender = sender
        self.chatRoomId = chatRoomId
        self.messageType = .image
        self.imageData = imageData
        self.fileName = nil
        self.fileExtension = nil
        self.fileSize = nil
        self.reactions = [:]
        self.replyToMessageId = nil
        self.isEdited = false
        self.editedAt = nil
    }
    
    // 파일 메시지용 초기화
    init(fileName: String, fileExtension: String, fileSize: Int, isFromCurrentUser: Bool, sender: String = "나", chatRoomId: String = "default") {
        self.id = UUID()
        self.text = "\(fileName).\(fileExtension)"
        self.isFromCurrentUser = isFromCurrentUser
        self.timestamp = Date()
        self.sender = sender
        self.chatRoomId = chatRoomId
        self.messageType = .file
        self.imageData = nil
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.fileSize = fileSize
        self.reactions = [:]
        self.replyToMessageId = nil
        self.isEdited = false
        self.editedAt = nil
    }
    
    // 반응 관련 메서드들
    func addReaction(_ emoji: String, from userId: String) {
        if reactions[emoji] == nil {
            reactions[emoji] = [String]()
        }
        if !reactions[emoji]!.contains(userId) {
            reactions[emoji]!.append(userId)
        }
    }
    
    func removeReaction(_ emoji: String, from userId: String) {
        reactions[emoji]?.removeAll { $0 == userId }
        if reactions[emoji]?.isEmpty == true {
            reactions[emoji] = nil
        }
    }
    
    func hasReaction(_ emoji: String, from userId: String) -> Bool {
        return reactions[emoji]?.contains(userId) == true
    }
    
    func getReactionCount(_ emoji: String) -> Int {
        return reactions[emoji]?.count ?? 0
    }
}

// 샘플 데이터용 구조체 (SwiftData 모델과 별도)
struct MessageData {
    let text: String
    let isFromCurrentUser: Bool
    let sender: String
    
    static let sampleMessages: [MessageData] = [
        MessageData(text: "안녕하세요!", isFromCurrentUser: false, sender: "친구"),
        MessageData(text: "안녕하세요! 반갑습니다 😊", isFromCurrentUser: true, sender: "나"),
        MessageData(text: "오늘 날씨가 정말 좋네요", isFromCurrentUser: false, sender: "친구"),
        MessageData(text: "네 맞아요! 산책하기 좋을 것 같아요", isFromCurrentUser: true, sender: "나"),
        MessageData(text: "같이 카페 가실래요?", isFromCurrentUser: false, sender: "친구"),
        MessageData(text: "좋아요! 몇 시에 만날까요?", isFromCurrentUser: true, sender: "나"),
    ]
}

