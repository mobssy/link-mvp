//
//  PhotoDescriber.swift
//  TalkMVP
//
//  Says in a sentence what a shared photo shows, on device
//

import Foundation
import FoundationModels
import ImageIO
import os

nonisolated private let photoLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "PhotoDescriber")

/// Says in a sentence what a photo shows.
nonisolated protocol PhotoDescribing: Sendable {
    /// - Parameters:
    ///   - imageData: The photo as a message stores it.
    ///   - languageCode: The language to describe it in, such as "ko".
    /// - Returns: One sentence, or nil when it can't be done on this device.
    func describe(_ imageData: Data, languageCode: String) async -> String?
}

/// Descriptions from the on-device model's image input, new in iOS 27. Before that, or on a
/// model without vision, there are none, and photos work as they always have.
nonisolated struct OnDevicePhotoDescriber: PhotoDescribing {
    func describe(_ imageData: Data, languageCode: String) async -> String? {
        guard #available(iOS 27, *) else { return nil }
        return await describeWithVision(imageData, languageCode: languageCode)
    }

    @available(iOS 27, *)
    private func describeWithVision(_ imageData: Data, languageCode: String) async -> String? {
        let model = SystemLanguageModel.default
        guard case .available = model.availability, model.capabilities.contains(.vision),
              let image = PhotoThumbnail.make(from: imageData, maxPixelSize: 1024) else { return nil }
        let session = LanguageModelSession(instructions: """
        You write short alt text for photos shared in a chat. Answer in the language of the request, \
        with one plain sentence. Don't guess who people are or where the photo was taken.
        """)
        do {
            let response = try await session.respond(options: GenerationOptions(samplingMode: .greedy)) {
                Self.request(for: languageCode)
                Attachment(image)
            }
            return Self.cleaned(response.content)
        } catch {
            photoLogger.notice("Photo description failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// The request, written in the language the description should be in. Asked in English for
    /// a Korean description, the model wrote an English sentence and then its translation.
    static func request(for languageCode: String) -> String {
        switch languageCode.prefix(2) {
        case "ko": "이 사진에 무엇이 있는지 15단어 이내의 한 문장으로 설명해 주세요."
        case "ja": "この写真に何が写っているか、15語以内の一文で説明してください。"
        case "zh": "请用一句不超过15个词的话说明这张照片的内容。"
        case "es": "En una frase de 15 palabras como máximo, di qué muestra esta foto."
        default: "In one sentence of at most 15 words, say what this photo shows."
        }
    }

    /// The first line the model wrote, trimmed; nil if it wrote nothing.
    static func cleaned(_ text: String) -> String? {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
    }
}

/// Decodes a photo small and upright in one step, without decoding it at full size first.
nonisolated enum PhotoThumbnail {
    static func make(from data: Data, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
