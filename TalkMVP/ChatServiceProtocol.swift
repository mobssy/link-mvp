import Foundation
import SwiftData

protocol ChatServiceProtocol: AnyObject {
    func sendMessage(_ message: Message, to chatRoom: ChatRoom)
    func markAsRead(chatRoom: ChatRoom)
    func sendReaction(_ emoji: String, to message: Message, in chatRoom: ChatRoom)
    func removeReaction(_ emoji: String, from message: Message, in chatRoom: ChatRoom)
    func editMessage(_ message: Message, in chatRoom: ChatRoom)
    func deleteMessage(_ message: Message, in chatRoom: ChatRoom)
}

extension ChatServiceProtocol {
    func sendMessage(_ message: Message, to chatRoom: ChatRoom) {}
    func markAsRead(chatRoom: ChatRoom) {}
    func sendReaction(_ emoji: String, to message: Message, in chatRoom: ChatRoom) {}
    func removeReaction(_ emoji: String, from message: Message, in chatRoom: ChatRoom) {}
    func editMessage(_ message: Message, in chatRoom: ChatRoom) {}
    func deleteMessage(_ message: Message, in chatRoom: ChatRoom) {}
}
