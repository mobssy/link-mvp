//
//  LocalizationService.swift
//  TalkMVP
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
    case errorTitle = "error_title"
    case friendRequestFailed = "friend_request_failed"
    case blockFailed = "block_failed"

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

    // Accessibility - Message Types & Input Actions
    case messageRead = "message_read"
    case messageUnread = "message_unread"
    case photoMessage = "photo_message"
    case videoMessage = "video_message"
    case audioMessageLabel = "audio_message_label"
    case fileMessage = "file_message"
    case deletedMessageLabel = "deleted_message_label"
    case sendMessage = "send_message"
    case attachFile = "attach_file"
    case cancelAttachment = "cancel_attachment"
    case sendAttachment = "send_attachment"
    case newChatButton = "new_chat_button"
    case messageActionHint = "message_action_hint"
    case loading
    case copiedMessage = "copied_message"
    case moreOptions = "more_options"
}

enum Language {
    case korean
    case english
    case japanese
    case chinese
    case spanish
}

/// Concrete Implementation of LocalizationService
/// Single Responsibility: 한/영/일/중/스 번역 담당
class LocalizationService: LocalizationServiceProtocol {
    static let shared = LocalizationService()

    private init() {}

    func text(for key: LocalizationKey, language: Language) -> String {
        switch key {
        // Basic Actions
        case .cancel:
            switch language {
            case .korean: return "취소"
            case .english: return "Cancel"
            case .japanese: return "キャンセル"
            case .chinese: return "取消"
            case .spanish: return "Cancelar"
            }
        case .save:
            switch language {
            case .korean: return "저장"
            case .english: return "Save"
            case .japanese: return "保存"
            case .chinese: return "保存"
            case .spanish: return "Guardar"
            }
        case .ok:
            switch language {
            case .korean: return "확인"
            case .english: return "OK"
            case .japanese: return "OK"
            case .chinese: return "确认"
            case .spanish: return "Aceptar"
            }
        case .done:
            switch language {
            case .korean: return "완료"
            case .english: return "Done"
            case .japanese: return "完了"
            case .chinese: return "完成"
            case .spanish: return "Listo"
            }
        case .close:
            switch language {
            case .korean: return "닫기"
            case .english: return "Close"
            case .japanese: return "閉じる"
            case .chinese: return "关闭"
            case .spanish: return "Cerrar"
            }
        case .delete:
            switch language {
            case .korean: return "삭제"
            case .english: return "Delete"
            case .japanese: return "削除"
            case .chinese: return "删除"
            case .spanish: return "Eliminar"
            }
        case .edit:
            switch language {
            case .korean: return "편집"
            case .english: return "Edit"
            case .japanese: return "編集"
            case .chinese: return "编辑"
            case .spanish: return "Editar"
            }
        case .add:
            switch language {
            case .korean: return "추가"
            case .english: return "Add"
            case .japanese: return "追加"
            case .chinese: return "添加"
            case .spanish: return "Agregar"
            }
        case .search:
            switch language {
            case .korean: return "검색"
            case .english: return "Search"
            case .japanese: return "検索"
            case .chinese: return "搜索"
            case .spanish: return "Buscar"
            }
        case .settings:
            switch language {
            case .korean: return "설정"
            case .english: return "Settings"
            case .japanese: return "設定"
            case .chinese: return "设置"
            case .spanish: return "Configuración"
            }
        case .profile:
            switch language {
            case .korean: return "프로필"
            case .english: return "Profile"
            case .japanese: return "プロフィール"
            case .chinese: return "个人资料"
            case .spanish: return "Perfil"
            }
        case .logout:
            switch language {
            case .korean: return "로그아웃"
            case .english: return "Sign Out"
            case .japanese: return "ログアウト"
            case .chinese: return "退出登录"
            case .spanish: return "Cerrar sesión"
            }
        case .signin:
            switch language {
            case .korean: return "로그인"
            case .english: return "Sign In"
            case .japanese: return "ログイン"
            case .chinese: return "登录"
            case .spanish: return "Iniciar sesión"
            }
        case .signup:
            switch language {
            case .korean: return "회원가입"
            case .english: return "Sign Up"
            case .japanese: return "新規登録"
            case .chinese: return "注册"
            case .spanish: return "Registrarse"
            }
        case .open:
            switch language {
            case .korean: return "열기"
            case .english: return "Open"
            case .japanese: return "開く"
            case .chinese: return "打开"
            case .spanish: return "Abrir"
            }
        case .attach:
            switch language {
            case .korean: return "첨부"
            case .english: return "Attach"
            case .japanese: return "添付"
            case .chinese: return "附加"
            case .spanish: return "Adjuntar"
            }
        case .viewProfile:
            switch language {
            case .korean: return "프로필 보기"
            case .english: return "View Profile"
            case .japanese: return "プロフィールを見る"
            case .chinese: return "查看资料"
            case .spanish: return "Ver perfil"
            }
        case .reply:
            switch language {
            case .korean: return "답장"
            case .english: return "Reply"
            case .japanese: return "返信"
            case .chinese: return "回复"
            case .spanish: return "Responder"
            }
        case .copyText:
            switch language {
            case .korean: return "복사"
            case .english: return "Copy"
            case .japanese: return "コピー"
            case .chinese: return "复制"
            case .spanish: return "Copiar"
            }
        case .addReaction:
            switch language {
            case .korean: return "반응 추가"
            case .english: return "Add Reaction"
            case .japanese: return "リアクション追加"
            case .chinese: return "添加反应"
            case .spanish: return "Agregar reacción"
            }
        case .send:
            switch language {
            case .korean: return "전송"
            case .english: return "Send"
            case .japanese: return "送信"
            case .chinese: return "发送"
            case .spanish: return "Enviar"
            }

        // Chat Related
        case .chat:
            switch language {
            case .korean: return "채팅"
            case .english: return "Chat"
            case .japanese: return "チャット"
            case .chinese: return "聊天"
            case .spanish: return "Chat"
            }
        case .message:
            switch language {
            case .korean: return "메시지"
            case .english: return "Message"
            case .japanese: return "メッセージ"
            case .chinese: return "消息"
            case .spanish: return "Mensaje"
            }
        case .messageInputPlaceholder:
            switch language {
            case .korean: return "메시지 입력"
            case .english: return "Type a message"
            case .japanese: return "メッセージを入力"
            case .chinese: return "输入消息"
            case .spanish: return "Escribe un mensaje"
            }
        case .typing:
            switch language {
            case .korean: return "입력 중"
            case .english: return "Typing"
            case .japanese: return "入力中"
            case .chinese: return "正在输入"
            case .spanish: return "Escribiendo"
            }
        case .online:
            switch language {
            case .korean: return "온라인"
            case .english: return "Online"
            case .japanese: return "オンライン"
            case .chinese: return "在线"
            case .spanish: return "En línea"
            }
        case .offline:
            switch language {
            case .korean: return "오프라인"
            case .english: return "Offline"
            case .japanese: return "オフライン"
            case .chinese: return "离线"
            case .spanish: return "Desconectado"
            }
        case .replyingTo:
            switch language {
            case .korean: return "%@님에게 답장"
            case .english: return "Replying to %@"
            case .japanese: return "%@に返信中"
            case .chinese: return "%@回复中"
            case .spanish: return "Respondiendo a %@"
            }
        case .me:
            switch language {
            case .korean: return "나"
            case .english: return "Me"
            case .japanese: return "私"
            case .chinese: return "我"
            case .spanish: return "Yo"
            }
        case .conversationSummary:
            switch language {
            case .korean: return "대화 요약"
            case .english: return "Conversation Summary"
            case .japanese: return "会話のまとめ"
            case .chinese: return "对话摘要"
            case .spanish: return "Resumen de conversación"
            }
        case .searchConversation:
            switch language {
            case .korean: return "대화 검색"
            case .english: return "Search conversation"
            case .japanese: return "会話を検索"
            case .chinese: return "搜索对话"
            case .spanish: return "Buscar conversación"
            }

        // Friends
        case .friends:
            switch language {
            case .korean: return "친구"
            case .english: return "Friends"
            case .japanese: return "友だち"
            case .chinese: return "朋友"
            case .spanish: return "Amigos"
            }
        case .addFriend:
            switch language {
            case .korean: return "친구 추가"
            case .english: return "Add Friend"
            case .japanese: return "友だち追加"
            case .chinese: return "添加朋友"
            case .spanish: return "Agregar amigo"
            }
        case .friendRequest:
            switch language {
            case .korean: return "친구 요청"
            case .english: return "Friend Request"
            case .japanese: return "友だちリクエスト"
            case .chinese: return "好友请求"
            case .spanish: return "Solicitud de amistad"
            }
        case .accept:
            switch language {
            case .korean: return "수락"
            case .english: return "Accept"
            case .japanese: return "承認"
            case .chinese: return "接受"
            case .spanish: return "Aceptar"
            }
        case .reject:
            switch language {
            case .korean: return "거절"
            case .english: return "Reject"
            case .japanese: return "拒否"
            case .chinese: return "拒绝"
            case .spanish: return "Rechazar"
            }
        case .block:
            switch language {
            case .korean: return "차단"
            case .english: return "Block"
            case .japanese: return "ブロック"
            case .chinese: return "屏蔽"
            case .spanish: return "Bloquear"
            }
        case .unblock:
            switch language {
            case .korean: return "차단 해제"
            case .english: return "Unblock"
            case .japanese: return "ブロック解除"
            case .chinese: return "解除屏蔽"
            case .spanish: return "Desbloquear"
            }
        case .addFriendTitle:
            switch language {
            case .korean: return "친구 추가"
            case .english: return "Add Friend"
            case .japanese: return "友だち追加"
            case .chinese: return "添加朋友"
            case .spanish: return "Agregar amigo"
            }
        case .addFriendMessage:
            switch language {
            case .korean: return "%@님을 친구로 추가하시겠습니까?"
            case .english: return "Add %@ as a friend?"
            case .japanese: return "%@を友だちに追加しますか？"
            case .chinese: return "确定添加%@为朋友吗？"
            case .spanish: return "¿Agregar a %@ como amigo?"
            }

        // Notifications & Errors
        case .notification:
            switch language {
            case .korean: return "알림"
            case .english: return "Notification"
            case .japanese: return "通知"
            case .chinese: return "通知"
            case .spanish: return "Notificación"
            }
        case .errorOccurred:
            switch language {
            case .korean: return "오류가 발생했습니다"
            case .english: return "An error occurred"
            case .japanese: return "エラーが発生しました"
            case .chinese: return "发生了错误"
            case .spanish: return "Ocurrió un error"
            }
        case .networkError:
            switch language {
            case .korean: return "네트워크 오류"
            case .english: return "Network Error"
            case .japanese: return "ネットワークエラー"
            case .chinese: return "网络错误"
            case .spanish: return "Error de red"
            }
        case .tryAgain:
            switch language {
            case .korean: return "다시 시도해주세요"
            case .english: return "Please try again"
            case .japanese: return "もう一度試してください"
            case .chinese: return "请再试一次"
            case .spanish: return "Por favor intenta de nuevo"
            }
        case .muteNotifications:
            switch language {
            case .korean: return "알림 끄기"
            case .english: return "Mute notifications"
            case .japanese: return "通知をオフ"
            case .chinese: return "关闭通知"
            case .spanish: return "Silenciar notificaciones"
            }
        case .unmuteNotifications:
            switch language {
            case .korean: return "알림 켜기"
            case .english: return "Unmute notifications"
            case .japanese: return "通知をオン"
            case .chinese: return "开启通知"
            case .spanish: return "Activar notificaciones"
            }

        // Permissions
        case .permissionRequired:
            switch language {
            case .korean: return "권한이 필요합니다"
            case .english: return "Permission Required"
            case .japanese: return "権限が必要です"
            case .chinese: return "需要权限"
            case .spanish: return "Se requiere permiso"
            }
        case .openSettings:
            switch language {
            case .korean: return "설정 열기"
            case .english: return "Open Settings"
            case .japanese: return "設定を開く"
            case .chinese: return "打开设置"
            case .spanish: return "Abrir configuración"
            }
        case .contactsPermissionTitle:
            switch language {
            case .korean: return "연락처 접근 권한 필요"
            case .english: return "Contacts Permission Required"
            case .japanese: return "連絡先アクセス権限が必要"
            case .chinese: return "需要通讯录权限"
            case .spanish: return "Se requiere permiso de contactos"
            }
        case .contactsPermissionMessage:
            switch language {
            case .korean: return "친구를 찾기 위해 연락처 접근 권한이 필요합니다. 설정에서 허용해 주세요."
            case .english: return "Contacts access is required to find friends. Please allow it in Settings."
            case .japanese: return "友だちを見つけるために連絡先へのアクセスが必要です。設定で許可してください。"
            case .chinese: return "需要访问通讯录以查找朋友。请在设置中允许。"
            case .spanish: return "Se requiere acceso a contactos para encontrar amigos. Por favor, permítalo en Configuración."
            }
        case .photoPermissionTitle:
            switch language {
            case .korean: return "사진 접근 권한 필요"
            case .english: return "Photos Permission Required"
            case .japanese: return "写真アクセス権限が必要"
            case .chinese: return "需要相册权限"
            case .spanish: return "Se requiere permiso de fotos"
            }
        case .photoPermissionMessage:
            switch language {
            case .korean: return "사진과 동영상을 첨부하려면 사진 접근 권한이 필요합니다. 설정에서 허용해 주세요."
            case .english: return "Photos access is required to attach images and videos. Please allow it in Settings."
            case .japanese: return "画像と動画を添付するために写真へのアクセスが必要です。設定で許可してください。"
            case .chinese: return "需要访问相册以附加图片和视频。请在设置中允许。"
            case .spanish: return "Se requiere acceso a fotos para adjuntar imágenes y videos. Por favor, permítalo en Configuración."
            }
        case .locationPermissionTitle:
            switch language {
            case .korean: return "위치 권한 필요"
            case .english: return "Location Permission Required"
            case .japanese: return "位置情報の権限が必要"
            case .chinese: return "需要位置权限"
            case .spanish: return "Se requiere permiso de ubicación"
            }
        case .locationPermissionMessage:
            switch language {
            case .korean: return "긴급 호출을 위해 위치 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요."
            case .english: return "Location access is required for emergency calls. Please allow it in Settings."
            case .japanese: return "緊急通話のために位置情報へのアクセスが必要です。設定で許可してください。"
            case .chinese: return "紧急呼叫需要位置访问权限。请在设置中允许。"
            case .spanish: return "Se requiere acceso a ubicación para llamadas de emergencia. Por favor, permítalo en Configuración."
            }

        // Accessibility
        case .chatScreen:
            switch language {
            case .korean: return "채팅 화면"
            case .english: return "Chat Screen"
            case .japanese: return "チャット画面"
            case .chinese: return "聊天界面"
            case .spanish: return "Pantalla de chat"
            }
        case .chatScreenHint:
            switch language {
            case .korean: return "%@과의 채팅 화면입니다"
            case .english: return "Chat with %@"
            case .japanese: return "%@とのチャット画面"
            case .chinese: return "%@的聊天界面"
            case .spanish: return "Chat con %@"
            }
        case .messageList:
            switch language {
            case .korean: return "메시지 목록"
            case .english: return "Messages"
            case .japanese: return "メッセージリスト"
            case .chinese: return "消息列表"
            case .spanish: return "Mensajes"
            }
        case .scrollMessagesHint:
            switch language {
            case .korean: return "위아래로 스크롤하여 메시지를 확인할 수 있습니다"
            case .english: return "Scroll up and down to review messages"
            case .japanese: return "上下にスクロールしてメッセージを確認できます"
            case .chinese: return "上下滚动查看消息"
            case .spanish: return "Desplázate hacia arriba y abajo para revisar mensajes"
            }
        case .connectionStatus:
            switch language {
            case .korean: return "연결 상태"
            case .english: return "Connection Status"
            case .japanese: return "接続状態"
            case .chinese: return "连接状态"
            case .spanish: return "Estado de conexión"
            }
        case .typingIndicator:
            switch language {
            case .korean: return "%@님이 입력 중입니다"
            case .english: return "%@ is typing"
            case .japanese: return "%@が入力中です"
            case .chinese: return "%@正在输入"
            case .spanish: return "%@ está escribiendo"
            }

        // Contacts & Matching
        case .contactsMatchResults:
            switch language {
            case .korean: return "연락처 매칭 결과"
            case .english: return "Contacts Match Results"
            case .japanese: return "連絡先マッチング結果"
            case .chinese: return "通讯录匹配结果"
            case .spanish: return "Resultados de coincidencia de contactos"
            }
        case .matchPrefix:
            switch language {
            case .korean: return "일치: "
            case .english: return "Match: "
            case .japanese: return "一致: "
            case .chinese: return "匹配: "
            case .spanish: return "Coincidencia: "
            }

        // Message Actions
        case .editedMessageAnnouncement:
            switch language {
            case .korean: return "메시지를 편집했습니다"
            case .english: return "Message edited"
            case .japanese: return "メッセージを編集しました"
            case .chinese: return "消息已编辑"
            case .spanish: return "Mensaje editado"
            }
        case .editMessagePrompt:
            switch language {
            case .korean: return "메시지를 수정하세요"
            case .english: return "Edit your message"
            case .japanese: return "メッセージを編集してください"
            case .chinese: return "编辑您的消息"
            case .spanish: return "Edita tu mensaje"
            }
        case .editMessage:
            switch language {
            case .korean: return "메시지 편집"
            case .english: return "Edit Message"
            case .japanese: return "メッセージ編集"
            case .chinese: return "编辑消息"
            case .spanish: return "Editar mensaje"
            }
        case .reportUser:
            switch language {
            case .korean: return "신고"
            case .english: return "Report"
            case .japanese: return "報告"
            case .chinese: return "举报"
            case .spanish: return "Reportar"
            }
        case .blockUser:
            switch language {
            case .korean: return "차단"
            case .english: return "Block"
            case .japanese: return "ブロック"
            case .chinese: return "屏蔽"
            case .spanish: return "Bloquear"
            }
        case .reportedUserMessage:
            switch language {
            case .korean: return "%@을(를) 신고했습니다"
            case .english: return "Reported %@"
            case .japanese: return "%@を報告しました"
            case .chinese: return "已举报%@"
            case .spanish: return "Reportado %@"
            }
        case .blockedUserMessage:
            switch language {
            case .korean: return "%@을(를) 차단했습니다"
            case .english: return "Blocked %@"
            case .japanese: return "%@をブロックしました"
            case .chinese: return "已屏蔽%@"
            case .spanish: return "Bloqueado %@"
            }
        case .deleteForMe:
            switch language {
            case .korean: return "나만 삭제"
            case .english: return "Delete for Me"
            case .japanese: return "自分のみ削除"
            case .chinese: return "仅删除我的"
            case .spanish: return "Eliminar para mí"
            }
        case .deleteForEveryone:
            switch language {
            case .korean: return "모두에게서 삭제"
            case .english: return "Delete for Everyone"
            case .japanese: return "全員から削除"
            case .chinese: return "对所有人删除"
            case .spanish: return "Eliminar para todos"
            }
        case .report:
            switch language {
            case .korean: return "신고"
            case .english: return "Report"
            case .japanese: return "報告"
            case .chinese: return "举报"
            case .spanish: return "Reportar"
            }

        // Links & Security
        case .suspiciousLinkDetected:
            switch language {
            case .korean: return "의심스러운 링크가 감지되었습니다"
            case .english: return "A suspicious link was detected"
            case .japanese: return "疑わしいリンクが検出されました"
            case .chinese: return "检测到可疑链接"
            case .spanish: return "Se detectó un enlace sospechoso"
            }
        case .unverifiedInfo:
            switch language {
            case .korean: return "확인되지 않은 정보"
            case .english: return "Unverified Info"
            case .japanese: return "未確認の情報"
            case .chinese: return "未经验证的信息"
            case .spanish: return "Información no verificada"
            }
        case .alwaysAllow:
            switch language {
            case .korean: return "항상 허용"
            case .english: return "Always Allow"
            case .japanese: return "常に許可"
            case .chinese: return "始终允许"
            case .spanish: return "Siempre permitir"
            }

        // Organization Room
        case .organizationRoom:
            switch language {
            case .korean: return "조직방"
            case .english: return "Organization Room"
            case .japanese: return "組織ルーム"
            case .chinese: return "组织房间"
            case .spanish: return "Sala de organización"
            }
        case .enableOrgRoom:
            switch language {
            case .korean: return "조직방 활성화"
            case .english: return "Enable Organization Room"
            case .japanese: return "組織ルームを有効化"
            case .chinese: return "启用组织房间"
            case .spanish: return "Habilitar sala de organización"
            }
        case .orgNameOptional:
            switch language {
            case .korean: return "조직명(선택)"
            case .english: return "Organization Name (Optional)"
            case .japanese: return "組織名（任意）"
            case .chinese: return "组织名称（可选）"
            case .spanish: return "Nombre de organización (opcional)"
            }
        case .workingHours:
            switch language {
            case .korean: return "근무 시간"
            case .english: return "Working Hours"
            case .japanese: return "勤務時間"
            case .chinese: return "工作时间"
            case .spanish: return "Horario laboral"
            }
        case .workingHoursFooter:
            switch language {
            case .korean: return "간단히 요일과 시작/종료 시간을 설정하세요"
            case .english: return "Quickly set weekdays and start/end times"
            case .japanese: return "曜日と開始/終了時間を簡単に設定"
            case .chinese: return "快速设置工作日和开始/结束时间"
            case .spanish: return "Configure días y horarios de inicio/fin"
            }
        case .channelSettings:
            switch language {
            case .korean: return "채널 설정"
            case .english: return "Channel Settings"
            case .japanese: return "チャンネル設定"
            case .chinese: return "频道设置"
            case .spanish: return "Configuración de canal"
            }
        case .channelTimezone:
            switch language {
            case .korean: return "채널 시간대"
            case .english: return "Channel Timezone"
            case .japanese: return "チャンネルのタイムゾーン"
            case .chinese: return "频道时区"
            case .spanish: return "Zona horaria del canal"
            }
        case .weekdays:
            switch language {
            case .korean: return "평일"
            case .english: return "Weekdays"
            case .japanese: return "平日"
            case .chinese: return "工作日"
            case .spanish: return "Días laborables"
            }
        case .daily:
            switch language {
            case .korean: return "매일"
            case .english: return "Daily"
            case .japanese: return "毎日"
            case .chinese: return "每天"
            case .spanish: return "Diario"
            }
        case .start:
            switch language {
            case .korean: return "시작"
            case .english: return "Start"
            case .japanese: return "開始"
            case .chinese: return "开始"
            case .spanish: return "Inicio"
            }
        case .end:
            switch language {
            case .korean: return "종료"
            case .english: return "End"
            case .japanese: return "終了"
            case .chinese: return "结束"
            case .spanish: return "Fin"
            }

        // Emergency
        case .emergencyCall:
            switch language {
            case .korean: return "긴급 호출"
            case .english: return "Emergency Call"
            case .japanese: return "緊急通話"
            case .chinese: return "紧急呼叫"
            case .spanish: return "Llamada de emergencia"
            }
        case .emergencyStarted:
            switch language {
            case .korean: return "긴급 호출이 시작되었습니다"
            case .english: return "Emergency call started"
            case .japanese: return "緊急通話が開始されました"
            case .chinese: return "紧急呼叫已开始"
            case .spanish: return "Llamada de emergencia iniciada"
            }

        // Translation
        case .translatingEllipsis:
            switch language {
            case .korean: return "번역 중..."
            case .english: return "Translating..."
            case .japanese: return "翻訳中..."
            case .chinese: return "翻译中..."
            case .spanish: return "Traduciendo..."
            }

        // Profile
        case .profileInfoUnavailable:
            switch language {
            case .korean: return "프로필 정보를 불러올 수 없습니다"
            case .english: return "Profile information is unavailable"
            case .japanese: return "プロフィール情報を取得できません"
            case .chinese: return "无法加载个人资料"
            case .spanish: return "Información de perfil no disponible"
            }

        // Captions
        case .addCaption:
            switch language {
            case .korean: return "캡션 추가..."
            case .english: return "Add a caption..."
            case .japanese: return "キャプションを追加..."
            case .chinese: return "添加说明..."
            case .spanish: return "Agregar descripción..."
            }

        // Attachments
        case .noAttachment:
            switch language {
            case .korean: return "첨부 파일 없음"
            case .english: return "No Attachment"
            case .japanese: return "添付ファイルなし"
            case .chinese: return "无附件"
            case .spanish: return "Sin adjunto"
            }
        case .video:
            switch language {
            case .korean: return "동영상"
            case .english: return "Video"
            case .japanese: return "動画"
            case .chinese: return "视频"
            case .spanish: return "Video"
            }
        case .photosVideos:
            switch language {
            case .korean: return "사진/동영상"
            case .english: return "Photos/Videos"
            case .japanese: return "写真/動画"
            case .chinese: return "照片/视频"
            case .spanish: return "Fotos/Videos"
            }
        case .file:
            switch language {
            case .korean: return "파일"
            case .english: return "File"
            case .japanese: return "ファイル"
            case .chinese: return "文件"
            case .spanish: return "Archivo"
            }
        case .sentPhoto:
            switch language {
            case .korean: return "사진을 보냈습니다"
            case .english: return "Sent a photo"
            case .japanese: return "写真を送りました"
            case .chinese: return "发送了一张照片"
            case .spanish: return "Envió una foto"
            }
        case .sentVideo:
            switch language {
            case .korean: return "동영상을 보냈습니다"
            case .english: return "Sent a video"
            case .japanese: return "動画を送りました"
            case .chinese: return "发送了一个视频"
            case .spanish: return "Envió un video"
            }
        case .sentFile:
            switch language {
            case .korean: return "파일을 보냈습니다"
            case .english: return "Sent a file"
            case .japanese: return "ファイルを送りました"
            case .chinese: return "发送了一个文件"
            case .spanish: return "Envió un archivo"
            }

        // Accessibility - Message Types & Input Actions
        case .messageRead:
            switch language {
            case .korean: return "읽음"
            case .english: return "Read"
            case .japanese: return "既読"
            case .chinese: return "已读"
            case .spanish: return "Leído"
            }
        case .messageUnread:
            switch language {
            case .korean: return "읽지 않음"
            case .english: return "Unread"
            case .japanese: return "未読"
            case .chinese: return "未读"
            case .spanish: return "No leído"
            }
        case .photoMessage:
            switch language {
            case .korean: return "사진"
            case .english: return "Photo"
            case .japanese: return "写真"
            case .chinese: return "照片"
            case .spanish: return "Foto"
            }
        case .videoMessage:
            switch language {
            case .korean: return "동영상"
            case .english: return "Video"
            case .japanese: return "動画"
            case .chinese: return "视频"
            case .spanish: return "Video"
            }
        case .audioMessageLabel:
            switch language {
            case .korean: return "음성 메시지"
            case .english: return "Audio message"
            case .japanese: return "音声メッセージ"
            case .chinese: return "语音消息"
            case .spanish: return "Mensaje de audio"
            }
        case .fileMessage:
            switch language {
            case .korean: return "파일"
            case .english: return "File"
            case .japanese: return "ファイル"
            case .chinese: return "文件"
            case .spanish: return "Archivo"
            }
        case .deletedMessageLabel:
            switch language {
            case .korean: return "삭제된 메시지"
            case .english: return "Deleted message"
            case .japanese: return "削除されたメッセージ"
            case .chinese: return "已删除的消息"
            case .spanish: return "Mensaje eliminado"
            }
        case .sendMessage:
            switch language {
            case .korean: return "메시지 전송"
            case .english: return "Send message"
            case .japanese: return "メッセージ送信"
            case .chinese: return "发送消息"
            case .spanish: return "Enviar mensaje"
            }
        case .attachFile:
            switch language {
            case .korean: return "파일 또는 미디어 첨부"
            case .english: return "Attach file or media"
            case .japanese: return "ファイルまたはメディアを添付"
            case .chinese: return "附加文件或媒体"
            case .spanish: return "Adjuntar archivo o multimedia"
            }
        case .cancelAttachment:
            switch language {
            case .korean: return "첨부 취소"
            case .english: return "Cancel attachment"
            case .japanese: return "添付をキャンセル"
            case .chinese: return "取消附件"
            case .spanish: return "Cancelar adjunto"
            }
        case .sendAttachment:
            switch language {
            case .korean: return "첨부 전송"
            case .english: return "Send attachment"
            case .japanese: return "添付を送信"
            case .chinese: return "发送附件"
            case .spanish: return "Enviar adjunto"
            }
        case .newChatButton:
            switch language {
            case .korean: return "새 채팅 만들기"
            case .english: return "Create new chat"
            case .japanese: return "新しいチャットを作成"
            case .chinese: return "创建新聊天"
            case .spanish: return "Crear nuevo chat"
            }
        case .messageActionHint:
            switch language {
            case .korean: return "길게 눌러 반응 추가, 밀어서 답장"
            case .english: return "Long press for reactions, swipe to reply"
            case .japanese: return "長押しでリアクション、スワイプで返信"
            case .chinese: return "长按添加反应，滑动回复"
            case .spanish: return "Mantén presionado para reacciones, desliza para responder"
            }
        case .loading:
            switch language {
            case .korean: return "로딩 중..."
            case .english: return "Loading..."
            case .japanese: return "読み込み中..."
            case .chinese: return "加载中..."
            case .spanish: return "Cargando..."
            }
        case .copiedMessage:
            switch language {
            case .korean: return "메시지를 복사했습니다"
            case .english: return "Message copied"
            case .japanese: return "メッセージをコピーしました"
            case .chinese: return "消息已复制"
            case .spanish: return "Mensaje copiado"
            }
        case .moreOptions:
            switch language {
            case .korean: return "더 보기"
            case .english: return "More options"
            case .japanese: return "もっと見る"
            case .chinese: return "更多选项"
            case .spanish: return "Más opciones"
            }
        case .errorTitle:
            switch language {
            case .korean: return "오류"
            case .english: return "Error"
            case .japanese: return "エラー"
            case .chinese: return "错误"
            case .spanish: return "Error"
            }
        case .friendRequestFailed:
            switch language {
            case .korean: return "친구 요청을 보내지 못했습니다. 다시 시도해주세요."
            case .english: return "Failed to send friend request. Please try again."
            case .japanese: return "友達リクエストの送信に失敗しました。もう一度お試しください。"
            case .chinese: return "发送好友请求失败，请重试。"
            case .spanish: return "Error al enviar solicitud de amistad. Inténtalo de nuevo."
            }
        case .blockFailed:
            switch language {
            case .korean: return "사용자를 차단하지 못했습니다. 다시 시도해주세요."
            case .english: return "Failed to block user. Please try again."
            case .japanese: return "ユーザーのブロックに失敗しました。もう一度お試しください。"
            case .chinese: return "屏蔽用户失败，请重试。"
            case .spanish: return "Error al bloquear al usuario. Inténtalo de nuevo."
            }
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
        let language: Language
        switch languageManager.currentLanguage {
        case .korean: language = .korean
        case .english: language = .english
        case .japanese: language = .japanese
        case .chinese: language = .chinese
        case .chineseTraditional: language = .chinese
        case .spanish: language = .spanish
        }
        return text(for: locKey, language: language)
    }
}
