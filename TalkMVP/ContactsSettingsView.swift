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
        let isKorean = languageManager.currentLanguage == .korean
        switch key {
        case "contacts": return isKorean ? "연락처" : "Contacts"
        case "enable_sync": return isKorean ? "연락처 동기화 사용" : "Enable Contacts Sync"
        case "sync_now": return isKorean ? "지금 동기화" : "Sync Now"
        case "syncing": return isKorean ? "동기화 중..." : "Syncing..."
        case "permission_needed": return isKorean ? "설정에서 연락처 접근 권한을 허용해주세요." : "Please allow Contacts access in Settings."
        case "privacy_hint": return isKorean ? "전화번호/이메일은 해시 처리되어 서버에 전송됩니다." : "Phone numbers/emails are hashed before sending to the server."
        case "no_matches": return isKorean ? "일치하는 사용자가 없습니다." : "No matching users found."
        case "found_matches": return isKorean ? "일치하는 사용자 %d명을 찾았습니다." : "Found %d matching users."
        default: return key
        }
    }
}
