# HIG pass (stage 3 of the app-wide cleanup)

Date: 2026-10-22. Status: approved in chat.

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
