# Design pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove what's staged or made up on the first screens and give each person one face, as the stage 6 spec describes.

**Architecture:** Sample data is a pure `SampleChats` builder (tested), inserted by the chat list. Avatars are `SenderAvatarView` (stage 5) plus a `GroupAvatarView`. `ChatService` loses its simulated connection and messages.

**Tech Stack:** SwiftUI, SwiftData, Swift Testing, XCUITest; iOS 27 simulators only.

**Spec:** `docs/superpowers/specs/2026-10-29-design-pass-design.md`

## Global Constraints

- Test on iOS 27 only (iPhone 18 Pro; iPad Pro 11-inch at the end). Deployment target stays iOS 26.
- One commit per item (D with E and F with G may share), English messages, no attribution trailers.
- New strings in ko, en, ja, zh, es.

## Review Focus

- A chat list with a room deleted and re-seeded: no duplicate sample rooms.
- A reader whose app language is Korean: Korean sample lines show no translation.
- Search: cancelling clears the results and hides the field.
- A group with one member: the group avatar shows one initial.
- A 1:1 room whose name is a friend: the title opens their profile, not the mini sheet.

---

### Task 1 (A): No staged connection

- [ ] UI test `testOpeningAChatShowsNoConnectionBanner`: open "Family Group"; `connectionStatus` element must not exist after 1 s. FAIL first.
- [ ] Remove `ConnectionStatusView`, `ChatService.ConnectionStatus`, `startConnection`/`disconnect`/`reconnect`/heartbeat; keep notification permission on first context; drop the three connection tests and `connection_status` string.
- [ ] Unit + UI on iOS 27; commit `fix: stop staging a server connection every time a chat opens`.

### Task 2 (B): Sample chats that say something

- [ ] Unit tests for `SampleChats.rooms(readerLanguage:)`: four rooms; the reader's lines are in the given language for ko/en/ja/zh-Hans/es; unread = trailing others; members match `TestData.groupMembers`; `TestData.language(of: "강호동") == "ko"`. FAIL first.
- [ ] Remove random messages, `OpenChatRooms`, `.newMessageReceived`; `ChatListView.createSampleDataIfNeeded` inserts `SampleChats` rooms and messages; the Korean friends get `"ko"` in `memberLanguages`. Fix UI tests that waited for a first message.
- [ ] Unit + UI; commit `fix: start the sample chats with real conversations, not random hellos`.

### Task 3 (C): One face per person

- [ ] Unit test `GroupAvatar.initials(members:)` (first two, one member, none). FAIL first.
- [ ] `GroupAvatarView`; use `SenderAvatarView`/`GroupAvatarView` in Friends rows, request/blocked/hidden/search rows, `FriendProfileView`, my profile cards, `ChatRoomRow`, `MiniProfileSheet`.
- [ ] Unit + UI; screenshots; commit `feat: give each person one face across the app`.

### Task 4 (D, E): Search on request, group details

- [ ] UI tests: search field absent until ⋯ → Search; tapping a group title shows its members. FAIL first.
- [ ] `searchable(text:isPresented:)` with a menu item; title button → `openProfile(of:)` for 1:1, `GroupInfoSheet` for groups; remove the unavailable branch and string. Update `testReplySuggestionsHideWhileSearching`.
- [ ] Unit + UI; commit `feat: open search from the menu and show a group's members from its title`.

### Task 5 (F, G): Settings order and words

- [ ] Reorder Sign Out / Delete Account; translation and accessibility copy.
- [ ] UI suite; commit `fix: put sign out before delete and say what settings do`.

### Task 6: Outcome

- [ ] iPad UI suite; spec Outcome; commit `docs: record how stage 6, the design pass, turned out`.
