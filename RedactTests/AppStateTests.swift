import XCTest
@testable import Redact

@MainActor
final class AppStateTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppStateTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testDefaultSettingsValues() {
        let state = AppState(baseURL: tempDir)
        XCTAssertEqual(state.settings.visibilityFullParagraphs, 1)
        XCTAssertEqual(state.settings.visibilityPartialParagraphs, 1)
        XCTAssertEqual(state.settings.hasCompletedFirstDocument, false)
        XCTAssertEqual(state.settings.trainingModeEnabled, true)
    }

    func testSaveAndLoadRoundTrips() {
        let state1 = AppState(baseURL: tempDir)
        state1.settings.visibilityFullParagraphs = 3
        state1.settings.visibilityPartialParagraphs = 2
        state1.settings.hasCompletedFirstDocument = true
        state1.settings.trainingModeEnabled = false
        state1.save()

        let state2 = AppState(baseURL: tempDir)
        XCTAssertEqual(state2.settings.visibilityFullParagraphs, 3)
        XCTAssertEqual(state2.settings.visibilityPartialParagraphs, 2)
        XCTAssertEqual(state2.settings.hasCompletedFirstDocument, true)
        XCTAssertEqual(state2.settings.trainingModeEnabled, false)
    }

    func testLoadFallsBackToDefaultsOnMissingFile() {
        let state = AppState(baseURL: tempDir)
        XCTAssertEqual(state.settings, AppSettings())
    }

    func testLoadFallsBackToDefaultsOnCorruptedFile() throws {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileURL = tempDir.appendingPathComponent("settings.json")
        try "not valid json {{{".data(using: .utf8)!.write(to: fileURL)

        let state = AppState(baseURL: tempDir)
        XCTAssertEqual(state.settings, AppSettings())
    }

    func testOverwritePreservesLatestValues() {
        let state = AppState(baseURL: tempDir)
        state.settings.visibilityFullParagraphs = 2
        state.save()

        state.settings.visibilityFullParagraphs = 5
        state.save()

        let reloaded = AppState(baseURL: tempDir)
        XCTAssertEqual(reloaded.settings.visibilityFullParagraphs, 5)
    }
}
