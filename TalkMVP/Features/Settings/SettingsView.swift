//
//  SettingsView.swift
//  TalkMVP
//
//  Main settings screen: profile card, preference links and account actions.

import SwiftUI
import UIKit
import SwiftData
import os

private let settingsLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "SettingsView")

struct SettingsView: View {
    var authManager: AuthManager
    @Environment(LanguageManager.self) private var languageManager
    @Environment(\.modelContext) private var modelContext
    @AppStorage("themeMode") private var themeMode: String = "system"

    @State private var showingDeleteAlert = false
    @State private var showingLogoutAlert = false

    // Sheets
    @State private var showingProfileEdit = false

    // Notifications
    @State private var notificationManager = NotificationManager()
    @AppStorage(NotificationPreferences.enabledKey) private var notificationsEnabled = true

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

                    SettingsSectionCard {
                        SettingsToggleRow(
                            systemImage: "bell.fill",
                            tint: .green,
                            title: localizedText("notifications"),
                            isOn: $notificationsEnabled
                        )
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            ThemeSettingsView().environment(languageManager)
                        } label: {
                            SettingsLinkRow(
                                systemImage: "paintpalette.fill",
                                tint: .orange,
                                title: languageManager.localize(ko: "테마", en: "Theme", ja: "テーマ", zh: "主题", es: "Tema")
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            LanguageSettingsView().environment(languageManager)
                        } label: {
                            SettingsLinkRow(
                                systemImage: "globe",
                                tint: .blue,
                                title: localizedText("language")
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            SecuritySettingsView().environment(languageManager)
                        } label: {
                            SettingsLinkRow(
                                systemImage: "lock.fill",
                                tint: .purple,
                                title: localizedText("app_lock")
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            AISettingsView().environment(languageManager)
                        } label: {
                            SettingsLinkRow(
                                systemImage: "sparkles",
                                tint: .pink,
                                title: localizedText("ai_features")
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            TranslationSettingsView().environment(languageManager)
                        } label: {
                            SettingsLinkRow(
                                systemImage: "character.bubble",
                                tint: .teal,
                                title: localizedText("translation")
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            ContactsSettingsView().environment(languageManager)
                        } label: {
                            SettingsLinkRow(
                                systemImage: "person.crop.circle.badge.plus",
                                tint: .green,
                                title: languageManager.localize(ko: "연락처", en: "Contacts", ja: "連絡先", zh: "通讯录", es: "Contactos")
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            AccessibilitySettingsView().environment(languageManager)
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
                            HelpView().environment(languageManager)
                        } label: {
                            SettingsLinkRow(
                                systemImage: "questionmark.circle.fill",
                                tint: .blue,
                                title: languageManager.localize(ko: "도움말", en: "Help", ja: "ヘルプ", zh: "帮助", es: "Ayuda")
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            AppInfoView().environment(languageManager)
                        } label: {
                            SettingsLinkRow(
                                systemImage: "info.circle.fill",
                                tint: .blue,
                                title: languageManager.localize(ko: "앱 정보", en: "App Info", ja: "アプリ情報", zh: "应用信息", es: "Información de la app")
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            TermsPoliciesView().environment(languageManager)
                        } label: {
                            SettingsLinkRow(
                                systemImage: "doc.text.fill",
                                tint: .blue,
                                title: languageManager.localize(ko: "약관 및 정책", en: "Terms & Policies", ja: "利用規約とポリシー", zh: "条款与政策", es: "Términos y políticas")
                            )
                        }
                    }
                    SettingsSectionCard {
                        VStack(spacing: 0) {
                            Button(localizedText("delete_account"), role: .destructive) {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                showingDeleteAlert = true
                            }
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                            .padding(.vertical, 12)

                            // The card's own 16-point inset sits above the first button and below the
                            // last; the same space around the line keeps the two buttons evenly spaced.
                            Divider()
                                .frame(height: 0.5)
                                .overlay(Color(UIColor.separator))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)

                            Button(localizedText("logout")) {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                showingLogoutAlert = true
                            }
                            .foregroundStyle(.red)
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
                    .environment(languageManager)
            }
            // Alerts for destructive actions
            .alert(localizedText("delete_account"), isPresented: $showingDeleteAlert) {
                Button(localizedText("cancel"), role: .cancel) {}
                Button(localizedText("delete_account"), role: .destructive) {
                    Task { await authManager.deleteAccount() }
                }
            } message: {
                Text(localizedText("delete_account_hint"))
            }
            .alert(localizedText("logout"), isPresented: $showingLogoutAlert) {
                Button(localizedText("cancel"), role: .cancel) {}
                Button(localizedText("logout")) {
                    authManager.signOut()
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

    private func localizedText(_ key: String) -> String {
        switch key {
        // Common
        case "settings": return languageManager.localize(ko: "설정", en: "Settings", ja: "設定", zh: "设置", es: "Configuración")
        case "cancel": return languageManager.localize(ko: "취소", en: "Cancel", ja: "キャンセル", zh: "取消", es: "Cancelar")

        // Language
        case "language": return languageManager.localize(ko: "언어", en: "Language", ja: "言語", zh: "语言", es: "Idioma")

        // Security / App Lock
        case "app_lock": return languageManager.localize(ko: "앱 잠금", en: "App Lock", ja: "アプリロック", zh: "应用锁定", es: "Bloqueo de aplicación")

        // Notifications
        case "notifications": return languageManager.localize(ko: "알림", en: "Notifications", ja: "通知", zh: "通知", es: "Notificaciones")

        // AI
        case "ai_features": return languageManager.localize(ko: "AI 기능", en: "AI Features", ja: "AI機能", zh: "AI功能", es: "Funciones de IA")

        // Translation
        case "translation": return languageManager.localize(ko: "번역", en: "Translation", ja: "翻訳", zh: "翻译", es: "Traducción")

        // Destructive
        case "delete_account": return languageManager.localize(ko: "계정 삭제", en: "Delete Account", ja: "アカウントを削除", zh: "删除账户", es: "Eliminar cuenta")
        case "delete_account_hint": return languageManager.localize(ko: "계정을 영구적으로 삭제합니다.", en: "Permanently delete your account.", ja: "アカウントを完全に削除します。", zh: "将永久删除您的账户。", es: "Elimina tu cuenta de forma permanente.")
        case "logout": return languageManager.localize(ko: "로그아웃", en: "Sign Out", ja: "ログアウト", zh: "退出登录", es: "Cerrar sesión")
        case "logout_hint": return languageManager.localize(ko: "현재 계정에서 로그아웃합니다.", en: "Sign out of your current account.", ja: "現在のアカウントからログアウトします。", zh: "从当前账户退出登录。", es: "Cierra sesión de tu cuenta actual.")

        default:
            // 디버깅을 위해 키가 정의되지 않은 경우를 확인
            settingsLogger.error("키 '\(key, privacy: .public)'가 정의되지 않음")
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
}
