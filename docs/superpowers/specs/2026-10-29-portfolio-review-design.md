# Portfolio review fixes (stage 5 of the app-wide cleanup)

Date: 2026-10-29. Status: 5-1 to 5-7 done; 5-8 waits on the user.

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

## Outcome

| Item | Commit | Notes |
|---|---|---|
| 5-1 | 21a863d | As planned. The stored test mode flag only fed the bar and is gone. |
| 5-2 | 8306151 | As planned. The Start Chat UI test now checks the selected tab once the list is back. |
| 5-4 | bcb7095 | The summary's first paragraph is "<date> · <n messages>", shown as a caption with `apple.intelligence`. The fallback summary lost its emoji bullets too. |
| 5-5 | 0a7fd87 | Friend rows also said "online" with a green dot for everyone, and a profile said "Online" for five minutes after a message; both went with the chat title's random status. The profile shows when they last wrote. |
| 5-6 | c2d55ef | The study group's members are 佐藤ゆき (Japanese) and Lucía García (Spanish). Reply writers take an optional language. |
| 5-7 | b254189 | Small icons use the nearest text style, or `@ScaledMetric` where none matches (row avatars at 40 pt, the send and play buttons). |
| 5-3 | 0253fd1 | Built last. A grid keeps the divider from widening the bubble; its texts are told to wrap, which the AX5 screenshot showed they didn't. VoiceOver used to skip translations entirely; the message's label now includes it. |

Also: cea1126 makes a ChatService test wait for the connection instead of 200 ms; the new summary test held up the main actor and broke it in full runs.

Verification: each item's unit and UI suites ran on iOS 27 and 26.5 (207 unit tests at the end, plus the new UI tests), the Siri test on iOS 27 alone, and the UI suite on an iPad Pro 11-inch (iOS 27) at the end. With two simulators running at once, gesture tests (swipe and hold to reply), the meeting notes test and the Siri test sometimes failed waiting on the on-device model or a gesture; each passed when run alone. The swipe-to-reply test on iOS 26.5 also failed alone at times (once in three, then again in the last run), so it is flaky there beyond load. The translation test now waits for the answer and its translation separately, as each comes from the on-device model. From the end of this stage the user asked for testing on iOS 27 only. Three simulators at once ran the Mac out of resources. Screenshots on iOS 27: the group chat, a one-to-one chat, the summary sheet, sign-in, Friends, and the chat at the largest text size.

Small things left as they are:

- At the largest text sizes "Translated" breaks with a hyphen beside its symbol.
- The chat subtitle and language badges read the recent messages again each time the chat redraws; cheap at these sizes, but not cached.
- Not yet checked on the open iPhone Duo.
