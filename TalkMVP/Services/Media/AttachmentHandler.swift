//
//  AttachmentHandler.swift
//  TalkMVP
//

import UIKit

// MARK: - Pending Attachment Model

enum PendingAttachment {
    case image(UIImage)
    case video(Data, URL)
    case document(Data, String, Int, String?) // data, fileName, fileSize, fileExtension
}

// MARK: - File Icon / Size Utilities

enum AttachmentHandler {
    static func fileIcon(for fileExtension: String) -> String {
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

    static func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
