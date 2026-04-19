//
//  LinkMVPApp.swift
//  L!nkMVP
//
//  Created by David Song on 9/26/25.
//

import SwiftUI
import SwiftData

@main
struct LinkMVPApp: App {
    @StateObject private var appLock = AppLockManager()
    @StateObject private var authManager: AuthManager
    @StateObject private var languageManager = LanguageManager()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("themeMode") private var themeMode: String = "system"
    @AppStorage("inAppBoldText") private var boldText = false
    @AppStorage("inAppReduceMotion") private var reduceMotion = false
    @AppStorage("inAppTextSizeStep") private var textSizeStep = 2

    init() {
        let context = ModelContext(sharedModelContainer)
        _authManager = StateObject(wrappedValue: AuthManager(modelContext: context))
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Message.self,
            ChatRoom.self,
            User.self,
            Friendship.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    private func dynamicTypeSizeForStep(_ step: Int) -> DynamicTypeSize {
        switch step {
        case 0: return .small
        case 1: return .medium
        case 3: return .xLarge
        case 4: return .xxLarge
        case 5: return .xxxLarge
        default: return .large  // step 2 = iOS 기본값
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(appLock)
                .environmentObject(languageManager)
                .tint(.appPrimary)
                .preferredColorScheme(themeMode == "light" ? .light : (themeMode == "dark" ? .dark : nil))
                .fontWeight(boldText ? .bold : .regular)
                .dynamicTypeSize(dynamicTypeSizeForStep(textSizeStep))
                .ignoresSafeArea(.all, edges: .all)
                .fullScreenCover(isPresented: Binding(get: { appLock.isLocked }, set: { _ in })) {
                    AppLockView()
                        .environmentObject(appLock)
                        .environmentObject(languageManager)
                }
                .task {
                    appLock.updateLockStateOnLaunch()
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            appLock.handleScenePhase(newPhase)
        }
    }
}
