//
//  LocalizationService.swift
//  L!nkMVP
//
//  Created by Claude Code
//

import Foundation

/// Single Responsibility: 다국어 처리 전담 서비스
/// Open/Closed: enum으로 타입 안전성 확보, 확장 용이
protocol LocalizationServiceProtocol {
    func text(for key: LocalizationKey, language: Language) -> String
}

enum LocalizationKey: String {
    // Basic Actions
    case cancel, save, ok, done, close, delete, edit, add, search, settings
    case profile, logout, signin, signup, `open`, attach, viewProfile, reply
    case copyText = "copy"
    case addReaction = "add_reaction"
    case send

    // Chat Related
    case chat, message, messageInputPlaceholder = "message_input_placeholder"
    case typing, online, offline
    case replyingTo = "replying_to"
    case me
    case conversationSummary = "conversation_summary"
    case searchConversation = "search_conversation"

    // Friends
    case friends, addFriend = "add_friend", friendRequest = "friend_request"
    case accept, reject, block, unblock
    case addFriendTitle = "add_friend_title"
    case addFriendMessage = "add_friend_message"

    // Notifications & Errors
    case notification, errorOccurred = "error_occurred"
    case networkError = "network_error", tryAgain = "try_again"
    case muteNotifications = "mute_notifications"
    case unmuteNotifications = "unmute_notifications"

    // Permissions
    case permissionRequired = "permission_required", openSettings = "open_settings"
    case contactsPermissionTitle = "contacts_permission_title"
    case contactsPermissionMessage = "contacts_permission_message"
    case photoPermissionTitle = "photo_permission_title"
    case photoPermissionMessage = "photo_permission_message"
    case locationPermissionTitle = "location_permission_title"
    case locationPermissionMessage = "location_permission_message"

    // Accessibility
    case chatScreen = "chat_screen", chatScreenHint = "chat_screen_hint"
    case messageList = "message_list", scrollMessagesHint = "scroll_messages_hint"
    case connectionStatus = "connection_status"
    case typingIndicator = "typing_indicator"

    // Contacts & Matching
    case contactsMatchResults = "contacts_match_results"
    case matchPrefix = "match_prefix"

    // Message Actions
    case editedMessageAnnouncement = "edited_message_announcement"
    case editMessagePrompt = "edit_message_prompt"
    case editMessage = "edit_message"
    case reportUser = "report_user", blockUser = "block_user"
    case reportedUserMessage = "reported_user_message"
    case blockedUserMessage = "blocked_user_message"
    case deleteForMe = "delete_for_me"
    case deleteForEveryone = "delete_for_everyone"
    case report = "report"

    // Links & Security
    case suspiciousLinkDetected = "suspicious_link_detected"
    case unverifiedInfo = "unverified_info"
    case alwaysAllow = "always_allow"

    // Organization Room
    case organizationRoom = "organization_room"
    case enableOrgRoom = "enable_org_room"
    case orgNameOptional = "org_name_optional"
    case workingHours = "working_hours"
    case workingHoursFooter = "working_hours_footer"
    case channelSettings = "channel_settings"
    case channelTimezone = "channel_timezone"
    case weekdays, daily, start, end

    // Emergency
    case emergencyCall = "emergency_call"
    case emergencyStarted = "emergency_started"

    // Translation
    case translatingEllipsis = "translating_ellipsis"

    // Profile
    case profileInfoUnavailable = "profile_info_unavailable"

    // Captions
    case addCaption = "add_caption"

    // Attachments
    case noAttachment = "no_attachment"
    case video
    case photosVideos = "photos_videos"
    case file
    case sentPhoto = "sent_photo"
    case sentVideo = "sent_video"
    case sentFile = "sent_file"
}

enum Language {
    case korean
    case english
}

/// Concrete Implementation of LocalizationService
/// Single Responsibility: 한/영 번역만 담당
class LocalizationService: LocalizationServiceProtocol {
    static let shared = LocalizationService()

    private init() {}

    func text(for key: LocalizationKey, language: Language) -> String {
        let isKorean = (language == .korean)

        switch key {
        // Basic Actions
        case .cancel: return isKorean ? "취소" : "Cancel"
        case .save: return isKorean ? "저장" : "Save"
        case .ok: return isKorean ? "확인" : "OK"
        case .done: return isKorean ? "완료" : "Done"
        case .close: return isKorean ? "닫기" : "Close"
        case .delete: return isKorean ? "삭제" : "Delete"
        case .edit: return isKorean ? "편집" : "Edit"
        case .add: return isKorean ? "추가" : "Add"
        case .search: return isKorean ? "검색" : "Search"
        case .settings: return isKorean ? "설정" : "Settings"
        case .profile: return isKorean ? "프로필" : "Profile"
        case .logout: return isKorean ? "로그아웃" : "Sign Out"
        case .signin: return isKorean ? "로그인" : "Sign In"
        case .signup: return isKorean ? "회원가입" : "Sign Up"
        case .open: return isKorean ? "열기" : "Open"
        case .attach: return isKorean ? "첨부" : "Attach"
        case .viewProfile: return isKorean ? "프로필 보기" : "View Profile"
        case .reply: return isKorean ? "답장" : "Reply"
        case .copyText: return isKorean ? "복사" : "Copy"
        case .addReaction: return isKorean ? "반응 추가" : "Add Reaction"
        case .send: return isKorean ? "전송" : "Send"

        // Chat Related
        case .chat: return isKorean ? "채팅" : "Chat"
        case .message: return isKorean ? "메시지" : "Message"
        case .messageInputPlaceholder: return isKorean ? "메시지 입력" : "Type a message"
        case .typing: return isKorean ? "입력 중" : "Typing"
        case .online: return isKorean ? "온라인" : "Online"
        case .offline: return isKorean ? "오프라인" : "Offline"
        case .replyingTo: return isKorean ? "%@님에게 답장" : "Replying to %@"
        case .me: return isKorean ? "나" : "Me"
        case .conversationSummary: return isKorean ? "대화 요약" : "Conversation Summary"
        case .searchConversation: return isKorean ? "대화 검색" : "Search conversation"

        // Friends
        case .friends: return isKorean ? "친구" : "Friends"
        case .addFriend: return isKorean ? "친구 추가" : "Add Friend"
        case .friendRequest: return isKorean ? "친구 요청" : "Friend Request"
        case .accept: return isKorean ? "수락" : "Accept"
        case .reject: return isKorean ? "거절" : "Reject"
        case .block: return isKorean ? "차단" : "Block"
        case .unblock: return isKorean ? "차단 해제" : "Unblock"
        case .addFriendTitle: return isKorean ? "친구 추가" : "Add Friend"
        case .addFriendMessage: return isKorean ? "%@님을 친구로 추가하시겠습니까?" : "Add %@ as a friend?"

        // Notifications & Errors
        case .notification: return isKorean ? "알림" : "Notification"
        case .errorOccurred: return isKorean ? "오류가 발생했습니다" : "An error occurred"
        case .networkError: return isKorean ? "네트워크 오류" : "Network Error"
        case .tryAgain: return isKorean ? "다시 시도해주세요" : "Please try again"
        case .muteNotifications: return isKorean ? "알림 끄기" : "Mute notifications"
        case .unmuteNotifications: return isKorean ? "알림 켜기" : "Unmute notifications"

        // Permissions
        case .permissionRequired: return isKorean ? "권한이 필요합니다" : "Permission Required"
        case .openSettings: return isKorean ? "설정 열기" : "Open Settings"
        case .contactsPermissionTitle: return isKorean ? "연락처 접근 권한 필요" : "Contacts Permission Required"
        case .contactsPermissionMessage: return isKorean ? "친구를 찾기 위해 연락처 접근 권한이 필요합니다. 설정에서 허용해 주세요." : "Contacts access is required to find friends. Please allow it in Settings."
        case .photoPermissionTitle: return isKorean ? "사진 접근 권한 필요" : "Photos Permission Required"
        case .photoPermissionMessage: return isKorean ? "사진과 동영상을 첨부하려면 사진 접근 권한이 필요합니다. 설정에서 허용해 주세요." : "Photos access is required to attach images and videos. Please allow it in Settings."
        case .locationPermissionTitle: return isKorean ? "위치 권한 필요" : "Location Permission Required"
        case .locationPermissionMessage: return isKorean ? "긴급 호출을 위해 위치 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요." : "Location access is required for emergency calls. Please allow it in Settings."

        // Accessibility
        case .chatScreen: return isKorean ? "채팅 화면" : "Chat Screen"
        case .chatScreenHint: return isKorean ? "%@과의 채팅 화면입니다" : "Chat with %@"
        case .messageList: return isKorean ? "메시지 목록" : "Messages"
        case .scrollMessagesHint: return isKorean ? "위아래로 스크롤하여 메시지를 확인할 수 있습니다" : "Scroll up and down to review messages"
        case .connectionStatus: return isKorean ? "연결 상태" : "Connection Status"
        case .typingIndicator: return isKorean ? "%@님이 입력 중입니다" : "%@ is typing"

        // Contacts & Matching
        case .contactsMatchResults: return isKorean ? "연락처 매칭 결과" : "Contacts Match Results"
        case .matchPrefix: return isKorean ? "일치: " : "Match: "

        // Message Actions
        case .editedMessageAnnouncement: return isKorean ? "메시지를 편집했습니다" : "Message edited"
        case .editMessagePrompt: return isKorean ? "메시지를 수정하세요" : "Edit your message"
        case .editMessage: return isKorean ? "메시지 편집" : "Edit Message"
        case .reportUser: return isKorean ? "신고" : "Report"
        case .blockUser: return isKorean ? "차단" : "Block"
        case .reportedUserMessage: return isKorean ? "%@을(를) 신고했습니다" : "Reported %@"
        case .blockedUserMessage: return isKorean ? "%@을(를) 차단했습니다" : "Blocked %@"
        case .deleteForMe: return isKorean ? "나만 삭제" : "Delete for Me"
        case .deleteForEveryone: return isKorean ? "모두에게서 삭제" : "Delete for Everyone"
        case .report: return isKorean ? "신고" : "Report"

        // Links & Security
        case .suspiciousLinkDetected: return isKorean ? "의심스러운 링크가 감지되었습니다" : "A suspicious link was detected"
        case .unverifiedInfo: return isKorean ? "확인되지 않은 정보" : "Unverified Info"
        case .alwaysAllow: return isKorean ? "항상 허용" : "Always Allow"

        // Organization Room
        case .organizationRoom: return isKorean ? "조직방" : "Organization Room"
        case .enableOrgRoom: return isKorean ? "조직방 활성화" : "Enable Organization Room"
        case .orgNameOptional: return isKorean ? "조직명(선택)" : "Organization Name (Optional)"
        case .workingHours: return isKorean ? "근무 시간" : "Working Hours"
        case .workingHoursFooter: return isKorean ? "간단히 요일과 시작/종료 시간을 설정하세요" : "Quickly set weekdays and start/end times"
        case .channelSettings: return isKorean ? "채널 설정" : "Channel Settings"
        case .channelTimezone: return isKorean ? "채널 시간대" : "Channel Timezone"
        case .weekdays: return isKorean ? "평일" : "Weekdays"
        case .daily: return isKorean ? "매일" : "Daily"
        case .start: return isKorean ? "시작" : "Start"
        case .end: return isKorean ? "종료" : "End"

        // Emergency
        case .emergencyCall: return isKorean ? "긴급 호출" : "Emergency Call"
        case .emergencyStarted: return isKorean ? "긴급 호출이 시작되었습니다" : "Emergency call started"

        // Translation
        case .translatingEllipsis: return isKorean ? "번역 중..." : "Translating..."

        // Profile
        case .profileInfoUnavailable: return isKorean ? "프로필 정보를 불러올 수 없습니다" : "Profile information is unavailable"

        // Captions
        case .addCaption: return isKorean ? "캡션 추가..." : "Add a caption..."

        // Attachments
        case .noAttachment: return isKorean ? "첨부 파일 없음" : "No Attachment"
        case .video: return isKorean ? "동영상" : "Video"
        case .photosVideos: return isKorean ? "사진/동영상" : "Photos/Videos"
        case .file: return isKorean ? "파일" : "File"
        case .sentPhoto: return isKorean ? "사진을 보냈습니다" : "Sent a photo"
        case .sentVideo: return isKorean ? "동영상을 보냈습니다" : "Sent a video"
        case .sentFile: return isKorean ? "파일을 보냈습니다" : "Sent a file"
        }
    }
}

// MARK: - Helper extension for LanguageManager compatibility
extension LocalizationService {
    func localizedText(_ key: String, languageManager: LanguageManager) -> String {
        // Fallback for string-based keys (for backward compatibility during migration)
        guard let locKey = LocalizationKey(rawValue: key) else {
            return key
        }
        let language: Language = (languageManager.currentLanguage == .korean) ? .korean : .english
        return text(for: locKey, language: language)
    }
}
