//
//  AttachmentFileStore.swift
//  TalkMVP
//
//  Owns the on-disk files behind file attachments
//

import Foundation
import os

nonisolated private let attachmentLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "AttachmentFileStore")

/// Keeps the bytes of file attachments on disk. A message stores only the path `save`
/// returns (`Message.fileURL`); whoever deletes the message hands that path back here,
/// otherwise the file outlives it.
nonisolated protocol AttachmentFileStoring {
    /// Writes `data` to a new file and returns the path to store on the message.
    func save(_ data: Data, fileExtension: String) throws -> String

    /// Removes the file a stored path refers to. A file that is already gone is not an error.
    func removeFile(atStoredPath path: String)

    /// Removes every attachment file not referred to by one of `storedPaths`.
    /// - Returns: How many files were removed.
    @discardableResult
    func removeFiles(keeping storedPaths: Set<String>) -> Int
}

/// Stores attachments in `Documents/Attachments`.
///
/// Files are looked up by name, not by the full stored path: the app container's path
/// changes when the app is reinstalled or updated, so an absolute path saved by an
/// earlier install no longer points anywhere. Earlier builds also wrote attachments
/// straight into `Documents` as `<UUID>.<ext>`; those are still found and cleaned up.
nonisolated struct DiskAttachmentFileStore: AttachmentFileStoring {
    private let directory: URL
    private let legacyDirectory: URL
    private let fileManager: FileManager

    init(
        documentsDirectory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0],
        fileManager: FileManager = .default
    ) {
        self.directory = documentsDirectory.appendingPathComponent("Attachments", isDirectory: true)
        self.legacyDirectory = documentsDirectory
        self.fileManager = fileManager
    }

    func save(_ data: Data, fileExtension: String) throws -> String {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        try data.write(to: url)
        return url.path
    }

    func removeFile(atStoredPath path: String) {
        let name = (path as NSString).lastPathComponent
        for folder in [directory, legacyDirectory] {
            let url = folder.appendingPathComponent(name)
            guard fileManager.fileExists(atPath: url.path) else { continue }
            remove(url)
        }
    }

    @discardableResult
    func removeFiles(keeping storedPaths: Set<String>) -> Int {
        let keptNames = Set(storedPaths.map { ($0 as NSString).lastPathComponent })
        let current = files(in: directory).filter { !keptNames.contains($0.lastPathComponent) }
        // Documents itself may hold other files; only touch ones named the way attachments were.
        let legacy = files(in: legacyDirectory).filter {
            UUID(uuidString: $0.deletingPathExtension().lastPathComponent) != nil
                && !keptNames.contains($0.lastPathComponent)
        }
        let unreferenced = current + legacy
        unreferenced.forEach(remove)
        return unreferenced.count
    }

    private func files(in folder: URL) -> [URL] {
        let contents = (try? fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey]
        )) ?? []
        return contents.filter {
            (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }
    }

    private func remove(_ url: URL) {
        do {
            try fileManager.removeItem(at: url)
        } catch {
            attachmentLogger.error("Failed to remove attachment \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
