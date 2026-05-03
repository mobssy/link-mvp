//
//  LanguageManager.swift
//  L!nkMVP
//
//  Created by David Song on 10/3/25.
//

import SwiftUI
import Foundation
import Combine
import StoreKit

class LanguageManager: ObservableObject {
    @Published var currentLanguage: Language = .korean

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

        var localizedDisplayName: String {
            switch self {
            case .korean: return Bundle.localizedString(forKey: "language.korean", value: "한국어", table: nil)
            case .english: return Bundle.localizedString(forKey: "language.english", value: "English", table: nil)
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

        // 언어 변경을 알리기 위해 NotificationCenter 사용
        NotificationCenter.default.post(name: .languageChanged, object: language)
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
        // 앱스토어 지역 확인 방법들

        // 1. iOS 18+에서는 Storefront.current 사용 (async이므로 동기적으로는 사용 불가)
        // 대신 기존 방식과 Locale을 조합하여 사용
        if #available(iOS 18.0, *) {
            // iOS 18+에서는 Storefront.current가 async이므로 동기 함수에서는 사용할 수 없음
            // 대신 기기 지역 정보를 우선 사용
        } else {
            // iOS 18 미만에서는 기존 방식 사용
            if let storeCountry = SKPaymentQueue.default().storefront?.countryCode {
                return storeCountry
            }
        }

        // 2. 기기의 현재 지역 설정으로 fallback
        if #available(iOS 16.0, *) {
            if let region = Locale.current.region {
                return region.identifier
            }
        } else {
            if let regionCode = Locale.current.regionCode {
                return regionCode
            }
        }

        // 3. 기본값
        return "US"
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

        // iOS 16+에서는 region.identifier 사용, 그 이전에는 regionCode 사용
        let currentRegion: String
        if #available(iOS 16.0, *) {
            currentRegion = Locale.current.region?.identifier ?? "unknown"
        } else {
            currentRegion = Locale.current.regionCode ?? "unknown"
        }

        return [
            "currentLanguage": currentLanguage.rawValue,
            "systemLanguage": systemLanguage,
            "storeRegion": storeRegion,
            "deviceRegion": currentRegion,
            "hasUserPreference": UserDefaults.standard.string(forKey: languageKey) != nil ? "true" : "false"
        ]
    }
}

extension Bundle {
    static func localizedString(forKey key: String, value: String, table: String?) -> String {
        return Bundle.main.localizedString(forKey: key, value: value, table: table)
    }
}

extension Notification.Name {
    static let languageChanged = Notification.Name("languageChanged")
}
