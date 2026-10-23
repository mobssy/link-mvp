//
//  ChatView+Media.swift
//  TalkMVP
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

extension ChatView {
    /// PHPickerViewController runs out of process, so no photo-library permission is needed.
    func openPhotosAttachment() {
        showingPhotosPicker = true
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

    // Attachments go through the view model like text and voice messages, so the
    // sent message shows up in the conversation right away.
    func sendPendingAttachment() {
        guard let attachment = pendingAttachment else { return }

        switch attachment {
        case .image(let image):
            if let data = image.jpegData(compressionQuality: 0.8) {
                viewModel?.sendImage(data)
            }
        case .video(let data, let url):
            let fileExtension = url.pathExtension
            viewModel?.sendVideo(data, fileExtension: fileExtension.isEmpty ? AttachmentPreviewer.fallbackVideoExtension : fileExtension)
        case .document(let data, let fileName, let fileSize, _):
            let fileExtension = (fileName as NSString).pathExtension
            do {
                let storedPath = try DiskAttachmentFileStore().save(data, fileExtension: fileExtension)
                viewModel?.sendFile(
                    fileName: (fileName as NSString).deletingPathExtension,
                    fileExtension: fileExtension,
                    fileSize: fileSize,
                    fileURL: storedPath
                )
            } catch {
                viewModel?.errorMessage = languageManager.localize(ko: "파일 저장에 실패했습니다.", en: "Failed to save file.", ja: "ファイルの保存に失敗しました。", zh: "保存文件失败。", es: "Error al guardar el archivo.")
            }
        }

        pendingAttachment = nil
        showingAttachmentPreview = false
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
                if error != nil {
                    Task { @MainActor in
                        self.viewModel?.errorMessage = self.languageManager.localize(ko: "이미지 로드에 실패했습니다.", en: "Failed to load image.", ja: "画像の読み込みに失敗しました。", zh: "加载图片失败。", es: "Error al cargar la imagen.")
                    }
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
