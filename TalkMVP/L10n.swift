import Foundation
import SwiftUI

/// Centralized localization helper to avoid scattering `localizedText` across views.
/// - Usage: `L10n.friends(language)` or `L10n.text("friends", language)`
enum L10n {
    /// Returns the localized string for a known key with built-in Korean/English/Japanese/Chinese/Spanish mapping.
    /// If you later add Localizable.strings, you can migrate calls to String(localized:),
    /// but this keeps behavior consistent today.
    static func text(_ key: String, _ language: AppLanguage) -> String {
        switch key {
        case "friends":
            switch language {
            case .korean: return "친구"
            case .english: return "Friends"
            case .japanese: return "友だち"
            case .chinese: return "朋友"
            case .spanish: return "Amigos"
            }
        case "friends_title":
            switch language {
            case .korean: return "친구"
            case .english: return "Friends"
            case .japanese: return "友だち"
            case .chinese: return "朋友"
            case .spanish: return "Amigos"
            }
        case "friends_list":
            switch language {
            case .korean: return "친구 목록"
            case .english: return "Friends List"
            case .japanese: return "友だちリスト"
            case .chinese: return "朋友列表"
            case .spanish: return "Lista de amigos"
            }
        case "friends_empty":
            switch language {
            case .korean: return "친구 목록이 비어 있습니다"
            case .english: return "Your friends list is empty"
            case .japanese: return "友だちリストが空です"
            case .chinese: return "朋友列表为空"
            case .spanish: return "Tu lista de amigos está vacía"
            }
        case "add_sample_friend":
            switch language {
            case .korean: return "샘플 친구 추가"
            case .english: return "Add Sample Friend"
            case .japanese: return "サンプル友だち追加"
            case .chinese: return "添加示例朋友"
            case .spanish: return "Agregar amigo de muestra"
            }
        case "pin_to_top":
            switch language {
            case .korean: return "상단 고정"
            case .english: return "Pin to Top"
            case .japanese: return "上部に固定"
            case .chinese: return "置顶"
            case .spanish: return "Fijar arriba"
            }
        case "unpin":
            switch language {
            case .korean: return "고정 해제"
            case .english: return "Unpin"
            case .japanese: return "固定解除"
            case .chinese: return "取消置顶"
            case .spanish: return "Desfijar"
            }
        case "delete":
            switch language {
            case .korean: return "삭제"
            case .english: return "Delete"
            case .japanese: return "削除"
            case .chinese: return "删除"
            case .spanish: return "Eliminar"
            }
        case "add_friend":
            switch language {
            case .korean: return "친구 추가"
            case .english: return "Add Friend"
            case .japanese: return "友だち追加"
            case .chinese: return "添加朋友"
            case .spanish: return "Agregar amigo"
            }
        case "search_friends":
            switch language {
            case .korean: return "친구 검색"
            case .english: return "Search Friends"
            case .japanese: return "友だち検索"
            case .chinese: return "搜索朋友"
            case .spanish: return "Buscar amigos"
            }
        case "search_friends_placeholder":
            switch language {
            case .korean: return "이름으로 검색"
            case .english: return "Search by name"
            case .japanese: return "名前で検索"
            case .chinese: return "按名字搜索"
            case .spanish: return "Buscar por nombre"
            }
        case "settings":
            switch language {
            case .korean: return "설정"
            case .english: return "Settings"
            case .japanese: return "設定"
            case .chinese: return "设置"
            case .spanish: return "Configuración"
            }
        case "manage_hidden_blocked":
            switch language {
            case .korean: return "숨김/차단 관리"
            case .english: return "Manage Hidden/Blocked"
            case .japanese: return "非表示/ブロック管理"
            case .chinese: return "管理隐藏/屏蔽"
            case .spanish: return "Gestionar ocultos/bloqueados"
            }
        case "online":
            switch language {
            case .korean: return "온라인"
            case .english: return "online"
            case .japanese: return "オンライン"
            case .chinese: return "在线"
            case .spanish: return "en línea"
            }
        case "new_friends":
            switch language {
            case .korean: return "새로운 친구 (%d)"
            case .english: return "New Friends (%d)"
            case .japanese: return "新しい友だち (%d)"
            case .chinese: return "新朋友 (%d)"
            case .spanish: return "Nuevos amigos (%d)"
            }
        case "received_requests":
            switch language {
            case .korean: return "받은 친구 요청 (%d)"
            case .english: return "Received Requests (%d)"
            case .japanese: return "受け取ったリクエスト (%d)"
            case .chinese: return "收到的请求 (%d)"
            case .spanish: return "Solicitudes recibidas (%d)"
            }
        case "sent_requests":
            switch language {
            case .korean: return "보낸 친구 요청 (%d)"
            case .english: return "Sent Requests (%d)"
            case .japanese: return "送ったリクエスト (%d)"
            case .chinese: return "发出的请求 (%d)"
            case .spanish: return "Solicitudes enviadas (%d)"
            }
        case "no_search_results":
            switch language {
            case .korean: return "검색 결과 없음"
            case .english: return "No Search Results"
            case .japanese: return "検索結果なし"
            case .chinese: return "没有搜索结果"
            case .spanish: return "Sin resultados de búsqueda"
            }
        case "no_match_for":
            switch language {
            case .korean: return "'%@'에 대한 검색 결과가 없습니다"
            case .english: return "No matches for '%@'"
            case .japanese: return "'%@'の検索結果がありません"
            case .chinese: return "'%@'没有匹配结果"
            case .spanish: return "Sin coincidencias para '%@'"
            }
        case "no_friends_yet":
            switch language {
            case .korean: return "아직 친구가 없습니다"
            case .english: return "No Friends Yet"
            case .japanese: return "まだ友だちがいません"
            case .chinese: return "还没有朋友"
            case .spanish: return "Aún no tienes amigos"
            }
        case "add_friends_suggestion":
            switch language {
            case .korean: return "이메일로 친구를 추가해보세요"
            case .english: return "Try adding friends by email"
            case .japanese: return "メールで友だちを追加してみましょう"
            case .chinese: return "试着通过邮箱添加朋友"
            case .spanish: return "Intenta agregar amigos por correo"
            }
        case "add_friend_by_email":
            switch language {
            case .korean: return "이메일로 친구 추가"
            case .english: return "Add Friend by Email"
            case .japanese: return "メールで友だち追加"
            case .chinese: return "通过邮箱添加朋友"
            case .spanish: return "Agregar amigo por correo"
            }
        case "hide":
            switch language {
            case .korean: return "숨기기"
            case .english: return "Hide"
            case .japanese: return "非表示"
            case .chinese: return "隐藏"
            case .spanish: return "Ocultar"
            }
        case "block":
            switch language {
            case .korean: return "차단"
            case .english: return "Block"
            case .japanese: return "ブロック"
            case .chinese: return "屏蔽"
            case .spanish: return "Bloquear"
            }
        case "friend_request":
            switch language {
            case .korean: return "친구 요청"
            case .english: return "Friend Request"
            case .japanese: return "友だちリクエスト"
            case .chinese: return "好友请求"
            case .spanish: return "Solicitud de amistad"
            }
        case "accept":
            switch language {
            case .korean: return "수락"
            case .english: return "Accept"
            case .japanese: return "承認"
            case .chinese: return "接受"
            case .spanish: return "Aceptar"
            }
        case "request_pending":
            switch language {
            case .korean: return "요청 대기 중"
            case .english: return "Request Pending"
            case .japanese: return "リクエスト保留中"
            case .chinese: return "请求待处理"
            case .spanish: return "Solicitud pendiente"
            }
        case "pending_short":
            switch language {
            case .korean: return "대기 중"
            case .english: return "Pending"
            case .japanese: return "保留中"
            case .chinese: return "待处理"
            case .spanish: return "Pendiente"
            }
        case "friend_email_placeholder":
            switch language {
            case .korean: return "친구 이메일 입력"
            case .english: return "Enter friend's email"
            case .japanese: return "友だちのメールを入力"
            case .chinese: return "输入朋友的邮箱"
            case .spanish: return "Ingresa el correo del amigo"
            }
        case "search":
            switch language {
            case .korean: return "검색"
            case .english: return "Search"
            case .japanese: return "検索"
            case .chinese: return "搜索"
            case .spanish: return "Buscar"
            }
        case "add_by_email":
            switch language {
            case .korean: return "이메일로 추가"
            case .english: return "Add by Email"
            case .japanese: return "メールで追加"
            case .chinese: return "通过邮箱添加"
            case .spanish: return "Agregar por correo"
            }
        case "add_by_email_footer":
            switch language {
            case .korean: return "친구의 이메일 주소를 입력하여 검색하세요"
            case .english: return "Enter your friend's email address to search"
            case .japanese: return "友だちのメールアドレスを入力して検索"
            case .chinese: return "输入朋友的邮箱地址进行搜索"
            case .spanish: return "Ingresa el correo de tu amigo para buscar"
            }
        case "searching":
            switch language {
            case .korean: return "검색 중"
            case .english: return "Searching"
            case .japanese: return "検索中"
            case .chinese: return "搜索中"
            case .spanish: return "Buscando"
            }
        case "searching_users":
            switch language {
            case .korean: return "사용자 검색 중..."
            case .english: return "Searching users..."
            case .japanese: return "ユーザー検索中..."
            case .chinese: return "正在搜索用户..."
            case .spanish: return "Buscando usuarios..."
            }
        case "search_results":
            switch language {
            case .korean: return "검색 결과"
            case .english: return "Search Results"
            case .japanese: return "検索結果"
            case .chinese: return "搜索结果"
            case .spanish: return "Resultados de búsqueda"
            }
        case "alert":
            switch language {
            case .korean: return "알림"
            case .english: return "Alert"
            case .japanese: return "アラート"
            case .chinese: return "提示"
            case .spanish: return "Alerta"
            }
        case "ok":
            switch language {
            case .korean: return "확인"
            case .english: return "OK"
            case .japanese: return "OK"
            case .chinese: return "确认"
            case .spanish: return "Aceptar"
            }
        case "cancel":
            switch language {
            case .korean: return "취소"
            case .english: return "Cancel"
            case .japanese: return "キャンセル"
            case .chinese: return "取消"
            case .spanish: return "Cancelar"
            }
        case "enter_email_message":
            switch language {
            case .korean: return "이메일을 입력해주세요"
            case .english: return "Please enter an email"
            case .japanese: return "メールを入力してください"
            case .chinese: return "请输入邮箱"
            case .spanish: return "Por favor ingresa un correo"
            }
        case "invalid_email_format":
            switch language {
            case .korean: return "올바른 이메일 형식이 아닙니다"
            case .english: return "Invalid email format"
            case .japanese: return "メール形式が無効です"
            case .chinese: return "邮箱格式无效"
            case .spanish: return "Formato de correo inválido"
            }
        case "search_error_prefix":
            switch language {
            case .korean: return "검색 오류: "
            case .english: return "Search error: "
            case .japanese: return "検索エラー: "
            case .chinese: return "搜索错误: "
            case .spanish: return "Error de búsqueda: "
            }
        case "user":
            switch language {
            case .korean: return "사용자"
            case .english: return "User"
            case .japanese: return "ユーザー"
            case .chinese: return "用户"
            case .spanish: return "Usuario"
            }
        case "status_message":
            switch language {
            case .korean: return "상태 메시지"
            case .english: return "Status Message"
            case .japanese: return "ステータスメッセージ"
            case .chinese: return "状态消息"
            case .spanish: return "Mensaje de estado"
            }
        case "friend_request_sent":
            switch language {
            case .korean: return "친구 요청을 보냈습니다"
            case .english: return "Friend request sent"
            case .japanese: return "友だちリクエストを送りました"
            case .chinese: return "已发送好友请求"
            case .spanish: return "Solicitud de amistad enviada"
            }
        case "friend_request_failed":
            switch language {
            case .korean: return "친구 요청에 실패했습니다"
            case .english: return "Friend request failed"
            case .japanese: return "友だちリクエストが失敗しました"
            case .chinese: return "好友请求失败"
            case .spanish: return "Error al enviar solicitud"
            }
        case "error_occurred_prefix":
            switch language {
            case .korean: return "오류 발생: "
            case .english: return "Error occurred: "
            case .japanese: return "エラー発生: "
            case .chinese: return "发生错误: "
            case .spanish: return "Error ocurrido: "
            }
        case "no_blocked_friends":
            switch language {
            case .korean: return "차단된 친구가 없습니다"
            case .english: return "No Blocked Friends"
            case .japanese: return "ブロックされた友だちがいません"
            case .chinese: return "没有被屏蔽的朋友"
            case .spanish: return "No hay amigos bloqueados"
            }
        case "blocked_list":
            switch language {
            case .korean: return "차단 목록"
            case .english: return "Blocked List"
            case .japanese: return "ブロックリスト"
            case .chinese: return "屏蔽列表"
            case .spanish: return "Lista de bloqueados"
            }
        case "close":
            switch language {
            case .korean: return "닫기"
            case .english: return "Close"
            case .japanese: return "閉じる"
            case .chinese: return "关闭"
            case .spanish: return "Cerrar"
            }
        case "blocked":
            switch language {
            case .korean: return "차단됨"
            case .english: return "Blocked"
            case .japanese: return "ブロック済み"
            case .chinese: return "已屏蔽"
            case .spanish: return "Bloqueado"
            }
        case "unblock":
            switch language {
            case .korean: return "차단 해제"
            case .english: return "Unblock"
            case .japanese: return "ブロック解除"
            case .chinese: return "解除屏蔽"
            case .spanish: return "Desbloquear"
            }
        case "unblock_friend":
            switch language {
            case .korean: return "친구 차단 해제"
            case .english: return "Unblock Friend"
            case .japanese: return "友だちのブロック解除"
            case .chinese: return "解除屏蔽朋友"
            case .spanish: return "Desbloquear amigo"
            }
        case "unblock_message":
            switch language {
            case .korean: return "%@님의 차단을 해제하시겠습니까?"
            case .english: return "Unblock %@?"
            case .japanese: return "%@のブロックを解除しますか？"
            case .chinese: return "确定解除对%@的屏蔽吗？"
            case .spanish: return "¿Desbloquear a %@?"
            }
        case "hidden_list":
            switch language {
            case .korean: return "숨김 목록"
            case .english: return "Hidden List"
            case .japanese: return "非表示リスト"
            case .chinese: return "隐藏列表"
            case .spanish: return "Lista de ocultos"
            }
        case "no_hidden_friends":
            switch language {
            case .korean: return "숨긴 친구가 없습니다"
            case .english: return "No Hidden Friends"
            case .japanese: return "非表示の友だちがいません"
            case .chinese: return "没有隐藏的朋友"
            case .spanish: return "No hay amigos ocultos"
            }
        case "hidden":
            switch language {
            case .korean: return "숨김"
            case .english: return "Hidden"
            case .japanese: return "非表示"
            case .chinese: return "已隐藏"
            case .spanish: return "Oculto"
            }
        case "unhide":
            switch language {
            case .korean: return "숨김 해제"
            case .english: return "Unhide"
            case .japanese: return "非表示解除"
            case .chinese: return "取消隐藏"
            case .spanish: return "Mostrar"
            }
        case "unhide_friend":
            switch language {
            case .korean: return "친구 숨김 해제"
            case .english: return "Unhide Friend"
            case .japanese: return "友だちの非表示解除"
            case .chinese: return "取消隐藏朋友"
            case .spanish: return "Mostrar amigo"
            }
        case "unhide_message":
            switch language {
            case .korean: return "%@님의 숨김을 해제하시겠습니까?"
            case .english: return "Unhide %@?"
            case .japanese: return "%@の非表示を解除しますか？"
            case .chinese: return "确定显示%@吗？"
            case .spanish: return "¿Mostrar a %@?"
            }
        case "add_friend_title":
            switch language {
            case .korean: return "친구 추가"
            case .english: return "Add Friend"
            case .japanese: return "友だち追加"
            case .chinese: return "添加朋友"
            case .spanish: return "Agregar amigo"
            }
        case "add_friend_message":
            switch language {
            case .korean: return "%@님을 친구로 추가하시겠습니까?"
            case .english: return "Add %@ as a friend?"
            case .japanese: return "%@を友だちに追加しますか？"
            case .chinese: return "确定添加%@为朋友吗？"
            case .spanish: return "¿Agregar a %@ como amigo?"
            }
        case "add":
            switch language {
            case .korean: return "추가"
            case .english: return "Add"
            case .japanese: return "追加"
            case .chinese: return "添加"
            case .spanish: return "Agregar"
            }
        case "favorites":
            switch language {
            case .korean: return "즐겨찾기"
            case .english: return "Favorites"
            case .japanese: return "お気に入り"
            case .chinese: return "收藏"
            case .spanish: return "Favoritos"
            }
        case "favorite":
            switch language {
            case .korean: return "즐겨찾기 추가"
            case .english: return "Add to Favorites"
            case .japanese: return "お気に入りに追加"
            case .chinese: return "添加到收藏"
            case .spanish: return "Agregar a favoritos"
            }
        case "unfavorite":
            switch language {
            case .korean: return "즐겨찾기 해제"
            case .english: return "Remove from Favorites"
            case .japanese: return "お気に入りから削除"
            case .chinese: return "从收藏中移除"
            case .spanish: return "Quitar de favoritos"
            }
        case "mute_notifications":
            switch language {
            case .korean: return "알림 끄기"
            case .english: return "Mute Notifications"
            case .japanese: return "通知をオフ"
            case .chinese: return "关闭通知"
            case .spanish: return "Silenciar notificaciones"
            }
        case "unmute_notifications":
            switch language {
            case .korean: return "알림 켜기"
            case .english: return "Unmute Notifications"
            case .japanese: return "通知をオン"
            case .chinese: return "开启通知"
            case .spanish: return "Activar notificaciones"
            }
        case "notifications_muted":
            switch language {
            case .korean: return "알림 꺼짐"
            case .english: return "Notifications Muted"
            case .japanese: return "通知オフ"
            case .chinese: return "通知已关闭"
            case .spanish: return "Notificaciones silenciadas"
            }
        case "notifications_enabled":
            switch language {
            case .korean: return "알림 켜짐"
            case .english: return "Notifications Enabled"
            case .japanese: return "通知オン"
            case .chinese: return "通知已开启"
            case .spanish: return "Notificaciones activadas"
            }
        case "send":
            switch language {
            case .korean: return "보내기"
            case .english: return "Send"
            case .japanese: return "送信"
            case .chinese: return "发送"
            case .spanish: return "Enviar"
            }
        case "add_caption":
            switch language {
            case .korean: return "설명을 추가하세요..."
            case .english: return "Add a caption..."
            case .japanese: return "キャプションを追加..."
            case .chinese: return "添加说明..."
            case .spanish: return "Agregar descripción..."
            }
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

    // Overload accepting LanguageManager.Language so call sites can pass currentLanguage directly
    static func text(_ key: String, _ language: LanguageManager.Language) -> String {
        let mapped: AppLanguage
        switch language {
        case .korean:            mapped = .korean
        case .english:           mapped = .english
        case .japanese:          mapped = .japanese
        case .chinese,
             .chineseTraditional: mapped = .chinese
        case .spanish:           mapped = .spanish
        }
        return text(key, mapped)
    }
}

/// Minimal protocol to read the current app language without importing the app's LanguageManager here.
/// Conform your LanguageManager to expose `currentLanguage` type `AppLanguage`.
public enum AppLanguage {
    case korean
    case english
    case japanese
    case chinese
    case spanish
}
