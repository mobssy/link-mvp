//
//  TalkMVPUITestsLaunchTests.swift
//  TalkMVPUITests
//
//  Created by David Song on 9/26/25.
//

import XCTest

final class TalkMVPUITestsLaunchTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestingInMemoryStore"]
        app.launch()

        // With nobody signed in, the app opens on the sign-in screen.
        XCTAssertTrue(app.buttons["testModeButton"].waitForExistence(timeout: 10))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
