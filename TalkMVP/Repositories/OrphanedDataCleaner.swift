//
//  OrphanedDataCleaner.swift
//  TalkMVP
//
//  Launch-time sweep for data nothing can reach any more
//

import Foundation
import SwiftData
import os

private let cleanerLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "OrphanedDataCleaner")

/// Removes messages whose chat room no longer exists and attachment files no message
/// refers to. Deleting a room now takes its messages and files with it, but builds before
/// that left both behind, and nothing in the app can reach them to delete them.
@MainActor
struct OrphanedDataCleaner {
    struct Result: Equatable {
        var deletedMessages = 0
        var deletedFiles = 0
    }

    private let modelContext: ModelContext
    private let attachmentFiles: AttachmentFileStoring

    init(modelContext: ModelContext, attachmentFiles: AttachmentFileStoring = DiskAttachmentFileStore()) {
        self.modelContext = modelContext
        self.attachmentFiles = attachmentFiles
    }

    /// The file sweep keeps only files the store's messages refer to. Against an in-memory
    /// store (UI tests, or the fallback when the on-disk store cannot be opened) that is no
    /// files at all, so it would wipe every attachment of the real store. Only sweep a store
    /// that is the one on disk.
    static func shouldRun(for container: ModelContainer) -> Bool {
        !container.configurations.isEmpty
            && container.configurations.allSatisfy { !$0.isStoredInMemoryOnly }
    }

    @discardableResult
    func run() throws -> Result {
        var result = Result()

        let roomIds = try modelContext.fetch(FetchDescriptor<ChatRoom>()).map(\.id.uuidString)
        let orphaned = #Predicate<Message> { !roomIds.contains($0.chatRoomId) }
        result.deletedMessages = try modelContext.fetchCount(FetchDescriptor(predicate: orphaned))
        if result.deletedMessages > 0 {
            try modelContext.delete(model: Message.self, where: orphaned)
            try modelContext.save()
        }

        let withFiles = FetchDescriptor<Message>(predicate: #Predicate { $0.fileURL != nil })
        let referenced = Set(try modelContext.fetch(withFiles).compactMap(\.fileURL))
        result.deletedFiles = attachmentFiles.removeFiles(keeping: referenced)

        if result != Result() {
            cleanerLogger.info("Removed \(result.deletedMessages) orphaned messages and \(result.deletedFiles) unreferenced attachment files")
        }
        return result
    }
}
