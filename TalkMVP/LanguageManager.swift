//
//  LanguageManager.swift
//  TalkMVP
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

        var displayName: String {
            switch self {
            case .korean: return "한국어"
            case .english: return "English"
            }
        }

        var localizedDisplayName: String {
            switch self {
            case .korean: return Bundle.localizedString(forKey: "language.korean", value: "한국어", table: nil)
            case .english: return Bundle.localizedString(forKey: "language.english", value: "English", table: nil)
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

        if systemLanguage.hasPrefix("ko") {
            // 3. 기기 시스템 언어가 한국어일 경우 → 앱은 무조건 한국어로 표시
            return .korean
        } else {
            // 4. 기기 시스템 언어가 한국어가 아닐 경우 → 앱은 무조건 영어로 표시
            return .english
        }
    }

    // 앱스토어 지역을 고려한 대안 구현 (필요시 위 메서드 대신 사용)
    private func determineInitialLanguageWithStoreRegion() -> Language {
        // 기기 시스템 언어 확인
        let systemLanguage = Locale.preferredLanguages.first ?? "en"

        if systemLanguage.hasPrefix("ko") {
            // 3. 기기 시스템 언어가 한국어일 경우 → 무조건 한국어
            return .korean
        } else if !systemLanguage.hasPrefix("ko") {
            // 4. 기기 시스템 언어가 한국어가 아닐 경우 → 무조건 영어
            return .english
        }

        // 시스템 언어 정보가 불확실한 경우 앱스토어 지역 확인
        // (실제로는 위의 조건들로 인해 이 부분은 실행되지 않음)
        let storeRegion = getAppStoreRegion()

        if storeRegion == "KR" {
            // 1. 한국 앱스토어에서 다운로드한 경우 → 기본 언어는 한국어
            return .korean
        } else {
            // 2. 그 외 해외 앱스토어에서 다운로드한 경우 → 기본 언어는 영어
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
        UserDefaults.standard.synchronize()
    }

    // 지역화된 문자열을 가져오는 헬퍼 메서드
    func localizedString(for key: String, defaultValue: String = "") -> String {
        guard let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(key, comment: "")
        }
        return bundle.localizedString(forKey: key, value: defaultValue, table: nil)
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
