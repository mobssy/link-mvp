//
//  MessageTranslation.swift
//  TalkMVP
//
//  Translating a message on device
//

import Foundation
import FoundationModels
import NaturalLanguage
import Translation
import os

nonisolated private let translationLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "Translation")

/// One way to translate a message. It returns nil when it can't, so the next one can try. There
/// is no made-up fallback: a phrasebook guess shown as a translation is worse than none.
nonisolated protocol MessageTranslating: Sendable {
    func translate(_ text: String, into target: String, autoDetect: Bool) async -> String?
}

/// Apple Intelligence's on-device model, where the device has it.
nonisolated struct OnDeviceModelTranslator: MessageTranslating {
    func translate(_ text: String, into target: String, autoDetect: Bool) async -> String? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let name = TranslationLanguage.name(for: target)
        let session = LanguageModelSession(instructions: """
            You are a professional translation engine.
            - Translate any input to \(name).
            - Return only the translated text with no quotes or extra commentary.
            - Preserve emojis and basic punctuation.
            - Keep the tone natural and concise.
            """)
        let prompt = autoDetect
            ? "Translate the following text to \(name). Detect the source language automatically. Return only the translation.\n\n\(text)"
            : "Translate to \(name). Return only the translation.\n\n\(text)"
        do {
            return try await session.respond(to: prompt).content
        } catch {
            translationLogger.notice("On-device translation failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

/// The Translation framework, with the languages installed on the device.
nonisolated struct SystemTranslator: MessageTranslating {
    func translate(_ text: String, into target: String, autoDetect: Bool) async -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let detected = recognizer.dominantLanguage else { return nil }
        let source = TranslationLanguage.normalizedCode(detected.rawValue)
        let destination = TranslationLanguage.normalizedCode(target)
        if source == destination { return text }
        guard let sourceLanguage = TranslationLanguage.locale(for: source),
              let targetLanguage = TranslationLanguage.locale(for: destination) else { return nil }
        do {
            return try await TranslationSession(installedSource: sourceLanguage, target: targetLanguage).translate(text).targetText
        } catch {
            translationLogger.notice("Apple Translation failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

/// The app's language codes as names the model understands and as the Translation framework's
/// languages.
nonisolated enum TranslationLanguage {
    static func name(for code: String) -> String {
        switch code {
        case "en": return "English"
        case "ko": return "Korean"
        case "ja": return "Japanese"
        case "zh-hans", "zh_cn", "zh": return "Chinese (Simplified)"
        case "zh-hant", "zh_tw": return "Chinese (Traditional)"
        case "es": return "Spanish"
        case "fr": return "French"
        case "de": return "German"
        case "auto": return "English" // default target if auto
        default: return code.uppercased()
        }
    }

    static func normalizedCode(_ code: String) -> String {
        let lowercased = code.lowercased()
        switch lowercased {
        case "zh-hans", "zh_cn", "zh", "cmn": return "zh-hans"
        case "zh-hant", "zh_tw": return "zh-hant"
        case "en", "eng": return "en"
        case "ko", "kor": return "ko"
        case "ja", "jpn": return "ja"
        case "es", "spa": return "es"
        case "fr", "fra": return "fr"
        case "de", "deu": return "de"
        case "auto":
            // "auto" should be resolved to the app language before reaching here;
            // fall back to English only as a last resort
            if let language = UserDefaults.standard.string(forKey: "selectedLanguage") {
                return normalizedCode(language)
            }
            return "en"
        default: return lowercased
        }
    }

    static func locale(for code: String) -> Locale.Language? {
        switch code {
        case "ko", "en", "ja", "es", "fr", "de": return Locale.Language(identifier: code)
        case "zh-hans": return Locale.Language(identifier: "zh-Hans")
        case "zh-hant": return Locale.Language(identifier: "zh-Hant")
        default: return nil
        }
    }
}
