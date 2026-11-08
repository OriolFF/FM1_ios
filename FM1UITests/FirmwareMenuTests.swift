import XCTest

final class FirmwareMenuTests: XCTestCase {
    func testInstallFromMenuSwitchesFirmware() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "firmware", "-firmware", "groove"]
        app.launch()

        let sheetTitle = app.navigationBars["Firmware"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 5), "firmware sheet should open")

        app.staticTexts["FM-1 Stock"].tap()
        let install = app.buttons["Install FM-1 Stock V15"]
        XCTAssertTrue(install.waitForExistence(timeout: 2))
        install.tap()

        // sheet closes, flashing runs, toolbar chip shows the new firmware
        XCTAssertTrue(sheetTitle.waitForNonExistence(timeout: 3), "sheet should close")
        let chip = app.buttons["Firmware"]
        XCTAssertTrue(chip.waitForExistence(timeout: 2))
        let predicate = NSPredicate(format: "label CONTAINS 'FM-1 Stock'")
        let deadline = Date().addingTimeInterval(8)
        var switched = false
        while Date() < deadline {
            if app.staticTexts.containing(predicate).count > 0 { switched = true; break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        XCTAssertTrue(switched, "toolbar should show the newly installed firmware")
    }
}
