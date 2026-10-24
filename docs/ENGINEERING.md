# Engineering notes

[English](ENGINEERING.md) · [한국어](ENGINEERING.ko.md) · [README](../README.md)

## What took iteration

L!NK has no backend: the other side of every chat is simulated, and every AI feature runs on the device's small on-device model. Most of the work went into making that model's output trustworthy in more than one language, and into keeping one codebase right on both iOS 26 and iOS 27. Each change below was tried on sample chats in Korean and English, with temporary probe tests that print the model's output, before it shipped. The commit messages tell each story in full.

### Making a small on-device model trustworthy

- **Meeting notes that don't invent tasks.** Early drafts padded the lists: "Should we invite Jordan?" became a task for the person who asked, and small talk about a hike became a to-do. Now each task has to quote the message it came from and say what that message does (a commitment, a request, a question), and the app keeps a task only when the quote is really in the chat. Owners come only from names the chat uses, and a request is never owned by its sender. Dates are read by `NSDataDetector`, not the model, after a bare "today" in a greeting was pinned to a noon nobody said. Six sample chats in English, Korean and both then came out with no invented tasks and no wrong owners.
- **Summaries of long chats.** The model reads about 4,000 tokens at once, so a long chat is cut into parts, the model takes notes on each part, and the summary is written from the notes, with the progress on screen. It took three rounds. Notes asked for as "four bullet points" copied each part's first lines. One summary of all the notes dwelt on how the chat began. And the model sometimes copied the prompt's own "[Write 2–3 sentences…]" placeholder, so the app now lays the summary out itself (guided generation). A 164-message trip-planning chat keeps both the dates settled at the start and the bookings made at the end.
- **One summary, two languages.** The English label for the reader's own messages, "Me", was read as a name ("Me will send the updated slides"). "You" fixed it; asking for the second person instead gave a stiff "당신" in Korean, so each language keeps its own label. Summary dates followed the device's region, so a Korean summary was dated in English; they now follow the app's language.
- **Replies in the right language.** The simulated other side used to answer from ten canned Korean lines ("Dinner at 7?" got "파일 잘 받았습니다 📄"). Now the on-device model answers what was said. Language detection needed guarding: on its own, "ok" was read as Polish and answered "Dobra.", and told to use "the user's language", the model picked Spanish. Detection is trusted only above 0.8 confidence, a short message is read together with earlier ones, and the app's language is the fallback.
- **Suggestions from the right side of the chat.** Suggested replies lost track of who was talking: "Congrats! When do you start?" got the suggestion "Congrats!". The transcript now marks Me and Them. An example answer in the prompt fixed it too, but then turned up word for word in unrelated chats, so it went.
- **Search by meaning across languages.** "저녁 약속" (dinner plans) should find "dinner tonight". Asked for related phrases, the model invented ones no message contains, so it returns single words. Asked for synonyms and translations together, it stayed in the search's language, so translations get a list of their own. And it translated the search as a whole ("dinner appointment"), so translations are matched word by word. The chat shows which words it added, so no match is a mystery.
- **Photo descriptions on iOS 27.** Asked in English for a Korean description, the model answered in English and then translated itself, so the request is now written in the language it should answer in. On iOS 26, photos work as before.
- **No translation beats a made-up one.** When neither Apple Intelligence nor the Translation framework could translate a message, the app fell back on a short phrasebook and on swapping Korean and English words one at a time, and showed the result as the translation. Now the line under the message says it couldn't translate.

### One codebase, iOS 26 and iOS 27

- **Swipe to reply.** `swipeActions` only works in a List, and the messages live in a ScrollView, so on iOS 26 a swipe to the right went to the system's swipe-back and left the chat. A SwiftUI drag gesture on the bubbles fixed the swipe but broke scrolling. The answer was a UIKit pan that starts only for a mostly sideways move to the right, which iOS 26's swipe-back waits for: a swipe on a bubble replies, and one beside it still goes back. Both were checked against the original behavior on iOS 26.5.
- **A test target that wouldn't load.** AppIntentsTesting (iOS 27) links a library iOS 26 doesn't have, and weak linking doesn't help when the framework itself is there, so the whole UI test bundle failed to load on iOS 26. The Siri tests moved to their own target, and the UI tests run on both versions again.
- **Staying on device.** Private Cloud Compute (iOS 27) could read a long chat in one go, but it needs a managed entitlement, and without one the first request crashes the app. Every AI feature stays on the device.

### SwiftUI state and concurrency

- **Sheets that showed stale results.** The meeting notes sheet opened on "Nothing to note yet" and stayed that way for seconds while the notes were being written. Its state lived in the chat view's `@State`, which only the sheet read, so setting it redrew nothing. It moved into an `@Observable` model the sheets read directly. The UI test written for it failed before the fix and passes after.
- **SwiftData across actors.** Summaries read SwiftData messages on the AI service's actor, racing with a disappearing message being deleted on the main thread. Swift 5 mode didn't flag it; the chat now hands the AI a `Sendable` copy.
- **A recording that froze the chat.** Holding the mic froze the whole chat: the audio session was switched on on the main thread, and the recorder switched it on again by itself when it started. In the simulator a 9-second press took over a minute to come back. Both now run off the main thread (`@concurrent`), and letting go before the recording has started calls it off cleanly.
- **Work nobody saw.** With translation on, every incoming message was translated twice, once for a dictionary nothing read, and every sent message once for nothing. That was real on-device inference; it's gone.

### Checking what the simulator can't

- Speech recognition doesn't run in the iOS simulator, so the transcription pipeline was checked on macOS with the same code: synthesized English and Korean sentences came back word for word. A test there caught the end of the audio being cut at a 1,024-frame boundary.
- The UI tests run on iPhone (iOS 26.5 and 27) and iPad, and the Siri actions run end to end through the system with AppIntentsTesting.

## Run on an iPhone

1. Open `TalkMVP.xcodeproj`, select the **TalkMVP** target → **Signing & Capabilities**, and choose your team. With a free Apple ID, also change the bundle identifier to something unique.
2. Connect the iPhone, pick it as the run destination and press **Run**.
3. With a free (personal) team, iOS blocks the first launch until you trust the developer: **Settings → General → VPN & Device Management → your Apple ID → Trust**. Free provisioning profiles expire after 7 days; running from Xcode again renews them.
4. On the sign-in screen, **Try Test Mode** opens the app with sample friends and chats — no account needed.

## Project structure

The app target is split by role: screens live in `Features/`, one folder per flow, and logic with no UI lives in `Services/`, `Repositories/` and `Models/`. `TalkMVP/` is a folder Xcode synchronizes into the target, so the folders on disk are the groups in Xcode.

```
link-mvp/
├── TalkMVP.xcodeproj/
├── TalkMVP/
│   ├── App/                     # Entry point and the tab shell
│   ├── Features/                # Screens, one folder per flow
│   │   ├── Auth/                # AuthView, SSOSignInView, AppLockView, OnboardingContactsView
│   │   ├── Chats/               # ChatListView
│   │   ├── Conversation/        # ChatView (+Friends/Helpers/Input/Media/Messages/Sheets), ChatViewModel,
│   │   │                        # MessageBubbleView, MeetingNotesView, ChatRoomBackgroundSettings, …
│   │   ├── Friends/             # FriendsView, FriendProfileView, FriendRowViews, AddFriendView, FriendManagementViews
│   │   └── Settings/            # SettingsView, SettingsCardComponents, ProfileEditView, *SettingsView pages,
│   │                            # HelpView, AppInfoView, TermsPoliciesView
│   ├── Services/                # Logic with no UI
│   │   ├── AI/                  # AIService, MeetingNotes (+Extractor/Grounding), ReplySuggestions, ReplyWriter,
│   │   │                        # MessageTranslation, MessageSearch, PhotoDescriber, VoiceTranscriber, …
│   │   ├── Auth/                # AuthManager, GoogleOAuthService, AppLockManager
│   │   ├── Chat/                # ChatService (+Protocol), AutoResponseService, OpenChatRooms, NotificationManager,
│   │   │                        # LocalNotificationDelegate
│   │   ├── Contacts/            # ContactsSyncService, FriendSearchService
│   │   ├── Location/            # LocationManager
│   │   └── Media/               # VoiceMessageService, AttachmentHandler, AttachmentPreviewer
│   ├── Intents/                 # ChatIntents, ChatIntentActions (Siri and Shortcuts)
│   ├── Models/                  # ChatRoom, Message, User (SwiftData)
│   ├── Repositories/            # SwiftData access behind protocols, attachment files, cleanup, the test account
│   ├── Localization/            # L10n, LanguageManager (+Extensions), LocalizationService
│   ├── DesignSystem/            # Brand colors, text size and accessibility preferences, touch targets
│   ├── AppShortcuts.xcstrings   # Siri phrases, in the app's five languages
│   ├── Localizable.xcstrings    # Siri and Shortcuts strings, in the same languages (the UI is localized in code)
│   └── Assets.xcassets/         # App icon, color sets, image assets
├── TalkMVPTests/
│   └── TalkMVPTests.swift       # Swift Testing suites
├── TalkMVPUITests/
│   ├── TalkMVPUITests.swift     # UI flows, on iPhone and iPad
│   └── TalkMVPUITestsLaunchTests.swift
├── TalkMVPSiriUITests/
│   └── SiriActionsUITests.swift # Siri actions run end to end with AppIntentsTesting (iOS 27 only)
└── docs/
    ├── ENGINEERING.md           # These notes
    └── screenshots/             # Images used in the README (kept out of the app bundle)
```

## Tests


```bash
# Unit tests (Swift Testing)
xcodebuild test -project TalkMVP.xcodeproj -scheme TalkMVP \
  -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TalkMVPTests

# UI tests — also run them on an iPad: the side-by-side layout test only runs in a regular-width window
xcodebuild test -project TalkMVP.xcodeproj -scheme TalkMVP \
  -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' -only-testing:TalkMVPUITests

# Siri and Shortcuts, run end to end with AppIntentsTesting — needs an iOS 27 simulator
xcodebuild test -project TalkMVP.xcodeproj -scheme TalkMVP \
  -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TalkMVPSiriUITests
```
