//
//  AttachmentPreviewer.swift
//  TalkMVP
//
//  Prepares file and video attachments for Quick Look
//

import Foundation

/// Turns a message's attachment into a file Quick Look can open.
///
/// Stored attachments are named `<UUID>.<ext>` and videos live inside the message as raw
/// data, so neither can be handed to Quick Look as is: it titles the preview with the
/// file name and picks a viewer from the extension. Each preview gets a temporary file
/// named the way the user knows it; the previous preview's file is discarded first.
struct AttachmentPreviewer {
    /// Extension for videos sent before the original one was recorded. Videos picked from
    /// the photo library are QuickTime movies.
    nonisolated static let fallbackVideoExtension = "mov"

    private let attachmentFiles: AttachmentFileStoring
    private let directory: URL
    private let fileManager: FileManager

    init(
        attachmentFiles: AttachmentFileStoring = DiskAttachmentFileStore(),
        directory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("AttachmentPreviews", isDirectory: true),
        fileManager: FileManager = .default
    ) {
        self.attachmentFiles = attachmentFiles
        self.directory = directory
        self.fileManager = fileManager
    }

    /// A file to preview `message`'s attachment, or nil when it has none or the file is gone.
    func previewURL(for message: Message) throws -> URL? {
        switch message.messageType {
        case .file:
            guard let storedPath = message.fileURL,
                  let source = attachmentFiles.url(forStoredPath: storedPath) else { return nil }
            let fileExtension = message.fileExtension ?? source.pathExtension
            let destination = try freshFile(named: message.fileName ?? "file", fileExtension: fileExtension)
            try fileManager.copyItem(at: source, to: destination)
            return destination
        case .video:
            guard let data = message.videoData else { return nil }
            let fileExtension = message.fileExtension ?? Self.fallbackVideoExtension
            let destination = try freshFile(named: "video", fileExtension: fileExtension)
            try data.write(to: destination)
            return destination
        default:
            return nil
        }
    }

    /// A path for a new preview file, after clearing out the previous preview. Each file gets
    /// its own folder so the user-facing name never collides.
    private func freshFile(named name: String, fileExtension: String) throws -> URL {
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
        let folder = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        // A name received from elsewhere could contain path separators.
        let safeName = name.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
        let file = folder.appendingPathComponent(safeName.isEmpty ? "file" : safeName)
        return fileExtension.isEmpty ? file : file.appendingPathExtension(fileExtension)
    }
}
