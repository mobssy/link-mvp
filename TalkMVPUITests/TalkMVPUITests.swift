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

    @MainActor
    func testTestModeSignsInAndSignOutReturnsToSignIn() throws {
        app.launch()

        // Signed out: the sign-in screen offers test mode.
        let testModeButton = app.buttons["testModeButton"]
        XCTAssertTrue(testModeButton.waitForExistence(timeout: 10))
        testModeButton.tap()
        let startButton = app.alerts.buttons["Start Test"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        // Signed in: the tab interface replaces the sign-in screen.
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        XCTAssertTrue(tabBar.buttons["Friends"].exists)
        XCTAssertTrue(app.staticTexts["Test Mode"].exists)

        // Sign out from Settings.
        tabBar.buttons["Settings"].tap()
        let signOutButton = app.buttons["Sign Out"].firstMatch
        XCTAssertTrue(signOutButton.waitForExistence(timeout: 5))
        signOutButton.tap()
        let confirmSignOut = app.alerts.buttons["Sign Out"]
        XCTAssertTrue(confirmSignOut.waitForExistence(timeout: 5))
        confirmSignOut.tap()

        // Back on the sign-in screen.
        XCTAssertTrue(testModeButton.waitForExistence(timeout: 10))
        XCTAssertFalse(tabBar.exists)
    }

    @MainActor
    func testStartingChatFromFriendProfileSavesTheRoom() throws {
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        app.buttons["testModeButton"].tap()
        let startButton = app.alerts.buttons["Start Test"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))

        // Twice, to check the second time reuses the first room instead of adding another.
        for _ in 0..<2 {
            tabBar.buttons["Friends"].tap()
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
            XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        }

        // The conversation is a real room in the chat list, listed once.
        tabBar.buttons.element(boundBy: 1).tap()
        let rooms = app.staticTexts.matching(NSPredicate(format: "label == %@", "강호동"))
        XCTAssertTrue(rooms.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(rooms.count, 1)
    }

    @MainActor
    func testSwipingAMessageStartsAReply() throws {
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        app.buttons["testModeButton"].tap()
        let startButton = app.alerts.buttons["Start Test"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))

        tabBar.buttons["Chats"].tap()
        let firstRoom = app.cells.firstMatch
        XCTAssertTrue(firstRoom.waitForExistence(timeout: 5))
        firstRoom.tap()

        let input = app.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText("swipe me\n")

        // Messages live in a ScrollView, not a List; swipe actions there need iOS 27's
        // swipeActionsContainer().
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
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
    }
}
