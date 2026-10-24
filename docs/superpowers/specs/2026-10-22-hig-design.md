# HIG pass (stage 3 of the app-wide cleanup)

Date: 2026-10-22. Status: done.

## Context

Stage 2 (code modernization) is done; see `2026-10-22-code-modernization-design.md`. This stage changes what people see and how they reach things, following Apple's Human Interface Guidelines. Each item is its own commit.

The audit behind it: screenshots of the main screens at the default text size and at Accessibility XL, in light and dark, plus a code search for fixed font sizes, tap gestures, small controls and hard-coded colors.

## Items

### 3-1 Dynamic Type follows the system

The app root applies `.dynamicTypeSize(...)` from an in-app setting whose default is `.large`, so the system text size never reaches the app: at Accessibility XL every screen but the friend profile sheet stays at the default size.

- By default the app follows the system text size. The in-app text size stays as an optional override, turned on in Accessibility settings. Someone who had already picked a size other than the default keeps it.
- Text with a fixed point size (the sign-in buttons) uses text styles. Icons that sit beside text scale with `@ScaledMetric`.
- Layouts that break at accessibility sizes are fixed, checked with screenshots.
- A unit test pins the default to "follow the system".

### 3-2 In-app accessibility settings add to the system ones

The in-app Bold Text, Reduce Motion and High Contrast switches apply when either they or the matching system setting is on.

### 3-3 Buttons, not tap gestures

The bubble avatar, a photo, an attachment and the connection banner respond to `onTapGesture`, which VoiceOver, Switch Control and keyboards can't use. They become `Button`s with labels. Icon-only buttons are checked for labels.

### 3-4 44-point touch targets

The send and microphone buttons (32 pt) and the bubble avatar (36 pt) keep their look and get a 44-point hit area.

### 3-5 Consistency and hierarchy

- The Chats tab's title says "Chats", like the tab.
- Settings loses the "Settings" section header inside Settings; "Language Settings" becomes "Language".
- The friend profile's Block button, a large filled button right under Start Chat, becomes a plain destructive button with a confirmation. Info cards with nothing to show ("Last Active: No Info", "Mutual Friends 0") are hidden.
- Hard-coded colors (`.gray`, `.blue` and the like) become semantic ones where they mean "secondary" or "tint".

## Out of scope (stage 4)

The two Add Friend buttons in a conversation's toolbar, sheets opened over sheets, and the iPhone Duo layout.

## Verification

For each item: a warning-free build, the unit and UI tests on iOS 27, and before/after screenshots of the affected screens at the default size and Accessibility XL, light and dark. At the end: the full suite on iOS 26.5 too.

## Outcome

| Item | Commit | Notes |
|---|---|---|
| 3-1 | 7f2d84e | The in-app size is applied to the window scenes' trait overrides: a `.dynamicTypeSize` on the root view never reached sheets. At accessibility sizes the chat title is replaced by the system, so it isn't capped. |
| 3-2 | 2105c9d | `prefersReducedMotion` and `prefersHighContrast` in the environment combine the system setting with the app's switch; views read those instead of the system values. |
| 3-3 | 72ed67f | Photos had the VoiceOver label "Unable to load image"; they now describe the photo when there is a description. |
| 3-4 | d5e0463 | The send, microphone, attach and schedule buttons and the bubble avatar get 44 points. iOS already accepts taps up to 8 points outside the send button, so no UI test can tell the difference; the content shape makes it a guarantee. The microphone also became usable with VoiceOver: activate to start, again to send. |
| 3-5 | 955590d | As planned, plus the help answer that named "Language Settings". |

Found along the way and fixed separately, while retaking the README screenshots:

- Replies in a group chat came from the group itself ("Family Group" said "Sounds good!", and meeting notes made "Work Colleagues" a task owner). Sample groups now have members, and a member answers (b8a9dcc).
- Reply suggestions stayed under a search's results (44a410c).
- Group chats used an SF Symbol that doesn't exist, so they had no icon (efa5213).

Verification: the full suite passed on iOS 27 after each item. On iOS 26.5, all 197 unit tests and every UI test but one passed; the avatar test failed once because the keyboard didn't take focus while another simulator was capturing screenshots, and passed when run again on its own.

Left for stage 4: a translation repeats the original right under the bubble that already shows it ("Show original" is on by default), and group chats still show the one-to-one "Add Friend" button in the toolbar.

