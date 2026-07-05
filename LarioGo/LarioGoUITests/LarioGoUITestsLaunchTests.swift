//
//  LarioGoUITestsLaunchTests.swift
//  LarioGo
//
//  Created by user on 29.6.26.
//


//
//  LarioGoUITestsLaunchTests.swift
//  LarioGoUITests
//
//  Created by Rork on June 22, 2026.
//

import XCTest

final class LarioGoUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
