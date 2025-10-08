//
//  AttachmentHandler.swift
//  TalkMVP
//
//  Created by Claude Code
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Pending Attachment Model

/// Single Responsibility: 첨부파일 데이터 표현
enum PendingAttachment {
    case image(UIImage)
    case video(Data, URL)
    case document(Data, String, Int, String?) // data, fileName, fileSize, fileExtension

    var displayName: String {
        switch self {
        case .image:
            return "사진"
        case .video:
            return "동영상"
        case .document(_, let fileName, _, _):
            return fileName
        }
    }

    var fileSize: Int? {
        switch self {
        case .image(let image):
            return image.jpegData(compressionQuality: 0.8)?.count
        case .video(let data, _):
            return data.count
        case .document(_, _, let size, _):
            return size
        }
    }
}

// MARK: - Attachment Handler Protocol

/// Dependency Inversion: 프로토콜로 추상화
protocol AttachmentHandlerProtocol {
    func handlePhotoPickerResult(_ items: [PHPickerResult], completion: @escaping (PendingAttachment?) -> Void)
    func handleDocumentSelection(_ url: URL, completion: @escaping (PendingAttachment?) -> Void)
    func saveAttachmentToDocuments(_ attachment: PendingAttachment) async throws -> String
}

// MARK: - Concrete Implementation

/// Single Responsibility: 첨부파일 처리 로직만 담당
class AttachmentHandler: AttachmentHandlerProtocol {
    static let shared = AttachmentHandler()

    private init() {}

    // MARK: - Photo Picker Handling

    func handlePhotoPickerResult(_ items: [PHPickerResult], completion: @escaping (PendingAttachment?) -> Void) {
        guard let item = items.first else {
            completion(nil)
            return
        }

        // 동영상 먼저 체크
        if item.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            handleVideoItem(item, completion: completion)
        } else {
            // 이미지 처리
            handleImageItem(item, completion: completion)
        }
    }

    private func handleVideoItem(_ item: PHPickerResult, completion: @escaping (PendingAttachment?) -> Void) {
        item.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
            guard let url = url, error == nil else {
                print("❌ Failed to load video: \(error?.localizedDescription ?? "unknown error")")
                completion(nil)
                return
            }

            do {
                let data = try Data(contentsOf: url)
                DispatchQueue.main.async {
                    completion(.video(data, url))
                    print("🎥 [AttachmentHandler] Video loaded for preview")
                }
            } catch {
                print("❌ Failed to read video data: \(error)")
                completion(nil)
            }
        }
    }

    private func handleImageItem(_ item: PHPickerResult, completion: @escaping (PendingAttachment?) -> Void) {
        item.itemProvider.loadObject(ofClass: UIImage.self) { reading, error in
            if let error = error {
                print("❌ Failed to load image: \(error.localizedDescription)")
                completion(nil)
                return
            }

            if let image = reading as? UIImage {
                DispatchQueue.main.async {
                    completion(.image(image))
                    print("🖼️ [AttachmentHandler] Image loaded for preview")
                }
            } else {
                completion(nil)
            }
        }
    }

    // MARK: - Document Handling

    func handleDocumentSelection(_ url: URL, completion: @escaping (PendingAttachment?) -> Void) {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .nameKey, .contentTypeKey])
            let fileName = resourceValues.name ?? url.lastPathComponent
            let fileSize = resourceValues.fileSize ?? 0

            // 파일 데이터 읽기
            let data = try Data(contentsOf: url)
            let fileExtension = url.pathExtension

            print("📎 [AttachmentHandler] Document loaded: \(fileName)")
            completion(.document(data, fileName, fileSize, fileExtension))
        } catch {
            print("❌ [AttachmentHandler] Failed to handle document: \(error)")
            completion(nil)
        }
    }

    // MARK: - Save to Documents Directory

    func saveAttachmentToDocuments(_ attachment: PendingAttachment) async throws -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        switch attachment {
        case .image(let image):
            guard let data = image.jpegData(compressionQuality: 0.8) else {
                throw AttachmentError.compressionFailed
            }
            let destinationURL = documentsPath
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("jpg")
            try data.write(to: destinationURL)
            return destinationURL.path

        case .video(let data, _):
            let destinationURL = documentsPath
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            try data.write(to: destinationURL)
            return destinationURL.path

        case .document(let data, let fileName, _, _):
            let fileExtension = (fileName as NSString).pathExtension
            let destinationURL = documentsPath
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileExtension)
            try data.write(to: destinationURL)
            return destinationURL.path
        }
    }
}

// MARK: - Custom Errors

enum AttachmentError: LocalizedError {
    case compressionFailed
    case saveFailed
    case invalidData

    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .saveFailed:
            return "Failed to save file to documents"
        case .invalidData:
            return "Invalid attachment data"
        }
    }
}

// MARK: - File Icon Utility

extension AttachmentHandler {
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
