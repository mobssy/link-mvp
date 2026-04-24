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
        switch key {
        case "title": return languageManager.localize(ko: "연락처로 친구를 더 빠르게 찾아요", en: "Find friends faster with Contacts", ja: "連絡先で友だちをもっと素早く見つけよう", zh: "通过通讯录更快找到朋友", es: "Encuentra amigos más rápido con Contactos")
        case "subtitle": return languageManager.localize(ko: "연락처의 전화번호/이메일을 안전하게 해시 처리하여 서버와 매칭합니다.", en: "We safely hash phone numbers/emails from your contacts to match with your friends.", ja: "連絡先の電話番号・メールを安全にハッシュ処理してサーバーとマッチングします。", zh: "我们对您通讯录中的电话/邮箱进行安全哈希处理，与服务器进行匹配。", es: "Procesamos de forma segura los números/correos de tus contactos para encontrar amigos.")
        case "not_now": return languageManager.localize(ko: "나중에", en: "Not Now", ja: "後で", zh: "稍后", es: "Ahora no")
        case "allow": return languageManager.localize(ko: "허용", en: "Allow", ja: "許可", zh: "允许", es: "Permitir")
        case "syncing": return languageManager.localize(ko: "동기화 중...", en: "Syncing...", ja: "同期中...", zh: "同步中...", es: "Sincronizando...")
        case "done": return languageManager.localize(ko: "완료", en: "Done", ja: "完了", zh: "完成", es: "Listo")
        case "permission_needed": return languageManager.localize(ko: "설정에서 연락처 접근 권한을 허용해주세요.", en: "Please allow Contacts access in Settings.", ja: "設定で連絡先へのアクセスを許可してください。", zh: "请在设置中允许访问通讯录。", es: "Por favor, permite el acceso a Contactos en Ajustes.")
        default: return key
        }
    }
}
