//
//  LinkMVPApp.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//

import AppIntents
import SwiftUI
import SwiftData
import os

private let appLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "App")

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
        // Use the container's main context: it is the same context `.modelContainer(_:)`
        // injects into the view hierarchy, so models AuthManager hands out (currentUser)
        // can be edited and saved from any view.
        let context = sharedModelContainer.mainContext
        _authManager = StateObject(wrappedValue: AuthManager(modelContext: context))
        // Siri and Shortcuts actions read and write the same store as the app's screens.
        let container = sharedModelContainer
        AppDependencyManager.shared.add(dependency: container)
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Message.self,
            ChatRoom.self,
            User.self,
            Friendship.self
        ])
        // UI tests pass this flag so every run starts signed out with an empty store.
        let inMemoryOnly = ProcessInfo.processInfo.arguments.contains("-UITestingInMemoryStore")
        // Try persistent store first; fall back to in-memory so the app stays alive
        // even if the on-disk store is corrupted (e.g. after a schema migration failure).
        if let container = try? ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemoryOnly)]) {
            return container
        }
        appLogger.error("Persistent store unavailable — falling back to in-memory store. Data will not persist this session.")
        if let container = try? ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]) {
            return container
        }
        fatalError("Could not create ModelContainer with any configuration.")
    }()

    private func cleanUpOrphanedData() {
        guard OrphanedDataCleaner.shouldRun(for: sharedModelContainer) else { return }
        do {
            try OrphanedDataCleaner(modelContext: sharedModelContainer.mainContext).run()
        } catch {
            appLogger.error("Orphaned data cleanup failed: \(error.localizedDescription, privacy: .public)")
        }
    }

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
                .fullScreenCover(isPresented: Binding(get: { appLock.isLocked }, set: { _ in })) {
                    AppLockView()
                        .environmentObject(appLock)
                        .environmentObject(languageManager)
                }
                .task {
                    appLock.updateLockStateOnLaunch()
                    cleanUpOrphanedData()
                    // Lets Siri match chat names in phrases like "Summarize Family Group".
                    ChatShortcuts.updateAppShortcutParameters()
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            appLock.handleScenePhase(newPhase)
        }
    }
}
