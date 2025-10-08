import Foundation
import SwiftUI

/// Centralized localization helper to avoid scattering `localizedText` across views.
/// - Usage: `L10n.friends(language)` or `L10n.text("friends", language)`
enum L10n {
    /// Returns the localized string for a known key with built-in Korean/English mapping.
    /// If you later add Localizable.strings, you can migrate calls to String(localized:),
    /// but this keeps behavior consistent today.
    static func text(_ key: String, _ language: AppLanguage) -> String {
        let isKorean = (language == .korean)
        switch key {
        case "friends": return isKorean ? "친구" : "Friends"
        case "friends_title": return isKorean ? "친구" : "Friends"
        case "friends_list": return isKorean ? "친구 목록" : "Friends List"
        case "friends_empty": return isKorean ? "친구 목록이 비어 있습니다" : "Your friends list is empty"
        case "add_sample_friend": return isKorean ? "샘플 친구 추가" : "Add Sample Friend"
        case "pin_to_top": return isKorean ? "상단 고정" : "Pin to Top"
        case "unpin": return isKorean ? "고정 해제" : "Unpin"
        case "delete": return isKorean ? "삭제" : "Delete"
        case "add_friend": return isKorean ? "친구 추가" : "Add Friend"
        case "search_friends": return isKorean ? "친구 검색" : "Search Friends"
        case "search_friends_placeholder": return isKorean ? "이름으로 검색" : "Search by name"
        case "settings": return isKorean ? "설정" : "Settings"
        case "manage_hidden_blocked": return isKorean ? "숨김/차단 관리" : "Manage Hidden/Blocked"
        case "online": return isKorean ? "온라인" : "online"
        case "new_friends": return isKorean ? "새로운 친구 (%d)" : "New Friends (%d)"
        case "received_requests": return isKorean ? "받은 친구 요청 (%d)" : "Received Requests (%d)"
        case "sent_requests": return isKorean ? "보낸 친구 요청 (%d)" : "Sent Requests (%d)"
        case "no_search_results": return isKorean ? "검색 결과 없음" : "No Search Results"
        case "no_match_for": return isKorean ? "'%@'에 대한 검색 결과가 없습니다" : "No matches for '%@'"
        case "no_friends_yet": return isKorean ? "아직 친구가 없습니다" : "No Friends Yet"
        case "add_friends_suggestion": return isKorean ? "이메일로 친구를 추가해보세요" : "Try adding friends by email"
        case "add_friend_by_email": return isKorean ? "이메일로 친구 추가" : "Add Friend by Email"
        case "hide": return isKorean ? "숨기기" : "Hide"
        case "block": return isKorean ? "차단" : "Block"
        case "friend_request": return isKorean ? "친구 요청" : "Friend Request"
        case "accept": return isKorean ? "수락" : "Accept"
        case "request_pending": return isKorean ? "요청 대기 중" : "Request Pending"
        case "pending_short": return isKorean ? "대기 중" : "Pending"
        case "friend_email_placeholder": return isKorean ? "친구 이메일 입력" : "Enter friend's email"
        case "search": return isKorean ? "검색" : "Search"
        case "add_by_email": return isKorean ? "이메일로 추가" : "Add by Email"
        case "add_by_email_footer": return isKorean ? "친구의 이메일 주소를 입력하여 검색하세요" : "Enter your friend's email address to search"
        case "searching": return isKorean ? "검색 중" : "Searching"
        case "searching_users": return isKorean ? "사용자 검색 중..." : "Searching users..."
        case "search_results": return isKorean ? "검색 결과" : "Search Results"
        case "alert": return isKorean ? "알림" : "Alert"
        case "ok": return isKorean ? "확인" : "OK"
        case "cancel": return isKorean ? "취소" : "Cancel"
        case "enter_email_message": return isKorean ? "이메일을 입력해주세요" : "Please enter an email"
        case "invalid_email_format": return isKorean ? "올바른 이메일 형식이 아닙니다" : "Invalid email format"
        case "search_error_prefix": return isKorean ? "검색 오류: " : "Search error: "
        case "user": return isKorean ? "사용자" : "User"
        case "status_message": return isKorean ? "상태 메시지" : "Status Message"
        case "friend_request_sent": return isKorean ? "친구 요청을 보냈습니다" : "Friend request sent"
        case "friend_request_failed": return isKorean ? "친구 요청에 실패했습니다" : "Friend request failed"
        case "error_occurred_prefix": return isKorean ? "오류 발생: " : "Error occurred: "
        case "no_blocked_friends": return isKorean ? "차단된 친구가 없습니다" : "No Blocked Friends"
        case "blocked_list": return isKorean ? "차단 목록" : "Blocked List"
        case "close": return isKorean ? "닫기" : "Close"
        case "blocked": return isKorean ? "차단됨" : "Blocked"
        case "unblock": return isKorean ? "차단 해제" : "Unblock"
        case "unblock_friend": return isKorean ? "친구 차단 해제" : "Unblock Friend"
        case "unblock_message": return isKorean ? "%@님의 차단을 해제하시겠습니까?" : "Unblock %@?"
        case "hidden_list": return isKorean ? "숨김 목록" : "Hidden List"
        case "no_hidden_friends": return isKorean ? "숨긴 친구가 없습니다" : "No Hidden Friends"
        case "hidden": return isKorean ? "숨김" : "Hidden"
        case "unhide": return isKorean ? "숨김 해제" : "Unhide"
        case "unhide_friend": return isKorean ? "친구 숨김 해제" : "Unhide Friend"
        case "unhide_message": return isKorean ? "%@님의 숨김을 해제하시겠습니까?" : "Unhide %@?"
        case "add_friend_title": return isKorean ? "친구 추가" : "Add Friend"
        case "add_friend_message": return isKorean ? "%@님을 친구로 추가하시겠습니까?" : "Add %@ as a friend?"
        case "add": return isKorean ? "추가" : "Add"
        case "favorites": return isKorean ? "즐겨찾기" : "Favorites"
        case "favorite": return isKorean ? "즐겨찾기 추가" : "Add to Favorites"
        case "unfavorite": return isKorean ? "즐겨찾기 해제" : "Remove from Favorites"
        case "mute_notifications": return isKorean ? "알림 끄기" : "Mute Notifications"
        case "unmute_notifications": return isKorean ? "알림 켜기" : "Unmute Notifications"
        case "notifications_muted": return isKorean ? "알림 꺼짐" : "Notifications Muted"
        case "notifications_enabled": return isKorean ? "알림 켜짐" : "Notifications Enabled"
        default:
            // Fallback: return key as-is with warning
            print("⚠️ L10n: Missing translation for key '\(key)'")
            return key.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    // Convenience helpers per commonly used keys
    static func friends(_ language: AppLanguage) -> String { text("friends", language) }
    static func friendsList(_ language: AppLanguage) -> String { text("friends_list", language) }
    static func searchPlaceholder(_ language: AppLanguage) -> String { text("search_friends_placeholder", language) }
}

/// Minimal protocol to read the current app language without importing the app's LanguageManager here.
/// Conform your LanguageManager to expose `currentLanguage` type `AppLanguage`.
public enum AppLanguage {
    case korean
    case english
}
