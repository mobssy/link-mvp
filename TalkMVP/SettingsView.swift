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
    @EnvironmentObject private var languageManager: LanguageManager
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
        case language
        case appInfo
        case privacy
        case storage
        case appIcon
        case aiFeatures
        case translation
        case disappearingMessages
        
        var id: String {
            switch self {
            case .profileEdit: return "profileEdit"
            case .notifications: return "notifications"
            // case .theme: return "theme" // removed
            case .language: return "language"
            case .appInfo: return "appInfo"
            case .privacy: return "privacy"
            case .storage: return "storage"
            case .appIcon: return "appIcon"
            case .aiFeatures: return "aiFeatures"
            case .translation: return "translation"
            case .disappearingMessages: return "disappearingMessages"
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
                accountSection
                settingsSection
                securitySection
                informationSection
                destructiveSection
            }
            .navigationTitle(localizedText("settings"))
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
            case .language:
                LanguageSettingsView()
                    .environmentObject(languageManager)
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
            case .disappearingMessages:
                DisappearingMessageDemoView()
                    .environmentObject(languageManager)
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
        .alert(localizedText("auth_failed"), isPresented: $showingAppLockError) {
            Button(localizedText("ok"), role: .cancel) { }
        } message: {
            Text(appLockErrorMessage)
        }
        .alert(localizedText("logout"), isPresented: $showingLogoutAlert) {
            Button(localizedText("cancel"), role: .cancel) { }
            Button(localizedText("logout"), role: .destructive) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    authManager.signOut()
                }
            }
        } message: {
            Text(localizedText("logout_message"))
        }
        .alert(localizedText("delete_account"), isPresented: $showingDeleteAlert) {
            Button(localizedText("cancel"), role: .cancel) { }
            Button(localizedText("delete"), role: .destructive) {
                Task {
                    isDeletingAccount = true
                    await authManager.deleteAccount()
                    isDeletingAccount = false
                }
            }
        } message: {
            Text(localizedText("delete_account_message"))
        }
        .overlay {
            if isDeletingAccount {
                ZStack {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView(localizedText("deleting_account"))
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
    
    // MARK: - Extracted Sections to help the compiler
    private var accountSection: some View {
        Section(localizedText("account")) {
            profileCard
        }
    }

    private var settingsSection: some View {
        Section(localizedText("settings")) {
            // 알림 설정 - 토글과 상세 설정
            HStack {
                settingsRowContent(title: localizedText("notifications"), icon: "bell")
                Spacer()
                Toggle("", isOn: $notificationsEnabled)
                    .labelsHidden()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                activeSheet = .notifications
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(localizedText("notifications")))
            .accessibilityHint(Text(localizedText("notifications_hint")))
            
            settingsRow(title: localizedText("language"), icon: "globe") {
                activeSheet = .language
            }
            
            settingsRow(title: localizedText("privacy"), icon: "lock") {
                activeSheet = .privacy
            }
            
            settingsRow(title: localizedText("app_icon"), icon: "app") {
                activeSheet = .appIcon
            }
            settingsRow(title: localizedText("storage"), icon: "internaldrive") {
                activeSheet = .storage
            }
            settingsRow(title: localizedText("ai_features"), icon: "sparkles") {
                activeSheet = .aiFeatures
            }
            settingsRow(title: localizedText("translation"), icon: "globe") {
                activeSheet = .translation
            }
            settingsRow(title: localizedText("disappearing_messages"), icon: "timer") {
                activeSheet = .disappearingMessages
            }
            HStack {
                settingsRowContent(title: localizedText("last_activity"), icon: "circle.fill")
                Spacer()
                Toggle("", isOn: $lastActivityEnabled)
                    .labelsHidden()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(localizedText("last_activity")))
            .accessibilityHint(Text(localizedText("last_activity_hint")))
        }
    }

    private var securitySection: some View {
        Section(localizedText("security")) {
            HStack {
                settingsRowContent(title: biometryTitle, icon: "lock.circle")
                Spacer()
                Toggle("", isOn: $appLockEnabled)
                    .labelsHidden()
                    .accessibilityLabel(Text(biometryTitle))
                    .accessibilityHint(Text("Face ID 또는 Touch ID로 앱을 보호합니다"))
            }
        }
    }

    private var informationSection: some View {
        Section(localizedText("information")) {
            settingsRow(title: localizedText("help"), icon: "questionmark.circle", action: {})
            settingsRow(title: localizedText("app_info"), icon: "info.circle") {
                activeSheet = .appInfo
            }
            settingsRow(title: localizedText("terms_policy"), icon: "doc.text", action: {})
        }
    }

    private var destructiveSection: some View {
        Section {
            Button(localizedText("delete_account"), role: .destructive) {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                showingDeleteAlert = true
            }
            .frame(maxWidth: .infinity)
            .font(.headline)
            .accessibilityLabel(Text(localizedText("delete_account")))
            .accessibilityHint(Text(localizedText("delete_account_hint")))

            Button(localizedText("logout")) {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                showingLogoutAlert = true
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .font(.headline)
            .accessibilityLabel(Text(localizedText("logout")))
            .accessibilityHint(Text(localizedText("logout_hint")))
        }
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
                    Text(authManager.currentUser?.displayName ?? localizedText("user"))
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(authManager.currentUser?.statusMessage ?? localizedText("status_placeholder"))
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
        .accessibilityLabel(Text(localizedText("edit_profile")))
        .accessibilityHint(Text(localizedText("edit_profile_hint")))
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
            case .faceID: return localizedText("app_lock_faceid")
            case .touchID: return localizedText("app_lock_touchid")
            default: return localizedText("app_lock")
            }
        } else {
            return localizedText("app_lock")
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
        return localizedText("setting_hint_\(title.lowercased())")
    }
    
    private func localizedText(_ key: String) -> String {
        switch key {
        // 섹션 헤더
        case "account": return languageManager.currentLanguage == .korean ? "계정" : "Account"
        case "settings": return languageManager.currentLanguage == .korean ? "설정" : "Settings"
        case "security": return languageManager.currentLanguage == .korean ? "보안" : "Security"
        case "information": return languageManager.currentLanguage == .korean ? "정보" : "Information"
        
        // 설정 항목들
        case "notifications": return languageManager.currentLanguage == .korean ? "알림" : "Notifications"
        case "language": return languageManager.currentLanguage == .korean ? "언어" : "Language"
        case "privacy": return languageManager.currentLanguage == .korean ? "개인정보" : "Privacy"
        case "app_icon": return languageManager.currentLanguage == .korean ? "앱 아이콘" : "App Icon"
        case "storage": return languageManager.currentLanguage == .korean ? "데이터 및 저장공간" : "Data & Storage"
        case "ai_features": return languageManager.currentLanguage == .korean ? "AI 요약/검색" : "AI Summary/Search"
        case "translation": return languageManager.currentLanguage == .korean ? "번역 채팅" : "Translation Chat"
        case "disappearing_messages": return languageManager.currentLanguage == .korean ? "자폭 메시지" : "Disappearing Messages"
        case "last_activity": return languageManager.currentLanguage == .korean ? "마지막 활동 표시" : "Show Last Activity"
        case "help": return languageManager.currentLanguage == .korean ? "도움말" : "Help"
        case "app_info": return languageManager.currentLanguage == .korean ? "앱 정보" : "App Info"
        case "terms_policy": return languageManager.currentLanguage == .korean ? "약관 및 정책" : "Terms & Policy"
        
        // 앱 잠금 관련
        case "app_lock": return languageManager.currentLanguage == .korean ? "앱 잠금" : "App Lock"
        case "app_lock_faceid": return languageManager.currentLanguage == .korean ? "앱 잠금 (Face ID)" : "App Lock (Face ID)"
        case "app_lock_touchid": return languageManager.currentLanguage == .korean ? "앱 잠금 (Touch ID)" : "App Lock (Touch ID)"
        
        // 버튼들
        case "delete_account": return languageManager.currentLanguage == .korean ? "계정 삭제" : "Delete Account"
        case "logout": return languageManager.currentLanguage == .korean ? "로그아웃" : "Sign Out"
        case "cancel": return languageManager.currentLanguage == .korean ? "취소" : "Cancel"
        case "ok": return languageManager.currentLanguage == .korean ? "확인" : "OK"
        case "delete": return languageManager.currentLanguage == .korean ? "삭제" : "Delete"
        
        // 프로필 관련
        case "user": return languageManager.currentLanguage == .korean ? "사용자" : "User"
        case "status_placeholder": return languageManager.currentLanguage == .korean ? "상태메시지를 입력하세요" : "Enter status message"
        case "edit_profile": return languageManager.currentLanguage == .korean ? "프로필 편집" : "Edit Profile"
        case "edit_profile_hint": return languageManager.currentLanguage == .korean ? "프로필 사진과 정보를 수정합니다" : "Edit profile photo and information"
        
        // 알림 및 메시지들
        case "auth_failed": return languageManager.currentLanguage == .korean ? "인증 실패" : "Authentication Failed"
        case "logout_message": return languageManager.currentLanguage == .korean ? "현재 계정에서 로그아웃하시겠습니까?" : "Are you sure you want to sign out?"
        case "delete_account_message": return languageManager.currentLanguage == .korean ? "정말로 계정을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다." : "Are you sure you want to delete your account? This action cannot be undone."
        case "deleting_account": return languageManager.currentLanguage == .korean ? "계정 삭제 중…" : "Deleting Account…"
        
        // 힌트들
        case "notifications_hint": return languageManager.currentLanguage == .korean ? "알림 옵션을 설정합니다" : "Configure notification options"
        case "last_activity_hint": return languageManager.currentLanguage == .korean ? "친구 프로필에 마지막 활동 정보를 표시합니다" : "Show last activity information on friend profiles"
        case "delete_account_hint": return languageManager.currentLanguage == .korean ? "모든 데이터가 삭제됩니다" : "All data will be deleted"
        case "logout_hint": return languageManager.currentLanguage == .korean ? "현재 계정에서 로그아웃합니다" : "Sign out from current account"
        
        default: return key
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
    @EnvironmentObject private var languageManager: LanguageManager
    
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
                Section(header: Text(localizedText("notification_settings"))) {
                    Toggle(localizedText("allow_notifications"), isOn: $notificationsEnabled)
                    
                    if notificationsEnabled {
                        Toggle(localizedText("push_notifications"), isOn: $pushNotificationsEnabled)
                        Toggle(localizedText("sound"), isOn: $soundEnabled)
                        Toggle(localizedText("vibration"), isOn: $vibrationEnabled)
                    }
                }
                
                if notificationsEnabled {
                    Section(header: Text(localizedText("notification_time")), footer: Text(localizedText("do_not_disturb_footer"))) {
                        Toggle(localizedText("quiet_hours"), isOn: $quietHoursEnabled)

                        if quietHoursEnabled {
                            DatePicker(localizedText("start"), selection: $startTime, displayedComponents: .hourAndMinute)
                            DatePicker(localizedText("end"), selection: $endTime, displayedComponents: .hourAndMinute)
                        }
                    }
                }
            }
            .navigationTitle(localizedText("notification_settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizedText("done")) {
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
    
    private func localizedText(_ key: String) -> String {
        switch key {
        case "notification_settings":
            return languageManager.currentLanguage == .korean ? "알림 설정" : "Notification Settings"
        case "allow_notifications":
            return languageManager.currentLanguage == .korean ? "알림 허용" : "Allow Notifications"
        case "push_notifications":
            return languageManager.currentLanguage == .korean ? "푸시 알림" : "Push Notifications"
        case "sound":
            return languageManager.currentLanguage == .korean ? "사운드" : "Sound"
        case "vibration":
            return languageManager.currentLanguage == .korean ? "진동" : "Vibration"
        case "notification_time":
            return languageManager.currentLanguage == .korean ? "알림 시간" : "Notification Time"
        case "do_not_disturb_footer":
            return languageManager.currentLanguage == .korean ? "방해 금지 시간대를 설정하세요" : "Set Do Not Disturb hours"
        case "quiet_hours":
            return languageManager.currentLanguage == .korean ? "조용한 시간대" : "Quiet Hours"
        case "start":
            return languageManager.currentLanguage == .korean ? "시작" : "Start"
        case "end":
            return languageManager.currentLanguage == .korean ? "종료" : "End"
        case "done":
            return languageManager.currentLanguage == .korean ? "완료" : "Done"
        default:
            return key
        }
    }
}

// MARK: - 앱 정보 뷰
struct AppInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var languageManager: LanguageManager
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
                            
                            Text(localizedText("version", version: appVersion, build: buildNumber))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                
                Section(localizedText("information")) {
                    InfoRow(title: localizedText("developer"), value: "David Song")
                    InfoRow(title: localizedText("category"), value: localizedText("social_networking"))
                    InfoRow(title: localizedText("size"), value: "12.3 MB")
                    InfoRow(title: localizedText("compatibility"), value: localizedText("ios_compatibility"))
                }
                
                Section(localizedText("support")) {
                    HStack {
                        Text(localizedText("send_feedback"))
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
                        Text(localizedText("rate_app"))
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
            .navigationTitle(localizedText("app_info"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizedText("done")) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingMailComposer) {
                MailView(
                    subject: localizedText("talkmvp_feedback"),
                    recipients: ["support@talkmvp.app"],
                    body: localizedText("feedback_body")
                )
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private func localizedText(_ key: String, version: String = "", build: String = "") -> String {
        switch key {
        case "version":
            return languageManager.currentLanguage == .korean ? "버전 \(version) (\(build))" : "Version \(version) (\(build))"
        case "information":
            return languageManager.currentLanguage == .korean ? "정보" : "Information"
        case "developer":
            return languageManager.currentLanguage == .korean ? "개발자" : "Developer"
        case "category":
            return languageManager.currentLanguage == .korean ? "카테고리" : "Category"
        case "social_networking":
            return languageManager.currentLanguage == .korean ? "소셜 네트워킹" : "Social Networking"
        case "size":
            return languageManager.currentLanguage == .korean ? "크기" : "Size"
        case "compatibility":
            return languageManager.currentLanguage == .korean ? "호환성" : "Compatibility"
        case "ios_compatibility":
            return languageManager.currentLanguage == .korean ? "iOS 17.0 이상" : "iOS 17.0 or later"
        case "support":
            return languageManager.currentLanguage == .korean ? "지원" : "Support"
        case "send_feedback":
            return languageManager.currentLanguage == .korean ? "피드백 보내기" : "Send Feedback"
        case "rate_app":
            return languageManager.currentLanguage == .korean ? "평가하기" : "Rate App"
        case "app_info":
            return languageManager.currentLanguage == .korean ? "앱 정보" : "App Information"
        case "done":
            return languageManager.currentLanguage == .korean ? "완료" : "Done"
        case "talkmvp_feedback":
            return languageManager.currentLanguage == .korean ? "TalkMVP 피드백" : "TalkMVP Feedback"
        case "feedback_body":
            return languageManager.currentLanguage == .korean ? "앱에 대한 의견을 보내주세요." : "Please send us your feedback about the app."
        default:
            return key
        }
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
    @EnvironmentObject private var languageManager: LanguageManager
    @State private var cacheSize: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section(localizedText("storage")) {
                    HStack {
                        Text(localizedText("cache_size"))
                        Spacer()
                        Text(cacheSize.isEmpty ? localizedText("calculating") : cacheSize)
                            .foregroundColor(.secondary)
                    }

                    Button(localizedText("clear_cache"), role: .destructive) {
                        clearCache()
                    }
                }
            }
            .navigationTitle(localizedText("data_storage"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizedText("done")) {
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
    
    private func localizedText(_ key: String) -> String {
        switch key {
        case "storage":
            return languageManager.currentLanguage == .korean ? "저장공간" : "Storage"
        case "cache_size":
            return languageManager.currentLanguage == .korean ? "캐시 용량" : "Cache Size"
        case "calculating":
            return languageManager.currentLanguage == .korean ? "계산 중…" : "Calculating…"
        case "clear_cache":
            return languageManager.currentLanguage == .korean ? "캐시 삭제" : "Clear Cache"
        case "data_storage":
            return languageManager.currentLanguage == .korean ? "데이터 및 저장공간" : "Data & Storage"
        case "done":
            return languageManager.currentLanguage == .korean ? "완료" : "Done"
        default:
            return key
        }
    }
}

// MARK: - AI 요약/검색 설정 뷰
struct AISummarySettingsView: View {
    @Binding var aiSummaryEnabled: Bool
    @Binding var aiSearchEnabled: Bool
    @Binding var aiAutoMeetingNotesEnabled: Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text(localizedText("ai_summary")), footer: Text(localizedText("ai_footer"))) {
                    Toggle(localizedText("enable_summary"), isOn: $aiSummaryEnabled)
                }

                if aiSummaryEnabled {
                    Section(header: Text(localizedText("options"))) {
                        Toggle(localizedText("search_indexing"), isOn: $aiSearchEnabled)
                        Toggle(localizedText("auto_meeting_notes"), isOn: $aiAutoMeetingNotesEnabled)
                    }
                }
            }
            .navigationTitle(localizedText("ai_summary_search"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizedText("done")) { 
                        dismiss() 
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private func localizedText(_ key: String) -> String {
        switch key {
        case "ai_summary":
            return languageManager.currentLanguage == .korean ? "AI 요약" : "AI Summary"
        case "ai_footer":
            return languageManager.currentLanguage == .korean ? 
                "요약 및 검색 기능은 기기 성능과 네트워크 상태에 따라 달라질 수 있습니다." : 
                "Summary and search features may vary depending on device performance and network conditions."
        case "enable_summary":
            return languageManager.currentLanguage == .korean ? "요약 활성화" : "Enable Summary"
        case "options":
            return languageManager.currentLanguage == .korean ? "옵션" : "Options"
        case "search_indexing":
            return languageManager.currentLanguage == .korean ? "과거 대화 검색 인덱싱" : "Search Indexing for Past Conversations"
        case "auto_meeting_notes":
            return languageManager.currentLanguage == .korean ? "그룹 회의록 자동 생성" : "Auto-Generate Group Meeting Notes"
        case "ai_summary_search":
            return languageManager.currentLanguage == .korean ? "AI 요약/검색" : "AI Summary/Search"
        case "done":
            return languageManager.currentLanguage == .korean ? "완료" : "Done"
        default:
            return key
        }
    }
}

// MARK: - 번역 채팅 설정 뷰
struct TranslationSettingsView: View {
    @Binding var translationEnabled: Bool
    @Binding var translationAutoDetect: Bool
    @Binding var translationTargetLanguage: String
    @Binding var translationShowOriginal: Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: LanguageManager

    private var languages: [(code: String, name: String)] {
        [
            ("auto", localizedText("auto_detect")),
            ("en", localizedText("english")),
            ("ja", localizedText("japanese")),
            ("ko", localizedText("korean")),
            ("zh-Hans", localizedText("chinese_simplified")),
            ("zh-Hant", localizedText("chinese_traditional")),
            ("es", localizedText("spanish")),
            ("fr", localizedText("french")),
            ("de", localizedText("german"))
        ]
    }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text(localizedText("translation"))) {
                    Toggle(localizedText("enable_translation"), isOn: $translationEnabled)
                }

                if translationEnabled {
                    Section(header: Text(localizedText("options"))) {
                        Toggle(localizedText("auto_language_detect"), isOn: $translationAutoDetect)
                        Toggle(localizedText("show_original"), isOn: $translationShowOriginal)
                    }

                    Section(header: Text(localizedText("default_target_language")), footer: Text(localizedText("language_footer"))) {
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
            .navigationTitle(localizedText("translation_chat"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizedText("done")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private func localizedText(_ key: String) -> String {
        switch key {
        case "translation":
            return languageManager.currentLanguage == .korean ? "번역" : "Translation"
        case "enable_translation":
            return languageManager.currentLanguage == .korean ? "번역 활성화" : "Enable Translation"
        case "options":
            return languageManager.currentLanguage == .korean ? "옵션" : "Options"
        case "auto_language_detect":
            return languageManager.currentLanguage == .korean ? "자동 언어 감지" : "Auto Language Detection"
        case "show_original":
            return languageManager.currentLanguage == .korean ? "원문 함께 표시" : "Show Original Text"
        case "default_target_language":
            return languageManager.currentLanguage == .korean ? "기본 대상 언어" : "Default Target Language"
        case "language_footer":
            return languageManager.currentLanguage == .korean ? 
                "채팅별로 다른 언어를 설정할 수 있도록 별도 옵션을 제공할 수 있습니다." : 
                "You can provide separate options to set different languages for each chat."
        case "translation_chat":
            return languageManager.currentLanguage == .korean ? "번역 채팅" : "Translation Chat"
        case "done":
            return languageManager.currentLanguage == .korean ? "완료" : "Done"
        
        // 언어 이름들
        case "auto_detect":
            return languageManager.currentLanguage == .korean ? "자동 감지" : "Auto Detect"
        case "english":
            return languageManager.currentLanguage == .korean ? "영어" : "English"
        case "japanese":
            return languageManager.currentLanguage == .korean ? "일본어" : "Japanese"
        case "korean":
            return languageManager.currentLanguage == .korean ? "한국어" : "Korean"
        case "chinese_simplified":
            return languageManager.currentLanguage == .korean ? "중국어(간체)" : "Chinese (Simplified)"
        case "chinese_traditional":
            return languageManager.currentLanguage == .korean ? "중국어(번체)" : "Chinese (Traditional)"
        case "spanish":
            return languageManager.currentLanguage == .korean ? "스페인어" : "Spanish"
        case "french":
            return languageManager.currentLanguage == .korean ? "프랑스어" : "French"
        case "german":
            return languageManager.currentLanguage == .korean ? "독일어" : "German"
        
        default:
            return key
        }
    }
}

// MARK: - 자폭 메시지 데모 뷰
struct DisappearingMessageDemoView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: LanguageManager
    @State private var enabled: Bool = false
    @State private var seconds: Int = 10

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text(localizedText("feature"))) {
                    Toggle(localizedText("enable"), isOn: $enabled)
                }

                if enabled {
                    Section(header: Text(localizedText("duration")), footer: Text(localizedText("footer"))) {
                        Stepper(value: $seconds, in: 5...300, step: 5) {
                            HStack {
                                Text(localizedText("auto_delete_after"))
                                Spacer()
                                Text(localizedText("seconds_value", seconds: seconds))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section(header: Text(localizedText("preview_header"))) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localizedText("preview_title"))
                            .font(.headline)
                        Text(localizedText("preview_desc", seconds: seconds))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(localizedText("title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizedText("done")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func localizedText(_ key: String, seconds: Int = 0) -> String {
        switch key {
        case "title":
            return languageManager.currentLanguage == .korean ? "자폭 메시지" : "Disappearing Messages"
        case "feature":
            return languageManager.currentLanguage == .korean ? "기능" : "Feature"
        case "enable":
            return languageManager.currentLanguage == .korean ? "자폭 메시지 활성화" : "Enable Disappearing Messages"
        case "duration":
            return languageManager.currentLanguage == .korean ? "자동 삭제 시간" : "Auto-Delete Time"
        case "auto_delete_after":
            return languageManager.currentLanguage == .korean ? "보낸 후 자동 삭제" : "Auto delete after sending"
        case "seconds_value":
            return languageManager.currentLanguage == .korean ? "\(seconds)초" : "\(seconds) sec"
        case "footer":
            return languageManager.currentLanguage == .korean ?
                "이 설정은 새로 보내는 메시지에만 적용됩니다. 저장소 절약 및 프라이버시 보호에 도움이 됩니다." :
                "This applies to newly sent messages only. Helps save storage and protect privacy."
        case "preview_header":
            return languageManager.currentLanguage == .korean ? "미리보기" : "Preview"
        case "preview_title":
            return languageManager.currentLanguage == .korean ? "샘플 메시지" : "Sample Message"
        case "preview_desc":
            return languageManager.currentLanguage == .korean ?
                "이 메시지는 전송 후 \(seconds)초 뒤 자동으로 삭제됩니다." :
                "This message will disappear \(seconds) seconds after it is sent."
        case "done":
            return languageManager.currentLanguage == .korean ? "완료" : "Done"
        default:
            return key
        }
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
        .environmentObject(LanguageManager())
}

