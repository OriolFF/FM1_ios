import XCTest

final class TutorialBrowserTests: XCTestCase {
    /// The options menu opens the bundled web tutorial, and it can be closed again.
    func testMenuOpensWebTutorial() {
        let app = XCUIApplication()
        app.launch()
        let menu = app.buttons["options.menu"].firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        menu.tap()
        let item = app.buttons["FM-1 Tutorial (web guide)"]
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        item.tap()
        let web = app.webViews.firstMatch
        XCTAssertTrue(web.waitForExistence(timeout: 10))
        // the page really loaded: a link to the first chapter is present
        XCTAssertTrue(web.links.firstMatch.waitForExistence(timeout: 10))
        sleep(1)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "tutorial"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["tutorial.web.done"].tap()
        XCTAssertFalse(web.waitForExistence(timeout: 3))
    }
}
