import SwiftUI

struct ContactsSettingsView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @StateObject private var service = ContactsSyncService()
    @AppStorage("contactsSyncEnabled") private var contactsSyncEnabled = false
    @State private var isSyncing = false
    @State private var status: String = ""
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section(header: Text(loc("contacts"))) {
                Toggle(isOn: $contactsSyncEnabled) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .foregroundColor(.green)
                        Text(loc("enable_sync"))
                    }
                }
                .onChange(of: contactsSyncEnabled) { _, newValue in
                    if newValue {
                        Task { await requestAndMaybeSync() }
                    }
                }

                Button(action: { Task { await requestAndSyncNow() } }) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.blue)
                        Text(isSyncing ? loc("syncing") : loc("sync_now"))
                    }
                }
                .disabled(isSyncing)

                if !status.isEmpty {
                    Text(status)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }

            Section(footer: Text(loc("privacy_hint"))) { EmptyView() }
        }
        .navigationTitle(loc("contacts"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if contactsSyncEnabled {
                Task { await requestAndMaybeSync() }
            }
        }
    }

    private func requestAndMaybeSync() async {
        let status = service.checkAuthorizationStatus()
        switch status {
        case .authorized:
            if contactsSyncEnabled { await runSync() }
        case .notDetermined:
            if await service.requestAccess() {
                if contactsSyncEnabled { await runSync() }
            } else {
                errorMessage = loc("permission_needed")
            }
        case .denied:
            errorMessage = loc("permission_needed")
        }
    }

    private func requestAndSyncNow() async {
        let status = service.checkAuthorizationStatus()
        switch status {
        case .authorized:
            await runSync()
        case .notDetermined:
            if await service.requestAccess() {
                await runSync()
            } else {
                errorMessage = loc("permission_needed")
            }
        case .denied:
            errorMessage = loc("permission_needed")
        }
    }

    @MainActor
    private func runSync() async {
        isSyncing = true
        errorMessage = nil
        status = loc("syncing")
        defer { isSyncing = false }
        do {
            let matched = try await service.syncAndMatch()
            if matched.isEmpty {
                status = loc("no_matches")
            } else {
                status = String(format: loc("found_matches"), matched.count)
            }
        } catch {
            errorMessage = error.localizedDescription
            status = ""
        }
    }

    private func loc(_ key: String) -> String {
        switch key {
        case "contacts": return languageManager.localize(ko: "연락처", en: "Contacts", ja: "連絡先", zh: "通讯录", es: "Contactos")
        case "enable_sync": return languageManager.localize(ko: "연락처 동기화 사용", en: "Enable Contacts Sync", ja: "連絡先同期を有効にする", zh: "启用通讯录同步", es: "Activar sincronización de contactos")
        case "sync_now": return languageManager.localize(ko: "지금 동기화", en: "Sync Now", ja: "今すぐ同期", zh: "立即同步", es: "Sincronizar ahora")
        case "syncing": return languageManager.localize(ko: "동기화 중...", en: "Syncing...", ja: "同期中...", zh: "正在同步...", es: "Sincronizando...")
        case "permission_needed": return languageManager.localize(ko: "설정에서 연락처 접근 권한을 허용해주세요.", en: "Please allow Contacts access in Settings.", ja: "設定で連絡先のアクセスを許可してください。", zh: "请在设置中允许访问通讯录。", es: "Permite el acceso a los contactos en Ajustes.")
        case "privacy_hint": return languageManager.localize(ko: "전화번호/이메일은 해시 처리되어 서버에 전송됩니다.", en: "Phone numbers/emails are hashed before sending to the server.", ja: "電話番号/メールはハッシュ処理されてサーバーに送信されます。", zh: "电话号码/邮箱经过哈希处理后发送至服务器。", es: "Los números de teléfono/correos electrónicos se cifran antes de enviarse al servidor.")
        case "no_matches": return languageManager.localize(ko: "일치하는 사용자가 없습니다.", en: "No matching users found.", ja: "一致するユーザーが見つかりませんでした。", zh: "未找到匹配的用户。", es: "No se encontraron usuarios coincidentes.")
        case "found_matches": return languageManager.localize(ko: "일치하는 사용자 %d명을 찾았습니다.", en: "Found %d matching users.", ja: "一致するユーザーが%d名見つかりました。", zh: "找到 %d 个匹配的用户。", es: "Se encontraron %d usuarios coincidentes.")
        default: return key
        }
    }
}
