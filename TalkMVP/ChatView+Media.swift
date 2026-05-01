//
//  ChatView+Media.swift
//  TalkMVP
//

import SwiftUI
import SwiftData
import Photos
import PhotosUI
import UniformTypeIdentifiers

extension ChatView {
    func openPhotosAttachment() {
        let hasPhotoUsageDescription = Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryUsageDescription") != nil
        if !hasPhotoUsageDescription {
            showingPhotosPicker = true
            return
        }

        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            showingPhotosPicker = true
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        self.showingPhotosPicker = true
                    } else {
                        self.showingPhotosPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showingPhotosPermissionAlert = true
        @unknown default:
            showingPhotosPermissionAlert = true
        }
    }

    func sendImageMessage(data: Data) async {
        let senderName = languageManager.localize(ko: "나", en: "Me", ja: "私", zh: "我", es: "Yo")
        let message = Message(imageData: data, isFromCurrentUser: true, sender: senderName, chatRoomId: chatRoom.id.uuidString)

        await MainActor.run {
            modelContext.insert(message)
            chatRoom.messages.append(message)
            chatRoom.lastMessage = localizedText("sent_photo")
            chatRoom.timestamp = Date()

            do {
                try modelContext.save()
            } catch {
                print("❌ [ChatView] Failed to send image: \(error)")
            }
        }
    }

    func sendVideoMessage(data: Data) async {
        let sentVideoText = localizedText("sent_video")
        let senderName = languageManager.localize(ko: "나", en: "Me", ja: "私", zh: "我", es: "Yo")
        let message = Message(text: sentVideoText, isFromCurrentUser: true, sender: senderName, chatRoomId: chatRoom.id.uuidString, messageType: .video)
        message.videoData = data

        await MainActor.run {
            modelContext.insert(message)
            chatRoom.messages.append(message)
            chatRoom.lastMessage = sentVideoText
            chatRoom.timestamp = Date()

            do {
                try modelContext.save()
            } catch {
                print("❌ [ChatView] Failed to send video: \(error)")
            }
        }
    }

    func handleDocumentSelection(_ url: URL) {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing { url.stopAccessingSecurityScopedResource() }
            showingDocumentPicker = false
        }

        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .nameKey, .contentTypeKey])
            let fileName = resourceValues.name ?? url.lastPathComponent
            let fileSize = resourceValues.fileSize ?? 0

            let data = try Data(contentsOf: url)
            let fileExtension = url.pathExtension

            pendingAttachment = .document(data, fileName, fileSize, fileExtension)
            showingAttachmentPreview = true
        } catch {
            print("❌ [ChatView] Failed to handle document: \(error)")
        }
    }

    func sendFileMessage(fileName: String, fileURL: String, fileSize: Int) {
        let nameWithoutExt = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        let senderName = languageManager.localize(ko: "나", en: "Me", ja: "私", zh: "我", es: "Yo")

        let message = Message(
            fileName: nameWithoutExt,
            fileExtension: ext,
            fileSize: fileSize,
            isFromCurrentUser: true,
            sender: senderName,
            chatRoomId: chatRoom.id.uuidString
        )
        message.fileURL = fileURL

        modelContext.insert(message)
        chatRoom.messages.append(message)
        chatRoom.lastMessage = localizedText("sent_file")
        chatRoom.timestamp = Date()

        do {
            try modelContext.save()
        } catch {
            print("❌ [ChatView] Failed to save file message: \(error)")
        }
    }

    func sendPendingAttachment() {
        guard let attachment = pendingAttachment else { return }

        Task {
            switch attachment {
            case .image(let image):
                if let data = image.jpegData(compressionQuality: 0.8) {
                    await sendImageMessage(data: data)
                }
            case .video(let data, _):
                await sendVideoMessage(data: data)
            case .document(let data, let fileName, let fileSize, _):
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let destinationURL = documentsPath
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension((fileName as NSString).pathExtension)

                do {
                    try data.write(to: destinationURL)
                    await MainActor.run {
                        sendFileMessage(fileName: fileName, fileURL: destinationURL.path, fileSize: fileSize)
                    }
                } catch {
                    print("❌ Failed to save file: \(error)")
                }
            }

            await MainActor.run {
                pendingAttachment = nil
                showingAttachmentPreview = false
            }
        }
    }

    func cancelPendingAttachment() {
        pendingAttachment = nil
        showingAttachmentPreview = false
    }

    func handlePhotoPickerSelection(_ items: [PHPickerResult]) {
        guard let item = items.first else { return }

        if item.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            item.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                guard let url = url, error == nil else {
                    print("❌ Failed to load video: \(error?.localizedDescription ?? "unknown error")")
                    return
                }

                do {
                    let data = try Data(contentsOf: url)
                    Task { @MainActor in
                        self.pendingAttachment = .video(data, url)
                        self.showingAttachmentPreview = true
                    }
                } catch {
                    print("❌ Failed to read video data: \(error)")
                }
            }
        } else {
            item.itemProvider.loadObject(ofClass: UIImage.self) { reading, error in
                if let error = error {
                    print("❌ Failed to load image: \(error.localizedDescription)")
                    return
                }

                if let image = reading as? UIImage {
                    Task { @MainActor in
                        self.pendingAttachment = .image(image)
                        self.showingAttachmentPreview = true
                    }
                }
            }
        }
    }
}
