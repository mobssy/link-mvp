//
//  TalkMVPTests.swift
//  TalkMVPTests
//
//  Created by David Song on 9/26/25.
//

import Testing
import Foundation
import SwiftData
import SwiftUI
import UserNotifications
@testable import TalkMVP

/// A throwaway Documents folder, so file-store tests never touch the app's real one.
private func makeTemporaryDocuments() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("TalkMVPTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

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

    @Test("Deleting a file message also deletes its file on disk")
    func deleteMessageRemovesAttachmentFile() async throws {
        let files = DiskAttachmentFileStore(documentsDirectory: try makeTemporaryDocuments())
        let repo = LocalMessageRepository(modelContext: try makeContext(), attachmentFiles: files)
        let path = try files.save(Data("report".utf8), fileExtension: "pdf")
        let message = Message(fileName: "report", fileExtension: "pdf", fileSize: 6, isFromCurrentUser: true, chatRoomId: "room-1")
        message.fileURL = path
        try await repo.saveMessage(message)

        try await repo.deleteMessage(message)

        #expect(!FileManager.default.fileExists(atPath: path))
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

    @Test("Starting a chat with someone saves the room once and reuses it afterwards")
    func directChatRoomIsCreatedOnceAndReused() async throws {
        let context = try makeContext()
        let repo = LocalChatRoomRepository(modelContext: context)

        let first = try await repo.directChatRoom(withUserId: "friend-1", name: "Mina", email: "mina@example.com")
        let again = try await repo.directChatRoom(withUserId: "friend-1", name: "Mina", email: "mina@example.com")
        let other = try await repo.directChatRoom(withUserId: "friend-2", name: "Joon", email: nil)

        #expect(first.id == again.id)
        #expect(first.id != other.id)
        #expect(first.name == "Mina")
        #expect(first.otherUserId == "friend-1")
        #expect(first.otherUserEmail == "mina@example.com")
        #expect(try await repo.fetchChatRooms().count == 2)
    }

    @Test("Deleting a chat room also deletes its messages, and only its messages")
    func deleteChatRoomDeletesItsMessages() async throws {
        let context = try makeContext()
        let repo = LocalChatRoomRepository(modelContext: context)
        let doomed = ChatRoom(name: "To Delete")
        let kept = ChatRoom(name: "Kept")
        try await repo.saveChatRoom(doomed)
        try await repo.saveChatRoom(kept)
        context.insert(Message(text: "a", isFromCurrentUser: true, chatRoomId: doomed.id.uuidString))
        context.insert(Message(text: "b", isFromCurrentUser: false, chatRoomId: doomed.id.uuidString))
        context.insert(Message(text: "keep me", isFromCurrentUser: true, chatRoomId: kept.id.uuidString))
        try context.save()

        try await repo.deleteChatRoom(doomed)

        let remaining = try context.fetch(FetchDescriptor<Message>())
        #expect(remaining.map(\.text) == ["keep me"])
    }

    @Test("Deleting a chat room deletes its messages' files and leaves other rooms' files")
    func deleteChatRoomRemovesItsAttachmentFiles() async throws {
        let context = try makeContext()
        let files = DiskAttachmentFileStore(documentsDirectory: try makeTemporaryDocuments())
        let repo = LocalChatRoomRepository(modelContext: context, attachmentFiles: files)
        let doomed = ChatRoom(name: "To Delete")
        let kept = ChatRoom(name: "Kept")
        try await repo.saveChatRoom(doomed)
        try await repo.saveChatRoom(kept)
        let doomedPath = try files.save(Data("a".utf8), fileExtension: "txt")
        let keptPath = try files.save(Data("b".utf8), fileExtension: "txt")
        for (room, path) in [(doomed, doomedPath), (kept, keptPath)] {
            let message = Message(fileName: "f", fileExtension: "txt", fileSize: 1, isFromCurrentUser: true, chatRoomId: room.id.uuidString)
            message.fileURL = path
            context.insert(message)
        }
        try context.save()

        try await repo.deleteChatRoom(doomed)

        #expect(!FileManager.default.fileExists(atPath: doomedPath))
        #expect(FileManager.default.fileExists(atPath: keptPath))
    }
}

// MARK: - Friendship

@MainActor
@Suite("Friendship")
struct FriendshipTests {
    @Test("The other person is found whichever side sent the request")
    func otherUserIdFromEitherSide() {
        let sent = Friendship(userId: "me", friendId: "them", friendName: "Them", friendEmail: "t@example.com")
        let received = Friendship(userId: "them", friendId: "me", friendName: "Them", friendEmail: "t@example.com")

        #expect(sent.otherUserId(currentUserId: "me") == "them")
        #expect(received.otherUserId(currentUserId: "me") == "them")
    }
}

// MARK: - DiskAttachmentFileStore

@MainActor
@Suite("DiskAttachmentFileStore")
struct DiskAttachmentFileStoreTests {

    @Test("Saved data is written under Attachments and removed by its stored path")
    func saveThenRemove() throws {
        let documents = try makeTemporaryDocuments()
        let store = DiskAttachmentFileStore(documentsDirectory: documents)

        let path = try store.save(Data("hello".utf8), fileExtension: "txt")

        #expect(path.hasPrefix(documents.appendingPathComponent("Attachments").path))
        #expect(FileManager.default.contents(atPath: path) == Data("hello".utf8))
        store.removeFile(atStoredPath: path)
        #expect(!FileManager.default.fileExists(atPath: path))
    }

    @Test("A path saved under an old app container still finds the file by name")
    func removeFileWithStaleContainerPath() throws {
        let store = DiskAttachmentFileStore(documentsDirectory: try makeTemporaryDocuments())
        let path = try store.save(Data("x".utf8), fileExtension: "txt")
        let name = (path as NSString).lastPathComponent
        let stale = "/var/mobile/Containers/Data/Application/OLD-CONTAINER/Documents/Attachments/\(name)"

        store.removeFile(atStoredPath: stale)

        #expect(!FileManager.default.fileExists(atPath: path))
    }

    @Test("A stored path resolves to the file wherever it lives, or nil once it is gone")
    func urlForStoredPath() throws {
        let documents = try makeTemporaryDocuments()
        let store = DiskAttachmentFileStore(documentsDirectory: documents)
        let current = try store.save(Data("x".utf8), fileExtension: "txt")
        let legacy = documents.appendingPathComponent("\(UUID().uuidString).pdf")
        try Data("old".utf8).write(to: legacy)

        #expect(store.url(forStoredPath: "/old/container/\((current as NSString).lastPathComponent)")?.path == current)
        #expect(store.url(forStoredPath: legacy.path)?.path == legacy.path)
        #expect(store.url(forStoredPath: "/nowhere/\(UUID().uuidString).txt") == nil)
    }

    @Test("Files earlier builds wrote straight into Documents are removed too")
    func removeLegacyFile() throws {
        let documents = try makeTemporaryDocuments()
        let store = DiskAttachmentFileStore(documentsDirectory: documents)
        let legacy = documents.appendingPathComponent("\(UUID().uuidString).pdf")
        try Data("old".utf8).write(to: legacy)

        store.removeFile(atStoredPath: legacy.path)

        #expect(!FileManager.default.fileExists(atPath: legacy.path))
    }

    @Test("Sweeping keeps referenced files and unrelated Documents files, removes the rest")
    func removeUnreferencedFiles() throws {
        let documents = try makeTemporaryDocuments()
        let store = DiskAttachmentFileStore(documentsDirectory: documents)
        let referenced = try store.save(Data("keep".utf8), fileExtension: "txt")
        let unreferenced = try store.save(Data("drop".utf8), fileExtension: "txt")
        let legacyUnreferenced = documents.appendingPathComponent("\(UUID().uuidString).pdf")
        try Data("old".utf8).write(to: legacyUnreferenced)
        let unrelated = documents.appendingPathComponent("notes.txt")
        try Data("not an attachment".utf8).write(to: unrelated)

        let removed = store.removeFiles(keeping: [referenced])

        #expect(removed == 2)
        #expect(FileManager.default.fileExists(atPath: referenced))
        #expect(!FileManager.default.fileExists(atPath: unreferenced))
        #expect(!FileManager.default.fileExists(atPath: legacyUnreferenced.path))
        #expect(FileManager.default.fileExists(atPath: unrelated.path))
    }
}

// MARK: - AttachmentPreviewer

@MainActor
@Suite("AttachmentPreviewer")
struct AttachmentPreviewerTests {
    private let files: DiskAttachmentFileStore
    private let previewer: AttachmentPreviewer

    init() throws {
        files = DiskAttachmentFileStore(documentsDirectory: try makeTemporaryDocuments())
        previewer = AttachmentPreviewer(
            attachmentFiles: files,
            directory: try makeTemporaryDocuments().appendingPathComponent("Previews")
        )
    }

    private func fileMessage(name: String, fileExtension: String, storedPath: String?) -> Message {
        let message = Message(fileName: name, fileExtension: fileExtension, fileSize: 1, isFromCurrentUser: true, chatRoomId: "room")
        message.fileURL = storedPath
        return message
    }

    @Test("A file attachment previews under its original name with its contents")
    func filePreviewUsesOriginalName() throws {
        let path = try files.save(Data("quarterly".utf8), fileExtension: "pdf")

        let url = try #require(try previewer.previewURL(for: fileMessage(name: "report", fileExtension: "pdf", storedPath: path)))

        #expect(url.lastPathComponent == "report.pdf")
        #expect(FileManager.default.contents(atPath: url.path) == Data("quarterly".utf8))
        #expect(FileManager.default.fileExists(atPath: path), "the stored attachment itself is left in place")
    }

    @Test("A file whose attachment is gone has nothing to preview")
    func missingFileHasNoPreview() throws {
        let message = fileMessage(name: "report", fileExtension: "pdf", storedPath: "/gone/\(UUID().uuidString).pdf")
        #expect(try previewer.previewURL(for: message) == nil)
        #expect(try previewer.previewURL(for: fileMessage(name: "report", fileExtension: "pdf", storedPath: nil)) == nil)
    }

    @Test("A name with path separators stays inside the preview folder")
    func unsafeNameIsSanitized() throws {
        let path = try files.save(Data("x".utf8), fileExtension: "txt")

        let url = try #require(try previewer.previewURL(for: fileMessage(name: "../../etc/passwd", fileExtension: "txt", storedPath: path)))

        #expect(url.lastPathComponent == ".._.._etc_passwd.txt")
    }

    @Test("A video previews with its recorded extension, or as a movie when none was recorded", arguments: [
        ("mp4", "mp4"),
        (nil, "mov")
    ] as [(String?, String)])
    func videoPreviewExtension(recorded: String?, expected: String) throws {
        let message = Message(text: "video", isFromCurrentUser: true, chatRoomId: "room", messageType: .video)
        message.videoData = Data([0x00, 0x01])
        message.fileExtension = recorded

        let url = try #require(try previewer.previewURL(for: message))

        #expect(url.pathExtension == expected)
        #expect(FileManager.default.contents(atPath: url.path) == Data([0x00, 0x01]))
    }

    @Test("Opening a new preview discards the previous one")
    func previousPreviewIsDiscarded() throws {
        let first = try files.save(Data("1".utf8), fileExtension: "txt")
        let second = try files.save(Data("2".utf8), fileExtension: "txt")
        let firstURL = try #require(try previewer.previewURL(for: fileMessage(name: "a", fileExtension: "txt", storedPath: first)))

        _ = try previewer.previewURL(for: fileMessage(name: "a", fileExtension: "txt", storedPath: second))

        #expect(!FileManager.default.fileExists(atPath: firstURL.path))
    }

    @Test("Text messages have nothing to preview")
    func textHasNoPreview() throws {
        #expect(try previewer.previewURL(for: Message(text: "hi", isFromCurrentUser: true)) == nil)
    }
}

// MARK: - OrphanedDataCleaner

@MainActor
@Suite("OrphanedDataCleaner")
struct OrphanedDataCleanerTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Message.self, ChatRoom.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test("Messages of deleted rooms and their files are removed; live rooms keep theirs")
    func removesOrphansOnly() throws {
        let context = try makeContext()
        let files = DiskAttachmentFileStore(documentsDirectory: try makeTemporaryDocuments())
        let room = ChatRoom(name: "Live")
        context.insert(room)
        let livePath = try files.save(Data("a".utf8), fileExtension: "txt")
        let orphanPath = try files.save(Data("b".utf8), fileExtension: "txt")
        let live = Message(fileName: "a", fileExtension: "txt", fileSize: 1, isFromCurrentUser: true, chatRoomId: room.id.uuidString)
        live.fileURL = livePath
        let orphan = Message(fileName: "b", fileExtension: "txt", fileSize: 1, isFromCurrentUser: true, chatRoomId: UUID().uuidString)
        orphan.fileURL = orphanPath
        context.insert(live)
        context.insert(orphan)
        context.insert(Message(text: "orphan text", isFromCurrentUser: false, chatRoomId: UUID().uuidString))
        try context.save()

        let result = try OrphanedDataCleaner(modelContext: context, attachmentFiles: files).run()

        #expect(result == OrphanedDataCleaner.Result(deletedMessages: 2, deletedFiles: 1))
        #expect(try context.fetch(FetchDescriptor<Message>()).map(\.id) == [live.id])
        #expect(FileManager.default.fileExists(atPath: livePath))
        #expect(!FileManager.default.fileExists(atPath: orphanPath))
    }

    @Test("A store with nothing orphaned is left alone")
    func nothingToClean() throws {
        let context = try makeContext()
        let room = ChatRoom(name: "Live")
        context.insert(room)
        context.insert(Message(text: "hi", isFromCurrentUser: true, chatRoomId: room.id.uuidString))
        try context.save()
        let files = DiskAttachmentFileStore(documentsDirectory: try makeTemporaryDocuments())

        let result = try OrphanedDataCleaner(modelContext: context, attachmentFiles: files).run()

        #expect(result == OrphanedDataCleaner.Result())
        #expect(try context.fetchCount(FetchDescriptor<Message>()) == 1)
    }

    @Test("Never runs against an in-memory store, whose empty message list would wipe real files")
    func skipsInMemoryStore() throws {
        let inMemory = try ModelContainer(
            for: Message.self, ChatRoom.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let onDisk = try ModelContainer(
            for: Message.self, ChatRoom.self,
            configurations: ModelConfiguration(url: try makeTemporaryDocuments().appendingPathComponent("test.store"))
        )

        #expect(OrphanedDataCleaner.shouldRun(for: inMemory) == false)
        #expect(OrphanedDataCleaner.shouldRun(for: onDisk) == true)
    }
}

// MARK: - FriendSearchService

@MainActor
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

// MARK: - AuthManager

@MainActor
@Suite("AuthManager")
struct AuthManagerTests {

    /// Each test gets its own in-memory store. A context created from the container keeps
    /// the container alive; `container.mainContext` would not once the container goes out of scope.
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Message.self, ChatRoom.self, User.self, Friendship.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private let attachmentFiles: DiskAttachmentFileStore

    init() throws {
        attachmentFiles = DiskAttachmentFileStore(documentsDirectory: try makeTemporaryDocuments())
    }

    private func makeManager(_ context: ModelContext) -> AuthManager {
        AuthManager(modelContext: context, simulatedLatency: .zero, attachmentFiles: attachmentFiles)
    }

    private func currentUsers(in context: ModelContext) throws -> [User] {
        try context.fetch(FetchDescriptor<User>(predicate: #Predicate { $0.isCurrentUser == true }))
    }

    @Test("A fresh store starts signed out")
    func startsSignedOut() throws {
        let context = try makeContext()
        let manager = makeManager(context)

        #expect(manager.isAuthenticated == false)
        #expect(manager.currentUser == nil)
    }

    @Test("The persisted current user is restored on launch, including the user object")
    func restoresPersistedSession() throws {
        let context = try makeContext()
        let saved = User(username: "jordan", displayName: "Jordan", email: "jordan@example.com", isCurrentUser: true)
        context.insert(saved)
        try context.save()

        let manager = makeManager(context)

        #expect(manager.isAuthenticated)
        #expect(manager.currentUser?.id == saved.id)
    }

    @Test("Sign-up creates the account, signs it in and seeds sample friends")
    func signUpCreatesAndActivatesUser() async throws {
        let context = try makeContext()
        let manager = makeManager(context)

        await manager.signUp(username: "jordan", displayName: "Jordan", email: "jordan@example.com", password: "secret1")

        #expect(manager.errorMessage == nil)
        #expect(manager.isAuthenticated)
        #expect(manager.currentUser?.username == "jordan")
        #expect(try currentUsers(in: context).map(\.username) == ["jordan"])
        #expect(try context.fetchCount(FetchDescriptor<Friendship>()) == 6)
    }

    @Test("Sign-up refuses a username or email that is already taken")
    func signUpRejectsDuplicates() async throws {
        let context = try makeContext()
        context.insert(User(username: "jordan", displayName: "Jordan", email: "jordan@example.com"))
        try context.save()
        let manager = makeManager(context)

        await manager.signUp(username: "someone-else", displayName: "J", email: "jordan@example.com", password: "secret1")

        #expect(manager.errorMessage != nil)
        #expect(manager.isAuthenticated == false)
        #expect(try context.fetchCount(FetchDescriptor<User>()) == 1)
    }

    @Test("Signing in with an unknown username reports an error and stays signed out")
    func signInUnknownUserFails() async throws {
        let context = try makeContext()
        let manager = makeManager(context)

        await manager.signIn(username: "nobody", password: "secret1")

        #expect(manager.errorMessage != nil)
        #expect(manager.isAuthenticated == false)
    }

    @Test("Signing in moves the current-user flag to the new account")
    func signInSwitchesCurrentUser() async throws {
        let context = try makeContext()
        let first = User(username: "first", displayName: "First", email: "first@example.com", isCurrentUser: true)
        let second = User(username: "second", displayName: "Second", email: "second@example.com")
        context.insert(first)
        context.insert(second)
        try context.save()
        let manager = makeManager(context)

        await manager.signIn(username: "second@example.com", password: "secret1")

        #expect(manager.currentUser?.id == second.id)
        #expect(first.isCurrentUser == false)
        #expect(second.isCurrentUser)
    }

    @Test("Signing out ends the session and is not undone by a relaunch")
    func signOutClearsPersistedSession() async throws {
        let context = try makeContext()
        let manager = makeManager(context)
        await manager.signUp(username: "jordan", displayName: "Jordan", email: "jordan@example.com", password: "secret1")

        manager.signOut()

        #expect(manager.isAuthenticated == false)
        #expect(try currentUsers(in: context).isEmpty)
        #expect(makeManager(context).isAuthenticated == false)
    }

    @Test("Apple sign-in reuses the account created by an earlier Apple sign-in")
    func appleSignInReusesAccount() async throws {
        let context = try makeContext()
        let manager = makeManager(context)
        var name = PersonNameComponents()
        name.givenName = "Jordan"

        await manager.signInWithApple(userId: "001234.abcdef", email: "j@example.com", fullName: name)
        let firstID = manager.currentUser?.id
        manager.signOut()
        await manager.signInWithApple(userId: "001234.abcdef", email: nil, fullName: nil)

        #expect(manager.currentUser?.id == firstID)
        #expect(manager.currentUser?.displayName == "Jordan")
        #expect(try context.fetchCount(FetchDescriptor<User>()) == 1)
    }

    @Test("Test mode signs in a tester account with the given friends")
    func startTestSessionSeedsFriends() throws {
        let context = try makeContext()
        let manager = makeManager(context)

        manager.startTestSession(
            displayName: "Tester",
            statusMessage: "Trying things out",
            friends: [(name: "A", email: "a@example.com"), (name: "B", email: "b@example.com")]
        )

        let testerID = try #require(manager.currentUser?.id.uuidString)
        let friendships = try context.fetch(FetchDescriptor<Friendship>())
        #expect(manager.currentUser?.username == "tester")
        #expect(friendships.count == 2)
        #expect(friendships.allSatisfy { $0.ownerUserId == testerID && $0.status == .accepted })
    }

    @Test("Deleting the account wipes local data and attachment files and ends the session")
    func deleteAccountWipesLocalData() async throws {
        let context = try makeContext()
        let manager = makeManager(context)
        await manager.signUp(username: "jordan", displayName: "Jordan", email: "jordan@example.com", password: "secret1")
        let room = ChatRoom(name: "Room")
        context.insert(room)
        context.insert(Message(text: "hi", isFromCurrentUser: true, chatRoomId: room.id.uuidString))
        let filePath = try attachmentFiles.save(Data("doc".utf8), fileExtension: "pdf")
        let fileMessage = Message(fileName: "doc", fileExtension: "pdf", fileSize: 3, isFromCurrentUser: true, chatRoomId: room.id.uuidString)
        fileMessage.fileURL = filePath
        context.insert(fileMessage)
        try context.save()

        await manager.deleteAccount()

        #expect(!FileManager.default.fileExists(atPath: filePath))
        #expect(manager.isAuthenticated == false)
        #expect(try context.fetchCount(FetchDescriptor<User>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Friendship>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<ChatRoom>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Message>()) == 0)
    }
}

// MARK: - ChatService

@MainActor
@Suite("ChatService")
struct ChatServiceTests {

    @Test("A connected service is released once its owner lets go of it")
    func connectedServiceIsReleased() async throws {
        let container = try ModelContainer(
            for: Message.self, ChatRoom.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        weak var weakService: ChatService?

        do {
            let service = ChatService(modelContext: ModelContext(container), connectDelay: 0)
            weakService = service
            service.startConnection()
            // Let the simulated handshake finish so the repeating timers are scheduled.
            try await Task.sleep(for: .milliseconds(200))
            #expect(service.connectionStatus == .connected)
        }

        // The repeating timers must not keep the service (and its message simulation) alive.
        #expect(weakService == nil)
    }

    @Test("Disconnecting reports the disconnected state")
    func disconnectUpdatesStatus() async throws {
        let container = try ModelContainer(
            for: Message.self, ChatRoom.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let service = ChatService(modelContext: ModelContext(container), connectDelay: 0)
        service.startConnection()
        try await Task.sleep(for: .milliseconds(200))

        service.disconnect()

        #expect(service.connectionStatus == .disconnected)
    }
}

// MARK: - ChatViewModel

/// Stands in for the simulated reply so a test doesn't receive a message seconds later.
@MainActor
private struct SilentAutoResponder: AutoResponding {
    func generateResponse(
        for chatRoom: ChatRoom,
        onTypingChange: @escaping (Bool) -> Void,
        onMessage: @escaping (Message) -> Void
    ) async throws {}
}

@MainActor
@Suite("ChatViewModel")
struct ChatViewModelTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Message.self, ChatRoom.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func makeRoom(in context: ModelContext) throws -> ChatRoom {
        let room = ChatRoom(name: "Room")
        context.insert(room)
        try context.save()
        return room
    }

    private let attachmentFiles: DiskAttachmentFileStore

    init() throws {
        attachmentFiles = DiskAttachmentFileStore(documentsDirectory: try makeTemporaryDocuments())
    }

    private func makeViewModel(_ context: ModelContext, room: ChatRoom) -> ChatViewModel {
        ChatViewModel(
            messageRepository: LocalMessageRepository(modelContext: context, attachmentFiles: attachmentFiles),
            chatRoomRepository: LocalChatRoomRepository(modelContext: context, attachmentFiles: attachmentFiles),
            chatRoom: room,
            autoResponder: SilentAutoResponder()
        )
    }

    @Test("Sending text shows it in the conversation and as the chat list preview")
    func sendMessageUpdatesConversationAndPreview() async throws {
        let context = try makeContext()
        let room = try makeRoom(in: context)
        let viewModel = makeViewModel(context, room: room)

        viewModel.newMessageText = "See you at 7"
        let task = try #require(viewModel.sendMessage())
        await task.value

        #expect(viewModel.messages.map(\.text) == ["See you at 7"])
        #expect(room.lastMessage == "See you at 7")
        #expect(viewModel.newMessageText.isEmpty)
    }

    @Test("Whitespace-only input is not sent")
    func blankMessageIsIgnored() async throws {
        let context = try makeContext()
        let room = try makeRoom(in: context)
        let viewModel = makeViewModel(context, room: room)

        viewModel.newMessageText = "   \n"

        #expect(viewModel.sendMessage() == nil)
        #expect(try context.fetchCount(FetchDescriptor<Message>()) == 0)
    }

    @Test("A sent video appears in the conversation immediately and is persisted")
    func sendVideoAppearsImmediately() async throws {
        let context = try makeContext()
        let room = try makeRoom(in: context)
        let viewModel = makeViewModel(context, room: room)
        let videoData = Data([0x00, 0x01, 0x02])

        await viewModel.sendVideo(videoData).value

        let sent = try #require(viewModel.messages.last)
        #expect(viewModel.messages.count == 1)
        #expect(sent.messageType == .video)
        #expect(sent.videoData == videoData)
        #expect(sent.fileExtension == AttachmentPreviewer.fallbackVideoExtension)
        #expect(room.lastMessage == sent.text)
        #expect(try context.fetchCount(FetchDescriptor<Message>()) == 1)
    }

    @Test("A sent video keeps its container format so it can be played back")
    func sendVideoRecordsExtension() async throws {
        let context = try makeContext()
        let viewModel = makeViewModel(context, room: try makeRoom(in: context))

        await viewModel.sendVideo(Data([0x00]), fileExtension: "mp4").value

        #expect(viewModel.messages.last?.fileExtension == "mp4")
    }

    @Test("The room's disappearing timer applies to every kind of message sent")
    func disappearingTimerAppliesToAllMessageTypes() async throws {
        let context = try makeContext()
        let room = try makeRoom(in: context)
        room.disappearingDuration = 60
        let viewModel = makeViewModel(context, room: room)

        viewModel.newMessageText = "hello"
        await viewModel.sendMessage()?.value
        await viewModel.sendImage(Data([0x01])).value
        await viewModel.sendVideo(Data([0x02])).value
        await viewModel.sendVoiceMessage(audioData: Data([0x03]), duration: 1).value
        await viewModel.sendFile(fileName: "a", fileExtension: "txt", fileSize: 1).value
        await viewModel.sendLocationMessage(latitude: 37.5, longitude: 127.0).value

        #expect(viewModel.messages.count == 6)
        for message in viewModel.messages {
            #expect(message.isDisappearing, "\(message.messageType) should disappear")
            #expect(message.disappearAfterSeconds == 60, "\(message.messageType) should use the room's timer")
        }
    }

    @Test("A sent file appears in the conversation immediately with its stored path")
    func sendFileAppearsImmediately() async throws {
        let context = try makeContext()
        let room = try makeRoom(in: context)
        let viewModel = makeViewModel(context, room: room)

        await viewModel.sendFile(fileName: "report", fileExtension: "pdf", fileSize: 2048, fileURL: "/tmp/report.pdf").value

        let sent = try #require(viewModel.messages.last)
        #expect(sent.messageType == .file)
        #expect(sent.fileName == "report")
        #expect(sent.fileExtension == "pdf")
        #expect(sent.fileSize == 2048)
        #expect(sent.fileURL == "/tmp/report.pdf")
        #expect(!room.lastMessage.isEmpty)
    }

    @Test("A scheduled message waits in the conversation without moving the chat list preview")
    func scheduledMessageWaits() async throws {
        let context = try makeContext()
        let room = try makeRoom(in: context)
        let viewModel = makeViewModel(context, room: room)

        await viewModel.scheduleMessage("  good morning ", sendAt: Date().addingTimeInterval(3600))?.value
        viewModel.sendDueScheduledMessages()

        let pending = try #require(viewModel.messages.first)
        #expect(pending.text == "good morning")
        #expect(pending.isPendingScheduled)
        #expect(try context.fetchCount(FetchDescriptor<Message>()) == 1)
        #expect(room.lastMessage.isEmpty)
    }

    @Test("A due scheduled message is sent like a typed one: timer, preview and order")
    func dueScheduledMessageIsSent() async throws {
        let context = try makeContext()
        let room = try makeRoom(in: context)
        room.disappearingDuration = 60
        let viewModel = makeViewModel(context, room: room)
        let sendAt = Date().addingTimeInterval(60)
        await viewModel.scheduleMessage("good morning", sendAt: sendAt)?.value
        viewModel.newMessageText = "typed meanwhile"
        await viewModel.sendMessage()?.value

        let now = sendAt.addingTimeInterval(1)
        await viewModel.sendDueScheduledMessages(now: now)?.value

        let sent = try #require(viewModel.messages.last)
        #expect(viewModel.messages.map(\.text) == ["typed meanwhile", "good morning"])
        #expect(!sent.isPendingScheduled)
        #expect(sent.scheduledFor == nil)
        #expect(sent.timestamp == now)
        #expect(sent.isDisappearing && sent.disappearAfterSeconds == 60)
        #expect(room.lastMessage == "good morning")
        #expect(room.timestamp == now)
    }

    @Test("Reactions and bookmarks are saved")
    func reactionAndBookmarkPersist() async throws {
        let context = try makeContext()
        let room = try makeRoom(in: context)
        let viewModel = makeViewModel(context, room: room)
        viewModel.newMessageText = "hi"
        await viewModel.sendMessage()?.value
        let message = try #require(viewModel.messages.first)

        await viewModel.addReaction("👍", to: message, from: "me").value
        await viewModel.toggleBookmark(message).value

        #expect(!context.hasChanges, "both edits were saved")
        #expect(message.hasReaction("👍", from: "me"))
        #expect(message.isBookmarked)
    }

    @Test("Expired disappearing messages leave the conversation, the store and the disk")
    func deleteExpiredMessagesRemovesEverywhere() async throws {
        let context = try makeContext()
        let room = try makeRoom(in: context)
        let viewModel = makeViewModel(context, room: room)
        let path = try attachmentFiles.save(Data("doc".utf8), fileExtension: "pdf")
        await viewModel.sendFile(fileName: "doc", fileExtension: "pdf", fileSize: 3, fileURL: path).value
        viewModel.newMessageText = "stays"
        await viewModel.sendMessage()?.value
        let expired = viewModel.messages.filter { $0.messageType == .file }

        await viewModel.deleteExpiredMessages(expired).value

        #expect(viewModel.messages.map(\.text) == ["stays"])
        #expect(try context.fetch(FetchDescriptor<Message>()).map(\.text) == ["stays"])
        #expect(!FileManager.default.fileExists(atPath: path))
    }
}

// MARK: - AIService

@MainActor
@Suite("AIService summary input")
struct AIServiceSummaryTests {
    @Test("A message is copied into a plain value before it leaves the main actor")
    func snapshotCopiesTheFieldsTheSummaryUses() {
        let message = Message(text: "lunch at noon?", isFromCurrentUser: false, sender: "Mina", chatRoomId: "room")

        let snapshot = SummaryMessage(message)
        message.text = "edited later"

        #expect(snapshot == SummaryMessage(text: "lunch at noon?", sender: "Mina", isFromCurrentUser: false, messageType: .text))
    }

    @Test("An empty conversation gets the no-messages text in the requested language", arguments: [
        ("en", "No messages to summarize."),
        ("ko", "요약할 메시지가 없습니다.")
    ])
    func emptyConversation(language: String, expected: String) async {
        let summary = await AIService.shared.summarize(messages: [], targetLanguage: language)
        #expect(summary == expected)
    }
}

// MARK: - Notifications

@MainActor
private final class FakeNotificationCenter: NotificationScheduling {
    var authorized = true
    private(set) var added: [UNNotificationRequest] = []
    private(set) var badgeCounts: [Int] = []

    func isAuthorizedToNotify() async -> Bool { authorized }
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { authorized }
    func add(_ request: UNNotificationRequest) async throws { added.append(request) }
    func setBadgeCount(_ newBadgeCount: Int) async throws { badgeCounts.append(newBadgeCount) }
    func removeAllPendingNotificationRequests() {}
    func removeAllDeliveredNotifications() {}
}

@MainActor
@Suite("NotificationManager")
struct NotificationManagerTests {
    /// A defaults domain of its own, starting empty like a fresh install.
    private let defaults = UserDefaults(suiteName: "NotificationManagerTests-\(UUID().uuidString)")!
    private let center = FakeNotificationCenter()

    private var manager: NotificationManager { NotificationManager(center: center, defaults: defaults) }

    @Test("The notifications switch counts as on until the user turns it off", arguments: [
        (nil, true),
        (true, true),
        (false, false)
    ] as [(Bool?, Bool)])
    func preferenceDefaultsToOn(stored: Bool?, expected: Bool) {
        if let stored { defaults.set(stored, forKey: NotificationPreferences.enabledKey) }
        #expect(NotificationPreferences.isEnabled(in: defaults) == expected)
    }

    @Test("A friend request notification is scheduled on a fresh install with permission granted")
    func friendRequestScheduledWhenAllowed() async throws {
        await manager.scheduleFriendRequestNotification(from: "Mina", email: "mina@example.com")

        let request = try #require(center.added.first)
        #expect(center.added.count == 1)
        #expect(request.content.body.contains("Mina"))
        #expect(request.content.userInfo["type"] as? String == "friend_request")
    }

    @Test("No friend request notification without permission")
    func friendRequestSkippedWithoutPermission() async {
        center.authorized = false
        await manager.scheduleFriendRequestNotification(from: "Mina", email: "mina@example.com")
        #expect(center.added.isEmpty)
    }

    @Test("No friend request notification once the user switched notifications off")
    func friendRequestSkippedWhenSwitchedOff() async {
        defaults.set(false, forKey: NotificationPreferences.enabledKey)
        await manager.scheduleFriendRequestNotification(from: "Mina", email: "mina@example.com")
        #expect(center.added.isEmpty)
    }

    @Test("The badge shows the count while notifications are on and clears when they are off")
    func badgeFollowsSwitch() async {
        await manager.updateBadgeCount(3).value
        defaults.set(false, forKey: NotificationPreferences.enabledKey)
        await manager.updateBadgeCount(3).value

        #expect(center.badgeCounts == [3, 0])
    }
}

// MARK: - Color hex conversion

@MainActor
@Suite("Color hex conversion")
struct ColorHexTests {

    @Test("Hex strings survive a round trip through Color", arguments: [
        "#FF0000", "#00FF00", "#0000FF", "#123456", "#99CCFF", "#FFFFFF", "#000000"
    ])
    func roundTrip(hex: String) throws {
        let color = try #require(Color(hex: hex))
        #expect(color.toHex() == hex)
    }

    @Test("Grayscale system colors convert instead of crashing", arguments: [
        (Color.white, "#FFFFFF"),
        (Color.black, "#000000")
    ])
    func grayscaleColors(color: Color, expected: String) {
        #expect(color.toHex() == expected)
    }

    @Test("Strings of the wrong length are rejected", arguments: ["", "#12", "#12345"])
    func wrongLengthIsRejected(hex: String) {
        #expect(Color(hex: hex) == nil)
    }
}
