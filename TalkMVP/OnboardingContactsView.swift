import SwiftUI

struct OnboardingContactsView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = ContactsSyncService()
    @State private var isRequesting = false
    @State private var status: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.appPrimary)
                .padding(.top, 20)

            Text(loc("title"))
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(loc("subtitle"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()

            if !status.isEmpty {
                Text(status)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Text(loc("not_now"))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }

                Button(action: { Task { await requestAccessAndSync() } }) {
                    if isRequesting { ProgressView() } else { Text(loc("allow")) }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.appPrimary)
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(isRequesting)
            }
            .padding(.horizontal)

            Spacer(minLength: 20)
        }
        .padding()
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func requestAccessAndSync() async {
        isRequesting = true
        defer { isRequesting = false }
        let status = service.checkAuthorizationStatus()
        switch status {
        case .authorized:
            await runSyncThenDismiss()
        case .notDetermined:
            if await service.requestAccess() {
                await runSyncThenDismiss()
            } else {
                self.status = loc("permission_needed")
            }
        case .denied:
            self.status = loc("permission_needed")
        }
    }

    @MainActor
    private func runSyncThenDismiss() async {
        self.status = loc("syncing")
        do {
            _ = try await service.syncAndMatch()
            self.status = loc("done")
            try? await Task.sleep(nanoseconds: 500_000_000)
            dismiss()
        } catch {
            self.status = error.localizedDescription
        }
    }

    private func loc(_ key: String) -> String {
        let isKorean = languageManager.currentLanguage == .korean
        switch key {
        case "title": return isKorean ? "연락처로 친구를 더 빠르게 찾아요" : "Find friends faster with Contacts"
        case "subtitle": return isKorean ? "연락처의 전화번호/이메일을 안전하게 해시 처리하여 서버와 매칭합니다." : "We safely hash phone numbers/emails from your contacts to match with your friends."
        case "not_now": return isKorean ? "나중에" : "Not Now"
        case "allow": return isKorean ? "허용" : "Allow"
        case "syncing": return isKorean ? "동기화 중..." : "Syncing..."
        case "done": return isKorean ? "완료" : "Done"
        case "permission_needed": return isKorean ? "설정에서 연락처 접근 권한을 허용해주세요." : "Please allow Contacts access in Settings."
        default: return key
        }
    }
}
