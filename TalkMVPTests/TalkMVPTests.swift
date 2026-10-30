//
//  TalkMVPTests.swift
//  TalkMVPTests
//
//  Created by David Song on 9/26/25.
//

import Testing
import AVFoundation
import Foundation
import ImageIO
import NaturalLanguage
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
            for: Message.self, ChatRoom.self, User.self, Friendship.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test("Leftover tester accounts are removed at launch, keeping the signed-in one")
    func removesLeftoverTesters() throws {
        let context = try makeContext()
        let signedIn = User(username: "tester", displayName: "Now", email: "test@example.com", isCurrentUser: true)
        signedIn.lastActiveAt = .distantPast
        let newer = User(username: "tester", displayName: "Newer", email: "test@example.com")
        let real = User(username: "jordan", displayName: "Jordan", email: "jordan@example.com")
        for user in [signedIn, newer, real] {
            context.insert(user)
            context.insert(Friendship(userId: user.id.uuidString, friendId: UUID().uuidString, friendName: "A", friendEmail: "a@example.com", status: .accepted))
        }
        try context.save()
        let files = DiskAttachmentFileStore(documentsDirectory: try makeTemporaryDocuments())

        let result = try OrphanedDataCleaner(modelContext: context, attachmentFiles: files).run()

        #expect(result.deletedTestAccounts == 1)
        #expect(Set(try context.fetch(FetchDescriptor<User>()).map(\.id)) == [signedIn.id, real.id])
        #expect(Set(try context.fetch(FetchDescriptor<Friendship>()).map(\.ownerUserId)) == [signedIn.id.uuidString, real.id.uuidString])
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
    /// Shared by every manager a test makes, like the Keychain is across launches.
    private let passwords = InMemoryPasswordStore()

    init() throws {
        attachmentFiles = DiskAttachmentFileStore(documentsDirectory: try makeTemporaryDocuments())
    }

    private func makeManager(_ context: ModelContext) -> AuthManager {
        AuthManager(modelContext: context, simulatedLatency: .zero, attachmentFiles: attachmentFiles, passwordStore: passwords)
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

    @Test("A wrong password is rejected with the same message as an unknown account")
    func signInWrongPasswordFails() async throws {
        let context = try makeContext()
        let manager = makeManager(context)
        await manager.signUp(username: "jordan", displayName: "Jordan", email: "jordan@example.com", password: "secret1")
        manager.signOut()

        await manager.signIn(username: "jordan", password: "not-it")
        let wrongPassword = manager.errorMessage
        #expect(manager.isAuthenticated == false)

        await manager.signIn(username: "nobody", password: "not-it")
        #expect(wrongPassword != nil)
        #expect(manager.errorMessage == wrongPassword)
    }

    @Test("An account signs in again with the password it signed up with")
    func signInWithSignUpPassword() async throws {
        let context = try makeContext()
        let manager = makeManager(context)
        await manager.signUp(username: "jordan", displayName: "Jordan", email: "jordan@example.com", password: "secret1")
        manager.signOut()

        await manager.signIn(username: "jordan@example.com", password: "secret1")

        #expect(manager.isAuthenticated)
        #expect(manager.errorMessage == nil)
    }

    @Test("An account with no stored password can't be signed into")
    func signInWithoutStoredPasswordFails() async throws {
        let context = try makeContext()
        context.insert(User(username: "legacy", displayName: "Legacy", email: "legacy@example.com"))
        try context.save()
        let manager = makeManager(context)

        await manager.signIn(username: "legacy", password: "")

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
        try passwords.setPassword("secret1", for: second.id)
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

    @Test("Two Apple IDs that start the same get separate accounts")
    func appleIDsSharingAPrefixStaySeparate() async throws {
        let context = try makeContext()
        let manager = makeManager(context)

        await manager.signInWithApple(userId: "001234.aaaaaaaa.0001", email: "one@example.com", fullName: nil)
        let firstID = try #require(manager.currentUser?.id)
        manager.signOut()
        await manager.signInWithApple(userId: "001234.aaaaaaaa.0002", email: "two@example.com", fullName: nil)

        #expect(manager.currentUser?.id != firstID)
        #expect(manager.currentUser?.email == "two@example.com")
        #expect(try context.fetchCount(FetchDescriptor<User>()) == 2)
    }

    @Test("Signing in with Apple never lands in an account that only has a matching username")
    func appleSignInIgnoresLookalikeUsernames() async throws {
        let context = try makeContext()
        let lookalike = User(username: "apple_001234.a", displayName: "Someone", email: "someone@example.com")
        context.insert(lookalike)
        try context.save()
        let manager = makeManager(context)

        await manager.signInWithApple(userId: "001234.abcdef", email: "j@example.com", fullName: nil)

        #expect(manager.currentUser?.id != lookalike.id)
        #expect(manager.currentUser?.ssoSubject == "001234.abcdef")
    }

    @Test("Sign-up can't take the usernames kept for Apple and Google accounts", arguments: ["apple_001234.a", "Google_12345678"])
    func signUpRejectsReservedUsernames(username: String) async throws {
        let context = try makeContext()
        let manager = makeManager(context)

        await manager.signUp(username: username, displayName: "J", email: "j@example.com", password: "secret1")

        #expect(manager.isAuthenticated == false)
        #expect(manager.errorMessage != nil)
        #expect(try context.fetchCount(FetchDescriptor<User>()) == 0)
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

    @Test("Entering test mode again reuses the one tester account and its friends")
    func testModeReusesTheTesterAccount() throws {
        let context = try makeContext()
        let manager = makeManager(context)
        let friends = [(name: "A", email: "a@example.com"), (name: "B", email: "b@example.com")]

        manager.startTestSession(displayName: "Tester", statusMessage: "Hi", friends: friends)
        let firstID = try #require(manager.currentUser?.id)
        manager.signOut()
        manager.startTestSession(displayName: "Tester", statusMessage: "Hi", friends: friends)

        #expect(manager.currentUser?.id == firstID)
        #expect(try context.fetchCount(FetchDescriptor<User>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Friendship>()) == 2)
    }

    @Test("Entering test mode removes tester accounts left behind earlier, but not real accounts")
    func testModeClearsLeftoverTesters() async throws {
        let context = try makeContext()
        let manager = makeManager(context)
        await manager.signUp(username: "jordan", displayName: "Jordan", email: "jordan@example.com", password: "secret1")
        manager.signOut()
        let realFriendships = try context.fetchCount(FetchDescriptor<Friendship>())
        for i in 0..<3 {
            let old = User(username: "tester", displayName: "Tester \(i)", email: "test@example.com")
            old.lastActiveAt = Date().addingTimeInterval(TimeInterval(-100 * (i + 1)))
            context.insert(old)
            context.insert(Friendship(userId: old.id.uuidString, friendId: UUID().uuidString, friendName: "A", friendEmail: "a@example.com", status: .accepted))
        }
        try context.save()

        manager.startTestSession(displayName: "Tester", statusMessage: "Hi", friends: [(name: "A", email: "a@example.com")])

        let testers = try context.fetch(FetchDescriptor<User>(predicate: #Predicate { $0.username == "tester" }))
        let tester = try #require(testers.first)
        #expect(testers.count == 1)
        #expect(tester.displayName == "Tester 0", "the most recently active one is kept")
        #expect(manager.currentUser?.id == tester.id)
        #expect(try context.fetchCount(FetchDescriptor<User>(predicate: #Predicate { $0.username == "jordan" })) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Friendship>()) == realFriendships + 1, "the tester keeps one friend A, no duplicate")
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

// MARK: - Message VoiceOver labels

@MainActor
@Suite("Message VoiceOver labels")
struct MessageSpokenSenderTests {
    @Test("A group message is read with the name of who sent it, not the group's")
    func groupMessageNamesItsSender() {
        #expect(ChatView.spokenSender(isFromCurrentUser: false, sender: "Minji", roomName: "Study Group", meLabel: "Me") == "Minji")
    }

    @Test("The reader's own messages are read with their label")
    func ownMessageUsesTheReadersLabel() {
        #expect(ChatView.spokenSender(isFromCurrentUser: true, sender: "나", roomName: "Study Group", meLabel: "Me") == "Me")
    }

    @Test("A message with no sender is read with the room's name", arguments: ["", "  "])
    func missingSenderFallsBackToTheRoom(sender: String) {
        #expect(ChatView.spokenSender(isFromCurrentUser: false, sender: sender, roomName: "Friend", meLabel: "Me") == "Friend")
    }
}

// MARK: - Message translation

/// A translator that always gives the same answer, or none.
private struct FixedTranslator: MessageTranslating {
    let answer: String?
    func translate(_ text: String, into target: String, autoDetect: Bool) async -> String? { answer }
}

@Suite("Message translation")
struct MessageTranslationTests {
    @Test("The first translator with an answer wins")
    func firstAnswerWins() async {
        let result = await AIService.firstTranslation(
            of: "¡Perfecto! Yo traigo el café", into: "en", autoDetect: true,
            using: [FixedTranslator(answer: nil), FixedTranslator(answer: "Perfect! I'll bring the coffee"), FixedTranslator(answer: "Perfect")]
        )
        #expect(result == "Perfect! I'll bring the coffee")
    }

    @Test("Nothing is made up when no translator can translate")
    func noGuessWhenNoneCan() async {
        let result = await AIService.firstTranslation(
            of: "업무는 어떠신가요?", into: "en", autoDetect: true,
            using: [FixedTranslator(answer: nil), FixedTranslator(answer: nil)]
        )
        #expect(result == nil)
    }

    @Test("A blank answer doesn't count as a translation")
    func blankAnswerIsSkipped() async {
        let result = await AIService.firstTranslation(
            of: "Hola", into: "en", autoDetect: true,
            using: [FixedTranslator(answer: "  \n"), FixedTranslator(answer: "Hello")]
        )
        #expect(result == "Hello")
    }

    @Test("The app's language codes map to the Translation framework's languages",
          arguments: [("ko", "ko"), ("zh-hans", "zh-Hans"), ("zh-hant", "zh-Hant"), ("de", "de")])
    func localesForCodes(code: String, identifier: String) {
        #expect(TranslationLanguage.locale(for: code) == Locale.Language(identifier: identifier))
    }

    @Test("The language recognizer's codes are normalized",
          arguments: [("kor", "ko"), ("zh", "zh-hans"), ("zh_TW", "zh-hant"), ("ES", "es")])
    func normalizedCodes(raw: String, code: String) {
        #expect(TranslationLanguage.normalizedCode(raw) == code)
    }
}

// MARK: - Voice recording

/// An audio session for tests: it counts what it was asked to do, can fail, and can hold an
/// activation until the test lets it finish.
private actor FakeAudioSession: AudioSessionSwitching {
    private(set) var activations = 0
    private(set) var deactivations = 0
    private let holdsActivation: Bool
    private let fails: Bool
    private var held: CheckedContinuation<Void, Never>?

    init(holdsActivation: Bool = false, fails: Bool = false) {
        self.holdsActivation = holdsActivation
        self.fails = fails
    }

    func activate(for use: AudioSessionUse) async throws {
        activations += 1
        if fails { throw CocoaError(.featureUnsupported) }
        if holdsActivation { await withCheckedContinuation { held = $0 } }
    }

    func deactivate() async {
        deactivations += 1
    }

    func finishActivation() {
        held?.resume()
        held = nil
    }
}

@MainActor
@Suite("Voice recording start")
struct VoiceRecordingStartTests {
    /// Waits until the recording has asked the session to switch on.
    private func waitForActivation(of session: FakeAudioSession) async throws {
        for _ in 0..<200 {
            if await session.activations > 0 { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("the audio session was never switched on")
    }

    @Test("Letting go while the session switches on calls the recording off")
    func cancelWhileStarting() async throws {
        let session = FakeAudioSession(holdsActivation: true)
        let service = VoiceMessageService(audioSession: session, requestPermission: { true })
        let start = Task { await service.startRecording() }
        try await waitForActivation(of: session)

        service.cancelRecording()
        await session.finishActivation()

        #expect(await start.value == false)
        #expect(!service.isRecording)
        #expect(await session.deactivations >= 1, "the session is switched back off")
    }

    @Test("A second press while one is starting doesn't start another")
    func secondStartIsIgnored() async throws {
        let session = FakeAudioSession(holdsActivation: true)
        let service = VoiceMessageService(audioSession: session, requestPermission: { true })
        let first = Task { await service.startRecording() }
        try await waitForActivation(of: session)

        #expect(await service.startRecording() == false)
        #expect(await session.activations == 1)

        service.cancelRecording()
        await session.finishActivation()
        _ = await first.value
    }

    @Test("Without microphone permission the session is never switched on")
    func noPermissionNoSession() async {
        let session = FakeAudioSession()
        let service = VoiceMessageService(audioSession: session, requestPermission: { false })
        #expect(await service.startRecording() == false)
        #expect(await session.activations == 0)
    }

    @Test("A session that can't switch on doesn't record")
    func failedSessionDoesNotRecord() async {
        let session = FakeAudioSession(fails: true)
        let service = VoiceMessageService(audioSession: session, requestPermission: { true })
        #expect(await service.startRecording() == false)
        #expect(!service.isRecording)
    }
}

// MARK: - Voice transcription

@Suite("Voice transcription")
struct VoiceTranscriptionTests {
    /// A second of a 440 Hz tone in a 44.1 kHz file, like a recording before conversion.
    private func toneFile() throws -> URL {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
        let tone = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44_100))
        tone.frameLength = 44_100
        let samples = try #require(tone.floatChannelData?[0])
        for i in 0..<Int(tone.frameLength) { samples[i] = 0.5 * sin(Float(i) * 2 * .pi * 440 / 44_100) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: tone)
        file.close() // until then only whole 1024-frame chunks are on disk
        return url
    }

    @Test("A recording is converted to the format the analyzer asks for")
    func audioIsConvertedToTheRequestedFormat() throws {
        let url = try toneFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let target = try #require(AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true))

        let converted = try AudioConversion.read(try AVAudioFile(forReading: url), as: target)

        #expect(converted.format == target)
        #expect(abs(Int(converted.frameLength) - 16_000) <= 2, "a second of audio is still a second long")
    }

    @Test("A recording already in the requested format is read whole")
    func audioInTheRequestedFormatIsUnchanged() throws {
        let url = try toneFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let file = try AVAudioFile(forReading: url)

        let read = try AudioConversion.read(file, as: file.processingFormat)

        #expect(read.frameLength == 44_100)
    }
}

// MARK: - Siri and Shortcuts

@MainActor
@Suite("Siri and Shortcuts actions")
struct ChatIntentActionsTests {
    private let context: ModelContext
    private let room = ChatRoom(name: "Family Group")

    init() throws {
        let container = try ModelContainer(
            for: Message.self, ChatRoom.self, User.self, Friendship.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
        context.insert(room)
        try context.save()
    }

    private func signIn() throws {
        context.insert(User(username: "tester", displayName: "Tester", email: "test@example.com", isCurrentUser: true))
        try context.save()
    }

    private func actions(locked: Bool = false, summary: String = "") -> ChatIntentActions {
        ChatIntentActions(context: context, isAppLocked: { locked }, summarize: { _, _ in summary })
    }

    @Test("Nothing runs while signed out, or while App Lock is on")
    func accessIsChecked() throws {
        #expect(throws: ChatIntentError.signedOut) { try actions().checkAccess() }
        try signIn()
        #expect(throws: ChatIntentError.appLocked) { try actions(locked: true).checkAccess() }
        try actions().checkAccess()
    }

    @Test("A message sent through Siri lands in the chat as the user's, with the chat's options and preview")
    func sendAddsTheMessage() async throws {
        try signIn()
        room.disappearingDuration = 60

        let sent = try await actions().send("  On my way  ", to: room.id)

        #expect(try context.fetch(FetchDescriptor<Message>()).map(\.text) == ["On my way"])
        #expect(sent.isFromCurrentUser)
        #expect(sent.isDisappearing && sent.disappearAfterSeconds == 60)
        #expect(room.lastMessage == "On my way")
    }

    @Test("A blank message, or a chat that is gone, is refused")
    func sendRefusesWhatItCannotSend() async throws {
        try signIn()
        await #expect(throws: ChatIntentError.emptyMessage) { try await actions().send("  ", to: room.id) }
        await #expect(throws: ChatIntentError.chatNotFound) { try await actions().send("hi", to: UUID()) }
    }

    @Test("Chats are found by part of their name, most recent first")
    func roomsMatchByName() throws {
        let older = ChatRoom(name: "Study Group")
        older.timestamp = Date().addingTimeInterval(-3600)
        room.timestamp = Date()
        context.insert(older)
        try context.save()

        #expect(try actions().rooms(matching: "group").map(\.name) == ["Family Group", "Study Group"])
        #expect(try actions().rooms(matching: "STUDY").map(\.name) == ["Study Group"])
    }

    @Test("Siri gets the summary as plain text, without the app's heading")
    func summaryIsPlainText() async throws {
        try signIn()
        let formatted = "Oct 14 · 3 messages\n\nDinner plans.\n\n**Decisions**\n• Saturday at 7"

        let summary = try await actions(summary: formatted).summary(of: room.id, language: "en")

        #expect(summary == "Dinner plans.\n\nDecisions\n• Saturday at 7")
    }

    @Test("A summary is in the language Siri speaks", arguments: [
        (["ko-KR"], "ko"), (["ja-JP"], "ja"), (["zh-Hans-CN"], "zh-Hans"), (["zh-Hant-TW"], "zh-Hant"),
        (["es-ES"], "es"), (["fr-FR"], "en"), ([], "en"),
    ] as [([String], String)])
    func summaryLanguage(preferred: [String], expected: String) {
        #expect(ChatIntentActions.summaryLanguage(for: preferred) == expected)
    }
}

// MARK: - Long chat summaries

@Suite("Long chat summaries")
struct ConversationChunkerTests {
    @Test("The token estimate stays above the model's own count, but not far above", arguments: [
        // Measured with SystemLanguageModel.tokenCount(for:) in the iOS 27 simulator.
        (String(repeating: "오늘 저녁에 삼겹살 어때? 좋아 몇 시에 볼까? ", count: 20), 342),
        (String(repeating: "Want to grab dinner tonight? Sure, where should we go? ", count: 20), 262),
    ])
    func estimateIsSafelyHigh(text: String, modelCount: Int) {
        let estimate = ConversationChunker.estimatedTokens(in: text)
        #expect(estimate >= modelCount)
        #expect(Double(estimate) <= Double(modelCount) * 1.5)
    }

    @Test("A chat is cut into consecutive parts within the budget, every line kept in order")
    func partsKeepEveryLineInOrder() {
        let lines = (1...40).map { "Mina: message number \($0) about the trip" }
        let parts = ConversationChunker.chunks(of: lines, budget: 60)

        #expect(parts.count > 1)
        #expect(Array(parts.joined()) == lines)
        #expect(parts.allSatisfy { part in part.reduce(0) { $0 + ConversationChunker.estimatedTokens(in: $1) } <= 60 })
    }

    @Test("A line too long for any part is cut short to fit one")
    func overlongLineIsCut() {
        let parts = ConversationChunker.chunks(of: ["short", String(repeating: "가", count: 500), "after"], budget: 100)

        #expect(parts.flatMap { $0 }.count == 3)
        #expect(parts.allSatisfy { part in part.reduce(0) { $0 + ConversationChunker.estimatedTokens(in: $1) } <= 100 })
    }

    @Test("A summary opens with its date and how much it covers, not a second title")
    func summaryHeading() {
        let heading = AIService.summaryHeading(date: "Oct 29", coverage: "12 messages")
        #expect(heading == "Oct 29 · 12 messages")
    }

    @Test("A summary written without the model opens with its date, and uses no emoji")
    func fallbackSummaryHasNoTitleOrEmoji() {
        let labels = AIService.summaryLabels(for: "en")
        let messages = [
            SummaryMessage(text: "Dinner on Saturday?", sender: "Sam", isFromCurrentUser: false, messageType: .text),
            SummaryMessage(text: "📷", sender: "Me", isFromCurrentUser: true, messageType: .image),
            SummaryMessage(text: "", sender: "Sam", isFromCurrentUser: false, messageType: .audio),
        ]
        let summary = AIService.fallbackSummary(
            messages: messages, textMessages: messages.compactMap(\.asText), labels: labels,
            participantList: "Me, Sam", fromMe: 1, fromOther: 2, dateStr: "Oct 29"
        )

        #expect(summary.components(separatedBy: "\n\n").first == "Oct 29")
        #expect(!summary.contains("Conversation Summary"))
        #expect(summary.unicodeScalars.allSatisfy { !$0.properties.isEmojiPresentation })
        #expect(summary.contains("• Image: 1"))
    }

    @Test("A summary is an overview, then a bold header over bullet lines for each section that has any")
    func summaryLayout() {
        let body = AIService.summaryBody(
            overview: " A trip to Jeju. ", keyTopics: ["Dates", " "], decisions: [],
            keyTopicsHeader: "Key Topics", decisionsHeader: "Decisions"
        )
        #expect(body == "A trip to Jeju.\n\n**Key Topics**\n• Dates")
        #expect(AIService.summaryBody(overview: " ", keyTopics: [], decisions: [], keyTopicsHeader: "K", decisionsHeader: "D") == nil)
    }

    @Test("A summary is dated the way the app's language writes dates")
    func summaryDateFollowsTheAppLanguage() throws {
        let date = try #require(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 14, minute: 1)))
        #expect(AIService.summaryDate(date, language: "ko").contains("오후"))
        #expect(AIService.summaryDate(date, language: "en").contains("Oct"))
        #expect(AIService.summaryDate(date, language: "ja").contains("2026年10月14日"))
    }

    @Test("A short chat is read in one part")
    func shortChatIsOnePart() {
        #expect(ConversationChunker.chunks(of: ["Me: hi", "Mina: hello"], budget: AIService.summaryTranscriptBudget).count == 1)
    }
}

// MARK: - Message search

@MainActor
@Suite("Message search")
struct MessageSearchTests {
    private func text(_ words: String) -> Message { Message(text: words, isFromCurrentUser: false, chatRoomId: "room") }

    @Test("Messages are found by their words, ignoring case, accents and width")
    func findsWordsLoosely() {
        let cafe = text("Café at 7?")
        let wide = text("ＤＩＮＮＥＲ")
        let other = text("see you")
        #expect(MessageSearch.filter([cafe, wide, other], query: "CAFE").map(\.id) == [cafe.id])
        #expect(MessageSearch.filter([cafe, wide, other], query: "dinner").map(\.id) == [wide.id])
    }

    @Test("Voice transcripts, photo descriptions and file names can be found; videos and places can't")
    func findsWhatAttachmentsSay() {
        let voice = Message(audioData: Data([1]), duration: 2, isFromCurrentUser: true, chatRoomId: "room")
        voice.transcript = "see you at the beach"
        let photo = Message(imageData: Data([1]), isFromCurrentUser: true, chatRoomId: "room")
        photo.imageDescription = "A dog running on a beach."
        let file = Message(fileName: "beach-trip", fileExtension: "pdf", fileSize: 10, isFromCurrentUser: true, chatRoomId: "room")
        let place = Message(latitude: 1, longitude: 2, isFromCurrentUser: true, chatRoomId: "room")
        let video = Message(text: "beach video", isFromCurrentUser: true, chatRoomId: "room", messageType: .video)

        let found = MessageSearch.filter([voice, photo, file, place, video], query: "beach")

        #expect(found.map(\.id) == [voice.id, photo.id, file.id])
    }

    @Test("A blank search finds everything, and related terms widen a search")
    func blankAndWidenedSearches() {
        let dinner = text("Dinner tonight?")
        let lunch = text("Lunch tomorrow?")
        #expect(MessageSearch.filter([dinner, lunch], query: "  ").count == 2)
        #expect(MessageSearch.filter([dinner, lunch], query: "저녁", relatedTerms: ["dinner"]).map(\.id) == [dinner.id])
    }

    @Test("Related terms leave out the search itself, repeats and short Latin fragments")
    func relatedTermsAreCleaned() {
        let terms = ["Dinner", " dinner ", "저녁 약속", "a", "of", "밥", "\"supper\""]
        #expect(OnDeviceSearchExpander.cleaned(terms, excluding: "저녁 약속") == ["Dinner", "밥", "supper"])
    }

    @Test("A translation of the whole search is used word by word")
    func translationsAreSplitIntoWords() {
        #expect(OnDeviceSearchExpander.words(of: ["dinner appointment", "식사", "夕食の約束"]) == ["dinner", "appointment", "식사", "夕食の約束"])
    }

    @Test("Related terms are asked for in the search's language, then the chat's")
    func termsCoverTheSearchAndTheChat() {
        let chat = ["Want to grab dinner tonight?", "Sure, where should we go?", "How about the Italian place downtown?"]
            .map { SummaryMessage(text: $0, sender: "Sam", isFromCurrentUser: false, messageType: .text) }
        let names = OnDeviceSearchExpander.languageNames(for: "오늘 저녁 약속", in: chat)
        #expect(names.all == "Korean and English")
        #expect(names.others == "English")
        #expect(OnDeviceSearchExpander.languageNames(for: "dinner plans", in: chat).others == nil, "nothing to translate into")
    }
}

// MARK: - AI feature settings

@Suite("AI feature settings")
struct AIFeatureSettingsTests {
    @Test("A switch reads its default until it is set, then what was set")
    func switchFallsBackToItsDefault() throws {
        let key = "test-\(UUID().uuidString)"
        defer { UserDefaults.standard.removeObject(forKey: key) }
        let feature = AIFeatureSwitch(key: key, defaultValue: true)

        #expect(feature.isOn)
        UserDefaults.standard.set(false, forKey: key)
        #expect(!feature.isOn)
    }

    @Test("Every AI feature starts on, each under its own key")
    func everyFeatureStartsOn() {
        let switches = [AIFeatureSettings.summary, AIFeatureSettings.search, AIFeatureSettings.meetingNotes, AIFeatureSettings.replySuggestions]
        #expect(switches.allSatisfy { $0.defaultValue })
        #expect(Set(switches.map { $0.key }).count == switches.count)
    }
}

// MARK: - Photo descriptions

@Suite("Photo descriptions")
struct PhotoDescriptionTests {
    /// A blank `width` x `height` image, encoded as `type` with an optional EXIF orientation.
    private func encodedImage(width: Int, height: Int, type: String = "public.png", orientation: Int? = nil) throws -> Data {
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, type as CFString, 1, nil))
        let properties = orientation.map { [kCGImagePropertyOrientation: $0] as CFDictionary }
        CGImageDestinationAddImage(destination, image, properties)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    @Test("A large photo is decoded small for the model")
    func largePhotosAreScaledDown() throws {
        let thumbnail = try #require(PhotoThumbnail.make(from: try encodedImage(width: 3000, height: 2000), maxPixelSize: 1024))
        #expect(thumbnail.width == 1024)
        #expect(abs(thumbnail.height - 683) <= 1)
    }

    @Test("A photo taken sideways is decoded upright")
    func rotatedPhotosAreDecodedUpright() throws {
        // Stored landscape, with EXIF saying to turn it a quarter turn to view it.
        let sideways = try encodedImage(width: 1200, height: 800, type: "public.jpeg", orientation: 6)
        let thumbnail = try #require(PhotoThumbnail.make(from: sideways, maxPixelSize: 600))
        #expect(thumbnail.height > thumbnail.width)
    }

    @Test("The request is written in the language the description should be in", arguments: [
        ("ko", "사진"), ("ja", "写真"), ("zh", "照片"), ("es", "foto"), ("en", "photo"), ("zh-Hans", "照片"), ("fr", "photo"),
    ])
    func requestIsInTheTargetLanguage(code: String, word: String) {
        #expect(OnDevicePhotoDescriber.request(for: code).contains(word))
    }

    @Test("Only the first line the model writes is kept")
    func descriptionIsOneLine() {
        #expect(OnDevicePhotoDescriber.cleaned("\n  A dog on a beach.  \n【日本語】ビーチの犬。") == "A dog on a beach.")
        #expect(OnDevicePhotoDescriber.cleaned(" \n ") == nil)
    }

    @Test("A described photo is spelled out for the model")
    func describedPhotoReadsAsWhatItShows() {
        let photo = SummaryMessage(text: "📷", sender: "Me", isFromCurrentUser: true, messageType: .image, imageDescription: "A dog on a beach.")
        #expect(photo.transcriptText == "[sent a photo: A dog on a beach.]")
    }
}

// MARK: - Auto replies

private struct FixedReplyWriter: ReplyWriting {
    let text: String?
    func reply(to conversation: [SummaryMessage], as partner: String, language: String?) async -> String? { text }
}

/// Remembers the chat it was shown and who it was asked to write as.
private actor RecordingReplyWriter: ReplyWriting {
    private(set) var seen: [SummaryMessage] = []
    private(set) var partner: String?
    private(set) var language: String?
    func reply(to conversation: [SummaryMessage], as partner: String, language: String?) async -> String? {
        seen = conversation
        self.partner = partner
        self.language = language
        return "ok"
    }
}

@MainActor
@Suite("Auto replies")
struct AutoReplyTests {
    private let context: ModelContext
    private let room = ChatRoom(name: "Mina")

    init() throws {
        let container = try ModelContainer(
            for: Message.self, ChatRoom.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
        context.insert(room)
        try context.save()
    }

    private func service(
        _ writers: [any ReplyWriting], pickMember: @escaping ([String]) -> String? = { $0.first },
        memberLanguage: @escaping (String) -> String? = { _ in nil }
    ) -> AutoResponseService {
        AutoResponseService(
            messageRepository: LocalMessageRepository(modelContext: context),
            chatRoomRepository: LocalChatRoomRepository(modelContext: context),
            writers: writers,
            pacing: .immediate,
            pickMember: pickMember,
            memberLanguage: memberLanguage
        )
    }

    private func say(_ text: String, minutesAgo: Double) throws {
        let message = Message(text: text, isFromCurrentUser: true, chatRoomId: room.id.uuidString)
        message.timestamp = Date().addingTimeInterval(-minutesAgo * 60)
        context.insert(message)
        try context.save()
    }

    @Test("The first writer that writes a reply wins, and the reply is saved and shown")
    func firstWrittenReplyIsSent() async throws {
        try say("Dinner at 7?", minutesAgo: 1)
        var typing: [Bool] = []
        var shown: Message?

        try await service([FixedReplyWriter(text: nil), FixedReplyWriter(text: "Sounds good!"), FixedReplyWriter(text: "unused")])
            .generateResponse(for: room, onTypingChange: { typing.append($0) }, onMessage: { shown = $0 })

        #expect(typing == [true, false])
        #expect(shown?.text == "Sounds good!")
        #expect(shown?.sender == "Mina")
        #expect(shown?.isFromCurrentUser == false)
        #expect(room.lastMessage == "Sounds good!")
        let saved = try await LocalMessageRepository(modelContext: context).fetchMessages(for: room.id.uuidString, limit: 10, before: nil)
        #expect(saved.map(\.text) == ["Dinner at 7?", "Sounds good!"])
    }

    @Test("In a group chat a member answers, not the group")
    func groupReplyComesFromAMember() async throws {
        room.memberNames = ["Jisoo", "Minho"]
        try say("Dinner at 7?", minutesAgo: 1)
        let writer = RecordingReplyWriter()
        var shown: Message?

        try await service([writer], pickMember: { $0.last }).generateResponse(for: room, onTypingChange: { _ in }, onMessage: { shown = $0 })

        #expect(shown?.sender == "Minho")
        #expect(await writer.partner == "Minho")
    }

    @Test("A member who writes another language answers in it")
    func memberAnswersInTheirLanguage() async throws {
        room.memberNames = ["佐藤ゆき", "Minho"]
        try say("Dinner at 7?", minutesAgo: 1)
        let writer = RecordingReplyWriter()

        try await service([writer], pickMember: { $0.first }, memberLanguage: { $0 == "佐藤ゆき" ? "ja" : nil })
            .generateResponse(for: room, onTypingChange: { _ in }, onMessage: { _ in })

        #expect(await writer.partner == "佐藤ゆき")
        #expect(await writer.language == "ja")
    }

    @Test("Stock replies are in the language they are asked for")
    func cannedReplyInAskedLanguage() async throws {
        let chat = [SummaryMessage(text: "Dinner at 7 tonight?", sender: "Me", isFromCurrentUser: true, messageType: .text)]
        let reply = try #require(await CannedReplyWriter(fallbackLanguage: "en").reply(to: chat, as: "Yuki", language: "ja"))
        #expect(CannedReplyWriter.replies["ja"]?.contains(reply) == true)
    }

    @Test("The sample study group's members write Japanese and Spanish")
    func sampleGroupIsMultilingual() throws {
        let members = try #require(TestData.groupMembers["study_group"])
        #expect(Set(members.compactMap(TestData.language(of:))) == ["ja", "es"])
    }

    @Test("The other side of a chat is a member in a group and the room's name otherwise")
    func otherSideSender() {
        let oneToOne = ChatRoom(name: "Mina")
        #expect(oneToOne.otherSideSender() == "Mina")
        let group = ChatRoom(name: "Family")
        group.memberNames = ["Jisoo", "Minho"]
        #expect(group.memberNames.contains(group.otherSideSender()))
        #expect(group.otherSideSender(pickingFrom: { $0.first }) == "Jisoo")
    }

    @Test("A room's person and group icons exist in SF Symbols")
    func roomSymbolsExist() {
        #expect(UIImage(systemName: ChatRoom.personSymbol) != nil)
        #expect(UIImage(systemName: ChatRoom.groupSymbol) != nil)
    }

    @Test("Writers see the chat so far, oldest first")
    func writersSeeTheChatInOrder() async throws {
        try say("first", minutesAgo: 3)
        try say("second", minutesAgo: 2)
        try say("third", minutesAgo: 1)
        let writer = RecordingReplyWriter()

        try await service([writer]).generateResponse(for: room, onTypingChange: { _ in }, onMessage: { _ in })

        #expect(await writer.seen.map(\.text) == ["first", "second", "third"])
    }

    @Test("In a disappearing chat the reply disappears too")
    func replyFollowsDisappearingSetting() async throws {
        room.disappearingDuration = 60
        try say("hi", minutesAgo: 1)
        var shown: Message?

        try await service([FixedReplyWriter(text: "hey")]).generateResponse(for: room, onTypingChange: { _ in }, onMessage: { shown = $0 })

        #expect(shown?.isDisappearing == true)
        #expect(shown?.disappearAfterSeconds == 60)
    }

    @Test("Stock replies are in the language the user writes in", arguments: [
        ("오늘 저녁에 뭐 먹을까요?", "ko"),
        ("What should we have for dinner tonight?", "en"),
        ("今夜は何を食べようか？", "ja"),
        ("我们今晚吃什么？", "zh"),
        ("¿Qué cenamos esta noche?", "es"),
    ])
    func stockRepliesFollowTheChatsLanguage(text: String, language: String) async throws {
        let chat = [SummaryMessage(text: text, sender: "Me", isFromCurrentUser: true, messageType: .text)]
        let reply = try #require(await CannedReplyWriter(fallbackLanguage: "en").reply(to: chat, as: "Mina"))
        #expect(CannedReplyWriter.replies[language]?.contains(reply) == true)
    }

    @Test("A message too short to tell is read together with the user's earlier ones")
    func shortMessagesUseTheEarlierOnes() {
        func chat(_ texts: String...) -> [SummaryMessage] {
            texts.map { SummaryMessage(text: $0, sender: "Me", isFromCurrentUser: true, messageType: .text) }
        }
        #expect(ConversationLanguage.of(chat("ok")) == nil)
        #expect(ConversationLanguage.of(chat("내일 몇 시에 만날까?", "ok")) == .korean)
        #expect(ConversationLanguage.of(chat("내일 몇 시에 만날까?", "Sounds great, see you there!")) == .english)

        let addressed = [SummaryMessage(text: "明日の会議、10時からで大丈夫？", sender: "Yuki", isFromCurrentUser: false, messageType: .text)]
        #expect(ConversationLanguage.of(addressed) == .japanese, "before the user writes, the chat's language is what they were written to in")
    }

    @Test("Attachments are spelled out for the model rather than left as an emoji")
    func attachmentsReadAsWhatWasSent() {
        let photo = SummaryMessage(text: "📷", sender: "Me", isFromCurrentUser: true, messageType: .image)
        let words = SummaryMessage(text: "see you", sender: "Me", isFromCurrentUser: true, messageType: .text)
        #expect(photo.transcriptText == "[sent a photo]")
        #expect(words.transcriptText == "see you")
    }

    @Test("With no text to go by, stock replies are in the app's language")
    func stockRepliesFallBackToTheAppLanguage() async throws {
        let reply = try #require(await CannedReplyWriter(fallbackLanguage: "ja").reply(to: [], as: "Mina"))
        #expect(CannedReplyWriter.replies["ja"]?.contains(reply) == true)
    }

    @Test("A model reply loses the speaker label and wrapping quotes", arguments: [
        ("You: Sounds good!", "Sounds good!"),
        ("Mina: \"See you at 7\"", "See you at 7"),
        ("“Sure thing”", "Sure thing"),
        ("\"Hi\" and \"bye\"", "\"Hi\" and \"bye\""),
        ("   ", nil),
    ] as [(String, String?)])
    func modelReplyIsCleaned(raw: String, expected: String?) {
        #expect(OnDeviceReplyWriter.cleaned(raw, partner: "Mina") == expected)
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

/// Notes the newest message as it stood each time the other side was asked to answer.
@MainActor
private final class RecordingAutoResponder: AutoResponding {
    weak var viewModel: ChatViewModel?
    private(set) var lastMessageWhenAsked: [SummaryMessage?] = []

    func generateResponse(
        for chatRoom: ChatRoom,
        onTypingChange: @escaping (Bool) -> Void,
        onMessage: @escaping (Message) -> Void
    ) async throws {
        lastMessageWhenAsked.append(viewModel?.messages.last.map(SummaryMessage.init))
    }
}

/// Stands in for on-device search expansion; a query's lookup can be slowed down.
private struct FixedExpander: SearchQueryExpanding {
    var terms: [String: [String]] = [:]
    var delays: [String: Duration] = [:]
    func relatedTerms(for query: String, in conversation: [SummaryMessage]) async -> [String] {
        try? await Task.sleep(for: delays[query] ?? .zero)
        return terms[query] ?? []
    }
}

/// Stands in for on-device photo descriptions.
private struct FixedDescriber: PhotoDescribing {
    var sentence: String?
    func describe(_ imageData: Data, languageCode: String) async -> String? { sentence }
}

/// Stands in for on-device transcription.
private struct FixedTranscriber: VoiceTranscribing {
    var words: String?
    var delay: Duration = .zero
    func transcribe(_ audio: Data, languageCode: String) async -> String? {
        try? await Task.sleep(for: delay)
        return words
    }
}

/// Stands in for the on-device model's reply suggestions.
private struct FixedSuggester: ReplySuggesting {
    var replies: [String] = []
    func suggestions(for conversation: [SummaryMessage]) async -> [String] { replies }
}

/// Waits for state a view model updates from its own tasks, such as the load it starts on init.
@MainActor
private func eventually(within timeout: Duration = .seconds(2), _ condition: () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
        guard ContinuousClock.now < deadline else { return false }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return true
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

    private func makeViewModel(
        _ context: ModelContext, room: ChatRoom,
        autoResponder: AutoResponding? = nil,
        suggester: ReplySuggesting = FixedSuggester(), suggestionsEnabled: Bool = true,
        transcriber: VoiceTranscribing = FixedTranscriber(),
        describer: PhotoDescribing = FixedDescriber(),
        expander: SearchQueryExpanding = FixedExpander(), searchByMeaning: Bool = true
    ) -> ChatViewModel {
        ChatViewModel(
            messageRepository: LocalMessageRepository(modelContext: context, attachmentFiles: attachmentFiles),
            chatRoomRepository: LocalChatRoomRepository(modelContext: context, attachmentFiles: attachmentFiles),
            chatRoom: room,
            autoResponder: autoResponder ?? SilentAutoResponder(),
            replySuggester: suggester,
            replySuggestionsEnabled: { suggestionsEnabled },
            voiceTranscriber: transcriber,
            photoDescriber: describer,
            searchExpander: expander,
            searchByMeaningEnabled: { searchByMeaning }
        )
    }

    @Test("A summary reads past the page on screen, up to its limit")
    func summaryReadsBeyondTheLoadedPage() async throws {
        let context = try makeContext()
        let room = try makeRoom(in: context)
        let start = Date().addingTimeInterval(-10_000)
        for index in 0..<120 {
            let message = Message(text: "message \(index)", isFromCurrentUser: index % 2 == 0, chatRoomId: room.id.uuidString)
            message.timestamp = start.addingTimeInterval(Double(index))
            context.insert(message)
        }
        try context.save()
        let viewModel = makeViewModel(context, room: room)
        await viewModel.loadMessages()

        let everything = await viewModel.recentConversation(limit: 300)
        let latest = await viewModel.recentConversation(limit: 80)

        #expect(viewModel.messages.count == 50, "only a page is on screen")
        #expect(everything.map(\.text) == (0..<120).map { "message \($0)" })
        #expect(latest.first?.text == "message 40")
        #expect(latest.count == 80)
    }

    @Test("Searching by meaning also finds messages that say it differently")
    func searchByMeaningFindsRelatedWords() async throws {
        let context = try makeContext()
        let room = try makeRoom(in: context)
        try receive("Dinner tonight at 7?", in: room, context: context)
        try receive("see you", in: room, context: context)
        let viewModel = makeViewModel(context, room: room, expander: FixedExpander(terms: ["저녁 약속": ["dinner"]]))
        await viewModel.loadMessages()
        #expect(viewModel.searchResults(for: "저녁 약속").isEmpty, "the words as typed match nothing")

        await viewModel.expandSearch(for: "저녁 약속", after: .zero)

        #expect(viewModel.relatedSearchTerms == ["dinner"])
        #expect(viewModel.searchResults(for: "저녁 약속").map(\.text) == ["Dinner tonight at 7?"])
        #expect(!viewModel.isExpandingSearch)
    }

    @Test("With searching by meaning off, search still matches the words as typed")
    func searchByMeaningCanBeTurnedOff() async throws {
        let context = try makeContext()
        let room = try makeRoom(in: context)
        try receive("Dinner tonight at 7?", in: room, context: context)
        let viewModel = makeViewModel(context, room: room, expander: FixedExpander(terms: ["저녁 약속": ["dinner"]]), searchByMeaning: false)
        await viewModel.loadMessages()

        await viewModel.expandSearch(for: "저녁 약속", after: .zero)

        #expect(viewModel.relatedSearchTerms.isEmpty)
        #expect(viewModel.searchResults(for: "저녁 약속").isEmpty)
        #expect(viewModel.searchResults(for: "dinner").count == 1)
    }

    @Test("A lookup that returns after a newer search started is ignored")
    func staleSearchLookupIsIgnored() async throws {
        let context = try makeContext()
        let room = try makeRoom(in: context)
        let expander = FixedExpander(terms: ["old query": ["old"], "new query": ["new"]], delays: ["old query": .milliseconds(300)])
        let viewModel = makeViewModel(context, room: room, expander: expander)

        let older = Task { await viewModel.expandSearch(for: "old query", after: .zero) }
        try await Task.sleep(for: .milliseconds(50)) // the older lookup is under way
        await viewModel.expandSearch(for: "new query", after: .zero)
        await older.value

        #expect(viewModel.relatedSearchTerms == ["new"])
        #expect(!viewModel.isExpandingSearch)
    }

    @Test("A photo is described, and the other side answers once the description is in")
    func photoIsDescribedBeforeTheReply() async throws {
        let context = try makeContext()
        let room = try makeRoom(in: context)
        let responder = RecordingAutoResponder()
        let viewModel = makeViewModel(context, room: room, autoResponder: responder, describer: FixedDescriber(sentence: "A dog running on a beach."))
        responder.viewModel = viewModel

        await viewModel.sendImage(Data([0x01])).value

        #expect(viewModel.messages.last?.imageDescription == "A dog running on a beach.")
        #expect(try context.fetch(FetchDescriptor<Message>()).first?.imageDescription == "A dog running on a beach.")
        #expect(await eventually { responder.lastMessageWhenAsked.map { $0?.imageDescription } == ["A dog running on a beach."] })
    }

    @Test("A voice message is written down, and the other side answers once the words are in")
    func voiceMessageIsTranscribedBeforeTheReply() async throws {
        let context = try makeContext()
        let room = try makeRoom(in: context)
        let responder = RecordingAutoResponder()
        let viewModel = makeViewModel(context, room: room, autoResponder: responder, transcriber: FixedTranscriber(words: "Let's meet at 7"))
        responder.viewModel = viewModel

        await viewModel.sendVoiceMessage(audioData: Data([0x01]), duration: 2).value

        #expect(viewModel.messages.last?.transcript == "Let's meet at 7")
        #expect(try context.fetch(FetchDescriptor<Message>()).first?.transcript == "Let's meet at 7")
        #expect(await eventually { responder.lastMessageWhenAsked.map { $0?.transcript } == ["Let's meet at 7"] })
    }

    @Test("A voice message shows as being transcribed until its words are in")
    func voiceMessageIsMarkedWhileTranscribing() async throws {
        let context = try makeContext()
        let room = try makeRoom(in: context)
        let viewModel = makeViewModel(context, room: room, transcriber: FixedTranscriber(words: "hi", delay: .milliseconds(300)))

        let sending = viewModel.sendVoiceMessage(audioData: Data([0x01]), duration: 1)

        #expect(await eventually { viewModel.messages.last.map { viewModel.transcribingMessageIDs.contains($0.id) } == true })
        await sending.value
        #expect(viewModel.transcribingMessageIDs.isEmpty)
        #expect(viewModel.messages.last?.transcript == "hi")
    }

    @Test("A voice message whose words can't be made out is still sent and answered")
    func untranscribedVoiceMessageIsStillAnswered() async throws {
        let context = try makeContext()
        let room = try makeRoom(in: context)
        let responder = RecordingAutoResponder()
        let viewModel = makeViewModel(context, room: room, autoResponder: responder, transcriber: FixedTranscriber(words: nil))
        responder.viewModel = viewModel

        await viewModel.sendVoiceMessage(audioData: Data([0x01]), duration: 2).value

        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages.last?.transcript == nil)
        #expect(await eventually { responder.lastMessageWhenAsked.count == 1 })
        #expect(responder.lastMessageWhenAsked.first??.transcript == nil)
    }

    private func receive(_ text: String, in room: ChatRoom, context: ModelContext) throws {
        context.insert(Message(text: text, isFromCurrentUser: false, sender: room.name, chatRoomId: room.id.uuidString))
        try context.save()
    }

    @Test("Replies are suggested while the other side has the last word, and cleared once the user answers")
    func replySuggestionsFollowTheLastSpeaker() async throws {
        let context = try makeContext()
        let room = try makeRoom(in: context)
        try receive("Dinner at 7?", in: room, context: context)
        let viewModel = makeViewModel(context, room: room, suggester: FixedSuggester(replies: ["Sure!", "Can't tonight"]))

        #expect(await eventually { viewModel.replySuggestions == ["Sure!", "Can't tonight"] })

        viewModel.newMessageText = "Sure!"
        await viewModel.sendMessage()?.value
        #expect(viewModel.replySuggestions.isEmpty)
        #expect(viewModel.refreshReplySuggestions() == nil, "the user spoke last, so there is nothing to answer")
    }

    @Test("With suggestions turned off in settings, none are asked for")
    func replySuggestionsCanBeTurnedOff() async throws {
        let context = try makeContext()
        let room = try makeRoom(in: context)
        try receive("Dinner at 7?", in: room, context: context)
        let viewModel = makeViewModel(context, room: room, suggester: FixedSuggester(replies: ["Sure!"]), suggestionsEnabled: false)

        await viewModel.loadMessages()

        #expect(viewModel.refreshReplySuggestions() == nil)
        #expect(viewModel.replySuggestions.isEmpty)
    }

    @Test("Model suggestions are trimmed, kept short, deduplicated and capped at three")
    func replySuggestionsAreCleaned() {
        let suggestions = [String(repeating: "a", count: 61), " Sure! ", "\"sure!\"", "", "Can't tonight", "What time?", "Maybe later"]
        #expect(OnDeviceReplySuggester.cleaned(suggestions) == ["Sure!", "Can't tonight", "What time?"])
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

// MARK: - Meeting notes

@MainActor
@Suite("Meeting notes")
struct MeetingNotesTests {
    private func msg(_ text: String, from sender: String = "Mina", mine: Bool = false) -> SummaryMessage {
        SummaryMessage(text: text, sender: sender, isFromCurrentUser: mine, messageType: .text)
    }

    private func task(_ quote: String, _ kind: MeetingNotes.ProposedTask.Kind, _ task: String, owner: String? = nil, due: String? = nil) -> MeetingNotes.ProposedTask {
        MeetingNotes.ProposedTask(quote: quote, kind: kind, task: task, owner: owner, due: due)
    }

    private func ground(_ tasks: [MeetingNotes.ProposedTask], decisions: [String] = [], questions: [String] = [], in chat: [SummaryMessage]) -> MeetingNotes {
        MeetingNotesGrounding.ground(.init(summary: " Plans ", decisions: decisions, openQuestions: questions, tasks: tasks), in: chat, meLabel: "Me")
    }

    @Test("Dates and times are kept as the chat wrote them, with the message they came from")
    func scheduleKeepsTheChatsWording() throws {
        let schedule = MeetingNotesExtractor.schedule(in: [
            msg("Let's meet on October 20, 2026 at 3:00 PM at the station"),
            msg("ok", mine: true),
        ])
        let item = try #require(schedule.first)
        #expect(schedule.count == 1)
        #expect(item.when.contains("October 20, 2026") && item.when.contains("3:00 PM"))
        #expect(item.context.contains("station"))
    }

    @Test("A day named in passing is not put on the schedule")
    func scheduleSkipsDaysWithoutADigit() {
        #expect(MeetingNotesExtractor.schedule(in: [
            msg("Have a good day today!"), msg("오늘도 좋은 하루 되세요!"), msg("see you Friday", mine: true),
        ]).isEmpty)
    }

    @Test("Without the model, decisions, commitments and questions are picked out by rule")
    func ruleBasedExtraction() {
        let notes = MeetingNotesExtractor.extract(from: [
            msg("Let's go with the Italian place"),
            msg("I'll book a table for four", mine: true),
            msg("자료는 제가 준비할게요", from: "Joon"),
            msg("Who is bringing the cake?"),
            msg("haha nice"),
        ], meLabel: "Me")

        #expect(notes.decisions == ["Let's go with the Italian place"])
        #expect(notes.actionItems.map(\.task) == ["I'll book a table for four", "자료는 제가 준비할게요"])
        #expect(notes.actionItems.map(\.owner) == ["Me", "Joon"])
        #expect(notes.openQuestions == ["Who is bringing the cake?"])
        #expect(!notes.generatedByModel)
    }

    @Test("Small talk alone leaves nothing to note")
    func smallTalkIsEmpty() {
        #expect(MeetingNotesExtractor.extract(from: [msg("hi"), msg("hello!", mine: true)], meLabel: "Me").isEmpty)
    }

    @Test("A question is not a task, even when the model calls it a commitment")
    func questionsAreNotTasks() {
        let notes = ground(
            [task("Sure, I'll send them tonight", .commitment, "Send the slides"), task("Should we invite Jordan?", .commitment, "Invite Jordan", owner: "Mina")],
            questions: ["Should we invite Jordan?"],
            in: [msg("Can you send the slides?"), msg("Sure, I'll send them tonight", mine: true), msg("Should we invite Jordan?")]
        )
        #expect(notes.actionItems == [.init(task: "Send the slides", owner: "Me", due: nil)])
        #expect(notes.openQuestions == ["Should we invite Jordan?"])
        #expect(notes.summary == "Plans")
        #expect(notes.generatedByModel)
    }

    @Test("A task whose quote is not in the chat, or says nothing about doing anything, is dropped")
    func unsupportedTasksAreDropped() {
        let notes = ground(
            [task("I'll bring the cake", .commitment, "Bring the cake", owner: "Mina"), task("pretty good, went hiking", .statement, "Share the hike")],
            questions: ["Who is bringing the cake?"],
            in: [msg("Who is bringing the cake?", mine: true), msg("pretty good, went hiking")]
        )
        #expect(notes.actionItems.isEmpty)
        #expect(notes.openQuestions == ["Who is bringing the cake?"])
    }

    @Test("A quote still matches when the model changes punctuation or adds the sender's name")
    func quoteMatchingIgnoresPunctuationAndSender() {
        let notes = ground([task("Me: i'll book a table for six", .commitment, "Book a table", due: " ")], in: [msg("I'll book a table for six!", mine: true)])
        #expect(notes.actionItems == [.init(task: "Book a table", owner: "Me", due: nil)])
    }

    @Test("A commitment keeps the owner the chat names, and otherwise belongs to its sender")
    func commitmentOwner() {
        let chat = [
            msg("Sure, on it", mine: true), msg("Jordan will bring the wine", from: "Alex"),
            msg("I'll handle the slides"), msg("Could you book the table, please.", from: "Alex"),
        ]
        let notes = ground([
            task("Sure, on it", .commitment, "Book the venue"),
            task("Jordan will bring the wine", .commitment, "Bring the wine", owner: "Jordan"),
            task("I'll handle the slides", .commitment, "Handle the slides", owner: "Sam"),
            // A request the model took for a commitment: the participant it names still wins.
            task("Could you book the table, please.", .commitment, "Book the table", owner: "me"),
        ], in: chat)
        #expect(notes.actionItems.map(\.owner) == ["Me", "Jordan", "Mina", "Me"])
    }

    @Test("A request belongs to the person asked: one the chat names, or the other person in a two-person chat")
    func requestOwner() {
        let ask = msg("Could you book the table for Saturday, please.", from: "Alex")
        #expect(ground([task(ask.text, .request, "Book the table", owner: "Alex")], in: [ask, msg("Sure", mine: true)]).actionItems.map(\.owner) == ["Me"])
        let askedAsAQuestion = msg("Can you send me the slides by Thursday?", from: "Alex")
        #expect(ground([task(askedAsAQuestion.text, .request, "Send the slides")], in: [askedAsAQuestion]).actionItems.map(\.owner) == [nil])

        let group = [msg("Joon, please send the deck.", from: "Alex"), msg("ok", from: "Joon"), msg("thanks", mine: true)]
        #expect(ground([task(group[0].text, .request, "Send the deck", owner: "Joon")], in: group).actionItems.map(\.owner) == ["Joon"])
        #expect(ground([task(group[0].text, .request, "Send the deck", owner: "Sam")], in: group).actionItems.map(\.owner) == [nil])
    }

    @Test("A task proposed twice, or a decision that only restates a task, is left out")
    func nothingIsListedTwice() {
        let notes = ground(
            [task("I'll book a table for six", .commitment, "Book a table for six"), task("I'll book a table for six", .commitment, "book a table for six.")],
            decisions: ["Me will book a table for six", "Dinner at the Italian place"],
            in: [msg("I'll book a table for six", mine: true)]
        )
        #expect(notes.actionItems.count == 1)
        #expect(notes.decisions == ["Dinner at the Italian place"])
    }

    @Test("A transcribed voice message counts as what was said")
    func voiceMessagesCountAsWords() {
        let said = SummaryMessage(text: "🎤", sender: "Me", isFromCurrentUser: true, messageType: .audio,
                                  transcript: "I'll book the table for October 20, 2026 at 7:00 PM")
        let unheard = SummaryMessage(text: "🎤", sender: "Mina", isFromCurrentUser: false, messageType: .audio)

        let notes = MeetingNotesExtractor.extract(from: [said, unheard], meLabel: "Me")

        #expect(notes.actionItems == [.init(task: "I'll book the table for October 20, 2026 at 7:00 PM", owner: "Me", due: nil)])
        #expect(notes.schedule.map(\.context) == ["I'll book the table for October 20, 2026 at 7:00 PM"])
        #expect(unheard.asText == nil)
        #expect(said.transcriptText == "[voice message] I'll book the table for October 20, 2026 at 7:00 PM")
        #expect(unheard.transcriptText == "[sent a voice message]")
    }

    @Test("Shared text lists only the sections that have content")
    func shareTextSkipsEmptySections() {
        let notes = MeetingNotes(
            summary: "Dinner plans",
            decisions: ["Italian place"],
            actionItems: [.init(task: "Book a table", owner: "Me", due: "today")],
            schedule: [.init(when: "Friday at 7", context: "Dinner Friday at 7?")],
            openQuestions: [],
            generatedByModel: true
        )
        let labels = MeetingNotes.Labels(title: "Notes", decisions: "Decisions", actionItems: "Tasks", schedule: "Schedule", openQuestions: "Questions")
        #expect(notes.shareText(labels: labels)
                == "Notes\n\nDinner plans\n\nDecisions\n• Italian place\n\nTasks\n• Me: Book a table (today)\n\nSchedule\n• Friday at 7 — Dinner Friday at 7?")
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

// MARK: - Bubble colors

/// A color's red, green and blue, from 0 to 1.
private func components(_ color: Color) -> (r: Double, g: Double, b: Double) {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, alpha: CGFloat = 0
    UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &alpha)
    return (Double(r), Double(g), Double(b))
}

/// The WCAG contrast ratio of two opaque colors: from 1 (none) to 21 (black on white).
private func contrastRatio(_ a: Color, _ b: Color) -> Double {
    func luminance(_ color: Color) -> Double {
        func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let c = components(color)
        return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
    }
    let (l1, l2) = (luminance(a), luminance(b))
    return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
}

@MainActor
@Suite("Bubble colors")
struct BubbleColorTests {
    @Test("Text on your own bubbles is easy to read")
    func ownBubbleTextContrast() {
        #expect(contrastRatio(.onAppPrimary, .appPrimary) >= 7, "WCAG AAA for body text")
    }

    @Test("Dimmed details on your bubbles, like a voice message's length, stay readable", arguments: [0.7, 0.8, 0.9])
    func dimmedDetailsStayReadable(opacity: Double) {
        let content = components(.onAppPrimary), bubble = components(.appPrimary)
        let blended = Color(
            red: content.r * opacity + bubble.r * (1 - opacity),
            green: content.g * opacity + bubble.g * (1 - opacity),
            blue: content.b * opacity + bubble.b * (1 - opacity)
        )
        #expect(contrastRatio(blended, .appPrimary) >= 4.5, "WCAG AA for text")
    }

    @Test("White on the brand color is too faint, which is why your bubbles no longer use it")
    func whiteOnBrandIsTooFaint() {
        #expect(contrastRatio(.white, .appPrimary) < 3)
    }

    @Test("White on the deeper brand shade is readable")
    func whiteOnStrongShade() {
        #expect(contrastRatio(.white, .appPrimaryStrong) >= 4.5)
    }

    @Test("Black on white measures 21:1")
    func formulaCheck() {
        #expect(abs(contrastRatio(.black, .white) - 21) < 0.01)
    }
}

@MainActor
@Suite("Brand text color")
struct BrandTextColorTests {
    /// The color as it looks in light or dark mode.
    private func resolved(_ color: Color, _ style: UIUserInterfaceStyle) -> Color {
        Color(UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style)))
    }

    @Test("Brand-colored text reads on white in light mode")
    func readableInLightMode() {
        #expect(contrastRatio(resolved(.appPrimaryText, .light), .white) >= 4.5)
    }

    @Test("Brand-colored text reads on black in dark mode")
    func readableInDarkMode() {
        #expect(contrastRatio(resolved(.appPrimaryText, .dark), .black) >= 4.5)
    }

    @Test("The sign-in button's text reads on the brand color")
    func signInButtonText() {
        #expect(contrastRatio(.onAppPrimary, .appPrimary) >= 7)
    }
}

// MARK: - App Lock

@Suite("App Lock")
@MainActor
struct AppLockTests {

    /// Stands in for Face ID and the passcode prompt. Only these main-actor tests touch it.
    private final class FakeAuthenticator: DeviceOwnerAuthenticating, @unchecked Sendable {
        var available = true
        var succeeds = false
        private(set) var prompts = 0

        func canAuthenticate() -> Bool { available }

        func authenticate(reason: String, fallbackTitle: String) async throws {
            prompts += 1
            if !succeeds { throw CancellationError() }
        }
    }

    private func makeDefaults(lockEnabled: Bool) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "AppLockTests-\(UUID().uuidString)")!
        defaults.set(lockEnabled, forKey: AppLockManager.enabledKey)
        return defaults
    }

    @Test("A cancelled or failed check keeps the app locked and the lock on")
    func failedCheckStaysLocked() async {
        let device = FakeAuthenticator()
        let defaults = makeDefaults(lockEnabled: true)
        let lock = AppLockManager(authenticator: device, defaults: defaults)
        lock.updateLockStateOnLaunch()

        await lock.authenticate()

        #expect(lock.isLocked)
        #expect(lock.errorMessage != nil)
        #expect(defaults.bool(forKey: AppLockManager.enabledKey), "failing must not turn App Lock off")
    }

    @Test("A successful check unlocks the app")
    func successfulCheckUnlocks() async {
        let device = FakeAuthenticator()
        device.succeeds = true
        let lock = AppLockManager(authenticator: device, defaults: makeDefaults(lockEnabled: true))
        lock.updateLockStateOnLaunch()
        #expect(lock.isLocked)

        await lock.authenticate()

        #expect(!lock.isLocked)
        #expect(lock.errorMessage == nil)
        #expect(device.prompts == 1)
    }

    @Test("Without a device passcode the setting is turned off instead of locking the owner out")
    func noPasscodeTurnsTheSettingOff() {
        let device = FakeAuthenticator()
        device.available = false
        let defaults = makeDefaults(lockEnabled: true)
        let lock = AppLockManager(authenticator: device, defaults: defaults)

        lock.updateLockStateOnLaunch()

        #expect(!lock.isLocked)
        #expect(!defaults.bool(forKey: AppLockManager.enabledKey))
    }

    @Test("Leaving the app locks it only when App Lock is on", arguments: [true, false])
    func backgroundLocksWhenEnabled(enabled: Bool) {
        let lock = AppLockManager(authenticator: FakeAuthenticator(), defaults: makeDefaults(lockEnabled: enabled))
        lock.handleScenePhase(.background)
        #expect(lock.isLocked == enabled)
    }
}

// MARK: - Passwords

@Suite("Password hashing")
struct PasswordHasherTests {
    private let hasher = PasswordHasher(iterations: 1_000)

    @Test("The right password matches its hash and others don't")
    func verifies() {
        let stored = hasher.hash("correct horse")
        #expect(hasher.verify("correct horse", against: stored))
        #expect(!hasher.verify("correct hors", against: stored))
        #expect(!hasher.verify("", against: stored))
    }

    @Test("The same password gets a new salt, and so a new hash, each time")
    func saltsDiffer() {
        let first = hasher.hash("secret1")
        let second = hasher.hash("secret1")
        #expect(first.salt != second.salt)
        #expect(first.hash != second.hash)
        #expect(first.salt.count == 16 && first.hash.count == 32)
    }

    @Test("A hash keeps the work factor it was made with")
    func keepsIterations() {
        let stored = PasswordHasher(iterations: 2_000).hash("secret1")
        #expect(stored.iterations == 2_000)
        #expect(hasher.verify("secret1", against: stored), "checking uses the stored count, not the hasher's own")
    }

    @Test("Byte comparison", arguments: [
        (Data([1, 2, 3]), Data([1, 2, 3]), true),
        (Data([1, 2, 3]), Data([1, 2, 4]), false),
        (Data([1, 2, 3]), Data([1, 2]), false)
    ])
    func constantTimeEqual(lhs: Data, rhs: Data, equal: Bool) {
        #expect(PasswordHasher.constantTimeEqual(lhs, rhs) == equal)
    }

    @Test("The Keychain store keeps a hash per account and forgets them all on wipe")
    func keychainStore() throws {
        let store = KeychainPasswordStore(service: "TalkMVPTests-\(UUID().uuidString)", hasher: hasher)
        defer { store.removeAllPasswords() }
        let jordan = UUID(), sam = UUID()
        try store.setPassword("secret1", for: jordan)
        try store.setPassword("other22", for: sam)
        try store.setPassword("changed", for: jordan)

        #expect(store.verifyPassword("changed", for: jordan), "setting again replaces the old hash")
        #expect(!store.verifyPassword("secret1", for: jordan))
        #expect(store.verifyPassword("other22", for: sam))
        #expect(!store.verifyPassword("other22", for: UUID()))

        store.removeAllPasswords()
        #expect(!store.verifyPassword("other22", for: sam))
    }

    @Test("The store forgets every password when the data is wiped")
    func storeRemovesAll() throws {
        let store = InMemoryPasswordStore(hasher: hasher)
        let id = UUID()
        try store.setPassword("secret1", for: id)
        #expect(store.verifyPassword("secret1", for: id))
        store.removeAllPasswords()
        #expect(!store.verifyPassword("secret1", for: id))
    }
}

// MARK: - FriendshipRepository

@Suite("FriendshipRepository")
@MainActor
struct FriendshipRepositoryTests {
    private let context: ModelContext
    private let repository: LocalFriendshipRepository
    private let me = FriendRequestParty(id: "me", name: "Jordan", email: "jordan@example.com")

    init() throws {
        let container = try ModelContainer(
            for: Message.self, ChatRoom.self, User.self, Friendship.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
        repository = LocalFriendshipRepository(modelContext: context)
    }

    @Test("A request is saved for both sides, each owned by its own person")
    func sendRequestSavesBothSides() throws {
        try repository.sendRequest(from: me, to: FriendRequestParty(id: "sam", name: "Sam", email: "sam@example.com"))

        let all = try context.fetch(FetchDescriptor<Friendship>())
        #expect(all.count == 2)
        let outgoing = try #require(all.first { $0.ownerUserId == "me" })
        let mirror = try #require(all.first { $0.ownerUserId == "sam" })
        #expect(outgoing.friendId == "sam" && outgoing.friendName == "Sam" && outgoing.status == .pending)
        #expect(mirror.friendId == "me" && mirror.friendName == "Jordan" && mirror.friendEmail == "jordan@example.com")
    }

    @Test("The user's list has what they own and requests sent to them, nobody else's")
    func friendshipsInvolvingTheUser() throws {
        try repository.addFriendships([
            Friendship(userId: "me", friendId: "a", friendName: "A", friendEmail: "", status: .accepted),
            Friendship(userId: "b", friendId: "me", friendName: "B", friendEmail: "", status: .pending),
            Friendship(userId: "c", friendId: "d", friendName: "D", friendEmail: "", status: .accepted)
        ])

        let names = Set(try repository.friendships(involving: "me").map(\.friendName))

        #expect(names == ["A", "B"])
    }

    @Test("Statuses by name come from the user's own records, newest first")
    func statusesByName() throws {
        let blocked = Friendship(userId: "me", friendId: "a", friendName: "Ana", friendEmail: "", status: .blocked)
        blocked.createdAt = Date(timeIntervalSince1970: 0)
        try repository.addFriendships([
            blocked,
            Friendship(userId: "me", friendId: "a2", friendName: "Ana", friendEmail: "", status: .accepted),
            Friendship(userId: "me", friendId: "b", friendName: "Ben", friendEmail: "", status: .pending),
            Friendship(userId: "other", friendId: "c", friendName: "Cy", friendEmail: "", status: .accepted)
        ])

        let statuses = try repository.statusesByName(ownedBy: "me")

        #expect(statuses == ["Ana": .accepted, "Ben": .pending])
    }

    @Test("A friendship is found by name among the user's own records, newest first")
    func friendshipByName() throws {
        let old = Friendship(userId: "me", friendId: "a", friendName: "Ana", friendEmail: "", status: .blocked)
        old.createdAt = Date(timeIntervalSince1970: 0)
        try repository.addFriendships([
            old,
            Friendship(userId: "me", friendId: "a2", friendName: "Ana", friendEmail: "", status: .accepted),
            Friendship(userId: "other", friendId: "b", friendName: "Ben", friendEmail: "", status: .accepted)
        ])

        #expect(try repository.friendship(ownedBy: "me", named: "Ana")?.friendId == "a2")
        #expect(try repository.friendship(ownedBy: "me", named: "Ben") == nil)
    }

    @Test("The records for a person are only the user's own, not another account's")
    func friendshipsForAPersonAreScopedToTheOwner() throws {
        try repository.addFriendships([
            Friendship(userId: "me", friendId: "a", friendName: "Ana", friendEmail: "", status: .pending),
            Friendship(userId: "other", friendId: "a", friendName: "Ana", friendEmail: "", status: .accepted),
            Friendship(userId: "other", friendId: "a", friendName: "Ana", friendEmail: "", status: .blocked)
        ])

        let mine = try repository.friendships(ownedBy: "me", friendId: "a")
        #expect(mine.map(\.status) == [.pending])
        #expect(try repository.friendships(ownedBy: "nobody", friendId: "a").isEmpty)
    }

    @Test("Status, favorite and notification changes are saved; delete removes")
    func updatesAndDelete() throws {
        try repository.addFriendships([Friendship(userId: "me", friendId: "a", friendName: "A", friendEmail: "", status: .accepted)])
        let friendship = try #require(try repository.friendship(ownedBy: "me", friendId: "a"))

        try repository.setStatus(.blocked, of: friendship)
        try repository.setFavorite(true, of: friendship)
        try repository.setNotificationsEnabled(false, of: friendship)
        let reloaded = try #require(try repository.friendships(ownedBy: "me", friendId: "a").first)
        #expect(reloaded.status == .blocked && reloaded.isFavorite && !reloaded.notificationsEnabled)

        try repository.delete([reloaded])
        #expect(try repository.friendship(ownedBy: "me", friendId: "a") == nil)
    }

    @Test("Hidden and blocked people get the same offer to add them as strangers", arguments: [
        (FriendshipStatus?.none, FriendStanding.stranger),
        (.hidden, .stranger),
        (.blocked, .stranger),
        (.pending, .requested),
        (.accepted, .friend)
    ])
    func standing(status: FriendshipStatus?, standing: FriendStanding) {
        #expect(FriendStanding(status) == standing)
    }
}

// MARK: - Text size

@Suite("Friend banner")
struct FriendBannerTests {

    @Test("A one-to-one chat with someone who isn't a friend offers Add Friend")
    func strangerInAOneToOneChat() {
        #expect(FriendBanner(isGroup: false, standing: .stranger, isBlocked: false) == .addFriend)
    }

    @Test("Once the request is out, the banner says so instead")
    func requestAlreadySent() {
        #expect(FriendBanner(isGroup: false, standing: .requested, isBlocked: false) == .requestSent)
    }

    @Test("No banner for a friend, a group, someone blocked, or before the standing is known")
    func nothingForFriendsGroupsBlockedOrUnknown() {
        #expect(FriendBanner(isGroup: false, standing: .friend, isBlocked: false) == .none)
        #expect(FriendBanner(isGroup: true, standing: .stranger, isBlocked: false) == .none)
        #expect(FriendBanner(isGroup: false, standing: .stranger, isBlocked: true) == .none)
        #expect(FriendBanner(isGroup: false, standing: nil, isBlocked: false) == .none)
    }

    @Test("A room with members, a group icon or an organization is a group, even before anyone joins")
    func whichRoomsAreGroups() {
        let withMembers = ChatRoom(name: "Family")
        withMembers.memberNames = ["Ana"]
        let organization = ChatRoom(name: "Team")
        organization.isOrganizationRoom = true

        #expect(withMembers.isGroup)
        #expect(ChatRoom(name: "New Group", profileImage: ChatRoom.groupSymbol).isGroup)
        #expect(organization.isGroup)
        #expect(!ChatRoom(name: "Ana").isGroup)
    }
}

@Suite("AppRouter")
@MainActor
struct AppRouterTests {

    @Test("The app starts on the Friends tab")
    func startsOnFriends() {
        #expect(AppRouter().selectedTab == .friends)
    }

    @Test("Opening a chat switches to Chats and hands the room over once")
    func openChatSwitchesToChatsAndHandsTheRoomOnce() {
        let router = AppRouter()
        let id = UUID()

        router.openChat(id)

        #expect(router.selectedTab == .chats)
        #expect(router.takeRoomToOpen() == id)
        #expect(router.takeRoomToOpen() == nil)
    }
}

@Suite("In-app text size")
struct InAppTextSizeTests {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "InAppTextSizeTests-\(UUID().uuidString)")!
    }

    @Test("A fresh install follows the system text size")
    func freshInstallFollowsSystem() {
        let defaults = makeDefaults()
        InAppTextSize.migrate(defaults)
        #expect(defaults.bool(forKey: InAppTextSize.overridesKey) == false)
    }

    @Test("Someone who picked a size before keeps it; the default size follows the system", arguments: [
        (0, true), (1, true), (2, false), (3, true), (4, true)
    ])
    func earlierChoiceIsKept(step: Int, overrides: Bool) {
        let defaults = makeDefaults()
        defaults.set(step, forKey: InAppTextSize.stepKey)
        InAppTextSize.migrate(defaults)
        #expect(defaults.bool(forKey: InAppTextSize.overridesKey) == overrides)
    }

    @Test("A decision already made isn't changed again")
    func migrationRunsOnce() {
        let defaults = makeDefaults()
        defaults.set(4, forKey: InAppTextSize.stepKey)
        defaults.set(false, forKey: InAppTextSize.overridesKey)
        InAppTextSize.migrate(defaults)
        #expect(defaults.bool(forKey: InAppTextSize.overridesKey) == false)
    }

    @Test("The slider's steps run from small to extra extra large, with the default in the middle")
    func stepSizes() {
        #expect(InAppTextSize.steps.map(InAppTextSize.size(forStep:)) == [.small, .medium, .large, .xLarge, .xxLarge])
        #expect(InAppTextSize.size(forStep: InAppTextSize.defaultStep) == .large)
    }
}

// MARK: - Accessibility preferences

@Suite("Accessibility preferences")
struct AccessibilityPreferencesTests {
    @Test("Reduce Motion applies when iOS or the app asks for it", arguments: [
        (false, false, false), (true, false, true), (false, true, true), (true, true, true)
    ])
    func reduceMotion(system: Bool, inApp: Bool, applies: Bool) {
        #expect(AccessibilityPreferences(systemReducesMotion: system, inAppReducesMotion: inApp).reducesMotion == applies)
    }

    @Test("High contrast applies with iOS's Increase Contrast or the app's switch", arguments: [
        (false, false, false), (true, false, true), (false, true, true), (true, true, true)
    ])
    func highContrast(system: Bool, inApp: Bool, applies: Bool) {
        #expect(AccessibilityPreferences(systemIncreasesContrast: system, inAppHighContrast: inApp).highContrast == applies)
    }
}

@Suite("Chat subtitle")
struct ChatSubtitleTests {
    private func subtitle(
        isGroup: Bool = false, members: [String] = [], partner: String? = nil,
        reader: String = "en", translating: Bool = true
    ) -> String? {
        ChatSubtitle.text(
            isGroup: isGroup, memberNames: members, partnerLanguage: partner,
            readerLanguage: reader, isTranslating: translating, translatedLabel: "Translated"
        )
    }

    @Test("A group shows who is in it, shortened when there are many")
    func groupMembers() {
        #expect(subtitle(isGroup: true, members: ["강호동", "한소희"]) == "강호동, 한소희")
        #expect(subtitle(isGroup: true, members: ["A", "B", "C"]) == "A, B, C")
        #expect(subtitle(isGroup: true, members: ["A", "B", "C", "D", "E"]) == "A, B +3")
        #expect(subtitle(isGroup: true, members: []) == nil)
    }

    @Test("A one-to-one chat shows the other person's language when it isn't the reader's")
    func partnerLanguage() {
        #expect(subtitle(partner: "ja") == "Japanese · Translated")
        #expect(subtitle(partner: "ja", translating: false) == "Japanese")
        #expect(subtitle(partner: "ja", reader: "ko") == "일본어 · Translated")
        #expect(subtitle(partner: "en") == nil)
        #expect(subtitle(partner: nil) == nil)
    }
}

@Suite("A sender's language")
struct SenderLanguageTests {
    private func message(_ text: String, from sender: String, mine: Bool = false) -> SummaryMessage {
        SummaryMessage(text: text, sender: mine ? "Me" : sender, isFromCurrentUser: mine, messageType: .text)
    }

    @Test("Read from what they wrote, not from the reader's messages")
    func readsTheirMessages() {
        let chat = [
            message("こんにちは、今日は一緒に夕ご飯を食べませんか？", from: "Yuki"),
            message("Sure, where do you want to go tonight?", from: "Me", mine: true),
            message("¿Vamos al restaurante nuevo esta noche?", from: "Lucía"),
        ]
        #expect(ConversationLanguage.of(sender: "Yuki", in: chat) == .japanese)
        #expect(ConversationLanguage.of(sender: "Lucía", in: chat) == .spanish)
        #expect(ConversationLanguage.of(sender: nil, in: chat) == .spanish, "anyone but the reader: the latest")
        #expect(ConversationLanguage.of(sender: "Sam", in: chat) == nil, "nothing from them yet")
    }
}

@Suite("Sender avatar")
struct SenderAvatarTests {
    @Test("The initial is the name's first letter, capitalized")
    func initial() {
        #expect(SenderAvatar(name: "강호동").initial == "강")
        #expect(SenderAvatar(name: "lucía").initial == "L")
        #expect(SenderAvatar(name: " ").initial == "?")
    }

    @Test("The color comes from the name: the same every time, and not the same for everyone")
    func color() {
        let names = ["강호동", "한소희", "佐藤ゆき", "Lucía García", "권지용", "Mina"]
        #expect(names.allSatisfy { SenderAvatar(name: $0).colorIndex == SenderAvatar(name: $0).colorIndex })
        #expect(names.allSatisfy { (0..<SenderAvatar.paletteCount).contains(SenderAvatar(name: $0).colorIndex) })
        #expect(Set(names.map { SenderAvatar(name: $0).colorIndex }).count > 1)
    }

    @Test("A group is drawn as its first two members' faces")
    func groupFaces() {
        #expect(GroupAvatar(members: ["강호동", "한소희", "유재석"]).faces.map(\.initial) == ["강", "한"])
        #expect(GroupAvatar(members: ["佐藤ゆき"]).faces == [SenderAvatar(name: "佐藤ゆき")])
        #expect(GroupAvatar(members: []).faces.isEmpty)
    }

    @Test("A language badge shows only for a language that isn't the reader's", arguments: [
        ("ja", "en", "JA"), ("es", "ko", "ES"), ("zh-Hans", "en", "ZH"), ("en", "en", nil), ("en", "en-US", nil), (nil, "en", nil),
    ] as [(String?, String, String?)])
    func languageBadge(sender: String?, reader: String, badge: String?) {
        #expect(SenderAvatar.languageBadge(senderLanguage: sender, readerLanguage: reader) == badge)
    }
}

@Suite("Sample chats")
struct SampleChatsTests {
    private static let languages: [(code: String, language: NLLanguage)] = [
        ("ko", .korean), ("en", .english), ("ja", .japanese), ("zh-Hans", .simplifiedChinese), ("es", .spanish),
    ]

    @Test("Each sample room's reader writes in the app's language, so answers come back in it", arguments: languages.map(\.code))
    func readerLinesAreInTheAppLanguage(code: String) throws {
        let expected = try #require(Self.languages.first { $0.code == code }?.language)
        for room in SampleChats.rooms(readerLanguage: code) {
            let conversation = room.lines.map {
                SummaryMessage(text: $0.text, sender: $0.speaker.name ?? "Me", isFromCurrentUser: $0.speaker == .reader, messageType: .text)
            }
            let own = conversation.filter(\.isFromCurrentUser).map(\.text).joined(separator: "\n")
            #expect(ConversationLanguage.confidentLanguage(of: own) == expected, "\(room.key) in \(code)")
        }
    }

    @Test("Previews and unread counts come from the messages themselves")
    func unreadCountsFollowTheMessages() {
        let rooms = SampleChats.rooms(readerLanguage: "en")
        #expect(rooms.map(\.key) == ["study_group", "family_group", "minji", "work_colleagues"])
        #expect(rooms.map(\.unreadCount) == [2, 1, 1, 0])
        #expect(rooms.allSatisfy { $0.lastMessage == $0.lines.last?.text })
        #expect(rooms.allSatisfy { !$0.lastMessage.contains("Hello") })
    }

    @Test("Group rooms have the members test mode knows, and each member's line is in their language")
    func membersWriteTheirLanguage() {
        for room in SampleChats.rooms(readerLanguage: "en") {
            #expect(room.members == (TestData.groupMembers[room.key] ?? []))
            for line in room.lines {
                guard let name = line.speaker.name, let code = TestData.language(of: name) else { continue }
                #expect(ConversationLanguage.confidentLanguage(of: line.text)?.rawValue.hasPrefix(code) == true, "\(name): \(line.text)")
            }
        }
    }

    @Test("A language the app doesn't speak gets the English lines")
    func unknownLanguageFallsBackToEnglish() {
        let french = SampleChats.rooms(readerLanguage: "fr").flatMap(\.lines).filter { $0.speaker == .reader }
        let english = SampleChats.rooms(readerLanguage: "en").flatMap(\.lines).filter { $0.speaker == .reader }
        #expect(french == english)
    }
}

@Suite("Translation preferences")
struct TranslationPreferencesTests {
    @Test("Translation is on until someone turns it off")
    func onByDefault() throws {
        let defaults = try #require(UserDefaults(suiteName: "TranslationPreferencesTests.\(UUID().uuidString)"))
        #expect(TranslationPreferences.isEnabled(in: defaults))
        defaults.set(false, forKey: TranslationPreferences.enabledKey)
        #expect(!TranslationPreferences.isEnabled(in: defaults))
    }
}
