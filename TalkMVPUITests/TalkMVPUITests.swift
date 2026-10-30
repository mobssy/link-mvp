//
//  TalkMVPUITests.swift
//  TalkMVPUITests
//
//  Created by David Song on 9/26/25.
//

import XCTest

final class TalkMVPUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Fresh in-memory store, English UI, and no contacts onboarding sheet in the way.
        app.launchArguments += [
            "-UITestingInMemoryStore",
            "-selectedLanguage", "en",
            "-contactsOnboardingShown", "YES"
        ]
    }

    /// A tab button, found by its label: the tab bar sits at the bottom on iPhone but at the
    /// top on iPad, where it is not exposed as `app.tabBars`.
    private func tab(_ name: String) -> XCUIElement {
        app.buttons[name].firstMatch
    }

    /// Enters test mode from the sign-in screen and waits for the tabs.
    private func signInWithTestMode() {
        let testModeButton = app.buttons["testModeButton"]
        XCTAssertTrue(testModeButton.waitForExistence(timeout: 10))
        testModeButton.tap()
        let startButton = app.alerts.buttons["Start Test"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()
        XCTAssertTrue(tab("Friends").waitForExistence(timeout: 10))
    }

    @MainActor
    func testTestModeSignsInAndSignOutReturnsToSignIn() throws {
        app.launch()

        // Signed out: the sign-in screen offers test mode. Signed in: the tabs replace it.
        signInWithTestMode()
        // Test mode doesn't put a bar on every screen; Settings' profile card says it.
        XCTAssertFalse(app.staticTexts["Test Mode"].exists)

        // Sign out from Settings.
        tab("Settings").tap()
        let signOutButton = app.buttons["Sign Out"].firstMatch
        XCTAssertTrue(signOutButton.waitForExistence(timeout: 5))
        signOutButton.tap()
        let confirmSignOut = app.alerts.buttons["Sign Out"]
        XCTAssertTrue(confirmSignOut.waitForExistence(timeout: 5))
        confirmSignOut.tap()

        // Back on the sign-in screen.
        XCTAssertTrue(app.buttons["testModeButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(tab("Chats").exists)
    }

    /// Sends `text` in the open chat and waits until the other side's answer is in and the
    /// translations have filled in, so nothing moves under a gesture that follows.
    private func sendAndWaitForTheAnswer(_ text: String) {
        let messages = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'message_'"))
        let before = messages.count
        let input = app.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText(text + "\n")
        let answered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count >= %d", before + 2), object: messages)
        XCTAssertEqual(XCTWaiter.wait(for: [answered], timeout: 90), .completed, "the other side answers")
        let translating = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Translating'")).firstMatch
        _ = translating.waitForNonExistence(timeout: 60)
        sleep(1)
    }

    /// Opens 강호동's profile from the Friends tab and starts the chat from it.
    private func startChatWithKang() {
        tab("Friends").tap()
        // The row is one button whose label combines the name and status; tapping it
        // hits the middle of the row, which must open the profile too.
        let friend = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "강호동")).firstMatch
        XCTAssertTrue(friend.waitForExistence(timeout: 5))
        friend.tap()
        let startChat = app.buttons["Start Chat"]
        XCTAssertTrue(startChat.waitForExistence(timeout: 5))
        startChat.tap()
    }

    @MainActor
    func testStartingChatFromFriendProfileSavesTheRoom() throws {
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        signInWithTestMode()

        // Twice, to check the second time reuses the first room instead of adding another.
        for _ in 0..<2 {
            startChatWithKang()

            // The chat opens in the Chats tab, not in a sheet over the profile.
            XCTAssertTrue(app.navigationBars.staticTexts["강호동"].waitForExistence(timeout: 10), "the conversation opens")
            XCTAssertFalse(app.buttons["Close"].exists, "the profile is gone")

            // Back to the chat list, as a person would before going to Friends again. In a
            // regular-width window the list is already beside the chat. On a phone the tab bar
            // hides in a chat, so the tab is checked once the list is back.
            if app.windows.firstMatch.frame.width < 600 {
                app.navigationBars.buttons.firstMatch.tap()
                XCTAssertTrue(app.navigationBars["Chats"].waitForExistence(timeout: 5))
            }
            XCTAssertTrue(tab("Chats").isSelected)
        }

        // The conversation is a real room in the chat list, listed once (the open chat's
        // title, beside the list on iPad, isn't a row).
        let rooms = app.cells.staticTexts.matching(NSPredicate(format: "label == %@", "강호동"))
        XCTAssertTrue(rooms.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(rooms.count, 1)
    }

    @MainActor
    func testStartChatInsideThatChatOnlyClosesTheProfile() throws {
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        signInWithTestMode()
        startChatWithKang()

        let input = app.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText("hi\n")
        let avatar = app.buttons["Profile of 강호동"].firstMatch
        XCTAssertTrue(avatar.waitForExistence(timeout: 60), "강호동 answers")
        avatar.tap()

        let startChat = app.buttons["Start Chat"]
        XCTAssertTrue(startChat.waitForExistence(timeout: 5))
        startChat.tap()
        XCTAssertTrue(startChat.waitForNonExistence(timeout: 5), "the profile closes")
        XCTAssertTrue(app.navigationBars.staticTexts["강호동"].exists, "the same chat is still open")
        XCTAssertTrue(input.exists)
    }

    @MainActor
    func testMessageMenuStartsAReply() throws {
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        signInWithTestMode()

        tab("Chats").tap()
        let firstRoom = app.cells.firstMatch
        XCTAssertTrue(firstRoom.waitForExistence(timeout: 5))
        firstRoom.tap()

        sendAndWaitForTheAnswer("hold me")

        let message = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'message_' AND label CONTAINS 'hold me'"))
            .firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        // On the bubble: the row spans the screen, and its middle is the empty side of the
        // user's own message.
        message.staticTexts["hold me"].press(forDuration: 1.2)

        let reply = app.buttons["Reply"]
        XCTAssertTrue(reply.waitForExistence(timeout: 3), "holding a message opens its menu")
        reply.tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 3), "the reply banner opens")
    }

    @MainActor
    func testSwipingAMessageStartsAReply() throws {
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        signInWithTestMode()

        tab("Chats").tap()
        let firstRoom = app.cells.firstMatch
        XCTAssertTrue(firstRoom.waitForExistence(timeout: 5))
        firstRoom.tap()

        sendAndWaitForTheAnswer("swipe me")

        // Messages live in a ScrollView rather than a List; swiping one must still
        // reveal its actions.
        let message = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'message_' AND label CONTAINS 'swipe me'"))
            .firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 5))

        // iOS 27 reveals a Reply button; on iOS 26 the swipe itself starts the reply once the
        // bubble has moved far enough, so the drag there has a set length: swipeRight()'s
        // depends on the element's size and the Xcode version, and fell short on this short
        // bubble after Xcode 27.1.
        if #available(iOS 27, *) {
            // From the bubble itself: the row spans the screen, and a swipe from its middle, the
            // empty side of the user's own message, sometimes did nothing. The action allows a
            // full swipe, so the reply may already have started and Reply slid away; only a
            // shorter swipe needs it tapped.
            let bubble = message.staticTexts["swipe me"]
            // From its left edge and not too far: the user's own bubble sits against the right
            // edge, and a drag that ran off the screen was sometimes dropped.
            let start = bubble.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 90, dy: 0)))
            let cancel = app.buttons["Cancel"]
            let reply = app.buttons["Reply"]
            let deadline = Date().addingTimeInterval(3)
            while !cancel.exists && !(reply.exists && reply.isHittable) && Date() < deadline {
                usleep(200_000)
            }
            if !cancel.exists {
                XCTAssertTrue(reply.exists && reply.isHittable, "swiping a message reveals Reply or starts the reply")
                reply.tap()
            }
        } else {
            let start = message.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
            start.press(forDuration: 0, thenDragTo: start.withOffset(CGVector(dx: 100, dy: 0)),
                        withVelocity: .fast, thenHoldForDuration: 0)
        }
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 3), "the reply banner opens")
    }

    @MainActor
    func testSenderAvatarIsAButtonThatOpensTheProfile() throws {
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        signInWithTestMode()

        tab("Chats").tap()
        app.staticTexts["Family Group"].firstMatch.tap()
        let input = app.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText("hi\n")

        // A button, so VoiceOver, Switch Control and keyboards can reach it, not just a tap.
        // In a group chat a member answers, so the avatar is theirs, not the group's.
        let avatar = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Profile of '")).firstMatch
        XCTAssertTrue(avatar.waitForExistence(timeout: 60), "the other side's bubble shows its avatar as a button")
        let member = String(avatar.label.dropFirst("Profile of ".count))
        XCTAssertNotEqual(member, "Family Group")
        avatar.tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5), "the profile opens")
        XCTAssertTrue(app.staticTexts[member].exists, "it is the member's profile")
    }

    @MainActor
    func testOneToOneChatWithAStrangerOffersAddFriendOnce() throws {
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        signInWithTestMode()

        // The sample chat with 김민지 is with someone who isn't a friend yet.
        tab("Chats").tap()
        app.staticTexts["김민지"].firstMatch.tap()
        let input = app.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText("hi\n")
        let reply = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Profile of '")).firstMatch
        XCTAssertTrue(reply.waitForExistence(timeout: 60), "the other side answers")

        // One Add Friend for the person, not one per message they sent.
        let addFriend = app.buttons.matching(NSPredicate(format: "label == 'Add Friend'"))
        XCTAssertEqual(addFriend.count, 1)
        addFriend.firstMatch.tap()
        let confirm = app.alerts.buttons["Add"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.staticTexts["Request Sent"].waitForExistence(timeout: 5))
        XCTAssertEqual(addFriend.count, 0)
    }

    @MainActor
    func testOpeningAChatShowsNoConnectionBanner() throws {
        // There is no server, so there is no connection to show being made.
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        signInWithTestMode()

        tab("Chats").tap()
        app.staticTexts["Family Group"].firstMatch.tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["connectionStatus"].exists)
        XCTAssertFalse(app.staticTexts["Connecting..."].exists)
    }

    @MainActor
    func testSearchOpensFromTheChatMenu() throws {
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        signInWithTestMode()

        tab("Chats").tap()
        app.staticTexts["Family Group"].firstMatch.tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 10))
        let search = app.searchFields.matching(NSPredicate(format: "placeholderValue == %@ OR label == %@", "Search conversation", "Search conversation")).firstMatch
        XCTAssertFalse(search.exists, "the conversation has the screen until search is asked for")

        app.buttons["More options"].firstMatch.tap()
        app.buttons["Search"].firstMatch.tap()
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.typeText("Saturday")
        // iPhone closes search with an X; on iPad the field takes the title's place with no
        // Close, and leaving it empty puts it away.
        let close = app.buttons["Close"].firstMatch
        if close.exists {
            close.tap()
        } else {
            app.buttons["Clear text"].firstMatch.tap()
            // Clearing may already end the editing, and the keyboard goes with it.
            sleep(1)
            let hide = app.keyboards.buttons["Hide keyboard"]
            if hide.exists && hide.isHittable { hide.tap() }
        }
        XCTAssertTrue(search.waitForNonExistence(timeout: 5), "closing puts it away")
        XCTAssertTrue(app.buttons["More options"].firstMatch.waitForExistence(timeout: 5), "the title and its menu are back")
    }

    @MainActor
    func testGroupTitleShowsItsMembers() throws {
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        signInWithTestMode()

        tab("Chats").tap()
        app.staticTexts["Family Group"].firstMatch.tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 10))

        app.navigationBars.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Family Group")).firstMatch.tap()
        let members = app.descendants(matching: .any)["groupMembers"]
        XCTAssertTrue(members.waitForExistence(timeout: 5), "the title opens the group's details")
        XCTAssertTrue(members.staticTexts["강호동"].exists)
        XCTAssertTrue(members.staticTexts["한소희"].exists)
        XCTAssertFalse(app.staticTexts["Profile information is unavailable"].exists)
    }

    @MainActor
    func testOpenChatOnAPhoneHasNoTabBar() throws {
        // As in Messages: on a phone an open conversation has the screen to itself, so its
        // bottom edge is the input field, not the input field over the tab bar.
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        try XCTSkipIf(app.windows.firstMatch.frame.width >= 600, "a regular-width window keeps its tabs")
        signInWithTestMode()

        tab("Chats").tap()
        app.staticTexts["김민지"].firstMatch.tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(tab("Friends").waitForNonExistence(timeout: 5), "the tab bar hides in a chat")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(tab("Friends").waitForExistence(timeout: 5), "and comes back with the chat list")
    }

    @MainActor
    func testATranslationIsPartOfItsMessage() throws {
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments += ["-translationEnabled", "YES"]
        app.launch()
        signInWithTestMode()

        // Written in Korean, so the answer comes back in Korean and the English reader gets
        // it translated.
        tab("Chats").tap()
        app.staticTexts["김민지"].firstMatch.tap()
        let input = app.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText("안녕하세요, 오늘 저녁 같이 먹을래요?\n")

        let reply = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Profile of '")).firstMatch
        XCTAssertTrue(reply.waitForExistence(timeout: 90), "the other side answers")

        // The translation is read with its message, not as a separate line after it. Both the
        // answer and its translation come from the on-device model, so each gets its own wait.
        let translated = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'message_' AND label CONTAINS 'Translated'"))
            .firstMatch
        XCTAssertTrue(translated.waitForExistence(timeout: 60), "the answer carries its translation")
    }

    @MainActor
    func testTranslationTurnsOffForOneChat() throws {
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments += ["-translationEnabled", "YES"]
        app.launch()
        signInWithTestMode()

        // 김민지 writes in Korean, so her messages come translated.
        tab("Chats").tap()
        app.staticTexts["김민지"].firstMatch.tap()
        let translated = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'message_' AND label CONTAINS 'Translated'"))
        XCTAssertTrue(translated.firstMatch.waitForExistence(timeout: 60), "translated to begin with")

        app.buttons["More options"].firstMatch.tap()
        app.buttons["Translate Messages"].firstMatch.tap()
        XCTAssertTrue(translated.firstMatch.waitForNonExistence(timeout: 5), "this chat shows the originals")
        XCTAssertTrue(app.staticTexts["Korean · Original"].waitForExistence(timeout: 5), "and says so under its name")

        // Kept for the chat: still off after leaving and coming back.
        if app.windows.firstMatch.frame.width < 600 {
            app.navigationBars.buttons.firstMatch.tap()
        }
        app.staticTexts["김민지"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Korean · Original"].waitForExistence(timeout: 5))
        XCTAssertFalse(translated.firstMatch.exists)
    }

    @MainActor
    func testReplySuggestionsHideWhileSearching() throws {
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        signInWithTestMode()

        tab("Chats").tap()
        app.staticTexts["Family Group"].firstMatch.tap()
        let input = app.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText("Dinner at 7?\n")

        let suggestions = app.descendants(matching: .any)["Suggested replies"].firstMatch
        guard suggestions.waitForExistence(timeout: 90) else {
            throw XCTSkip("No reply suggestions: they need Apple Intelligence")
        }
        // The results may not include the message the suggestions answer. On iPad the chat
        // list's search field is on screen too.
        app.buttons["More options"].firstMatch.tap()
        app.buttons["Search"].firstMatch.tap()
        let search = app.searchFields.matching(NSPredicate(format: "placeholderValue == %@ OR label == %@", "Search conversation", "Search conversation")).firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("dinner")
        XCTAssertTrue(suggestions.waitForNonExistence(timeout: 5), "searching hides the suggestions")
    }

    @MainActor
    func testWideWindowShowsChatListBesideConversation() throws {
        // A regular-width window (iPad, iPhone Duo's inner display) keeps the chat list on
        // screen next to the open conversation; compact windows push instead, which the
        // other tests cover.
        // Judged by the window, not the device: an unfolded iPhone Duo counts, a phone doesn't.
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        try XCTSkipUnless(app.windows.firstMatch.frame.width >= 600, "needs a regular-width window")
        signInWithTestMode()

        tab("Chats").tap()
        XCTAssertTrue(app.staticTexts["Select a Chat"].waitForExistence(timeout: 5), "no conversation is open yet")

        app.staticTexts["Family Group"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars.staticTexts["Family Group"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields.firstMatch.exists, "the conversation is open")
        let otherRoom = app.staticTexts["Study Group"].firstMatch
        XCTAssertTrue(otherRoom.isHittable, "the list stays on screen beside it")

        otherRoom.tap()
        XCTAssertTrue(app.navigationBars.staticTexts["Study Group"].waitForExistence(timeout: 5), "picking another room switches the conversation")
        XCTAssertFalse(app.staticTexts["Select a Chat"].exists)
    }

    @MainActor
    func testWideWindowShowsFriendsAndSettingsInTwoColumns() throws {
        // Like the Chats tab: in a regular-width window the list stays beside what it opened.
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        try XCTSkipUnless(app.windows.firstMatch.frame.width >= 600, "needs a regular-width window")
        signInWithTestMode()

        tab("Friends").tap()
        XCTAssertTrue(app.staticTexts["Select a Friend"].waitForExistence(timeout: 5), "no profile is open yet")
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "강호동")).firstMatch.tap()
        XCTAssertTrue(app.buttons["Start Chat"].waitForExistence(timeout: 5), "the profile opens beside the list")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "권지용")).firstMatch.isHittable,
                      "the list stays on screen")
        // Blocked from the open profile, the friend leaves the list and the column empties.
        app.buttons["Block"].firstMatch.tap()
        let confirmBlock = app.alerts.buttons["Block"]
        XCTAssertTrue(confirmBlock.waitForExistence(timeout: 5))
        confirmBlock.tap()
        XCTAssertTrue(app.staticTexts["Select a Friend"].waitForExistence(timeout: 5), "no stale profile is left open")

        tab("Settings").tap()
        XCTAssertTrue(app.staticTexts["Select a Setting"].waitForExistence(timeout: 5), "no page is open yet")
        app.buttons["Language"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Language"].waitForExistence(timeout: 5), "the page opens beside the list")
        XCTAssertTrue(app.buttons["Help"].firstMatch.isHittable, "the list stays on screen")
    }

    @MainActor
    func testMeetingNotesShowProgressUntilTheNotesAreWritten() throws {
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        signInWithTestMode()

        tab("Chats").tap()
        app.staticTexts["Family Group"].firstMatch.tap()
        let input = app.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        // A task with a date: the notes have something in them with or without Apple Intelligence.
        input.typeText("I'll bring the cake on Saturday at 6 PM.\n")
        // Wait for the other side's answer, so nothing else redraws the chat while the notes open.
        // The sample chat already has messages; the answer is the one after the user's.
        let messages = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'message_'"))
        let sent = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count >= 5"), object: messages)
        XCTAssertEqual(XCTWaiter.wait(for: [sent], timeout: 10), .completed, "the message is sent")
        let answered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count >= 6"), object: messages)
        XCTAssertEqual(XCTWaiter.wait(for: [answered], timeout: 90), .completed, "the other side answers")

        app.buttons["More options"].firstMatch.tap()
        let menuItem = app.buttons["Meeting Notes"].firstMatch
        XCTAssertTrue(menuItem.waitForExistence(timeout: 5))
        menuItem.tap()

        // From the moment the sheet opens it says the notes are being written; it used to open
        // on "Nothing to note yet" and keep that until something else redrew the chat.
        let writing = app.staticTexts["Writing meeting notes..."]
        let nothingToNote = app.staticTexts["Nothing to note yet"]
        let actionItems = app.staticTexts["Action Items"]
        XCTAssertTrue(writing.waitForExistence(timeout: 2) || actionItems.exists, "the sheet shows the notes are on their way")
        XCTAssertFalse(nothingToNote.exists)
        XCTAssertTrue(actionItems.waitForExistence(timeout: 120), "the notes replace the progress")
        XCTAssertFalse(nothingToNote.exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
    }
}
