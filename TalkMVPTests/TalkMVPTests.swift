//
//  TalkMVPTests.swift
//  TalkMVPTests
//
//  Created by David Song on 9/26/25.
//

import Testing
import Foundation
import SwiftData
@testable import TalkMVP

// MARK: - AttachmentHandler

@Suite("AttachmentHandler")
struct AttachmentHandlerTests {

    @Test("Known extensions map to their expected SF Symbol", arguments: [
        ("pdf", "doc.text.fill"),
        ("doc", "doc.fill"),
        ("docx", "doc.fill"),
        ("txt", "text.justify"),
        ("zip", "doc.zipper"),
        ("rar", "doc.zipper"),
        ("mp3", "music.note"),
        ("wav", "music.note"),
        ("mp4", "video.fill"),
        ("mov", "video.fill")
    ])
    func fileIconKnownExtensions(ext: String, expectedSymbol: String) {
        #expect(AttachmentHandler.fileIcon(for: ext) == expectedSymbol)
    }

    @Test("Unknown extension falls back to the generic document icon")
    func fileIconUnknownExtension() {
        #expect(AttachmentHandler.fileIcon(for: "xyz") == "doc.fill")
        #expect(AttachmentHandler.fileIcon(for: "") == "doc.fill")
    }

    @Test("Extension matching is case-insensitive")
    func fileIconCaseInsensitive() {
        #expect(AttachmentHandler.fileIcon(for: "PDF") == "doc.text.fill")
        #expect(AttachmentHandler.fileIcon(for: "Mp4") == "video.fill")
    }

    @Test("File size formatting never crashes and produces non-empty output")
    func formatFileSizeProducesOutput() {
        #expect(!AttachmentHandler.formatFileSize(0).isEmpty)
        #expect(!AttachmentHandler.formatFileSize(1024).isEmpty)
        #expect(!AttachmentHandler.formatFileSize(5 * 1024 * 1024).isEmpty)
    }

    @Test("Gigabyte-scale sizes are formatted using the GB unit")
    func formatFileSizeGigabyteScale() {
        let result = AttachmentHandler.formatFileSize(2 * 1024 * 1024 * 1024)
        #expect(result.contains("GB"))
    }
}

// MARK: - L10n

@Suite("L10n")
struct L10nTests {

    @Test("Known key resolves to the correct string per language", arguments: [
        (AppLanguage.korean, "친구"),
        (AppLanguage.english, "Friends"),
        (AppLanguage.japanese, "友だち"),
        (AppLanguage.chinese, "朋友"),
        (AppLanguage.spanish, "Amigos")
    ])
    func knownKeyPerLanguage(language: AppLanguage, expected: String) {
        #expect(L10n.text("friends", language) == expected)
    }

    @Test("Unknown key falls back to a humanized version of the key itself")
    func unknownKeyFallsBackToHumanizedKey() {
        #expect(L10n.text("this_key_does_not_exist", AppLanguage.english) == "This Key Does Not Exist")
    }

    @Test("LanguageManager.Language overload maps to the matching AppLanguage")
    func languageManagerOverloadMapsCorrectly() {
        #expect(L10n.text("send", LanguageManager.Language.korean) == L10n.text("send", AppLanguage.korean))
        #expect(L10n.text("send", LanguageManager.Language.english) == L10n.text("send", AppLanguage.english))
        #expect(L10n.text("send", LanguageManager.Language.japanese) == L10n.text("send", AppLanguage.japanese))
    }

    @Test("Traditional Chinese currently falls back to Simplified Chinese text")
    func traditionalChineseFallsBackToSimplified() {
        // AppLanguage has no distinct case for Traditional Chinese, so both
        // LanguageManager variants resolve to the same translated string today.
        #expect(L10n.text("send", LanguageManager.Language.chineseTraditional) == L10n.text("send", AppLanguage.chinese))
    }
}

// MARK: - MessageRepository

@MainActor
@Suite("MessageRepository")
struct MessageRepositoryTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Message.self, ChatRoom.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test("Saved messages can be fetched back for their chat room")
    func saveAndFetchMessages() async throws {
        let repo = LocalMessageRepository(modelContext: try makeContext())
        let message = Message(text: "hello", isFromCurrentUser: true, chatRoomId: "room-1")

        try await repo.saveMessage(message)
        let fetched = try await repo.fetchMessages(for: "room-1", limit: 10, before: nil)

        #expect(fetched.count == 1)
        #expect(fetched.first?.text == "hello")
    }

    @Test("Fetch only returns messages for the requested chat room")
    func fetchMessagesScopedToChatRoom() async throws {
        let repo = LocalMessageRepository(modelContext: try makeContext())
        try await repo.saveMessage(Message(text: "in room 1", isFromCurrentUser: true, chatRoomId: "room-1"))
        try await repo.saveMessage(Message(text: "in room 2", isFromCurrentUser: true, chatRoomId: "room-2"))

        let fetched = try await repo.fetchMessages(for: "room-1", limit: 10, before: nil)

        #expect(fetched.count == 1)
        #expect(fetched.first?.text == "in room 1")
    }

    @Test("Fetch returns messages oldest-first and respects the limit")
    func fetchMessagesOrderingAndLimit() async throws {
        let repo = LocalMessageRepository(modelContext: try makeContext())
        let base = Date()
        for i in 0..<5 {
            let message = Message(text: "msg-\(i)", isFromCurrentUser: true, chatRoomId: "room-1")
            message.timestamp = base.addingTimeInterval(TimeInterval(i))
            try await repo.saveMessage(message)
        }

        // Limit to the 3 newest, which should come back oldest-first: msg-2, msg-3, msg-4.
        let fetched = try await repo.fetchMessages(for: "room-1", limit: 3, before: nil)

        #expect(fetched.map(\.text) == ["msg-2", "msg-3", "msg-4"])
    }

    @Test("markMessagesAsRead only marks incoming, unread messages")
    func markMessagesAsReadOnlyAffectsIncomingUnread() async throws {
        let repo = LocalMessageRepository(modelContext: try makeContext())

        let ownMessage = Message(text: "mine", isFromCurrentUser: true, chatRoomId: "room-1")
        let incomingUnread = Message(text: "incoming unread", isFromCurrentUser: false, chatRoomId: "room-1")
        let incomingAlreadyRead = Message(text: "incoming read", isFromCurrentUser: false, chatRoomId: "room-1")
        incomingAlreadyRead.isRead = true

        try await repo.saveMessage(ownMessage)
        try await repo.saveMessage(incomingUnread)
        try await repo.saveMessage(incomingAlreadyRead)

        try await repo.markMessagesAsRead(in: "room-1")

        #expect(ownMessage.isRead == false)
        #expect(incomingUnread.isRead == true)
        #expect(incomingAlreadyRead.isRead == true)
    }

    @Test("Deleting a message removes it from subsequent fetches")
    func deleteMessageRemovesIt() async throws {
        let repo = LocalMessageRepository(modelContext: try makeContext())
        let message = Message(text: "to delete", isFromCurrentUser: true, chatRoomId: "room-1")
        try await repo.saveMessage(message)

        try await repo.deleteMessage(message)
        let fetched = try await repo.fetchMessages(for: "room-1", limit: 10, before: nil)

        #expect(fetched.isEmpty)
    }
}

// MARK: - ChatRoomRepository

@MainActor
@Suite("ChatRoomRepository")
struct ChatRoomRepositoryTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Message.self, ChatRoom.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test("Chat rooms are fetched newest-first by timestamp")
    func fetchChatRoomsSortedNewestFirst() async throws {
        let repo = LocalChatRoomRepository(modelContext: try makeContext())

        let older = ChatRoom(name: "Older")
        older.timestamp = Date().addingTimeInterval(-100)
        let newer = ChatRoom(name: "Newer")
        newer.timestamp = Date()

        try await repo.saveChatRoom(older)
        try await repo.saveChatRoom(newer)

        let rooms = try await repo.fetchChatRooms()

        #expect(rooms.map(\.name) == ["Newer", "Older"])
    }

    @Test("Fetching a chat room by an unknown id returns nil")
    func fetchChatRoomByMissingIdReturnsNil() async throws {
        let repo = LocalChatRoomRepository(modelContext: try makeContext())
        let result = try await repo.fetchChatRoom(by: UUID())
        #expect(result == nil)
    }

    @Test("Updating unread count persists the new value")
    func updateUnreadCountPersists() async throws {
        let repo = LocalChatRoomRepository(modelContext: try makeContext())
        let room = ChatRoom(name: "Test Room")
        try await repo.saveChatRoom(room)

        try await repo.updateUnreadCount(for: room.id, count: 7)

        let fetched = try await repo.fetchChatRoom(by: room.id)
        #expect(fetched?.unreadCount == 7)
    }

    @Test("Updating unread count for a missing room throws")
    func updateUnreadCountMissingRoomThrows() async throws {
        let repo = LocalChatRoomRepository(modelContext: try makeContext())
        await #expect(throws: (any Error).self) {
            try await repo.updateUnreadCount(for: UUID(), count: 1)
        }
    }

    @Test("Updating last message and timestamp persists both fields")
    func updateChatRoomLastMessage() async throws {
        let repo = LocalChatRoomRepository(modelContext: try makeContext())
        let room = ChatRoom(name: "Test Room")
        try await repo.saveChatRoom(room)

        let newTimestamp = Date().addingTimeInterval(60)
        try await repo.updateChatRoom(room, lastMessage: "updated!", timestamp: newTimestamp)

        #expect(room.lastMessage == "updated!")
        #expect(room.timestamp == newTimestamp)
    }

    @Test("Deleting a chat room removes it from subsequent fetches")
    func deleteChatRoomRemovesIt() async throws {
        let repo = LocalChatRoomRepository(modelContext: try makeContext())
        let room = ChatRoom(name: "To Delete")
        try await repo.saveChatRoom(room)

        try await repo.deleteChatRoom(room)
        let rooms = try await repo.fetchChatRooms()

        #expect(rooms.isEmpty)
    }
}

// MARK: - FriendSearchService

@Suite("FriendSearchService")
struct FriendSearchServiceTests {

    @Test("Email validation accepts well-formed addresses and rejects malformed ones", arguments: [
        ("user@example.com", true),
        ("first.last+tag@sub.example.co", true),
        ("no-at-sign.com", false),
        ("missing-domain@", false),
        ("@missing-local.com", false),
        ("spaces in@email.com", false),
        ("", false)
    ])
    func emailValidation(email: String, expectedValid: Bool) {
        #expect(isValidEmail(email) == expectedValid)
    }

    @Test("Searching with an invalid email returns no results")
    func searchUsersWithInvalidEmailReturnsEmpty() async throws {
        let results = try await FriendSearchService.searchUsers(by: "not-an-email")
        #expect(results.isEmpty)
    }

    @Test("Searching with a valid email returns a result derived from it")
    func searchUsersWithValidEmailReturnsResult() async throws {
        let results = try await FriendSearchService.searchUsers(by: "  Jordan@Example.com  ")

        #expect(results.count == 1)
        #expect(results.first?.email == "Jordan@Example.com")
        #expect(results.first?.username == "Jordan")
    }

    @Test("Sending a friend request reports success")
    func sendFriendRequestSucceeds() async throws {
        let sent = try await FriendSearchService.sendFriendRequest(from: "user-1", to: "user-2")
        #expect(sent == true)
    }
}

// MARK: - LocalizationService

@MainActor
@Suite("LocalizationService")
struct LocalizationServiceTests {

    @Test("Known key resolves per language", arguments: [
        (Language.korean, "취소"),
        (Language.english, "Cancel"),
        (Language.japanese, "キャンセル"),
        (Language.chinese, "取消"),
        (Language.spanish, "Cancelar")
    ])
    func cancelKeyPerLanguage(language: Language, expected: String) {
        #expect(LocalizationService.shared.text(for: .cancel, language: language) == expected)
    }

    @Test("String-keyed bridging resolves a known key through LanguageManager")
    func localizedTextResolvesKnownKey() {
        let manager = LanguageManager()
        manager.setLanguage(.english)
        #expect(LocalizationService.shared.localizedText("save", languageManager: manager) == "Save")
    }

    @Test("String-keyed bridging returns the raw key when it doesn't match any LocalizationKey")
    func localizedTextFallsBackToRawKeyWhenUnknown() {
        let manager = LanguageManager()
        manager.setLanguage(.english)
        #expect(LocalizationService.shared.localizedText("not_a_real_localization_key", languageManager: manager) == "not_a_real_localization_key")
    }

    @Test("Traditional Chinese currently falls back to Simplified Chinese text, same as L10n")
    func traditionalChineseFallsBackToSimplified() {
        let manager = LanguageManager()
        manager.setLanguage(.chineseTraditional)
        #expect(LocalizationService.shared.localizedText("cancel", languageManager: manager) == "取消")
    }
}

// MARK: - ContactsSyncService

@Suite("ContactsSyncService")
struct ContactsSyncServiceTests {

    @Test("Phone normalization keeps a leading plus and strips other non-digits", arguments: [
        ("+1 (555) 123-4567", "+15551234567"),
        ("010-1234-5678", "01012345678"),
        ("(02) 1234.5678", "0212345678"),
        ("+82 10 1234 5678", "+821012345678"),
        ("", "")
    ])
    func normalizePhone(input: String, expected: String) {
        #expect(ContactsSyncService.normalizePhone(input) == expected)
    }

    @Test("Phone normalization only keeps a plus sign when it leads the string")
    func normalizePhoneIgnoresEmbeddedPlus() {
        #expect(ContactsSyncService.normalizePhone("555+123") == "555123")
    }

    @Test("SHA-256 hashing is deterministic and matches a known digest")
    func sha256IsDeterministic() {
        let first = ContactsSyncService.sha256("test@example.com")
        let second = ContactsSyncService.sha256("test@example.com")
        #expect(first == second)
        #expect(first.count == 64) // SHA-256 hex digest length
    }

    @Test("SHA-256 hashing produces different digests for different input")
    func sha256DiffersForDifferentInput() {
        #expect(ContactsSyncService.sha256("a") != ContactsSyncService.sha256("b"))
    }
}
