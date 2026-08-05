import XCTest

/// Captures the three App Store screenshots that need the app driven to a state.
///
/// The fourth shot — the document library — is the launch screen, so
/// `scripts/capture-screenshots.sh` takes it directly with `simctl` and never enters
/// this file. The states here cannot be reached that way: the writing view is a tap
/// deep, and the mid-reveal frame exists for about two seconds.
///
/// Screenshots leave the simulator as `XCTAttachment`s with `.keepAlways` lifetime,
/// which the capture script extracts with `xcresulttool export attachments`. Writing
/// PNGs straight to the repo is not available from inside the simulator sandbox.
///
/// Run through `scripts/capture-screenshots.sh`, which seeds the document state these
/// tests assume. Run bare against an empty app, they fail at the first assertion
/// rather than capturing an empty screen — a blank screenshot that reached the App
/// Store would be worse than a failed test.
final class ScreenshotCaptureTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    // MARK: - Helpers

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Looks up by accessibility label without assuming an element type. "Done" is a
    /// `Text` carrying a label, "Start Editing" is a `Button` — querying the wrong
    /// collection silently finds nothing and fails as a timeout, which reads like a
    /// broken app rather than a wrong query.
    private func element(labeled label: String) -> XCUIElement {
        app.descendants(matching: .any)[label]
    }

    /// Opens the seeded in-progress session. The library is the launch screen.
    private func openInProgressSession(file: StaticString = #filePath, line: UInt = #line) {
        let resume = element(labeled: "Continue Writing")
        XCTAssertTrue(
            resume.waitForExistence(timeout: 15),
            "no in-progress session on screen — run scripts/capture-screenshots.sh, which seeds one",
            file: file, line: line
        )
        resume.tap()
    }

    // MARK: - 01 — writing, mid-session

    func test01WritingWithRedaction() {
        openInProgressSession()

        // The Done button only exists past 50 words, so waiting on it confirms the
        // writing view is up and the seeded text loaded, not just that a tap landed.
        let done = element(labeled: "Done")
        XCTAssertTrue(done.waitForExistence(timeout: 15), "writing view did not load the seeded session")

        // Let the overlay reposition debounce (50ms) and its fade settle.
        Thread.sleep(forTimeInterval: 1.5)
        capture("01-writing")
    }

    // MARK: - 02 — mid-reveal, and 03 — stats

    /// One test, because the reveal is a single continuous animation: the mid-reveal
    /// frame and the stats card that follows it cannot be reached independently.
    func test02RevealAndStats() {
        openInProgressSession()

        let done = element(labeled: "Done")
        XCTAssertTrue(done.waitForExistence(timeout: 15), "writing view did not load the seeded session")

        Thread.sleep(forTimeInterval: 1.0)

        // Pressed via a coordinate rather than the element. Done is a Text with a
        // long-press gesture, not a control, and XCUITest tries to scroll an element
        // into view before pressing it — which fails with kAXErrorCannotComplete here
        // because there is nothing scrollable to act on. A coordinate press skips that
        // step. The element lookup above still does the waiting, so this does not
        // become a blind tap at fixed pixels.
        done.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 1.0)

        // The seeded session is ~135 words, so revealDuration clamps to its 2s floor.
        // Sampling at 0.9s lands mid-cascade: some bars faded, some still solid.
        Thread.sleep(forTimeInterval: 0.9)
        capture("02-reveal")

        // Stats appear once the cascade completes and the document is saved.
        let stats = element(labeled: "Start Editing")
        XCTAssertTrue(stats.waitForExistence(timeout: 20), "stats card never appeared after the reveal")
        Thread.sleep(forTimeInterval: 0.8)
        capture("03-stats")
    }
}
