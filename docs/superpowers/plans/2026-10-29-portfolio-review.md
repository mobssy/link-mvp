# Portfolio review fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the chat screen's conversation the loudest thing on it, as the stage 5 spec describes.

**Architecture:** Pure decisions (subtitle, avatar look, sender language, summary layout, reply language) are `nonisolated` value types with Swift Testing tests; views read them. No model schema change.

**Tech Stack:** SwiftUI (iOS 26 target, iOS 27 features behind `#available`), SwiftData, Swift Testing, XCUITest.

**Spec:** `docs/superpowers/specs/2026-10-29-portfolio-review-design.md`

## Global Constraints

- Deployment target iOS 26; tested on iOS 27 (iPhone 18 Pro) and iOS 26.5 (iPhone 17 Pro Max) before each commit.
- One commit per item, English messages with `fix:`/`feat:` prefixes, no attribution trailers.
- SF Symbols verified in the catalog: `translate`, `apple.intelligence`.
- New strings in the app's five languages (ko, en, ja, zh, es) through `languageManager.localize`.

## Review Focus

- A one-to-one chat whose partner has sent nothing yet: no subtitle, no badge.
- A sender whose messages mix languages: the badge follows their most recent text messages.
- An own message never gets a translation or badge.
- A group with many members: the subtitle stays one line.
- iPad: the tab bar stays; only compact width hides it.

---

### Task 1: Test mode stays out of the way (5-1)

**Files:** Modify `TalkMVP/App/ContentView.swift`; Test `TalkMVPUITests/TalkMVPUITests.swift`.

- [ ] Change `testTestModeSignsInAndSignOutReturnsToSignIn` to assert `app.staticTexts["Test Mode"]` does NOT exist after signing in; run, expect FAIL.
- [ ] Remove `bottomAccessory`, `TestModeIndicatorView`, `showTestModeIndicator`; restyle `TestModeButtonView` as `.buttonStyle(.bordered)` with `.controlSize(.large)`.
- [ ] Full suites on both simulators; commit `fix: keep test mode out of the way on every screen`.

### Task 2: No tab bar inside a chat (5-2)

**Files:** Modify `TalkMVP/Features/Conversation/ChatView.swift`; Test UI.

- [ ] UI test `testOpenChatHidesTheTabBarOnPhone`: open the "Friend" room; on width < 600 assert `tab("Friends")` is not hittable; FAIL first.
- [ ] `ChatView` applies `.toolbar(horizontalSizeClass == .compact ? .hidden : .automatic, for: .tabBar)`.
- [ ] Full suites; commit `fix: give an open chat the whole screen on iPhone`.

### Task 3: A translation is part of its message (5-3)

**Files:** Modify `MessageBubbleView.swift`, `ChatView+Messages.swift`, `ChatViewSupportingViews.swift`; Test UI.

- [ ] UI test: in a chat with a received message in another language, the translation text is inside the bubble's accessibility element (label contains "Translated"); FAIL first.
- [ ] `MessageBubbleView` takes `translation: MessageTranslation?` (`text`, `autoDetect`, `target`); `.text` case shows original, `Divider`, `TranslatedTextView` (restyled: `translate` symbol + "Translated" caption, translation in body size). The outside `TranslatedTextView` is removed.
- [ ] Full suites; commit `fix: show a translation inside its message`.

### Task 4: Summary without the repeated title (5-4)

**Files:** Modify `AIService.swift`, `ChatView.swift`, `ChatViewSupportingViews.swift`; Test `TalkMVPTests.swift`.

- [ ] Tests: `AIService.summaryHeading(date:coverage:)` is `"<date> · <coverage>"` with no "✨" or "**"; the fallback summary's first paragraph has no emoji; update `summaryIsPlainText`'s input to the new format. FAIL first.
- [ ] Write the heading through that function; drop 📊 and emoji bullets; the sheet shows paragraph 0 as a caption `Label(..., systemImage: "apple.intelligence")` and the rest as cards.
- [ ] Full suites; commit `fix: state the summary's title once`.

### Task 5: No made-up presence (5-5)

**Files:** Create `TalkMVP/Features/Conversation/ChatSubtitle.swift`; Modify `ChatView.swift`, `ChatViewModel.swift`; Test unit.

- [ ] Tests for `ChatSubtitle.text(isGroup:memberNames:partnerLanguage:readerLanguage:languageName:)`: group → names joined, more than 3 → first 2 + "+N"; one-to-one foreign → "Japanese · Translated"; same or nil → nil. FAIL first.
- [ ] Remove `isOnline` and its polling; the title view shows the subtitle when non-nil. Partner language: `SenderLanguage` (Task 6) over the partner's messages.
- [ ] Full suites; commit `fix: show what a chat really is under its title, not a made-up online status`.

### Task 6: Who speaks what in a group (5-6)

**Files:** Create `TalkMVP/Features/Conversation/SenderAvatar.swift`, `SenderLanguage.swift`; Modify `MessageBubbleView.swift`, `ChatView+Messages.swift`, `ContentView.swift` (`TestData`), `AutoResponseService.swift`, `ReplyWriter.swift`; Test unit.

- [ ] Tests: `SenderAvatar(name:)` initial is the first grapheme uppercased and its color index is the same across runs and in range; `SenderLanguage.code(of:in:)` reads the sender's last text messages and returns nil for none; `TestData.language(of:)` for the multilingual group's members; `AutoResponseService` asks writers for that member's language. FAIL first.
- [ ] Avatar view: initial on palette color with a language code badge when it differs from the reader's. Sample "study_group" members: one Japanese, one Spanish writer. `ReplyWriting.reply(to:as:language:)` with `language` overriding the detected one.
- [ ] Full suites; commit `feat: show who is who, and who speaks what, in a group chat`.

### Task 7: Text size reaches icons (5-7)

**Files:** Modify the small fixed icons in `MessageBubbleView.swift`, `ChatView+Input.swift`, `ChatViewSupportingViews.swift`, `FriendProfileView.swift`, `SettingsCardComponents.swift`, `LanguageSettingsView.swift`, `ProfileEditView.swift`; `ChatView.swift`.

- [ ] Replace fixed sizes under 48 pt with `@ScaledMetric` values (same base size); remove the `accessibility3` clamp.
- [ ] Screenshots of a chat at AX5 on iOS 27; full suites; commit `fix: let small icons and the chat follow the reader's text size`.

### Task 8: Record the outcome

- [ ] Spec Outcome table, status; commit `docs: record how stage 5, the portfolio review, turned out`.
