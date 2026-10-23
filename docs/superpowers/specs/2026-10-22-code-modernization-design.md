# Code modernization (stage 2 of the app-wide cleanup)

Date: 2026-10-22. Status: approved in chat.

## Context

The app-wide cleanup runs in stages, each approved separately:

1. Folder hierarchy (done, a8621f2)
2. **Code optimization and modernization (this document)**
3. HIG: Dynamic Type, buttons instead of tap gestures, touch targets, semantic colors, visual hierarchy
4. UX and navigation, including the iPhone Duo redesign (AppNavigation, two columns in every tab)
5. Optional: one localization system instead of three

Security fixes found during stage 1 (App Lock bypass, unchecked passwords, SSO account collisions) were done first: ceaac8f, 8f4fa22, 4142267.

## Goal

No behavior changes. The code becomes faster where it measurably wastes work, follows SOLID where it doesn't, and uses current SwiftUI and Swift Concurrency APIs. Every item keeps the existing tests passing.

## Items, one commit each

### 2-1 Friend state per conversation, not per bubble

`MessageBubbleView.loadFriendState()` runs a SwiftData fetch on appear for every incoming bubble, so a conversation with N incoming messages does N fetches of the same answer. `ChatView` already works out whether the other person is a friend (`checkIfFriend`). The bubble receives that state from the conversation instead of fetching it.

### 2-2 FriendshipRepository

Chat rooms and messages go through repositories. Friendships don't: `FriendsView`, `FriendProfileView`, `ChatView+Friends`, `ChatListView`, `MessageBubbleView` and `SettingsView` build `FetchDescriptor`s themselves. Add `FriendshipRepositoryProtocol` and `LocalFriendshipRepository` in `Repositories/`, following `ChatRoomRepository`, and move those queries and writes behind it. Unit tests on an in-memory store.

### 2-3 ObservableObject to @Observable

Ten classes: `LanguageManager`, `ContactsSyncService`, `LocationManager`, `ChatViewModel`, `NotificationManager`, `AppLockManager`, `ChatService`, `VoiceMessageService`, `AuthManager`, `ChatViewModelContainer`.

- `@EnvironmentObject` (64 places) becomes `@Environment(T.self)`, `.environmentObject` becomes `.environment`, `@StateObject` becomes `@State`, `@ObservedObject` becomes a plain property or `@Bindable`.
- `ChatViewModelContainer` exists only to forward `objectWillChange`; it goes away.
- `objectWillChange.send()` calls go away; they were needed only where SwiftUI couldn't see a change.
- `ContactsSyncService` declares its own `objectWillChange`; it becomes ordinary observed state.
- Views then redraw only when a property they read changes.

### 2-4 Swift Concurrency instead of GCD

Eleven `DispatchQueue.main` uses become `Task` with `Task.sleep`, or run directly where the caller is already on the main actor. `LocationManager`'s delegate callbacks hop to the main actor.

### 2-5 Deprecated APIs

- `foregroundColor` (197 places) becomes `foregroundStyle`.
- `NavigationView` (2) becomes `NavigationStack`.
- `DateFormatter`s built inside views on every call (3) become `Date.formatted` styles.

### 2-6 One type, one file

- `LocationManager` leaves `ChatViewSupportingViews` for `Services/Location/`.
- `ChatViewContainer` leaves `FriendProfileView` for `Features/Conversation/`.
- `FullScreenImageView` leaves `MessageBubbleView`.
- `LocalNotificationDelegate` leaves `ChatService`.
- `Color(hex:)` leaves `ChatRoomBackgroundSettings` for `DesignSystem/`.

## Out of scope

- Localization: three systems coexist (`localize(ko:en:…)` inline, `L10n`, `LocalizationService`). Merging them is stage 5.
- Visual or behavior changes: stages 3 and 4.

## Verification

- Each item: a warning-free build, then the unit and UI tests on the iPhone 27 simulator (iOS 27).
- After 2-3: the full suite on iOS 26.5 as well.
- At the end: the Siri tests on iOS 27, and a launch over existing simulator data.
