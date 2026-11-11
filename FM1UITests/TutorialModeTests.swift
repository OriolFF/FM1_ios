import XCTest

final class TutorialModeTests: XCTestCase {
    private func launch(firmware: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-firmware", firmware]
        app.launch()
        return app
    }

    /// Tutorial mode is persisted, so set it explicitly rather than assuming the start state.
    private func setTutorial(_ on: Bool, _ app: XCUIApplication) {
        let toggle = app.buttons["tutorial.toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        if (toggle.value as? String == "On") != on { toggle.tap() }
    }

    func testStockFirmwareShowsFullTutorial() throws {
        let app = launch(firmware: "stockV15")
        let badge = app.buttons["tutorial.algorithm"]
        setTutorial(false, app)
        XCTAssertTrue(badge.waitForNonExistence(timeout: 2), "badges are hidden until tutorial mode is on")

        setTutorial(true, app)
        XCTAssertTrue(badge.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["tutorial.rec"].exists)
        XCTAssertTrue(app.buttons["tutorial.knob4"].exists)

        badge.tap()
        XCTAssertTrue(app.navigationBars["Tutorial"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Effect on the sound"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["tutorial.now"].exists, "stock cards show live state")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Tutorial"].waitForNonExistence(timeout: 3))

        setTutorial(false, app)
        XCTAssertTrue(badge.waitForNonExistence(timeout: 2))
    }

    func testOtherFirmwareShowsOnlyCommonBehaviour() throws {
        let app = launch(firmware: "groove")
        setTutorial(true, app)
        let badge = app.buttons["tutorial.select"]
        XCTAssertTrue(badge.waitForExistence(timeout: 4))
        badge.tap()
        XCTAssertTrue(app.navigationBars["Tutorial"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["How to use"].exists)
        XCTAssertFalse(app.staticTexts["Effect on the sound"].exists, "no firmware-specific sound info")
        let note = NSPredicate(format: "label CONTAINS 'Only the behaviour shared by every firmware'")
        XCTAssertTrue(app.staticTexts.containing(note).count > 0)
    }
}
