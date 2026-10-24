# UX and navigation (stage 4 of the app-wide cleanup)

Date: 2026-10-24. Status: approved, in progress.

## Context

Stage 3 (HIG) is done; see `2026-10-22-hig-design.md`. This stage fixes how people move around the app: things that show twice, sheets that stack on sheets, and wide screens (iPhone Duo open, iPad) that show a stretched phone layout. Each item is its own commit, tested on iOS 26.5 and iOS 27 before it lands.

Goals: every action has one obvious place, no flow stacks a sheet on a sheet, and every tab uses the width of an open Duo. Non-goals: new features, visual restyling, localization changes (stage 5). Anti-goal: a phone user losing a path they had (every action removed from one place must still exist in another).

## Items

### 4-1 A translation shows once

The bubble already is the original text and the translation sits under it. With "Show original" on (the default) the original is printed again under the translation, so the same sentence shows twice.

- Remove the "Show original" toggle from Translation settings and the extra original line from `TranslatedTextView`. The `translationShowOriginal` stored value is no longer read.
- The README screenshot script's `-translationShowOriginal NO` argument becomes unnecessary.

### 4-2 One Add Friend per person

In a one-to-one chat with someone who isn't a friend, Add Friend is in the ⋯ menu and also on every bubble they sent. In a group chat it's on every bubble of each member who isn't a friend.

- One-to-one chat (`chatRoom.otherUserId != nil`) with a non-friend: one banner under the navigation bar, "<name> isn't your friend" with an Add Friend button, the same confirmation as today. After the request it reads "Request sent" (no button). Blocked: no banner; Unblock stays in the ⋯ menu. The ⋯ menu loses Add Friend.
- Bubbles lose the inline Add Friend button and "Request pending" text, in all chats.
- Group chat: the member's profile sheet (`MiniProfileSheet`, shown for members who aren't friends) gets an Add Friend button that sends the request, then shows "Request sent".
- The bubble's context menu keeps Add Friend, as a path that works the same everywhere for VoiceOver and keyboard users.

### 4-3 No sheet on a sheet

- Start Chat on a friend's profile closes the profile, switches to the Chats tab and opens that friend's one-to-one room (finding or creating it as `ChatViewContainer` does today). In a regular-width window the room opens in the split view's detail column; in a compact one it's pushed.
- An app-level router (`@Observable`, in the environment, behind a protocol) holds the selected tab and a room to open. `AuthenticatedTabsView` binds the tab to it; `ChatListView` reads the room to open, selects it, and clears it.
- When the profile was opened from inside the chat with that same person, Start Chat only closes the profile.
- The profile's ⋯ menu "View Conversation" duplicates Start Chat and is removed.
- The Friends tab's ⋯ menu loses "Settings", which opened the whole Settings screen as a sheet; the Settings tab is one tap away.
- `ChatViewContainer` is no longer presented as a sheet; its find-or-create logic moves to where the router opens the room (or the container is deleted if nothing else uses it).

### 4-4 Two columns on wide screens

The Chats tab already uses `NavigationSplitView`. Friends and Settings are single `NavigationStack`s stretched across the Duo's inner display and iPad.

- Friends: `NavigationSplitView` with the friend list in the sidebar and the selected friend's profile in the detail column; an empty-state view when nothing is selected. In a compact window this collapses to a push, so on iPhone and the folded Duo tapping a friend pushes the profile instead of presenting a sheet (as Contacts does). The profile's Close button only shows when it's presented as a sheet (from a chat).
- Settings: `NavigationSplitView` with the settings list in the sidebar and the chosen page in the detail column, like Settings on iPad. In a compact window it pushes, as today.
- Selection is view state, so folding or unfolding the Duo keeps the open chat, friend or settings page.
- After this item: retake the README Duo image as a folded and open pair (the user folds the simulator in DeviceHub).

## Left to the builder

- The banner's exact look (glass capsule or plain bar), as long as it's one line and reads in both themes.
- Whether the Settings sidebar keeps its card styling or becomes a `List`; selection must work in both column layouts.
- Which rows in the Friends list are selectable (friends, new friends); request rows keep their accept and decline buttons.
- The router's name and file (`App/` is the place).

## Verification

- Unit tests (Swift Testing) for the router: switching tab and handing a room to open, and clearing it once read.
- UI tests: a one-to-one chat with a non-friend shows one Add Friend control; Start Chat from a profile lands in the Chats tab with that room open and no sheet; the iPad (or Duo) shows two columns in Friends and Settings.
- Full unit and UI suites on iOS 26.5 and iOS 27 before each commit; screenshots of the changed screens on iPhone, iPad and the open Duo.
