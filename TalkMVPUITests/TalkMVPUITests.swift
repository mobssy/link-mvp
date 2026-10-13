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
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
    }
}
