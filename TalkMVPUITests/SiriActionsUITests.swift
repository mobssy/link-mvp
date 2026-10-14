//
//  SiriActionsUITests.swift
//  TalkMVPUITests
//
//  The Siri and Shortcuts actions, run through the system against the app
//

import AppIntentsTesting
import XCTest

final class SiriActionsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Sends a message and summarizes a chat the way Siri would, through AppIntentsTesting (new in
    /// iOS 27), against the running app signed into test mode.
    @MainActor
    func testSiriSendsAMessageAndSummarizesAChat() async throws {
        guard #available(iOS 27, *) else { throw XCTSkip("Running App Intents from a test needs iOS 27.") }
        let app = XCUIApplication()
        app.launchArguments += ["-UITestingInMemoryStore", "-selectedLanguage", "en", "-contactsOnboardingShown", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["testModeButton"].waitForExistence(timeout: 10))
        app.buttons["testModeButton"].tap()
        app.alerts.buttons["Start Test"].tap()
        XCTAssertTrue(app.buttons["Chats"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["Chats"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Family Group"].firstMatch.waitForExistence(timeout: 5))

        let definitions = IntentDefinitions(bundleIdentifier: "com.cclab.TalkMVP.TalkMVP")
        let matches = try await definitions.entities["ChatRoomEntity"].entities(matching: "Family")
        let family = try XCTUnwrap(matches.first, "Siri finds the chat by part of its name")

        try await definitions.intents["SendChatMessageIntent"].makeIntent(chat: family, message: "Sent from Siri").run()

        app.staticTexts["Family Group"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Sent from Siri"].firstMatch.waitForExistence(timeout: 5), "the message shows up in the chat")

        let result = try await definitions.intents["SummarizeChatIntent"].makeIntent(chat: family).run()
        let summary: String = try result.value
        XCTAssertFalse(summary.isEmpty)
        print("SIRI-SUMMARY \(summary.replacingOccurrences(of: "\n", with: " / "))")
    }
}
