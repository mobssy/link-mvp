//
//  LanguageManager.swift
//  TalkMVP
//
//  Created by David Song on 10/3/25.
//

import SwiftUI
import Foundation
import Combine

@MainActor
@Observable
class LanguageManager {
    var currentLanguage: Language = .korean

    enum Language: String, CaseIterable {
        case korean = "ko"
        case english = "en"
        case japanese = "ja"
        case chinese = "zh-Hans"
        case chineseTraditional = "zh-Hant"
        case spanish = "es"

        var displayName: String {
            switch self {
            case .korean: return "한국어"
            case .english: return "English"
            case .japanese: return "日本語"
            case .chinese: return "中文（简体）"
            case .chineseTraditional: return "中文（繁體）"
            case .spanish: return "Español"
            }
        }
    }

    private let languageKey = "selectedLanguage"

    init() {
        loadLanguagePreference()
        applyLanguage()
    }

    func setLanguage(_ language: Language) {
        currentLanguage = language
        saveLanguagePreference()
        applyLanguage()
    }

    private func loadLanguagePreference() {
        // 사용자가 이미 언어를 설정했는지 확인
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = Language(rawValue: savedLanguage) {
            currentLanguage = language
        } else {
            // 처음 실행 시 언어 결정 로직
            currentLanguage = determineInitialLanguage()
        }
    }

    private func determineInitialLanguage() -> Language {
        // 1. 먼저 기기 시스템 언어 확인 (최우선 조건)
        let systemLanguage = Locale.preferredLanguages.first ?? "en"

        if systemLanguage.hasPrefix("ja") {
            return .japanese
        } else if systemLanguage.hasPrefix("zh-Hant") || systemLanguage.hasPrefix("zh_Hant") {
            return .chineseTraditional
        } else if systemLanguage.hasPrefix("zh") {
            return .chinese
        } else if systemLanguage.hasPrefix("es") {
            return .spanish
        } else if systemLanguage.hasPrefix("ko") {
            return .korean
        } else {
            return .english
        }
    }

    private func getAppStoreRegion() -> String {
        // StoreKit's Storefront.current is async, so this synchronous debug helper
        // reports the device region instead.
        Locale.current.region?.identifier ?? "US"
    }

    private func saveLanguagePreference() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
    }

    private func applyLanguage() {
        UserDefaults.standard.set([currentLanguage.rawValue], forKey: "AppleLanguages")
    }

    // 5개 언어를 인라인으로 분기하는 편의 메서드 (번체 중국어는 간체로 폴백)
    func localize(ko: String, en: String, ja: String, zh: String, es: String) -> String {
        switch currentLanguage {
        case .korean: return ko
        case .english: return en
        case .japanese: return ja
        case .chinese, .chineseTraditional: return zh
        case .spanish: return es
        }
    }

    // 간체/번체 중국어를 구분할 때 사용하는 6개 언어 메서드
    func localize(ko: String, en: String, ja: String, zhHans: String, zhHant: String, es: String) -> String {
        switch currentLanguage {
        case .korean: return ko
        case .english: return en
        case .japanese: return ja
        case .chinese: return zhHans
        case .chineseTraditional: return zhHant
        case .spanish: return es
        }
    }

    // 디버깅을 위한 언어 설정 정보 제공
    func getLanguageInfo() -> [String: String] {
        let systemLanguage = Locale.preferredLanguages.first ?? "unknown"
        let storeRegion = getAppStoreRegion()

        let currentRegion = Locale.current.region?.identifier ?? "unknown"

        return [
            "currentLanguage": currentLanguage.rawValue,
            "systemLanguage": systemLanguage,
            "storeRegion": storeRegion,
            "deviceRegion": currentRegion,
            "hasUserPreference": UserDefaults.standard.string(forKey: languageKey) != nil ? "true" : "false"
        ]
    }
}
