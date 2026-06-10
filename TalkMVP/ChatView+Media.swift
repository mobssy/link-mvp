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
        await MainActor.run {
            viewModel?.sendImage(data)
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
                viewModel?.errorMessage = languageManager.localize(ko: "동영상 전송에 실패했습니다.", en: "Failed to send video.", ja: "動画の送信に失敗しました。", zh: "发送视频失败。", es: "Error al enviar el vídeo.")
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
            viewModel?.errorMessage = languageManager.localize(ko: "파일을 열지 못했습니다.", en: "Failed to open file.", ja: "ファイルを開けませんでした。", zh: "无法打开文件。", es: "No se pudo abrir el archivo.")
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
            viewModel?.errorMessage = languageManager.localize(ko: "파일 전송에 실패했습니다.", en: "Failed to send file.", ja: "ファイルの送信に失敗しました。", zh: "发送文件失败。", es: "Error al enviar el archivo.")
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
                    await MainActor.run {
                        viewModel?.errorMessage = languageManager.localize(ko: "파일 저장에 실패했습니다.", en: "Failed to save file.", ja: "ファイルの保存に失敗しました。", zh: "保存文件失败。", es: "Error al guardar el archivo.")
                    }
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
                    Task { @MainActor in
                        self.viewModel?.errorMessage = self.languageManager.localize(ko: "동영상 로드에 실패했습니다.", en: "Failed to load video.", ja: "動画の読み込みに失敗しました。", zh: "加载视频失败。", es: "Error al cargar el vídeo.")
                    }
                    return
                }

                do {
                    let data = try Data(contentsOf: url)
                    Task { @MainActor in
                        self.pendingAttachment = .video(data, url)
                        self.showingAttachmentPreview = true
                    }
                } catch {
                    Task { @MainActor in
                        self.viewModel?.errorMessage = self.languageManager.localize(ko: "동영상 데이터를 읽지 못했습니다.", en: "Failed to read video data.", ja: "動画データの読み取りに失敗しました。", zh: "无法读取视频数据。", es: "Error al leer datos de vídeo.")
                    }
                }
            }
        } else {
            item.itemProvider.loadObject(ofClass: UIImage.self) { reading, error in
                if let error = error {
                    Task { @MainActor in
                        self.viewModel?.errorMessage = self.languageManager.localize(ko: "이미지 로드에 실패했습니다.", en: "Failed to load image.", ja: "画像の読み込みに失敗しました。", zh: "加载图片失败。", es: "Error al cargar la imagen.")
                    }
                    _ = error
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
