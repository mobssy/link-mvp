//  SettingsView+Main.swift
//  L!nkMVP
//
//  Restored main SettingsView definition so the existing extension compiles.

import SwiftUI
import UIKit
import SwiftData

struct SettingsView: View {
    @ObservedObject var authManager: AuthManager
    @EnvironmentObject private var languageManager: LanguageManager
    @Environment(\.modelContext) private var modelContext
    @AppStorage("themeMode") private var themeMode: String = "system"

    // These must be accessible from the extension in another file, so don't mark them private.
    @State var showingDeleteAlert = false
    @State var showingLogoutAlert = false

    // Sheets
    @State private var showingProfileEdit = false

    // App Lock
    @AppStorage("appLockEnabled") private var appLockEnabled = false

    // Notifications
    @StateObject private var notificationManager = NotificationManager()
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    // AI / Translation settings (shared via AppStorage across app)
    @AppStorage("aiSummaryEnabled") private var aiSummaryEnabled = false
    @AppStorage("aiSearchEnabled") private var aiSearchEnabled = true
    @AppStorage("aiAutoMeetingNotesEnabled") private var aiAutoMeetingNotesEnabled = false

    @AppStorage("translationEnabled") private var translationEnabled = false
    @AppStorage("translationAutoDetect") private var translationAutoDetect = true
    @AppStorage("translationTargetLanguage") private var translationTargetLanguage = "auto"
    @AppStorage("translationShowOriginal") private var translationShowOriginal = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ProfileCardView(
                        title: profileDisplayName().capitalized,
                        subtitle: authManager.currentUser?.statusMessage ?? languageManager.localize(ko: "테스트 모드로 체험 중입니다", en: "Experiencing in test mode", ja: "テストモードで体験中です", zh: "正在以测试模式体验", es: "Experimentando en modo de prueba"),
                        imageData: authManager.currentUser?.profileImageData,
                        action: { showingProfileEdit = true }
                    )

                    SettingsSectionCard(title: localizedText("settings")) {
                        SettingsToggleRow(
                            systemImage: "bell.fill",
                            tint: .green,
                            title: localizedText("notifications"),
                            isOn: $notificationsEnabled
                        )
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            ThemeSettingsView().environmentObject(languageManager)
                        } label: {
                            SettingsLinkRow(
                                systemImage: "paintpalette.fill",
                                tint: .orange,
                                title: languageManager.localize(ko: "테마", en: "Theme", ja: "テーマ", zh: "主题", es: "Tema")
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            LanguageSettingsView().environmentObject(languageManager)
                        } label: {
                            SettingsLinkRow(
                                systemImage: "globe",
                                tint: .blue,
                                title: localizedText("language_settings")
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            SecuritySettingsView().environmentObject(languageManager)
                        } label: {
                            SettingsLinkRow(
                                systemImage: "lock.fill",
                                tint: .purple,
                                title: localizedText("app_lock")
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            AISettingsView().environmentObject(languageManager)
                        } label: {
                            SettingsLinkRow(
                                systemImage: "sparkles",
                                tint: .pink,
                                title: localizedText("ai_features")
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            TranslationSettingsView().environmentObject(languageManager)
                        } label: {
                            SettingsLinkRow(
                                systemImage: "character.bubble",
                                tint: .teal,
                                title: localizedText("translation")
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            ContactsSettingsView().environmentObject(languageManager)
                        } label: {
                            SettingsLinkRow(
                                systemImage: "person.crop.circle.badge.plus",
                                tint: .green,
                                title: languageManager.localize(ko: "연락처", en: "Contacts", ja: "連絡先", zh: "通讯录", es: "Contactos")
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            AccessibilitySettingsView().environmentObject(languageManager)
                        } label: {
                            SettingsLinkRow(
                                systemImage: "accessibility",
                                tint: .indigo,
                                title: languageManager.localize(ko: "손쉬운 사용", en: "Accessibility", ja: "アクセシビリティ", zh: "辅助功能", es: "Accesibilidad")
                            )
                        }
                    }

                    SettingsSectionCard(title: languageManager.localize(ko: "정보", en: "Info", ja: "情報", zh: "信息", es: "Info")) {
                        NavigationLink {
                            HelpView().environmentObject(languageManager)
                        } label: {
                            SettingsLinkRow(
                                systemImage: "questionmark.circle.fill",
                                tint: .blue,
                                title: languageManager.localize(ko: "도움말", en: "Help", ja: "ヘルプ", zh: "帮助", es: "Ayuda")
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            AppInfoView().environmentObject(languageManager)
                        } label: {
                            SettingsLinkRow(
                                systemImage: "info.circle.fill",
                                tint: .blue,
                                title: languageManager.localize(ko: "앱 정보", en: "App Info", ja: "アプリ情報", zh: "应用信息", es: "Información de la app")
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            TermsPoliciesView().environmentObject(languageManager)
                        } label: {
                            SettingsLinkRow(
                                systemImage: "doc.text.fill",
                                tint: .blue,
                                title: languageManager.localize(ko: "약관 및 정책", en: "Terms & Policies", ja: "利用規約とポリシー", zh: "条款与政策", es: "Términos y políticas")
                            )
                        }
                    }
                    SettingsSectionCard(title: "") {
                        VStack(spacing: 0) {
                            Button(localizedText("delete_account"), role: .destructive) {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                showingDeleteAlert = true
                            }
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                            .padding(.vertical, 12)

                            Divider()
                                .frame(height: 0.5)
                                .overlay(Color(UIColor.separator))
                                .padding(.horizontal, 16)

                            Button(localizedText("logout")) {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                showingLogoutAlert = true
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                            .padding(.vertical, 12)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .sheet(isPresented: $showingProfileEdit) {
                ProfileEditView(authManager: authManager)
                    .environmentObject(languageManager)
            }
            // Alerts for destructive actions
            .alert(localizedText("delete_account"), isPresented: $showingDeleteAlert) {
                Button(localizedText("cancel"), role: .cancel) {}
                Button(localizedText("delete_account"), role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text(localizedText("delete_account_hint"))
            }
            .alert(localizedText("logout"), isPresented: $showingLogoutAlert) {
                Button(localizedText("cancel"), role: .cancel) {}
                Button(localizedText("logout")) {
                    authManager.currentUser = nil
                    authManager.isAuthenticated = false
                }
            } message: {
                Text(localizedText("logout_hint"))
            }
            .onChange(of: notificationsEnabled) { _, newValue in
                if !newValue {
                    notificationManager.clearAllNotifications()
                } else {
                    // 권한 재요청 (이미 허용된 경우 no-op)
                    Task {
                        await notificationManager.requestPermission()
                    }
                    // 읽지 않은 메시지 총합을 계산하여 배지 복원
                    let descriptor = FetchDescriptor<ChatRoom>()
                    let rooms = (try? modelContext.fetch(descriptor)) ?? []
                    let totalUnread = rooms.map { $0.unreadCount }.reduce(0, +)
                    notificationManager.updateBadgeCount(totalUnread)
                }
            }
            .navigationTitle(localizedText("settings"))
            .navigationBarTitleDisplayMode(.large)
        }
        .preferredColorScheme(themeMode == "light" ? .light : (themeMode == "dark" ? .dark : nil))
    }

    private var header: some View {
        Text(localizedText("settings"))
            .font(.system(size: 36, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }

    private var testModeBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "wrench.adjustable")
            Text(languageManager.localize(ko: "테스트 모드", en: "Test Mode", ja: "テストモード", zh: "测试模式", es: "Modo de prueba"))
        }
        .font(.footnote.weight(.semibold))
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .foregroundStyle(.white)
        .background(Capsule().fill(Color.orange))
        .shadow(color: Color.orange.opacity(0.3), radius: 8, y: 4)
        .padding(.trailing, 20)
        .padding(.top, 8)
    }

    private var bottomActionBar: some View {
        HStack(spacing: 24) {
            Button {
                showingDeleteAlert = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                    Text(localizedText("delete_account"))
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
            }
            .buttonStyle(.plain)

            Button {
                showingLogoutAlert = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text(localizedText("logout"))
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule(style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // Must be accessible from the extension file, so use internal access (default).
    func localizedText(_ key: String) -> String {
        switch key {
        // Common
        case "settings": return languageManager.localize(ko: "설정", en: "Settings", ja: "設定", zh: "设置", es: "Configuración")
        case "cancel": return languageManager.localize(ko: "취소", en: "Cancel", ja: "キャンセル", zh: "取消", es: "Cancelar")
        case "user": return languageManager.localize(ko: "사용자", en: "User", ja: "ユーザー", zh: "用户", es: "Usuario")

        // Profile
        case "profile": return languageManager.localize(ko: "프로필", en: "Profile", ja: "プロフィール", zh: "个人资料", es: "Perfil")

        // Language
        case "language": return languageManager.localize(ko: "언어", en: "Language", ja: "言語", zh: "语言", es: "Idioma")
        case "language_settings": return languageManager.localize(ko: "언어 설정", en: "Language Settings", ja: "言語設定", zh: "语言设置", es: "Configuración de idioma")

        // Security / App Lock
        case "security": return languageManager.localize(ko: "보안", en: "Security", ja: "セキュリティ", zh: "安全", es: "Seguridad")
        case "app_lock": return languageManager.localize(ko: "앱 잠금", en: "App Lock", ja: "アプリロック", zh: "应用锁定", es: "Bloqueo de aplicación")
        case "app_lock_hint": return languageManager.localize(ko: "앱을 열 때 Face ID/Touch ID 인증을 요구합니다", en: "Require Face ID/Touch ID to unlock the app", ja: "アプリを開く際にFace ID/Touch IDの認証が必要です", zh: "打开应用时需要Face ID/Touch ID验证", es: "Requiere Face ID/Touch ID para desbloquear la app")
        case "app_lock_title": return languageManager.localize(ko: "앱 잠금", en: "App Lock", ja: "アプリロック", zh: "应用锁定", es: "Bloqueo de aplicación")
        case "app_lock_desc": return languageManager.localize(ko: "앱을 열 때 Face ID/Touch ID 인증을 요구합니다", en: "Require Face ID/Touch ID to unlock the app", ja: "アプリを開く際にFace ID/Touch IDの認証が必要です", zh: "打开应用时需要Face ID/Touch ID验证", es: "Requiere Face ID/Touch ID para desbloquear la app")
        case "unlock_reason": return languageManager.localize(ko: "앱을 잠금 해제하려면 인증이 필요합니다", en: "Authentication is required to unlock the app", ja: "アプリのロックを解除するには認証が必要です", zh: "解锁应用需要进行身份验证", es: "Se requiere autenticación para desbloquear la app")

        // Notifications
        case "notifications": return languageManager.localize(ko: "알림", en: "Notifications", ja: "通知", zh: "通知", es: "Notificaciones")
        case "push_permission": return languageManager.localize(ko: "푸시 권한", en: "Push Permission", ja: "プッシュ権限", zh: "推送权限", es: "Permiso de notificaciones")
        case "granted": return languageManager.localize(ko: "허용됨", en: "Granted", ja: "許可済み", zh: "已允许", es: "Permitido")
        case "denied": return languageManager.localize(ko: "거부됨", en: "Denied", ja: "拒否済み", zh: "已拒绝", es: "Denegado")
        case "request_permission": return languageManager.localize(ko: "권한 요청", en: "Request Permission", ja: "権限をリクエスト", zh: "请求权限", es: "Solicitar permiso")

        // AI
        case "ai_features": return languageManager.localize(ko: "AI 기능", en: "AI Features", ja: "AI機能", zh: "AI功能", es: "Funciones de IA")
        case "ai_summary": return languageManager.localize(ko: "대화 요약", en: "Conversation Summary", ja: "会話要約", zh: "对话摘要", es: "Resumen de conversación")
        case "ai_search": return languageManager.localize(ko: "대화 검색", en: "Conversation Search", ja: "会話検索", zh: "对话搜索", es: "Búsqueda de conversación")
        case "ai_meeting_notes": return languageManager.localize(ko: "자동 회의 노트", en: "Auto Meeting Notes", ja: "自動会議メモ", zh: "自动会议记录", es: "Notas de reunión automáticas")

        // Translation
        case "translation": return languageManager.localize(ko: "번역", en: "Translation", ja: "翻訳", zh: "翻译", es: "Traducción")
        case "translation_footer": return languageManager.localize(ko: "언어 자동 감지 또는 대상 언어를 지정할 수 있습니다", en: "Enable auto-detect or choose a target language", ja: "言語の自動検出またはターゲット言語を指定できます", zh: "可以启用自动检测或指定目标语言", es: "Activa la detección automática o elige un idioma de destino")
        case "translation_enable": return languageManager.localize(ko: "번역 활성화", en: "Enable Translation", ja: "翻訳を有効にする", zh: "启用翻译", es: "Activar traducción")
        case "translation_auto_detect": return languageManager.localize(ko: "자동 감지", en: "Auto Detect", ja: "自動検出", zh: "自动检测", es: "Detección automática")
        case "translation_target": return languageManager.localize(ko: "대상 언어", en: "Target Language", ja: "ターゲット言語", zh: "目标语言", es: "Idioma de destino")
        case "translation_show_original": return languageManager.localize(ko: "원문 함께 표시", en: "Show Original", ja: "原文も表示", zh: "同时显示原文", es: "Mostrar original")
        case "auto": return languageManager.localize(ko: "자동", en: "Auto", ja: "自動", zh: "自动", es: "Automático")

        // Destructive
        case "delete_account": return languageManager.localize(ko: "계정 삭제", en: "Delete Account", ja: "アカウントを削除", zh: "删除账户", es: "Eliminar cuenta")
        case "delete_account_hint": return languageManager.localize(ko: "계정을 영구적으로 삭제합니다.", en: "Permanently delete your account.", ja: "アカウントを完全に削除します。", zh: "将永久删除您的账户。", es: "Elimina tu cuenta de forma permanente.")
        case "logout": return languageManager.localize(ko: "로그아웃", en: "Sign Out", ja: "ログアウト", zh: "退出登录", es: "Cerrar sesión")
        case "logout_hint": return languageManager.localize(ko: "현재 계정에서 로그아웃합니다.", en: "Sign out of your current account.", ja: "現在のアカウントからログアウトします。", zh: "从当前账户退出登录。", es: "Cierra sesión de tu cuenta actual.")

        default:
            // 디버깅을 위해 키가 정의되지 않은 경우를 확인
            print("⚠️ SettingsView: 키 '\(key)'가 정의되지 않음")
            return key
        }
    }

    private func profileDisplayName() -> String {
        let raw = (authManager.currentUser?.displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            return languageManager.localize(ko: "사용자", en: "User", ja: "ユーザー", zh: "用户", es: "Usuario")
        }
        if raw == "테스터" || raw == "Tester" {
            return languageManager.localize(ko: "테스터", en: "Tester", ja: "テスター", zh: "测试员", es: "Tester")
        }
        return raw
    }

    private func languageDisplayName() -> String {
        switch languageManager.currentLanguage {
        case .korean: return "한국어"
        case .english: return "English"
        case .japanese: return "日本語"
        case .chinese: return "中文"
        case .spanish: return "Español"
        case .chineseTraditional:
            <#code#>
        }
    }

    private func notificationFooterText() -> String {
        return languageManager.localize(
            ko: "알림 권한은 기기 설정에서 변경할 수 있습니다",
            en: "You can change notification permissions in the device Settings",
            ja: "通知権限はデバイスの設定から変更できます",
            zh: "您可以在设备设置中更改通知权限",
            es: "Puedes cambiar los permisos de notificación en la configuración del dispositivo"
        )
    }

    private func deleteAccount() {
        // Delete all user data from SwiftData
        do {
            // Delete all messages
            let messageDescriptor = FetchDescriptor<Message>()
            let messages = try modelContext.fetch(messageDescriptor)
            for message in messages {
                modelContext.delete(message)
            }

            // Delete all chat rooms
            let chatRoomDescriptor = FetchDescriptor<ChatRoom>()
            let chatRooms = try modelContext.fetch(chatRoomDescriptor)
            for chatRoom in chatRooms {
                modelContext.delete(chatRoom)
            }

            // Delete all friendships
            let friendshipDescriptor = FetchDescriptor<Friendship>()
            let friendships = try modelContext.fetch(friendshipDescriptor)
            for friendship in friendships {
                modelContext.delete(friendship)
            }

            // Delete all users except current user (or delete all if desired)
            let userDescriptor = FetchDescriptor<User>()
            let users = try modelContext.fetch(userDescriptor)
            for user in users {
                modelContext.delete(user)
            }

            // Save the deletion
            try modelContext.save()

            // Sign out
            authManager.currentUser = nil
            authManager.isAuthenticated = false

            print("✅ [SettingsView] Account and all data deleted successfully")
        } catch {
            print("❌ [SettingsView] Failed to delete account: \(error)")
        }
    }
}
