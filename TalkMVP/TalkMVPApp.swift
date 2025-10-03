//
//  TalkMVPApp.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//

import SwiftUI
import SwiftData

@main
struct TalkMVPApp: App {
    @StateObject private var appLock = AppLockManager()
    @StateObject private var authManager: AuthManager
    @StateObject private var languageManager = LanguageManager()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let context = ModelContext(sharedModelContainer)
        _authManager = StateObject(wrappedValue: AuthManager(modelContext: context))
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Message.self,
            ChatRoom.self,
            User.self,
            Friendship.self,
            Poll.self,
            PollOption.self,
            PollVote.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(appLock)
                .environmentObject(languageManager)
                .ignoresSafeArea(.all, edges: .all)
                .fullScreenCover(isPresented: Binding(get: { appLock.isLocked }, set: { _ in })) {
                    AppLockView()
                        .environmentObject(appLock)
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
