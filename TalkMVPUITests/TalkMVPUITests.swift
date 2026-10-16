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
        XCTAssertTrue(app.staticTexts["Test Mode"].exists)

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

    @MainActor
    func testStartingChatFromFriendProfileSavesTheRoom() throws {
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        signInWithTestMode()

        // Twice, to check the second time reuses the first room instead of adding another.
        for _ in 0..<2 {
            tab("Friends").tap()
            // The row is one button whose label combines the name and status; tapping it
            // hits the middle of the row, which must open the profile too.
            let friend = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "강호동")).firstMatch
            XCTAssertTrue(friend.waitForExistence(timeout: 5))
            friend.tap()
            let startChat = app.buttons["Start Chat"]
            XCTAssertTrue(startChat.waitForExistence(timeout: 5))
            startChat.tap()
            XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: 10) || app.textFields.firstMatch.waitForExistence(timeout: 1),
                          "the conversation opens")

            // Close the chat sheet, then the profile sheet.
            for _ in 0..<2 {
                app.swipeDown(velocity: .fast)
            }
            XCTAssertTrue(tab("Friends").waitForExistence(timeout: 5))
        }

        // The conversation is a real room in the chat list, listed once.
        tab("Chats").tap()
        let rooms = app.staticTexts.matching(NSPredicate(format: "label == %@", "강호동"))
        XCTAssertTrue(rooms.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(rooms.count, 1)
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

        let input = app.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText("hold me\n")

        let message = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'message_' AND label CONTAINS 'hold me'"))
            .firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        message.press(forDuration: 1.2)

        let reply = app.buttons["Reply"]
        XCTAssertTrue(reply.waitForExistence(timeout: 3), "holding a message opens its menu")
        reply.tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 3), "the reply banner opens")
    }

    @MainActor
    func testSwipingAMessageStartsAReply() throws {
        guard #available(iOS 27, *) else {
            throw XCTSkip("On iOS 26 a swipe in the conversation goes back to the chat list; replying there is in the message's menu.")
        }
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        signInWithTestMode()

        tab("Chats").tap()
        let firstRoom = app.cells.firstMatch
        XCTAssertTrue(firstRoom.waitForExistence(timeout: 5))
        firstRoom.tap()

        let input = app.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText("swipe me\n")

        // Messages live in a ScrollView rather than a List; swiping one must still
        // reveal its actions.
        let message = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'message_' AND label CONTAINS 'swipe me'"))
            .firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        message.swipeRight()

        let reply = app.buttons["Reply"]
        XCTAssertTrue(reply.waitForExistence(timeout: 3), "swiping a message reveals Reply")
        reply.tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 3), "the reply banner opens")
    }

    @MainActor
    func testWideWindowShowsChatListBesideConversation() throws {
        // A regular-width window (iPad, iPhone Duo's inner display) keeps the chat list on
        // screen next to the open conversation; compact windows push instead, which the
        // other tests cover.
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "needs a regular-width window")
        XCUIDevice.shared.orientation = .portrait
        app.launch()
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
        let messages = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'message_'"))
        let answered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count >= 2"), object: messages)
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
