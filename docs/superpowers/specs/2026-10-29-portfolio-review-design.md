# Portfolio review fixes (stage 5 of the app-wide cleanup)

Date: 2026-10-29. Status: approved, in progress.

## Context

Stage 4 (UX and navigation) is done; see `2026-10-24-ux-navigation-design.md`. A design review of the README screenshots, written as a Human Interface reviewer would read them, found the screens' loudest element is a debug control, the chat's bottom edge stacks three bars, the app's core feature (translation) has its weakest visual treatment, and the chat title shows a presence the app cannot know. This stage fixes those. The localization unification planned as stage 5 moves after it.

Goals: the conversation is the loudest thing on a chat screen; a translation reads as part of its message; nothing on screen claims what the app can't know; a multilingual group shows who speaks what; text and icons follow the reader's text size. Non-goals: new features, a new visual identity. Anti-goal: a screen that looks calmer but loses a path someone had (test mode must stay findable; every translation still shows).

## Findings checked against the code

- Test mode's indicator is a `tabViewBottomAccessory`: an orange bar on every tab, above the tab bar. The sign-in button is an orange-to-red gradient.
- A chat keeps the tab bar, so on iPhone the bottom is the input field, the test mode bar and the tab bar.
- A translation is outside the bubble: a globe and footnote-size gray text.
- The summary sheet's title is "Conversation Summary" and the text's first line is "✨ **Conversation Summary**" again. The fallback summary starts with "📊" and uses emoji bullets.
- "Online" under a chat's title is `Int.random(in: 1...10) <= 8` every 30 seconds, in groups and one-to-one chats alike.
- Group avatars are all `person.fill`, and the sample groups' members all have Korean names.
- Fixed font sizes: 33, of which 32 are on icons and one on an emoji; no body text has a fixed size. The gaps are small inline icons (14 to 30 pt) that don't follow the text size, and the chat clamps text at `accessibility3`.

## Items

### 5-1 Test mode stays out of the way

- Remove the bottom accessory. Settings' profile card already says "Experiencing in test mode".
- The sign-in screen's test mode button becomes a standard bordered button (no gradient, no shadow); it keeps its identifier.

### 5-2 No tab bar inside a chat

- In a compact width (iPhone, folded Duo) an open chat hides the tab bar, so the bottom edge is the input field alone, as in Messages. Wide windows keep their columns and the tab bar.

### 5-3 A translation is part of its message

- The translation moves into the received bubble: the original, a hairline divider, then the translation at the same text size, with a small `translate` symbol and "Translated" over it.
- VoiceOver reads the bubble as the original, then "Translated", then the translation.
- Loading and "translation unavailable" show in the same place.

### 5-4 Summary without the repeated title

- The summary's first paragraph is the date and coverage line only; no title, no ✨. The fallback summary loses "📊" and its emoji bullets.
- The sheet shows that first line under the title as a quiet caption with the `apple.intelligence` symbol, marking the text as written by the on-device model. Siri's plain text still drops the first paragraph.

### 5-5 No made-up presence

- Remove the random online status and its polling.
- Under a one-to-one chat's title: the other person's language, when it is not the reader's, and that their messages are translated ("Japanese · Translated"). Nothing when it's the same language or not known yet.
- Under a group's title: its members' names ("강호동, 한소희"), shortened to the first names plus a count when long.

### 5-6 Who speaks what in a group

- A received message's avatar is the sender's initial on a color picked from their name, the same in every chat.
- A small language code badge (JA, ES) sits on the avatar when the sender writes in a language other than the reader's, worked out from their messages in this chat. No flags: a language is not a country.
- One sample group becomes multilingual: members who write in Japanese and Spanish, and the simulated reply from a member is written in that member's language.

### 5-7 Text size reaches icons

- Small inline icons in bubbles, the input bar and rows scale with Dynamic Type (`@ScaledMetric` or a text style). Large decorative icons (48 pt and up) stay as they are.
- Remove the chat's clamp at `accessibility3`; check the chat at the largest size (AX5).

### 5-8 README story (waits on the user)

- How L!NK differs from Live Translation in Messages, and whether older users were the original audience. Not written until the user answers.

## Left to the builder

- The avatar palette, as long as each color reads in both themes and with Increase Contrast.
- Where the members' language comes from in the sample data, as long as nothing on screen claims a language the app didn't see in their messages.

## Verification

- Unit tests (Swift Testing) for the logic: the chat subtitle, the avatar initial and color, the sender language badge, the summary's first paragraph, the reply language for a group member.
- UI tests: an open chat on iPhone has no tab bar; the received bubble contains its translation; signing in no longer shows the "Test Mode" bar.
- Full unit and UI suites on iOS 27 and iOS 26.5 before each commit; screenshots of the changed screens.
