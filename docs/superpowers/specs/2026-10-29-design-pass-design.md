# Design pass (stage 6 of the app-wide cleanup)

Date: 2026-10-29. Status: done.

## Context

Stage 5 fixed what a portfolio design review found; see `2026-10-29-portfolio-review-design.md`. The user then asked for more design work and for me to pick what to fix. I went through the main screens in light mode and proposed A to G; the user approved the recommendation: A, B and C first, then D with E, then F with G.

L!NK's aim, as the user put it: not an app for older people, but one that older people can use easily too. Two tests guide every item: would someone new to the app, or an older person, be confused here; and does the screen claim something the app can't know.

Goals: nothing on screen is staged or made up; the first screens (chat list, Friends) say something real at a glance; one person looks the same everywhere. Non-goals: new features, a new visual identity. Anti-goal: a path someone had going missing (search, notifications settings, a group's members).

Testing is on iOS 27 only, as the user asked; the deployment target stays iOS 26.

## Items

### A. No staged connection

Opening a chat painted the top of the screen orange with "Connecting...", then green "Connected" for three seconds: a simulated handshake with a server that doesn't exist.

- Remove the banner and the simulated connection (status, handshake, heartbeat). The app has no server and everything runs on the device, so going offline stops nothing; an offline banner would be a warning about nothing. Ruling: the proposal said "show offline only when really offline"; on reflection there is nothing to warn about, so nothing is shown.
- Asking for notification permission, which the connection used to trigger, stays where it happens now (the chat list's service), without the connection.

### B. Sample chats that say something

With the app open, a canned "Hello!" landed in a random room every 15 to 45 seconds, raising the unread badge (10 to 16 in a minute), and every room's preview read "Hello!" with a random unread count.

- Stop the random incoming messages, and with them the notifications they posted and the open-rooms bookkeeping that only kept them out of the open chat.
- Each sample room starts with a short conversation: the other side writes in their language (Korean for the friends and the 1:1 "Friend", Japanese and Spanish in the study group), the reader's lines are in the app's language. Previews, times and unread counts follow from those messages (unread = the messages after the reader's last one).
- The Korean friends answer in Korean, as the study group's members answer in theirs, so a reader in another language sees the translation at work.

### C. One face per person

Chat bubbles already show a sender's initial on a color (stage 5). Everywhere else a person is the same gray person icon.

- People: the same initial and color in the Friends list and request rows, a friend's profile, the profile cards for the signed-in user, a one-to-one room in the chat list, the member sheet.
- Groups: the first two members' initials, overlapped, in the chat list and wherever the group is shown.
- Organization rooms keep their own logo.

### D. Search when asked for

Every chat had a search field under the title, always on.

- The field shows when Search is chosen from the chat's ⋯ menu (first item) and goes away when the search is cancelled. Nothing else about search changes.

### E. Group details instead of a dead end

A group's own profile was a sheet saying "Profile information is unavailable".

- Tapping a chat's title opens what it's about: in a one-to-one chat, the person's profile (as tapping their avatar does); in a group, a group sheet with its members, each with their face, language badge, and Add Friend for those who aren't friends.
- The unavailable sheet is gone.

### F. Sign out before delete

- In Settings, Sign Out comes first; Delete Account is set apart at the very bottom, so it isn't the first red thing under a thumb.

### G. Plainer settings words

- Translation: say what each control does in plain words ("Detect the language of each message", "Translate into"), with a footer that explains the pair.
- Accessibility: the rows naming iOS features (VoiceOver and others) can't be tapped and only repeat iOS; replace them with one line saying the app follows the system settings.

## Left to the builder

- The sample conversations' wording, as long as each is short, plausible, and the reader's lines exist in the app's five languages.
- The group avatar's exact geometry.

## Verification

- Unit tests (Swift Testing) for: the sample chats (reader's lines in each app language, unread counts, members as in `TestData`), the Korean friends' language, the group avatar's initials.
- UI tests: opening a chat shows no connection banner; the chat list's previews aren't "Hello!"; search opens from the menu; the group title opens the member list.
- Unit and UI suites on iOS 27 (iPhone 18 Pro) before each commit, and the UI suite on iPad (iOS 27) at the end; screenshots of the changed screens.

## Outcome

| Item | Commit | Notes |
|---|---|---|
| A | 2d69cff | Ruling: no offline banner either; with no server, going offline stops nothing. |
| B | 075c9d3 | `SampleChats` builds the rooms. The one-to-one sample is 김민지 instead of a room called "Friend" ("Friend isn't your friend"). The Korean friends answer in Korean. The random messages' notifications went with them. |
| C | 2941289 | `GroupAvatar` (first two members). Requests not yet accepted, blocked and hidden friends show their face in gray. |
| D, E | 0ce4001, 9a4fd9a, 64d62d7 | Search is the menu's first item and opens focused. On iPad the field takes the title bar's place with no Close button, so leaving it empty closes it (9a4fd9a); the message field lets go of the keyboard first, or search closed at once while typing. The mini profile lost its "unavailable" line too. |
| F, G | 01ea7da | Ruling: Auto Detect is gone from Translation settings, as it changed nothing visible (the Translation framework detects either way). Spanish was missing from "Translate Into" and is added. |

Tests: the swipe-to-reply UI test failed in most full runs. On iOS 27 the action allows a full swipe, so Reply had already slid away (f766ac5); `swipeRight()` started on the empty side of the row (a1d407b); and on iPad the reply started after more than a second (5d97f64). With the three fixes it passed the last full run and every run alone. The search fixes (9a4fd9a, 64d62d7) came from the iPad run and the reply suggestions test.

Verification: unit and UI suites on iOS 27 (iPhone 18 Pro) for each item; the last full run passed all 232 tests (two wide-window tests skipped). On the iPad Pro 11-inch (iOS 27) the UI suite passed except tests that later passed alone or were fixed above. Screenshots in light mode: Friends, a friend's profile, the chat list, the study group, its member sheet, the chat menu, search, the 김민지 chat, Settings, Translation and Accessibility settings.

Small things left as they are:

- Opening or closing search rebuilds the conversation, so its translations show "Translating..." and are made again.
- The signed-in user's card in Friends keeps its green dot.
- Seed messages are only added to an empty chat list; an existing install keeps its old "Hello!" rooms until it is reset.
