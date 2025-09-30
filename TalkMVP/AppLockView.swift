import SwiftUI

struct AppLockView: View {
    @EnvironmentObject var appLock: AppLockManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)

                Text("잠금 해제 필요")
                    .font(.title2)
                    .fontWeight(.semibold)

                if let error = appLock.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button(action: {
                    appLock.authenticate()
                }) {
                    HStack {
                        Image(systemName: "faceid")
                        Text("인증 시도")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active && appLock.isLocked {
                // 포그라운드 복귀 시 자동 인증 시도
                appLock.authenticate()
            }
        }
        .onAppear {
            if appLock.isLocked {
                appLock.authenticate()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("앱 잠금 화면")
        .accessibilityHint("Face ID 또는 Touch ID로 인증하세요")
    }
}

#Preview {
    AppLockView()
        .environmentObject(AppLockManager())
}
