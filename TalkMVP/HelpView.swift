import SwiftUI
import MessageUI

struct HelpView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingSupportSheet = false
    @State private var showingMailComposer = false
    @State private var expandedSections: Set<String> = []

    // MARK: - FAQ Categories
    enum FAQCategory: String, CaseIterable {
        case gettingStarted
        case messaging
        case friends
        case notifications
        case accountSettings
        case troubleshooting

        func title(languageManager: LanguageManager) -> String {
            switch self {
            case .gettingStarted: return languageManager.localize(ko: "시작하기", en: "Getting Started", ja: "はじめに", zh: "入门指南", es: "Primeros pasos")
            case .messaging: return languageManager.localize(ko: "메시지", en: "Messaging", ja: "メッセージ", zh: "消息", es: "Mensajería")
            case .friends: return languageManager.localize(ko: "친구", en: "Friends", ja: "友だち", zh: "朋友", es: "Amigos")
            case .notifications: return languageManager.localize(ko: "알림", en: "Notifications", ja: "通知", zh: "通知", es: "Notificaciones")
            case .accountSettings: return languageManager.localize(ko: "계정 및 설정", en: "Account & Settings", ja: "アカウントと設定", zh: "账户与设置", es: "Cuenta y ajustes")
            case .troubleshooting: return languageManager.localize(ko: "문제 해결", en: "Troubleshooting", ja: "トラブルシューティング", zh: "故障排除", es: "Solución de problemas")
            }
        }

        func icon() -> String {
            switch self {
            case .gettingStarted: return "star.fill"
            case .messaging: return "message.fill"
            case .friends: return "person.2.fill"
            case .notifications: return "bell.fill"
            case .accountSettings: return "gearshape.fill"
            case .troubleshooting: return "wrench.and.screwdriver.fill"
            }
        }
    }

    struct FAQItem: Identifiable {
        let id = UUID()
        let category: FAQCategory
        let questionKey: String
        let answerKeys: [String]
    }

    private var allFAQs: [FAQItem] {
        [
            // Getting Started
            FAQItem(category: .gettingStarted, questionKey: "faq_first_steps_q", answerKeys: ["faq_first_steps_a1", "faq_first_steps_a2", "faq_first_steps_a3"]),
            FAQItem(category: .gettingStarted, questionKey: "faq_profile_setup_q", answerKeys: ["faq_profile_setup_a"]),

            // Messaging
            FAQItem(category: .messaging, questionKey: "faq_msg_not_sending_q", answerKeys: ["faq_msg_not_sending_a1", "faq_msg_not_sending_a2"]),
            FAQItem(category: .messaging, questionKey: "faq_send_photos_q", answerKeys: ["faq_send_photos_a"]),
            FAQItem(category: .messaging, questionKey: "faq_delete_msg_q", answerKeys: ["faq_delete_msg_a"]),
            FAQItem(category: .messaging, questionKey: "faq_search_msg_q", answerKeys: ["faq_search_msg_a"]),

            // Friends
            FAQItem(category: .friends, questionKey: "faq_how_to_add_friend_q", answerKeys: ["faq_how_to_add_friend_a"]),
            FAQItem(category: .friends, questionKey: "faq_block_friend_q", answerKeys: ["faq_block_friend_a"]),
            FAQItem(category: .friends, questionKey: "faq_favorite_friend_q", answerKeys: ["faq_favorite_friend_a"]),

            // Notifications
            FAQItem(category: .notifications, questionKey: "faq_notifs_not_coming_q", answerKeys: ["faq_notifs_not_coming_a1", "faq_notifs_not_coming_a2"]),
            FAQItem(category: .notifications, questionKey: "faq_mute_chat_q", answerKeys: ["faq_mute_chat_a"]),

            // Account & Settings
            FAQItem(category: .accountSettings, questionKey: "faq_change_language_q", answerKeys: ["faq_change_language_a"]),
            FAQItem(category: .accountSettings, questionKey: "faq_change_theme_q", answerKeys: ["faq_change_theme_a"]),
            FAQItem(category: .accountSettings, questionKey: "faq_forgot_password_q", answerKeys: ["faq_forgot_password_a1", "faq_forgot_password_a2"]),
            FAQItem(category: .accountSettings, questionKey: "faq_delete_account_q", answerKeys: ["faq_delete_account_a1", "faq_delete_account_a2"]),

            // Troubleshooting
            FAQItem(category: .troubleshooting, questionKey: "faq_app_slow_q", answerKeys: ["faq_app_slow_a1", "faq_app_slow_a2"]),
            FAQItem(category: .troubleshooting, questionKey: "faq_crash_q", answerKeys: ["faq_crash_a"]),
        ]
    }

    private func localizedText(_ key: String) -> String {
        switch key {
        // General
        case "help": return languageManager.localize(ko: "도움말", en: "Help", ja: "ヘルプ", zh: "帮助", es: "Ayuda")
        case "faqs": return languageManager.localize(ko: "자주 묻는 질문", en: "FAQs", ja: "よくある質問", zh: "常见问题", es: "Preguntas frecuentes")
        case "contact_support": return languageManager.localize(ko: "지원 문의", en: "Contact Support", ja: "サポートへのお問い合わせ", zh: "联系支持", es: "Contactar soporte")
        case "send_feedback": return languageManager.localize(ko: "피드백 보내기", en: "Send Feedback", ja: "フィードバックを送る", zh: "发送反馈", es: "Enviar comentarios")
        case "email_support": return languageManager.localize(ko: "이메일로 문의하기", en: "Email Support", ja: "メールでのお問い合わせ", zh: "邮件支持", es: "Soporte por correo")
        case "app_version": return languageManager.localize(ko: "앱 버전", en: "App Version", ja: "アプリバージョン", zh: "应用版本", es: "Versión de la app")
        case "quick_guides": return languageManager.localize(ko: "빠른 가이드", en: "Quick Guides", ja: "クイックガイド", zh: "快速指南", es: "Guías rápidas")
        case "tips_tricks": return languageManager.localize(ko: "유용한 팁", en: "Tips & Tricks", ja: "ヒントとコツ", zh: "技巧提示", es: "Consejos y trucos")

        // Getting Started
        case "faq_first_steps_q": return languageManager.localize(ko: "앱을 처음 사용해요. 어떻게 시작하나요?", en: "I'm new to the app. How do I get started?", ja: "アプリを初めて使います。どうすれば始められますか？", zh: "我是新用户，如何开始使用？", es: "Soy nuevo en la app. ¿Cómo empiezo?")
        case "faq_first_steps_a1": return languageManager.localize(ko: "1. 프로필을 설정하세요 (이름, 프로필 사진)", en: "1. Set up your profile (name, photo)", ja: "1. プロフィールを設定します（名前、写真）", zh: "1. 设置您的资料（姓名、照片）", es: "1. Configura tu perfil (nombre, foto)")
        case "faq_first_steps_a2": return languageManager.localize(ko: "2. 친구 탭에서 친구를 추가하세요", en: "2. Add friends from the Friends tab", ja: "2. 友だちタブから友だちを追加します", zh: "2. 在朋友标签页添加朋友", es: "2. Agrega amigos desde la pestaña Amigos")
        case "faq_first_steps_a3": return languageManager.localize(ko: "3. 채팅 탭에서 대화를 시작하세요", en: "3. Start chatting from the Chats tab", ja: "3. チャットタブでチャットを始めます", zh: "3. 在聊天标签页开始聊天", es: "3. Empieza a chatear desde la pestaña Chats")
        case "faq_profile_setup_q": return languageManager.localize(ko: "프로필을 어떻게 설정하나요?", en: "How do I set up my profile?", ja: "プロフィールはどう設定しますか？", zh: "如何设置我的资料？", es: "¿Cómo configuro mi perfil?")
        case "faq_profile_setup_a": return languageManager.localize(ko: "친구 탭 → 내 프로필을 탭하면 이름, 상태 메시지, 프로필 사진을 변경할 수 있습니다.", en: "Tap your profile in the Friends tab to change your name, status message, and profile photo.", ja: "友だちタブでプロフィールをタップすると、名前・ステータスメッセージ・写真を変更できます。", zh: "在朋友标签页点击您的资料，即可更改姓名、状态消息和头像。", es: "Toca tu perfil en la pestaña Amigos para cambiar tu nombre, mensaje de estado y foto.")

        // Messaging
        case "faq_msg_not_sending_q": return languageManager.localize(ko: "메시지가 전송되지 않아요", en: "Messages aren't sending", ja: "メッセージが送信されません", zh: "消息发送不出去", es: "Los mensajes no se envían")
        case "faq_msg_not_sending_a1": return languageManager.localize(ko: "네트워크 연결을 확인하세요 (Wi-Fi 또는 데이터)", en: "Check your network connection (Wi-Fi or cellular data)", ja: "ネットワーク接続を確認してください（Wi-Fiまたはデータ）", zh: "检查您的网络连接（Wi-Fi或移动数据）", es: "Verifica tu conexión de red (Wi-Fi o datos móviles)")
        case "faq_msg_not_sending_a2": return languageManager.localize(ko: "앱을 다시 시작해보세요", en: "Try restarting the app", ja: "アプリを再起動してみてください", zh: "尝试重新启动应用", es: "Intenta reiniciar la app")
        case "faq_send_photos_q": return languageManager.localize(ko: "사진/동영상을 어떻게 보내나요?", en: "How do I send photos/videos?", ja: "写真・動画はどう送りますか？", zh: "如何发送照片/视频？", es: "¿Cómo envío fotos/videos?")
        case "faq_send_photos_a": return languageManager.localize(ko: "채팅 입력창 왼쪽의 + 버튼을 눌러 사진/동영상을 선택하세요.", en: "Tap the + button on the left of the message input to select photos/videos.", ja: "メッセージ入力欄の左側の＋ボタンをタップして写真・動画を選択してください。", zh: "点击消息输入框左侧的+按钮选择照片/视频。", es: "Toca el botón + a la izquierda del campo de mensaje para seleccionar fotos/videos.")
        case "faq_delete_msg_q": return languageManager.localize(ko: "보낸 메시지를 삭제할 수 있나요?", en: "Can I delete sent messages?", ja: "送信したメッセージを削除できますか？", zh: "可以删除已发送的消息吗？", es: "¿Puedo eliminar mensajes enviados?")
        case "faq_delete_msg_a": return languageManager.localize(ko: "메시지를 길게 눌러 '삭제'를 선택하세요. 자신이 보낸 메시지만 삭제할 수 있습니다.", en: "Long press a message and select 'Delete'. You can only delete your own messages.", ja: "メッセージを長押しして「削除」を選択してください。自分が送ったメッセージのみ削除できます。", zh: "长按消息并选择「删除」。您只能删除自己发送的消息。", es: "Mantén presionado un mensaje y selecciona 'Eliminar'. Solo puedes eliminar tus propios mensajes.")
        case "faq_search_msg_q": return languageManager.localize(ko: "이전 메시지를 검색하려면?", en: "How do I search previous messages?", ja: "過去のメッセージを検索するには？", zh: "如何搜索以前的消息？", es: "¿Cómo busco mensajes anteriores?")
        case "faq_search_msg_a": return languageManager.localize(ko: "채팅방 상단의 검색 아이콘을 탭하여 키워드로 검색하세요.", en: "Tap the search icon at the top of the chat to search by keyword.", ja: "チャット上部の検索アイコンをタップしてキーワードで検索してください。", zh: "点击聊天顶部的搜索图标，按关键词搜索。", es: "Toca el ícono de búsqueda en la parte superior del chat para buscar por palabra clave.")

        // Friends
        case "faq_how_to_add_friend_q": return languageManager.localize(ko: "친구를 추가하려면?", en: "How do I add friends?", ja: "友だちを追加するには？", zh: "如何添加朋友？", es: "¿Cómo agrego amigos?")
        case "faq_how_to_add_friend_a": return languageManager.localize(ko: "친구 탭 → + 버튼 → 이메일로 검색하여 친구 요청을 보내세요.", en: "Friends tab → + button → Search by email and send a friend request.", ja: "友だちタブ → ＋ボタン → メールで検索して友だちリクエストを送ってください。", zh: "朋友标签页 → +按钮 → 按邮箱搜索并发送好友请求。", es: "Pestaña Amigos → botón + → Busca por correo y envía una solicitud de amistad.")
        case "faq_block_friend_q": return languageManager.localize(ko: "친구를 차단하려면?", en: "How do I block a friend?", ja: "友だちをブロックするには？", zh: "如何屏蔽朋友？", es: "¿Cómo bloqueo a un amigo?")
        case "faq_block_friend_a": return languageManager.localize(ko: "친구 목록에서 친구를 왼쪽으로 스와이프하여 '차단'을 선택하세요.", en: "Swipe left on a friend in the list and select 'Block'.", ja: "リストの友だちを左にスワイプして「ブロック」を選択してください。", zh: "在列表中左滑好友，选择「屏蔽」。", es: "Desliza hacia la izquierda sobre un amigo en la lista y selecciona 'Bloquear'.")
        case "faq_favorite_friend_q": return languageManager.localize(ko: "즐겨찾기 친구는 무엇인가요?", en: "What are favorite friends?", ja: "お気に入りの友だちとは？", zh: "什么是收藏好友？", es: "¿Qué son los amigos favoritos?")
        case "faq_favorite_friend_a": return languageManager.localize(ko: "친구를 오른쪽으로 스와이프하여 별표를 추가하면 즐겨찾기 섹션에 표시됩니다.", en: "Swipe right on a friend and add a star to show them in the favorites section.", ja: "友だちを右にスワイプして星を追加するとお気に入りセクションに表示されます。", zh: "右滑好友并添加星标，即可显示在收藏区域。", es: "Desliza hacia la derecha sobre un amigo y agrega una estrella para mostrarlo en la sección de favoritos.")

        // Notifications
        case "faq_notifs_not_coming_q": return languageManager.localize(ko: "알림이 오지 않아요", en: "I'm not receiving notifications", ja: "通知が届きません", zh: "收不到通知", es: "No recibo notificaciones")
        case "faq_notifs_not_coming_a1": return languageManager.localize(ko: "설정 → 알림에서 TalkMVP 알림이 허용되어 있는지 확인하세요.", en: "Check Settings → Notifications and ensure TalkMVP notifications are enabled.", ja: "設定 → 通知でTalkMVPの通知が許可されているか確認してください。", zh: "检查设置 → 通知，确保TalkMVP的通知已启用。", es: "Verifica en Ajustes → Notificaciones que las notificaciones de TalkMVP estén activadas.")
        case "faq_notifs_not_coming_a2": return languageManager.localize(ko: "집중 모드나 방해 금지 모드를 확인하세요.", en: "Check Focus mode or Do Not Disturb settings.", ja: "集中モードまたはおやすみモードを確認してください。", zh: "检查专注模式或勿扰模式设置。", es: "Verifica el modo Concentración o No molestar.")
        case "faq_mute_chat_q": return languageManager.localize(ko: "특정 채팅방 알림을 끄려면?", en: "How do I mute a specific chat?", ja: "特定のチャットの通知をオフにするには？", zh: "如何关闭特定聊天的通知？", es: "¿Cómo silencio un chat específico?")
        case "faq_mute_chat_a": return languageManager.localize(ko: "채팅방 우측 상단의 종 아이콘을 탭하여 알림을 끄거나 켤 수 있습니다.", en: "Tap the bell icon at the top right of the chat to toggle notifications.", ja: "チャット右上のベルアイコンをタップして通知のオン・オフを切り替えてください。", zh: "点击聊天右上角的铃铛图标来切换通知。", es: "Toca el ícono de campana en la parte superior derecha del chat para activar o desactivar notificaciones.")

        // Account & Settings
        case "faq_change_language_q": return languageManager.localize(ko: "언어를 변경하려면?", en: "How do I change the language?", ja: "言語を変更するには？", zh: "如何更改语言？", es: "¿Cómo cambio el idioma?")
        case "faq_change_language_a": return languageManager.localize(ko: "설정 → 언어 설정에서 한국어/English를 선택하세요.", en: "Settings → Language Settings → Select your preferred language.", ja: "設定 → 言語設定でお好みの言語を選択してください。", zh: "设置 → 语言设置 → 选择您偏好的语言。", es: "Ajustes → Configuración de idioma → Selecciona tu idioma preferido.")
        case "faq_change_theme_q": return languageManager.localize(ko: "테마를 변경하려면?", en: "How do I change the theme?", ja: "テーマを変更するには？", zh: "如何更改主题？", es: "¿Cómo cambio el tema?")
        case "faq_change_theme_a": return languageManager.localize(ko: "설정 → 테마에서 라이트/다크/시스템 모드를 선택하세요.", en: "Settings → Theme → Select Light/Dark/System mode.", ja: "設定 → テーマでライト/ダーク/システムモードを選択してください。", zh: "设置 → 主题 → 选择亮色/暗色/系统模式。", es: "Ajustes → Tema → Selecciona modo Claro/Oscuro/Sistema.")
        case "faq_forgot_password_q": return languageManager.localize(ko: "비밀번호를 잊었어요", en: "I forgot my password", ja: "パスワードを忘れました", zh: "我忘记了密码", es: "Olvidé mi contraseña")
        case "faq_forgot_password_a1": return languageManager.localize(ko: "로그인 화면에서 '비밀번호 재설정'을 선택하세요.", en: "Select 'Reset Password' on the login screen.", ja: "ログイン画面で「パスワードのリセット」を選択してください。", zh: "在登录屏幕选择「重置密码」。", es: "Selecciona 'Restablecer contraseña' en la pantalla de inicio de sesión.")
        case "faq_forgot_password_a2": return languageManager.localize(ko: "등록된 이메일로 재설정 링크가 전송됩니다.", en: "A reset link will be sent to your registered email.", ja: "登録済みのメールアドレスにリセットリンクが送信されます。", zh: "重置链接将发送到您的注册邮箱。", es: "Se enviará un enlace de restablecimiento a tu correo registrado.")
        case "faq_delete_account_q": return languageManager.localize(ko: "계정을 삭제하려면?", en: "How do I delete my account?", ja: "アカウントを削除するには？", zh: "如何删除我的账户？", es: "¿Cómo elimino mi cuenta?")
        case "faq_delete_account_a1": return languageManager.localize(ko: "설정 → 계정 삭제를 선택하세요.", en: "Settings → Delete Account.", ja: "設定 → アカウントの削除を選択してください。", zh: "设置 → 删除账户。", es: "Ajustes → Eliminar cuenta.")
        case "faq_delete_account_a2": return languageManager.localize(ko: "⚠️ 삭제된 계정은 복구할 수 없으며, 모든 대화 내용이 영구 삭제됩니다.", en: "⚠️ Deleted accounts cannot be recovered, and all conversations are permanently deleted.", ja: "⚠️ 削除されたアカウントは復元できず、すべての会話が完全に削除されます。", zh: "⚠️ 已删除的账户无法恢复，所有对话将被永久删除。", es: "⚠️ Las cuentas eliminadas no se pueden recuperar y todas las conversaciones se eliminan permanentemente.")

        // Troubleshooting
        case "faq_app_slow_q": return languageManager.localize(ko: "앱이 느려요", en: "The app is slow", ja: "アプリが遅いです", zh: "应用运行缓慢", es: "La app va lenta")
        case "faq_app_slow_a1": return languageManager.localize(ko: "앱을 완전히 종료한 후 다시 실행해보세요.", en: "Force quit the app and restart it.", ja: "アプリを完全に終了してから再起動してください。", zh: "强制退出应用并重新启动。", es: "Fuerza el cierre de la app y reiníciala.")
        case "faq_app_slow_a2": return languageManager.localize(ko: "기기를 재시작해보세요.", en: "Restart your device.", ja: "デバイスを再起動してください。", zh: "重启您的设备。", es: "Reinicia tu dispositivo.")
        case "faq_crash_q": return languageManager.localize(ko: "앱이 자주 종료돼요", en: "The app crashes frequently", ja: "アプリが頻繁に落ちます", zh: "应用经常崩溃", es: "La app se cierra con frecuencia")
        case "faq_crash_a": return languageManager.localize(ko: "최신 버전으로 업데이트했는지 확인하세요. 문제가 지속되면 지원팀에 문의하세요.", en: "Make sure you're on the latest version. If the problem persists, contact support.", ja: "最新バージョンに更新されているか確認してください。問題が続く場合はサポートにお問い合わせください。", zh: "确保您使用的是最新版本。如果问题持续，请联系支持。", es: "Asegúrate de tener la última versión. Si el problema persiste, contacta al soporte.")

        // Quick Guides
        case "guide_reactions": return languageManager.localize(ko: "반응 추가하기", en: "Add Reactions", ja: "リアクションを追加", zh: "添加反应", es: "Agregar reacciones")
        case "guide_reactions_desc": return languageManager.localize(ko: "메시지를 길게 눌러 이모지 반응을 추가할 수 있습니다.", en: "Long press a message to add emoji reactions.", ja: "メッセージを長押しして絵文字リアクションを追加できます。", zh: "长按消息可添加表情反应。", es: "Mantén presionado un mensaje para agregar reacciones de emoji.")
        case "guide_reply": return languageManager.localize(ko: "답장하기", en: "Reply to Messages", ja: "返信する", zh: "回复消息", es: "Responder mensajes")
        case "guide_reply_desc": return languageManager.localize(ko: "메시지를 왼쪽으로 스와이프하여 답장할 수 있습니다.", en: "Swipe left on a message to reply.", ja: "メッセージを左にスワイプして返信できます。", zh: "左滑消息即可回复。", es: "Desliza hacia la izquierda un mensaje para responder.")
        case "guide_translation": return languageManager.localize(ko: "메시지 번역", en: "Message Translation", ja: "メッセージ翻訳", zh: "消息翻译", es: "Traducción de mensajes")
        case "guide_translation_desc": return languageManager.localize(ko: "설정 → 번역에서 자동 번역을 활성화하세요.", en: "Enable auto-translation in Settings → Translation.", ja: "設定 → 翻訳で自動翻訳を有効にしてください。", zh: "在设置 → 翻译中启用自动翻译。", es: "Activa la traducción automática en Ajustes → Traducción.")

        default: return key
        }
    }

    private func faqsByCategory(_ category: FAQCategory) -> [FAQItem] {
        allFAQs.filter { $0.category == category }
    }

    var body: some View {
        List {
            // Quick Guides Section
            Section {
                QuickGuideRow(
                    icon: "hand.tap.fill",
                    title: localizedText("guide_reactions"),
                    description: localizedText("guide_reactions_desc")
                )
                QuickGuideRow(
                    icon: "arrowshape.turn.up.left.fill",
                    title: localizedText("guide_reply"),
                    description: localizedText("guide_reply_desc")
                )
                QuickGuideRow(
                    icon: "character.bubble.fill",
                    title: localizedText("guide_translation"),
                    description: localizedText("guide_translation_desc")
                )
            } header: {
                Text(localizedText("quick_guides"))
            }

            // FAQ Categories
            Section {
                ForEach(FAQCategory.allCases, id: \.self) { category in
                    FAQCategoryView(
                        category: category,
                        faqs: faqsByCategory(category),
                        isExpanded: expandedSections.contains(category.rawValue),
                        localizedText: localizedText,
                        languageManager: languageManager
                    ) {
                        toggleSection(category.rawValue)
                    }
                }
            } header: {
                Text(localizedText("faqs"))
            }

            // Support Section
            Section {
                Button {
                    sendEmail()
                } label: {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.appPrimary)
                        Text(localizedText("email_support"))
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }

                Button {
                    showingSupportSheet = true
                } label: {
                    HStack {
                        Image(systemName: "message.fill")
                            .foregroundColor(.appPrimary)
                        Text(localizedText("send_feedback"))
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            } header: {
                Text(localizedText("contact_support"))
            }

            // App Version
            Section {
                HStack {
                    Text(localizedText("app_version"))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(getAppVersion())
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(localizedText("help"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingSupportSheet) {
            FeedbackView()
                .environmentObject(languageManager)
        }
    }

    private func toggleSection(_ sectionId: String) {
        if expandedSections.contains(sectionId) {
            expandedSections.remove(sectionId)
        } else {
            expandedSections.insert(sectionId)
        }
    }

    private func sendEmail() {
        let email = "support@linkmvp.com"
        let subject = languageManager.localize(
            ko: "TalkMVP 지원 요청",
            en: "TalkMVP Support Request",
            ja: "TalkMVP サポートリクエスト",
            zh: "TalkMVP 支持请求",
            es: "Solicitud de soporte TalkMVP"
        )
        let body = languageManager.localize(
            ko: "문의 내용을 입력해주세요:\n\n앱 버전: \(getAppVersion())",
            en: "Please describe your issue:\n\nApp Version: \(getAppVersion())",
            ja: "お問い合わせ内容を入力してください:\n\nアプリバージョン: \(getAppVersion())",
            zh: "请输入您的问题:\n\n应用版本: \(getAppVersion())",
            es: "Por favor describe tu problema:\n\nVersión de la app: \(getAppVersion())"
        )

        let urlString = "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    private func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Quick Guide Row
struct QuickGuideRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.appPrimary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - FAQ Category View
struct FAQCategoryView: View {
    let category: HelpView.FAQCategory
    let faqs: [HelpView.FAQItem]
    let isExpanded: Bool
    let localizedText: (String) -> String
    let languageManager: LanguageManager
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Image(systemName: category.icon())
                        .foregroundColor(.appPrimary)
                        .frame(width: 24)

                    Text(category.title(languageManager: languageManager))
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(faqs) { faq in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Q. \(localizedText(faq.questionKey))")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            ForEach(faq.answerKeys, id: \.self) { answerKey in
                                Text("• \(localizedText(answerKey))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.leading, 36)

                        if faq.id != faqs.last?.id {
                            Divider()
                                .padding(.leading, 36)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Feedback View
struct FeedbackView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackText = ""
    @State private var showingConfirmation = false

    private func localizedText(_ key: String) -> String {
        switch key {
        case "send_feedback": return languageManager.localize(ko: "피드백 보내기", en: "Send Feedback", ja: "フィードバックを送る", zh: "发送反馈", es: "Enviar comentarios")
        case "feedback_placeholder": return languageManager.localize(ko: "의견을 들려주세요...", en: "Share your feedback...", ja: "ご意見をお聞かせください...", zh: "请分享您的反馈...", es: "Comparte tus comentarios...")
        case "send": return languageManager.localize(ko: "보내기", en: "Send", ja: "送信", zh: "发送", es: "Enviar")
        case "cancel": return languageManager.localize(ko: "취소", en: "Cancel", ja: "キャンセル", zh: "取消", es: "Cancelar")
        case "feedback_sent": return languageManager.localize(ko: "피드백 전송 완료", en: "Feedback Sent", ja: "フィードバック送信完了", zh: "反馈已发送", es: "Comentarios enviados")
        case "feedback_thanks": return languageManager.localize(ko: "소중한 의견 감사합니다!", en: "Thank you for your feedback!", ja: "貴重なご意見ありがとうございます！", zh: "感谢您的宝贵反馈！", es: "¡Gracias por tus comentarios!")
        case "ok": return languageManager.localize(ko: "확인", en: "OK", ja: "OK", zh: "确认", es: "Aceptar")
        default: return key
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextEditor(text: $feedbackText)
                    .padding()
                    .overlay(alignment: .topLeading) {
                        if feedbackText.isEmpty {
                            Text(localizedText("feedback_placeholder"))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 24)
                                .allowsHitTesting(false)
                        }
                    }

                Spacer()
            }
            .navigationTitle(localizedText("send_feedback"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedText("cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizedText("send")) {
                        sendFeedback()
                    }
                    .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert(localizedText("feedback_sent"), isPresented: $showingConfirmation) {
                Button(localizedText("ok")) {
                    dismiss()
                }
            } message: {
                Text(localizedText("feedback_thanks"))
            }
        }
    }

    private func sendFeedback() {
        // TODO: Implement actual feedback submission to backend
        print("📝 Feedback submitted: \(feedbackText)")
        showingConfirmation = true
    }
}

#Preview {
    NavigationStack {
        HelpView()
            .environmentObject(LanguageManager())
    }
}
