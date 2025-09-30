//
//  SettingsView.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//

import SwiftUI
import SwiftData
import UserNotifications
import StoreKit
import MessageUI
import LocalAuthentication

// 실제 설정 뷰
struct SettingsView: View {
    @StateObject private var authManager: AuthManager
    // 설정값들
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("pushNotificationsEnabled") private var pushNotificationsEnabled = true
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("vibrationEnabled") private var vibrationEnabled = true
    @AppStorage("quietHoursEnabled") private var quietHoursEnabled = false
    @AppStorage("quietStartHour") private var quietStartHour = 22
    @AppStorage("quietStartMinute") private var quietStartMinute = 0
    @AppStorage("quietEndHour") private var quietEndHour = 8
    @AppStorage("quietEndMinute") private var quietEndMinute = 0
    @AppStorage("appLockEnabled") private var appLockEnabled = false

    // AI 요약/검색 설정
    @AppStorage("aiSummaryEnabled") private var aiSummaryEnabled = false
    @AppStorage("aiSearchEnabled") private var aiSearchEnabled = true
    @AppStorage("aiAutoMeetingNotesEnabled") private var aiAutoMeetingNotesEnabled = false

    // 번역 채팅 설정
    @AppStorage("translationEnabled") private var translationEnabled = false
    @AppStorage("translationAutoDetect") private var translationAutoDetect = true
    @AppStorage("translationTargetLanguage") private var translationTargetLanguage = "auto"
    @AppStorage("translationShowOriginal") private var translationShowOriginal = true
    
    @AppStorage("lastActivityEnabled") private var lastActivityEnabled = true
    
    // 단일 시트 상태
    @State private var activeSheet: SettingsSheet?
    
    private enum SettingsSheet: Identifiable {
        case profileEdit
        case notifications
        // case theme // removed
        case appInfo
        case privacy
        case storage
        case appIcon
        case aiFeatures
        case translation
        
        var id: String {
            switch self {
            case .profileEdit: return "profileEdit"
            case .notifications: return "notifications"
            // case .theme: return "theme" // removed
            case .appInfo: return "appInfo"
            case .privacy: return "privacy"
            case .storage: return "storage"
            case .appIcon: return "appIcon"
            case .aiFeatures: return "aiFeatures"
            case .translation: return "translation"
            }
        }
    }
    
    @State private var isProfilePressed = false
    @State private var showingLogoutAlert = false
    @State private var showingAppLockError = false
    @State private var appLockErrorMessage = ""
    @State private var showingDeleteAlert = false
    @State private var isDeletingAccount = false
    
    init(authManager: AuthManager) {
        self._authManager = StateObject(wrappedValue: authManager)
    }
    
    /*
    private var colorScheme: ColorScheme? {
        switch appTheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil // system
        }
    }
    */
    
    var body: some View {
        NavigationStack {
                List {
                    Section("계정") {
                        profileCard
                    }
                
                Section("설정") {
                    // 알림 설정 - 토글과 상세 설정
                    HStack {
                        settingsRowContent(title: "알림", icon: "bell")
                        Spacer()
                        Toggle("", isOn: $notificationsEnabled)
                            .labelsHidden()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        activeSheet = .notifications
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text("알림"))
                    .accessibilityHint(Text("알림 옵션을 설정합니다"))
                    
                    settingsRow(title: "개인정보", icon: "lock") {
                        activeSheet = .privacy
                    }
                    // Removed theme row
//                    settingsRow(title: "테마", icon: "paintbrush") {
//                        activeSheet = .theme
//                    }
                    settingsRow(title: "앱 아이콘", icon: "app") {
                        activeSheet = .appIcon
                    }
                    settingsRow(title: "데이터 및 저장공간", icon: "internaldrive") {
                        activeSheet = .storage
                    }
                    settingsRow(title: "AI 요약/검색", icon: "sparkles") {
                        activeSheet = .aiFeatures
                    }
                    settingsRow(title: "번역 채팅", icon: "globe") {
                        activeSheet = .translation
                    }
                    HStack {
                        settingsRowContent(title: "마지막 활동 표시", icon: "circle.fill")
                        Spacer()
                        Toggle("", isOn: $lastActivityEnabled)
                            .labelsHidden()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text("마지막 활동 표시"))
                    .accessibilityHint(Text("친구 프로필에 마지막 활동 정보를 표시합니다"))
                }
                
                Section("보안") {
                    HStack {
                        settingsRowContent(title: biometryTitle, icon: "lock.circle")
                        Spacer()
                        Toggle("", isOn: $appLockEnabled)
                            .labelsHidden()
                            .accessibilityLabel(Text(biometryTitle))
                            .accessibilityHint(Text("Face ID 또는 Touch ID로 앱을 보호합니다"))
                    }
                }
                
                Section("정보") {
                    settingsRow(title: "도움말", icon: "questionmark.circle", action: {})
                    settingsRow(title: "앱 정보", icon: "info.circle") {
                        activeSheet = .appInfo
                    }
                    settingsRow(title: "약관 및 정책", icon: "doc.text", action: {})
                }
                
                Section {
                    Button("계정 삭제", role: .destructive) {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        showingDeleteAlert = true
                    }
                    .frame(maxWidth: .infinity)
                    .font(.headline)
                    .accessibilityLabel(Text("계정 삭제"))
                    .accessibilityHint(Text("모든 데이터가 삭제됩니다"))

                    Button("로그아웃") {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        showingLogoutAlert = true
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .font(.headline)
                    .accessibilityLabel(Text("로그아웃"))
                    .accessibilityHint(Text("현재 계정에서 로그아웃합니다"))
                }
            }
            .navigationTitle("설정")
            .background(Color(UIColor.systemGroupedBackground))
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .profileEdit:
                ProfileEditView(authManager: authManager)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            case .notifications:
                NotificationSettingsView(
                    notificationsEnabled: $notificationsEnabled,
                    pushNotificationsEnabled: $pushNotificationsEnabled,
                    soundEnabled: $soundEnabled,
                    vibrationEnabled: $vibrationEnabled,
                    quietHoursEnabled: $quietHoursEnabled,
                    quietStartHour: $quietStartHour,
                    quietStartMinute: $quietStartMinute,
                    quietEndHour: $quietEndHour,
                    quietEndMinute: $quietEndMinute
                )
            /*
            case .theme:
                ThemeSettingsView(selectedTheme: $appTheme)
            */
            case .appInfo:
                AppInfoView()
            case .privacy:
                PrivacySettingsView()
            case .storage:
                StorageSettingsView()
            case .appIcon:
                AppIconSettingsView()
            case .aiFeatures:
                AISummarySettingsView(
                    aiSummaryEnabled: $aiSummaryEnabled,
                    aiSearchEnabled: $aiSearchEnabled,
                    aiAutoMeetingNotesEnabled: $aiAutoMeetingNotesEnabled
                )
            case .translation:
                TranslationSettingsView(
                    translationEnabled: $translationEnabled,
                    translationAutoDetect: $translationAutoDetect,
                    translationTargetLanguage: $translationTargetLanguage,
                    translationShowOriginal: $translationShowOriginal
                )
            }
        }
        .onChange(of: notificationsEnabled) { oldValue, newValue in
            if newValue {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                    DispatchQueue.main.async {
                        if !granted {
                            notificationsEnabled = false
                        }
                    }
                }
            } else {
                // 필요시 예약된 알림 취소 등 추가 처리 가능
            }
        }
        .onChange(of: appLockEnabled) { oldValue, newValue in
            if newValue {
                authenticateForAppLock()
            } else {
                // 앱 잠금 해제 시 추가 동작이 필요하면 여기에 구현
            }
        }
        .alert("인증 실패", isPresented: $showingAppLockError) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(appLockErrorMessage)
        }
        .alert("로그아웃", isPresented: $showingLogoutAlert) {
            Button("취소", role: .cancel) { }
            Button("로그아웃", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    authManager.signOut()
                }
            }
        } message: {
            Text("현재 계정에서 로그아웃하시겠습니까?")
        }
        .alert("계정 삭제", isPresented: $showingDeleteAlert) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) {
                Task {
                    isDeletingAccount = true
                    await authManager.deleteAccount()
                    isDeletingAccount = false
                }
            }
        } message: {
            Text("정말로 계정을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.")
        }
        .overlay {
            if isDeletingAccount {
                ZStack {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView("계정 삭제 중…")
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(12)
                }
            }
        }
        /*
        .preferredColorScheme(colorScheme)
        .id(appTheme)
        */
    }
    
    // MARK: - 프로필 카드
    private var profileCard: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            activeSheet = .profileEdit
        }) {
            HStack(spacing: 16) {
                // 프로필 이미지
                profileImage
                
                // 사용자 정보
                VStack(alignment: .leading, spacing: 4) {
                    Text(authManager.currentUser?.displayName ?? "사용자")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(authManager.currentUser?.statusMessage ?? "상태메시지를 입력하세요")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // 화살표 아이콘
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .scaleEffect(isProfilePressed ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isProfilePressed)
            }
            .padding(.vertical, 12)
            .scaleEffect(isProfilePressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isProfilePressed)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(Text("프로필 편집"))
        .accessibilityHint(Text("프로필 사진과 정보를 수정합니다"))
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation {
                isProfilePressed = pressing
            }
        }, perform: {})
    }
    
    // MARK: - 프로필 이미지
    private var profileImage: some View {
        Group {
            if let imageData = authManager.currentUser?.profileImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                    )
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .background(Circle().fill(Color(UIColor.systemBackground)))
            }
        }
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
    }
    
    // MARK: - 보안 관련 헬퍼
    private var biometryTitle: String {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID: return "앱 잠금 (Face ID)"
            case .touchID: return "앱 잠금 (Touch ID)"
            default: return "앱 잠금"
            }
        } else {
            return "앱 잠금"
        }
    }

    private func authenticateForAppLock() {
        let context = LAContext()
        context.localizedFallbackTitle = "암호 사용"
        var authError: NSError?

        // Prefer biometrics only if available AND Face ID usage description key exists (avoids crash when key is missing)
        let hasFaceIDUsageDescription = Bundle.main.object(forInfoDictionaryKey: "NSFaceIDUsageDescription") != nil
        let biometricsAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError)
        let policy: LAPolicy = (biometricsAvailable && hasFaceIDUsageDescription) ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication

        let reason = "앱 잠금을 활성화하려면 인증이 필요합니다."

        if context.canEvaluatePolicy(policy, error: &authError) {
            context.evaluatePolicy(policy, localizedReason: reason) { success, error in
                DispatchQueue.main.async {
                    if success {
                        appLockEnabled = true
                    } else {
                        appLockEnabled = false
                        appLockErrorMessage = (error as NSError?)?.localizedDescription ?? "인증에 실패했습니다."
                        showingAppLockError = true
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                appLockEnabled = false
                appLockErrorMessage = authError?.localizedDescription ?? "이 기기에서는 생체 인증 또는 기기 암호 인증을 사용할 수 없습니다."
                showingAppLockError = true
            }
        }
    }
    
    // MARK: - 설정 행
    private func settingsRow(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            settingsRowContent(title: title, icon: icon)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text(hintForSetting(title)))
    }
    
    // MARK: - 설정 행 콘텐츠 (재사용)
    private func settingsRowContent(title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            // 아이콘 배경
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.blue.opacity(0.1))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                )
            
            // 제목
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            // 화살표
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    private func hintForSetting(_ title: String) -> String {
        switch title {
        case "개인정보": return "개인정보 및 정책을 확인합니다"
        // Removed "테마" case
        // case "테마": return "라이트, 다크 또는 시스템 테마를 선택합니다"
        case "앱 아이콘": return "앱 아이콘을 변경합니다"
        case "데이터 및 저장공간": return "캐시 용량 확인 및 정리를 할 수 있습니다"
        case "도움말": return "도움말 정보를 확인합니다"
        case "앱 정보": return "앱 버전 및 정보를 확인합니다"
        case "약관 및 정책": return "약관과 정책을 확인합니다"
        default: return "자세한 설정을 확인합니다"
        }
    }
}

// MARK: - 알림 설정 뷰
struct NotificationSettingsView: View {
    @Binding var notificationsEnabled: Bool
    @Binding var pushNotificationsEnabled: Bool
    @Binding var soundEnabled: Bool
    @Binding var vibrationEnabled: Bool
    @Binding var quietHoursEnabled: Bool
    @Binding var quietStartHour: Int
    @Binding var quietStartMinute: Int
    @Binding var quietEndHour: Int
    @Binding var quietEndMinute: Int
    @Environment(\.dismiss) private var dismiss
    
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()
    
    init(
        notificationsEnabled: Binding<Bool>,
        pushNotificationsEnabled: Binding<Bool>,
        soundEnabled: Binding<Bool>,
        vibrationEnabled: Binding<Bool>,
        quietHoursEnabled: Binding<Bool>,
        quietStartHour: Binding<Int>,
        quietStartMinute: Binding<Int>,
        quietEndHour: Binding<Int>,
        quietEndMinute: Binding<Int>
    ) {
        self._notificationsEnabled = notificationsEnabled
        self._pushNotificationsEnabled = pushNotificationsEnabled
        self._soundEnabled = soundEnabled
        self._vibrationEnabled = vibrationEnabled
        self._quietHoursEnabled = quietHoursEnabled
        self._quietStartHour = quietStartHour
        self._quietStartMinute = quietStartMinute
        self._quietEndHour = quietEndHour
        self._quietEndMinute = quietEndMinute

        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year, .month, .day], from: Date())
        comps.hour = quietStartHour.wrappedValue
        comps.minute = quietStartMinute.wrappedValue
        self._startTime = State(initialValue: calendar.date(from: comps) ?? Date())

        comps.hour = quietEndHour.wrappedValue
        comps.minute = quietEndMinute.wrappedValue
        self._endTime = State(initialValue: calendar.date(from: comps) ?? Date())
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("알림 설정")) {
                    Toggle("알림 허용", isOn: $notificationsEnabled)
                    
                    if notificationsEnabled {
                        Toggle("푸시 알림", isOn: $pushNotificationsEnabled)
                        Toggle("사운드", isOn: $soundEnabled)
                        Toggle("진동", isOn: $vibrationEnabled)
                    }
                }
                
                if notificationsEnabled {
                    Section(header: Text("알림 시간"), footer: Text("방해 금지 시간대를 설정하세요")) {
                        Toggle("조용한 시간대", isOn: $quietHoursEnabled)

                        if quietHoursEnabled {
                            DatePicker("시작", selection: $startTime, displayedComponents: .hourAndMinute)
                            DatePicker("종료", selection: $endTime, displayedComponents: .hourAndMinute)
                        }
                    }
                }
            }
            .navigationTitle("알림 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") {
                        dismiss()
                    }
                }
            }
            .onChange(of: startTime) { _, newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                quietStartHour = comps.hour ?? 0
                quietStartMinute = comps.minute ?? 0
            }
            .onChange(of: endTime) { _, newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                quietEndHour = comps.hour ?? 0
                quietEndMinute = comps.minute ?? 0
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - 앱 정보 뷰
struct AppInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showingMailComposer = false
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 16) {
                        // 앱 아이콘
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.blue.gradient)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "message.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            )
                        
                        VStack(spacing: 4) {
                            Text("TalkMVP")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("버전 \(appVersion) (\(buildNumber))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                
                Section("정보") {
                    InfoRow(title: "개발자", value: "David Song")
                    InfoRow(title: "카테고리", value: "소셜 네트워킹")
                    InfoRow(title: "크기", value: "12.3 MB")
                    InfoRow(title: "호환성", value: "iOS 17.0 이상")
                }
                
                Section("지원") {
                    HStack {
                        Text("피드백 보내기")
                        Spacer()
                        Image(systemName: "envelope")
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if MFMailComposeViewController.canSendMail() {
                            showingMailComposer = true
                        } else if let url = URL(string: "mailto:support@talkmvp.app?subject=Feedback%20for%20TalkMVP") {
                            openURL(url)
                        }
                    }
                    
                    HStack {
                        Text("평가하기")
                        Spacer()
                        Image(systemName: "star")
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            if #available(iOS 18.0, *) {
                                AppStore.requestReview(in: scene)
                            } else {
                                SKStoreReviewController.requestReview(in: scene)
                            }
                        }
                    }
                }
            }
            .navigationTitle("앱 정보")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingMailComposer) {
                MailView(
                    subject: "TalkMVP 피드백",
                    recipients: ["support@talkmvp.app"],
                    body: "앱에 대한 의견을 보내주세요."
                )
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - 개인정보 설정 뷰
struct PrivacySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var dataCollectionEnabled = false
    @State private var analyticsEnabled = true
    @State private var crashReportEnabled = true
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("데이터 수집"), footer: Text("앱 개선을 위해 익명화된 데이터를 수집합니다.")) {
                    Toggle("사용 데이터 수집", isOn: $dataCollectionEnabled)
                    Toggle("분석 데이터", isOn: $analyticsEnabled)
                    Toggle("크래시 리포트", isOn: $crashReportEnabled)
                }
                
                Section(header: Text("개인정보 보호")) {
                    HStack {
                        Text("개인정보 처리방침")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let url = URL(string: "https://example.com/privacy") {
                            openURL(url)
                        }
                    }
                    
                    HStack {
                        Text("서비스 이용약관")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let url = URL(string: "https://example.com/terms") {
                            openURL(url)
                        }
                    }
                }
                
                Section {
                    Button("모든 데이터 삭제") {
                        // 데이터 삭제 로직
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("개인정보")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - 앱 아이콘 설정 뷰
struct AppIconSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIconName: String? = UIApplication.shared.alternateIconName
    @State private var showingIconError = false
    @State private var iconErrorMessage = ""

    // 프로젝트에 구성된 대체 아이콘 이름을 여기에 나열하세요. (Assets 및 Info.plist에 설정 필요)
    private let icons: [(name: String?, title: String, symbol: String)] = [
        (nil, "기본 아이콘", "app.fill"),
        ("AltIcon", "대체 아이콘", "app.badge.fill")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("앱 아이콘 선택"), footer: Text("대체 아이콘을 사용하려면 프로젝트의 Assets 및 Info.plist에 Alternate App Icons가 구성되어 있어야 합니다.")) {
                    ForEach(icons, id: \.name) { item in
                        HStack(spacing: 12) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                                .frame(width: 28)

                            Text(item.title)

                            Spacer()

                            if selectedIconName == item.name {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { setAppIcon(item.name) }
                    }
                }
            }
            .navigationTitle("앱 아이콘")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") { dismiss() }
                }
            }
            .alert("아이콘 변경 실패", isPresented: $showingIconError) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(iconErrorMessage)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func setAppIcon(_ name: String?) {
        // 이미 선택된 경우 무시
        if selectedIconName == name { return }

        UIApplication.shared.setAlternateIconName(name) { error in
            DispatchQueue.main.async {
                if let error = error {
                    iconErrorMessage = error.localizedDescription
                    showingIconError = true
                } else {
                    selectedIconName = name
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
            }
        }
    }
}

// MARK: - 데이터 및 저장공간 뷰
struct StorageSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var cacheSize: String = "계산 중…"

    var body: some View {
        NavigationStack {
            List {
                Section("저장공간") {
                    HStack {
                        Text("캐시 용량")
                        Spacer()
                        Text(cacheSize)
                            .foregroundColor(.secondary)
                    }

                    Button("캐시 삭제", role: .destructive) {
                        clearCache()
                    }
                }
            }
            .navigationTitle("데이터 및 저장공간")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                recalcCacheSize()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func recalcCacheSize() {
        DispatchQueue.global(qos: .utility).async {
            let size = folderSize(at: cachesDirectory())
            let formatted = format(bytes: size)
            DispatchQueue.main.async {
                cacheSize = formatted
            }
        }
    }

    private func clearCache() {
        let url = cachesDirectory()
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
            for item in contents {
                try? FileManager.default.removeItem(at: item)
            }
        } catch {
            // 무시: 일부 파일은 삭제되지 않을 수 있음
        }
        recalcCacheSize()
    }

    private func cachesDirectory() -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }

    private func folderSize(at url: URL) -> Int64 {
        var size: Int64 = 0
        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey], options: [], errorHandler: nil) {
            for case let fileURL as URL in enumerator {
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                    if resourceValues.isRegularFile == true {
                        size += Int64(resourceValues.fileSize ?? 0)
                    }
                } catch {
                    continue
                }
            }
        }
        return size
    }

    private func format(bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - AI 요약/검색 설정 뷰
struct AISummarySettingsView: View {
    @Binding var aiSummaryEnabled: Bool
    @Binding var aiSearchEnabled: Bool
    @Binding var aiAutoMeetingNotesEnabled: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("AI 요약"), footer: Text("요약 및 검색 기능은 기기 성능과 네트워크 상태에 따라 달라질 수 있습니다.")) {
                    Toggle("요약 활성화", isOn: $aiSummaryEnabled)
                }

                if aiSummaryEnabled {
                    Section(header: Text("옵션")) {
                        Toggle("과거 대화 검색 인덱싱", isOn: $aiSearchEnabled)
                        Toggle("그룹 회의록 자동 생성", isOn: $aiAutoMeetingNotesEnabled)
                    }
                }
            }
            .navigationTitle("AI 요약/검색")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - 번역 채팅 설정 뷰
struct TranslationSettingsView: View {
    @Binding var translationEnabled: Bool
    @Binding var translationAutoDetect: Bool
    @Binding var translationTargetLanguage: String
    @Binding var translationShowOriginal: Bool
    @Environment(\.dismiss) private var dismiss

    private let languages: [(code: String, name: String)] = [
        ("auto", "자동 감지"),
        ("en", "영어"),
        ("ja", "일본어"),
        ("ko", "한국어"),
        ("zh-Hans", "중국어(간체)"),
        ("zh-Hant", "중국어(번체)"),
        ("es", "스페인어"),
        ("fr", "프랑스어"),
        ("de", "독일어")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("번역")) {
                    Toggle("번역 활성화", isOn: $translationEnabled)
                }

                if translationEnabled {
                    Section(header: Text("옵션")) {
                        Toggle("자동 언어 감지", isOn: $translationAutoDetect)
                        Toggle("원문 함께 표시", isOn: $translationShowOriginal)
                    }

                    Section(header: Text("기본 대상 언어"), footer: Text("채팅별로 다른 언어를 설정할 수 있도록 별도 옵션을 제공할 수 있습니다.")) {
                        ForEach(languages, id: \.code) { lang in
                            HStack {
                                Text(lang.name)
                                Spacer()
                                if translationTargetLanguage == lang.code {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                translationTargetLanguage = lang.code
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            }
                        }
                    }
                }
            }
            .navigationTitle("번역 채팅")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - 메일 컴포저 래퍼
struct MailView: UIViewControllerRepresentable {
    var subject: String
    var recipients: [String]
    var body: String
    @Environment(\.dismiss) private var dismiss

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailView
        init(_ parent: MailView) { self.parent = parent }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.dismiss()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setSubject(subject)
        vc.setToRecipients(recipients)
        vc.setMessageBody(body, isHTML: false)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
}

// MARK: - 정보 행 헬퍼
struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: User.self)
    let context = ModelContext(container)
    return SettingsView(authManager: AuthManager(modelContext: context))
}
