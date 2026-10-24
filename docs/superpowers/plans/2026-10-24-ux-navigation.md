# UX and Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every action has one place, no sheet opens on a sheet, and Friends and Settings use two columns on wide screens.

**Architecture:** Four commits, one per spec item. A small `@Observable` router in the environment carries "switch to Chats and open this room". Friends and Settings move to `NavigationSplitView` like Chats already is; a friend's profile stops owning a `NavigationStack` so it can be pushed or put in a detail column.

**Tech Stack:** SwiftUI (iOS 26 target, iOS 27 SDK), SwiftData, Swift Testing, XCTest UI tests.

**Spec:** `docs/superpowers/specs/2026-10-24-ux-navigation-design.md`

## Global Constraints

- Deployment target stays iOS 26; iOS 27 APIs only behind `#available`.
- SOLID: the router is reached through a protocol; large views split into `TypeName+Concern.swift`.
- Strings in all five app languages (ko, en, ja, zh, es), through the file's existing helper (`L10n.text`, `languageManager.localize`, or the file's `localizedText`).
- New SF Symbols checked against the iOS 26 runtime's `name_availability.plist`.
- Each commit: build without warnings, unit + UI suites pass on iOS 26.5 (6C65CA04…) and iOS 27 (99AACAD0…) via `scratchpad/verify.sh`; English commit message, no trailers; no push.

## Review Focus

- A chat whose other side has no `otherUserId` (the sample "Friend" room): the banner still offers Add Friend, by name. Test in Task 2.
- Start Chat when the Chats tab has never been opened (its view isn't built yet): the room still opens. Test in Task 3 (the UI test starts on Friends).
- Blocking or hiding the friend whose profile is in the detail column: the column goes back to the empty state rather than showing a stale profile. Checked by hand in Task 4.
- Folding the Duo with a friend or settings page open: it stays open. Checked by hand in Task 4 on the Duo sim.
- Start Chat from a profile opened inside that same chat: the sheet just closes, no tab switch. Test in Task 3.

---

### Task 1: A translation shows once (4-1)

**Files:**
- Modify: `TalkMVP/Features/Conversation/ChatViewSupportingViews.swift` (`TranslatedTextView`: drop `showOriginal` and its `Text`)
- Modify: `TalkMVP/Features/Conversation/ChatView+Messages.swift:176-181`, `TalkMVP/Features/Conversation/ChatView.swift:104` (drop the `translationShowOriginal` storage and argument)
- Modify: `TalkMVP/Features/Settings/TranslationSettingsView.swift` (drop the toggle, its `@AppStorage`, and the `translation_show_original` string)

- [ ] Step 1: Make the edits; `grep -rn translationShowOriginal TalkMVP` returns nothing.
- [ ] Step 2: Build; screenshot Study Group with translation on (iOS 27): one translation line per bubble, no repeated original. Screenshot Translation settings: no Show original row.
- [ ] Step 3: Full suites on both runtimes pass.
- [ ] Step 4: Commit `fix: show a translation once, under its original`.

### Task 2: One Add Friend per person (4-2)

**Files:**
- Create: `TalkMVP/Features/Conversation/FriendBanner.swift`
- Modify: `TalkMVP/Features/Conversation/ChatView.swift` (banner under `ConnectionStatusView`; remove the ⋯ menu's Add Friend; member sheet arguments)
- Modify: `TalkMVP/Features/Conversation/ChatView+Friends.swift` (`requestFriendship()`)
- Modify: `TalkMVP/Features/Conversation/MessageBubbleView.swift:82-101` (remove inline button and pending text; keep the context menu)
- Modify: `TalkMVP/Features/Conversation/ChatViewSupportingViews.swift` (`MiniProfileSheet` gains Add Friend)
- Test: `TalkMVPTests/TalkMVPTests.swift` (new `@Suite("Friend banner")`), `TalkMVPUITests/TalkMVPUITests.swift`

**Interfaces:**
- Produces:
  ```swift
  enum FriendBanner: Equatable {
      case none, addFriend, requestSent
      /// What a chat shows under its navigation bar about the person it is with.
      init(isGroup: Bool, standing: FriendStanding?, isBlocked: Bool)
  }
  ```
  `standing == nil` means not known yet (no banner). Groups and blocked people get `.none`; `.stranger` → `.addFriend`; `.requested` → `.requestSent`; `.friend` → `.none`.
- `ChatView.requestFriendship()`: `addFriendToChatRoom()` when `chatRoom.otherUserId != nil`, else `try sendFriendRequest(toSender: chatRoom.name)`. The 1:1 standing is `isFriend`/`friendRequestSent` when the room has an `otherUserId`, else `senderStandings?[chatRoom.name] ?? .stranger` (once `senderStandings` is loaded).
- `MiniProfileSheet(name:symbol:standing: FriendStanding? = nil, onAddFriend: (() throws -> Void)? = nil)`: shows an Add Friend button when `standing == .stranger` and `onAddFriend != nil`, "Request Sent" text when `.requested` (local state flips after a successful send).

- [ ] Step 1: Write the failing tests:
  ```swift
  @Suite("Friend banner") struct FriendBannerTests {
      @Test func strangerInAOneToOneChat() { #expect(FriendBanner(isGroup: false, standing: .stranger, isBlocked: false) == .addFriend) }
      @Test func requestAlreadySent() { #expect(FriendBanner(isGroup: false, standing: .requested, isBlocked: false) == .requestSent) }
      @Test func nothingForFriendsGroupsBlockedOrUnknown() {
          #expect(FriendBanner(isGroup: false, standing: .friend, isBlocked: false) == .none)
          #expect(FriendBanner(isGroup: true, standing: .stranger, isBlocked: false) == .none)
          #expect(FriendBanner(isGroup: false, standing: .stranger, isBlocked: true) == .none)
          #expect(FriendBanner(isGroup: false, standing: nil, isBlocked: false) == .none)
      }
  }
  ```
  UI test `testOneToOneChatWithAStrangerOffersAddFriendOnce`: open Chats → "Friend", send "hi", wait for the reply bubble (`message_` identifier, not from me); `app.buttons.matching(label == "Add Friend").count == 1`; tap it, confirm the alert, then `staticTexts["Request Sent"]` exists and no "Add Friend" button remains.
- [ ] Step 2: Run them; they fail (no `FriendBanner`; two or more Add Friend buttons).
- [ ] Step 3: Implement `FriendBanner`, the banner view (one line: text "<name> isn't your friend" + bordered Add Friend button, or "Request Sent"), `requestFriendship()`, and the alert reuse; remove the menu item and the bubbles' inline controls; extend `MiniProfileSheet` and pass `senderStandings?[name]` and `sendFriendRequest(toSender:)` from `ChatView`'s profile sheet.
- [ ] Step 4: Tests pass; full suites on both runtimes pass.
- [ ] Step 5: Commit `fix: offer Add Friend once per person in a chat`.

### Task 3: Start Chat switches tabs instead of stacking sheets (4-3)

**Files:**
- Create: `TalkMVP/App/AppRouter.swift`
- Modify: `TalkMVP/App/ContentView.swift` (tab selection from the router; reset to `.friends` where it resets to `0` today)
- Modify: `TalkMVP/Features/Chats/ChatListView.swift` (open the handed room)
- Modify: `TalkMVP/Features/Friends/FriendProfileView.swift` (Start Chat; remove View Conversation and the chat sheet)
- Modify: `TalkMVP/Features/Conversation/ChatView.swift` (profile sheet passes `isInChatWithThisPerson: true` when it shows the room's own person)
- Modify: `TalkMVP/Features/Friends/FriendsView.swift` (remove `.settings` sheet case and menu item)
- Delete: `TalkMVP/Features/Conversation/ChatViewContainer.swift` (its find-or-create moves to `FriendProfileView.startChat()`)
- Test: `TalkMVPTests/TalkMVPTests.swift` (`@Suite("AppRouter")`), `TalkMVPUITests/TalkMVPUITests.swift`

**Interfaces:**
- Produces:
  ```swift
  enum AppTab: Hashable { case friends, chats, settings }

  @MainActor protocol AppRouting: AnyObject {
      var selectedTab: AppTab { get set }
      /// Switches to Chats and asks it to open `roomID`.
      func openChat(_ roomID: UUID)
      /// The room Chats should open, handed over once.
      func takeRoomToOpen() -> UUID?
  }

  @MainActor @Observable final class AppRouter: AppRouting { … }
  ```
  `AppRouter` is created in `ContentView` and put in the environment (`.environment(router)`); views read `@Environment(AppRouter.self)`.
- `FriendProfileView(friendship:, isInChatWithThisPerson: Bool = false)`.

- [ ] Step 1: Write the failing tests:
  ```swift
  @Suite("AppRouter") @MainActor struct AppRouterTests {
      @Test func openChatSwitchesToChatsAndHandsTheRoomOnce() {
          let router = AppRouter(); let id = UUID()
          router.openChat(id)
          #expect(router.selectedTab == .chats)
          #expect(router.takeRoomToOpen() == id)
          #expect(router.takeRoomToOpen() == nil)
      }
      @Test func startsOnFriends() { #expect(AppRouter().selectedTab == .friends) }
  }
  ```
  Rewrite `testStartingChatFromFriendProfileSavesTheRoom`: twice — Friends tab → 강호동 → Start Chat → `navigationBars.staticTexts["강호동"]` exists, `buttons["Close"]` doesn't, `tab("Chats").isSelected`; go back to the list (`navigationBars.buttons.firstMatch` in compact). Then exactly one "강호동" row. New `testStartChatInsideThatChatOnlyClosesTheProfile`: open the 강호동 room this way, tap the avatar of one of their messages (send "hi" first), Start Chat → the profile closes and the same chat is on screen.
- [ ] Step 2: Run; fail (no `AppRouter`; Start Chat opens a sheet).
- [ ] Step 3: Implement the router, wire `ContentView`/`AuthenticatedTabsView` (`TabView(selection:)` on `AppTab` tags), `ChatListView` `.onChange(of: router.roomToOpenMarker, initial: true)` (or an equivalent observable value) that sets `selectedRoomID = router.takeRoomToOpen()`, and `FriendProfileView.startChat()` (`directChatRoom(withUserId:name:email:)`, then `router.openChat(room.id)`, then `dismiss()`; if `isInChatWithThisPerson`, only `dismiss()`).
- [ ] Step 4: Tests pass; full suites on both runtimes pass.
- [ ] Step 5: Commit `fix: open a chat from a profile in the Chats tab, not in another sheet`.

### Task 4: Two columns in Friends and Settings (4-4)

**Files:**
- Modify: `TalkMVP/Features/Friends/FriendProfileView.swift` (no own `NavigationStack`; Close button only when `showsCloseButton`)
- Modify: `TalkMVP/Features/Conversation/ChatView.swift` (profile sheet wraps `FriendProfileView` in a `NavigationStack` with `showsCloseButton: true`)
- Modify: `TalkMVP/Features/Friends/FriendRowViews.swift` (`FriendRow` becomes a `NavigationLink(value: friendship.id)` label; its sheet goes)
- Modify: `TalkMVP/Features/Friends/FriendsView.swift` (`NavigationSplitView`, `List(selection: $selectedFriendID)`, detail = profile or `ContentUnavailableView`; `onOpened` runs when the selection changes; selection cleared when the friend leaves the accepted list)
- Modify: `TalkMVP/Features/Settings/SettingsView.swift` (+ new `SettingsView+Pages.swift` if the file grows: `enum SettingsPage: Hashable` with one case per linked page and `@ViewBuilder func page(_:)`)
- Modify: `TalkMVP/Localization/L10n.swift` (`select_friend`, `select_friend_hint`, `select_setting`, `select_setting_hint`)
- Test: `TalkMVPUITests/TalkMVPUITests.swift`

**Interfaces:**
- `FriendProfileView(friendship:, isInChatWithThisPerson: Bool = false, showsCloseButton: Bool = false)`.
- Settings sidebar keeps its cards; rows become `NavigationLink(value: SettingsPage.x)` with `.navigationDestination(for: SettingsPage.self)` on the sidebar, which in a split view replaces the detail column. If that doesn't select in the regular layout, fall back to `List(selection:)` (the spec leaves this to the builder) and note it in the commit.

- [ ] Step 1: Write the failing UI test `testWideWindowShowsFriendsAndSettingsInTwoColumns` (skip unless window width ≥ 600, like the Chats one): Friends shows "Select a Friend"; tap 강호동 → "Start Chat" visible and the 권지용 row still hittable. Settings shows "Select a Setting"; tap Language → the language page's title shows in the detail column and the Help row is still hittable. Update `testSenderAvatarIsAButtonThatOpensTheProfile` and the Task 3 tests if their Close/back expectations change in compact (profile pushed in Friends, sheet with Close in chats).
- [ ] Step 2: Run on the iPad Pro 11-inch (M4) iOS 27 sim; fail.
- [ ] Step 3: Implement as listed. On iPhone a friend's profile pushes; from a chat it stays a sheet.
- [ ] Step 4: Tests pass on iPad and both iPhone runtimes. By hand on the Duo sim (open): two columns in all three tabs; select a friend and a settings page, then ask the user to fold and check they stay open. Block a friend from the detail column: the empty state returns.
- [ ] Step 5: Commit `feat: show Friends and Settings in two columns on wide screens`.

### Task 5: Close out

- [ ] Spec status → done with an Outcome table (commits, anything that changed from the spec); progress memory updated.
- [ ] README: drop `-translationShowOriginal NO` from the capture notes if mentioned; retake the Duo image as a folded+open pair once the user folds the sim (`compose_duo.py`).
- [ ] Commit `docs: record how stage 4, UX and navigation, turned out`.
