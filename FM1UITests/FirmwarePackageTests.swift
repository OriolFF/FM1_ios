import XCTest

/// Firmware packages: install one from a URL at runtime (no rebuild), flash it, and switch
/// between a bundled package firmware and the stock one.
private enum PkgModes {
    static let names = ["UP", "DN", "UPDN", "RND", "ORD", "REPEAT", "DNUP", "UP+8", "CONV", "DIVG", "PINKY", "THUMB", "WALK", "CHORD"]
    static func any(_ f: (String) -> Bool) -> Bool { names.contains(where: f) }
}

final class FirmwarePackageTests: XCTestCase {

    /// Every test starts from the bundled catalog (no packages left over from earlier runs).
    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FM1_TEST_RESET_PACKAGES"] = "1"
        return app
    }

    /// A minimal script firmware, delivered as a `data:` URL so the test needs no network.
    static var testPackageURL: String {
        let manifest = """
        {"format":1,"id":"ui-test","name":"UI Test Firmware","version":"0.1","bootTitle":"TEST",
         "summary":"Installed by FirmwarePackageTests.","runtime":"script","scripts":["main.js"],
         "engine":{"instruments":[{"id":"lead","type":"va","voices":2},{"id":"drums","type":"drums"},{"id":"smp","type":"sampler"}],
                   "samples":[{"name":"BLIP","zones":[{"file":"samples/blip.wav","root":60}]}],
                   "sequencer":{"patterns":1,"tracks":[{"id":"lead","instrument":"lead"}]}}}
        """
        let script = """
        var lead = fm.inst("lead");
        function onBoot() { lead.setAll({cutoff: 0.6, mode: 1}); }
        function onKey(k, down, v) { var n = 53 + k; if (down) lead.note(n, v); else lead.off(n); }
        function render(g) { g.clear("#101418"); g.text(120, 100, "HELLO PACKAGE", {size: 20, align: "center"}); g.text(120, 140, "SET " + fm.inst("smp").sets().join(","), {size: 12, align: "center"}); }
        """
        // a package-own sample travels in the bundle as base64: 0.1 s of 440 Hz, 16-bit mono 22.05 kHz
        var pcm = Data()
        for i in 0..<2205 { var v = Int16(10000 * sin(2 * Double.pi * 440 * Double(i) / 22050)); pcm.append(Data(bytes: &v, count: 2)) }
        var wav = Data("RIFF".utf8)
        func put<T>(_ x: T) { var y = x; wav.append(Data(bytes: &y, count: MemoryLayout<T>.size)) }
        put(UInt32(36 + pcm.count)); wav.append(Data("WAVEfmt ".utf8))
        put(UInt32(16)); put(UInt16(1)); put(UInt16(1)); put(UInt32(22050)); put(UInt32(44100)); put(UInt16(2)); put(UInt16(16))
        wav.append(Data("data".utf8)); put(UInt32(pcm.count)); wav.append(pcm)
        let bundle: [String: Any] = ["fm1fw": 1, "files": ["manifest.json": manifest, "main.js": script,
                                                           "samples/blip.wav": ["base64": wav.base64EncodedString()]]]
        let data = try! JSONSerialization.data(withJSONObject: bundle)
        return "data:application/json;base64," + data.base64EncodedString()
    }

    private func waitForChip(_ app: XCUIApplication, containing text: String, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.staticTexts.containing(predicate).count > 0 { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        return false
    }

    /// Scrolls the firmware list until `e` can be tapped.
    @discardableResult
    private func reveal(_ e: XCUIElement, in app: XCUIApplication, up: Bool = true) -> Bool {
        // "hittable" is not enough: the sheet's bottom Install bar covers the last rows
        let bar = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Install ' OR label ENDSWITH 'is installed'")).allElementsBoundByIndex
            .map(\.frame).filter { $0.height > 20 && $0.width > 300 }.map(\.minY).min() ?? .greatestFiniteMagnitude
        func clear() -> Bool { e.exists && e.isHittable && e.frame.maxY < bar - 8 && e.frame.minY > 80 }
        for _ in 0..<10 {
            if clear() { return true }
            let list = app.collectionViews.firstMatch.exists ? app.collectionViews.firstMatch : app.tables.firstMatch
            if up { list.swipeUp() } else { list.swipeDown() }
        }
        return clear()
    }

    private func packageScreen(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "PackageScreen").firstMatch
    }

    func testInstallPackageFromURLAndSwitchToIt() throws {
        let app = makeApp()
        app.launchArguments = ["-demo", "firmware", "-firmware", "stock-v15"]
        app.launchEnvironment["FM1_TEST_PACKAGE_URL"] = Self.testPackageURL
        app.launch()

        let sheetTitle = app.navigationBars["Firmware"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 5), "firmware sheet should open")

        let fromURL = app.buttons["Install from URL…"]
        XCTAssertTrue(reveal(fromURL, in: app), "install-from-URL button")
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))   // let the list settle after scrolling
        fromURL.tap()
        let download = app.buttons["Download & Install"]
        XCTAssertTrue(download.waitForExistence(timeout: 5), "URL page should open")
        download.tap()
        let done = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Installed UI Test Firmware'")).firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 8), "package should download and install")
        app.navigationBars.buttons.element(boundBy: 0).tap()        // back to the firmware list

        // a successful install selects the new firmware, so the bottom button offers to flash it
        let flash = app.buttons["Install UI Test Firmware 0.1"]
        if !flash.waitForExistence(timeout: 8) {
            let msgs = app.staticTexts.allElementsBoundByIndex.map(\.label).filter { $0.contains("nstall") || $0.contains("fail") }
            XCTFail("package should download and install; messages: \(msgs)")
        }
        XCTAssertTrue(reveal(app.staticTexts["UI Test Firmware"], in: app, up: false), "the new firmware is listed in the menu")
        flash.tap()
        XCTAssertTrue(sheetTitle.waitForNonExistence(timeout: 3), "sheet should close")
        XCTAssertTrue(waitForChip(app, containing: "UI Test Firmware"), "toolbar shows the package firmware")

        // the package's own script draws the screen after the boot animation
        let screen = packageScreen(app)
        XCTAssertTrue(screen.waitForExistence(timeout: 8), "package screen should be shown")
        let deadline = Date().addingTimeInterval(6)
        while Date() < deadline && !screen.label.contains("HELLO PACKAGE") { RunLoop.current.run(until: Date().addingTimeInterval(0.3)) }
        XCTAssertTrue(screen.label.contains("HELLO PACKAGE"), "script output on the TFT, got: \(screen.label)")
        XCTAssertTrue(screen.label.contains("SET BLIP"), "the package's own sample installed and loaded, got: \(screen.label)")
    }

    func testSwitchBetweenBundledPackageAndStock() throws {
        let app = makeApp()
        app.launchArguments = ["-demo", "firmware", "-firmware", "stock-v15"]
        app.launch()

        let sheetTitle = app.navigationBars["Firmware"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 5))
        let sloop = app.staticTexts["SLOOP"]
        XCTAssertTrue(reveal(sloop, in: app), "bundled package listed")
        sloop.tap()
        let install = app.buttons["Install SLOOP 2.8-p1"]
        XCTAssertTrue(install.waitForExistence(timeout: 2))
        install.tap()
        XCTAssertTrue(sheetTitle.waitForNonExistence(timeout: 3))
        XCTAssertTrue(waitForChip(app, containing: "SLOOP"))

        let screen = packageScreen(app)
        XCTAssertTrue(screen.waitForExistence(timeout: 8))
        let deadline = Date().addingTimeInterval(6)
        while Date() < deadline && !screen.label.contains("TRACKS") { RunLoop.current.run(until: Date().addingTimeInterval(0.3)) }
        XCTAssertTrue(screen.label.contains("TRACKS"), "SLOOP boots to its TRACKS screen, got: \(screen.label)")

        // and back to the original firmware
        app.buttons["Firmware"].tap()
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 3))
        reveal(app.staticTexts["FM-1 Stock"], in: app, up: false)
        app.staticTexts["FM-1 Stock"].tap()
        app.buttons["Install FM-1 Stock V15"].tap()
        XCTAssertTrue(sheetTitle.waitForNonExistence(timeout: 3))
        XCTAssertTrue(waitForChip(app, containing: "FM-1 Stock"))
        XCTAssertTrue(packageScreen(app).waitForNonExistence(timeout: 8), "stock firmware draws its own screen again")
    }
    /// Felucca's ARP page drives the host arpeggiator: KNOB1 (MODE) turns it on, a second ARP tap opens ARP 2.
    func testFeluccaArpPage() throws {
        let app = makeApp()
        app.launchArguments = ["-firmware", "felucca"]
        app.launch()
        let screen = packageScreen(app)
        XCTAssertTrue(screen.waitForExistence(timeout: 8), "Felucca draws its screen")
        func screenShows(_ s: String, _ timeout: TimeInterval = 6) -> Bool {
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline { if screen.label.contains(s) { return true }; RunLoop.current.run(until: Date().addingTimeInterval(0.3)) }
            return false
        }
        XCTAssertTrue(screenShows("HOME"), "boots to HOME, got: \(screen.label)")

        let arp = app.staticTexts["ARP"].firstMatch
        XCTAssertTrue(arp.waitForExistence(timeout: 3))
        arp.tap()
        XCTAssertTrue(screenShows("ARP "), "ARP page shows the arp state, got: \(screen.label)")
        XCTAssertTrue(screen.label.contains("MODE") && screen.label.contains("RATE") && screen.label.contains("GATE"), "ARP knob cards, got: \(screen.label)")

        // KNOB1 is MODE, with OFF as its lowest value (arp settings persist per package, so start from OFF)
        let label = app.staticTexts["KNOB1"]
        func turnKnob1(up: Bool) {
            // start on the knob (below its label); right/up turns it up, left/down turns it down
            let a = label.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 4))
            a.press(forDuration: 0.1, thenDragTo: label.coordinate(withNormalizedOffset: CGVector(dx: up ? 1.5 : -0.5, dy: 4)))
        }
        for _ in 0..<8 where !screenShows("ARP OFF", 1) { turnKnob1(up: false) }
        XCTAssertTrue(screenShows("ARP OFF"), "MODE turns down to OFF, got: \(screen.label)")
        turnKnob1(up: true)
        let deadline = Date().addingTimeInterval(4)
        while Date() < deadline && screen.label.contains("ARP OFF") { RunLoop.current.run(until: Date().addingTimeInterval(0.3)) }
        XCTAssertFalse(screen.label.contains("ARP OFF"), "KNOB1 switches the arp on, got: \(screen.label)")
        XCTAssertTrue(PkgModes.any { screen.label.contains("ARP \($0) ·") }, "a mode is shown, got: \(screen.label)")
        for _ in 0..<8 where !screenShows("ARP OFF", 1) { turnKnob1(up: false) }   // leave it off for the next run

        arp.tap()
        XCTAssertTrue(screenShows("LATCH"), "second ARP tap opens ARP 2, got: \(screen.label)")
    }
    /// Real network install: Felucca's packed file from the public GitHub repo, over https.
    /// Needs the simulator to be online. The downloaded copy replaces the bundled one; the next test resets it.
    func testInstallFromHTTPSAndRun() throws {
        let app = makeApp()
        app.launchArguments = ["-demo", "firmware", "-firmware", "stock-v15"]
        app.launchEnvironment["FM1_TEST_PACKAGE_URL"] = "https://raw.githubusercontent.com/OriolFF/FM1_ios/main/Firmwares/dist/felucca.fm1fw"
        app.launch()
        let sheetTitle = app.navigationBars["Firmware"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 5))

        let fromURL = app.buttons["Install from URL…"]
        XCTAssertTrue(reveal(fromURL, in: app))
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        fromURL.tap()
        let download = app.buttons["Download & Install"]
        XCTAssertTrue(download.waitForExistence(timeout: 5))
        download.tap()
        let done = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Installed Felucca'")).firstMatch
        if !done.waitForExistence(timeout: 30) {
            let msgs = app.staticTexts.allElementsBoundByIndex.map(\.label).filter { $0.contains("nstall") || $0.contains("fail") || $0.contains("rror") }
            XCTFail("https download should install; messages: \(msgs)")
        }
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // a successful install selects it: flash the downloaded Felucca and check it runs
        let flash = app.buttons["Install Felucca 1.8.1-p1"]
        XCTAssertTrue(flash.waitForExistence(timeout: 5), "downloaded firmware selected")
        flash.tap()
        XCTAssertTrue(sheetTitle.waitForNonExistence(timeout: 3))
        XCTAssertTrue(waitForChip(app, containing: "Felucca"))
        let screen = packageScreen(app)
        XCTAssertTrue(screen.waitForExistence(timeout: 8))
        let deadline = Date().addingTimeInterval(6)
        while Date() < deadline && !screen.label.contains("HOME") { RunLoop.current.run(until: Date().addingTimeInterval(0.3)) }
        XCTAssertTrue(screen.label.contains("HOME"), "downloaded Felucca boots to HOME, got: \(screen.label)")
    }
    /// Track 1 can load another engine: SAVE > PRESETS, KNOB 3 (ENGINE) goes ANALOG -> FM6 and back.
    func testFeluccaTrackEngineSwitch() throws {
        let app = makeApp()
        app.launchArguments = ["-firmware", "felucca"]
        app.launch()
        let screen = packageScreen(app)
        XCTAssertTrue(screen.waitForExistence(timeout: 8))
        func screenShows(_ s: String, _ timeout: TimeInterval = 6) -> Bool {
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline { if screen.label.contains(s) { return true }; RunLoop.current.run(until: Date().addingTimeInterval(0.3)) }
            return false
        }
        XCTAssertTrue(screenShows("HOME"))
        app.staticTexts["SAVE"].firstMatch.tap()
        XCTAssertTrue(screenShows("SAVE > PRESETS"), "SAVE opens PRESETS, got: \(screen.label)")
        XCTAssertTrue(screenShows("ENGINE"), "ENGINE knob card, got: \(screen.label)")

        let label = app.staticTexts["KNOB3"]
        func turn(up: Bool) {
            let a = label.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 4))
            a.press(forDuration: 0.1, thenDragTo: label.coordinate(withNormalizedOffset: CGVector(dx: up ? 1.5 : -0.5, dy: 4)))
        }
        // start from ANALOG (engine choices persist per package)
        for _ in 0..<4 where !screenShows("ENGINE ANALOG", 1) { turn(up: false) }
        XCTAssertTrue(screenShows("ENGINE ANALOG"), "track 1 on ANALOG, got: \(screen.label)")
        turn(up: true)
        let moved = ["FM6", "PHASE", "SAMPLE"].contains { screenShows("ENGINE \($0)", 1) }
        XCTAssertTrue(moved, "KNOB 3 changes the engine, got: \(screen.label)")
        for _ in 0..<4 where !screenShows("ENGINE ANALOG", 1) { turn(up: false) }
        XCTAssertTrue(screenShows("ENGINE ANALOG"), "and back, got: \(screen.label)")
    }
    /// Melodee's tracks 5–8 are MIDI tracks: ALGORITHM walks the tracks up to T5, which shows its MIDI channel.
    func testMelodeeMIDITrack() throws {
        let app = makeApp()
        app.launchArguments = ["-firmware", "melodee"]
        app.launch()
        let screen = packageScreen(app)
        XCTAssertTrue(screen.waitForExistence(timeout: 8))
        func screenShows(_ s: String, _ timeout: TimeInterval = 6) -> Bool {
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline { if screen.label.contains(s) { return true }; RunLoop.current.run(until: Date().addingTimeInterval(0.3)) }
            return false
        }
        XCTAssertTrue(screenShows("■") || screenShows("▶", 1), "Melodee boots on its stage (track selection persists), got: \(screen.label)")
        let enc = app.staticTexts["ALGORITHM"]
        func turn(up: Bool) {
            let a = enc.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 4))
            a.press(forDuration: 0.1, thenDragTo: enc.coordinate(withNormalizedOffset: CGVector(dx: up ? 1.0 : 0.0, dy: 4)))
        }
        for _ in 0..<12 where !screenShows("MIDI CH", 1) { turn(up: true) }
        XCTAssertTrue(screenShows("MIDI CH"), "a MIDI track shows its channel, got: \(screen.label)")
        for _ in 0..<12 where !screenShows("T1 ", 1) { turn(up: false) }   // leave track 1 selected
    }
    /// Track 1 on the SAMPLE engine: the shipped sets and a user sample (made by the debug hook) are its sounds.
    func testFeluccaSampleEngineWithUserSample() throws {
        let app = makeApp()
        app.launchArguments = ["-firmware", "felucca"]
        app.launchEnvironment["FM1_TEST_USER_SAMPLE"] = "felucca"
        app.launch()
        let screen = packageScreen(app)
        XCTAssertTrue(screen.waitForExistence(timeout: 8))
        func screenShows(_ s: String, _ timeout: TimeInterval = 6) -> Bool {
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline { if screen.label.contains(s) { return true }; RunLoop.current.run(until: Date().addingTimeInterval(0.3)) }
            return false
        }
        XCTAssertTrue(screenShows("HOME"))
        app.staticTexts["SAVE"].firstMatch.tap()
        XCTAssertTrue(screenShows("SAVE > PRESETS"))
        // `reach` is how far the drag goes (in label widths): short drags give one or two steps
        func turn(_ knob: String, up: Bool, reach: CGFloat = 1) {
            let l = app.staticTexts[knob]
            l.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 4))
                .press(forDuration: 0.1, thenDragTo: l.coordinate(withNormalizedOffset: CGVector(dx: 0.5 + (up ? reach : -reach), dy: 4)))
        }
        for _ in 0..<6 where !screenShows("ENGINE SAMPLE", 1) { turn("KNOB3", up: true) }
        XCTAssertTrue(screenShows("ENGINE SAMPLE"), "SAMPLE is the last engine, got: \(screen.label)")
        XCTAssertTrue(screenShows("PIANO"), "shipped sample sets are listed, got: \(screen.label)")
        for _ in 0..<16 where !screenShows("▶ TEST_SINE", 1) { turn("KNOB2", up: true, reach: 0.4) }
        XCTAssertTrue(screenShows("▶ TEST_SINE"), "the user sample is a sound, got: \(screen.label)")
        for _ in 0..<6 where !screenShows("ENGINE ANALOG", 1) { turn("KNOB3", up: false) }
        XCTAssertTrue(screenShows("ENGINE ANALOG"), "back to ANALOG, got: \(screen.label)")
    }
}
