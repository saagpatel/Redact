import XCTest
@testable import Redact

final class RedactionStateTests: XCTestCase {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Round-trip helpers

    private func assertRoundTrip(_ state: RedactionState, file: StaticString = #filePath, line: UInt = #line) throws {
        let data = try encoder.encode(state)
        let decoded = try decoder.decode(RedactionState.self, from: data)
        XCTAssertEqual(decoded, state, file: file, line: line)
    }

    // MARK: - Empty state

    func testEmptyParagraphsArrayRoundTrips() throws {
        let state = RedactionState(paragraphs: [], activeParagraphIndex: 0)
        try assertRoundTrip(state)
    }

    // MARK: - Single paragraph, each visibility level

    func testSingleVisibleParagraphRoundTrips() throws {
        let state = RedactionState(
            paragraphs: [
                .init(index: 0, visibility: .visible, partiallyVisibleIndices: [])
            ],
            activeParagraphIndex: 0
        )
        try assertRoundTrip(state)
    }

    func testSinglePartialParagraphRoundTrips() throws {
        let indices = [0, 3, 7, 12, 15, 20]
        let state = RedactionState(
            paragraphs: [
                .init(index: 0, visibility: .partial, partiallyVisibleIndices: indices)
            ],
            activeParagraphIndex: 0
        )
        try assertRoundTrip(state)
    }

    func testSingleRedactedParagraphRoundTrips() throws {
        let state = RedactionState(
            paragraphs: [
                .init(index: 0, visibility: .redacted, partiallyVisibleIndices: [])
            ],
            activeParagraphIndex: 0
        )
        try assertRoundTrip(state)
    }

    // MARK: - Mixed visibility states

    func testTenParagraphsMixedVisibilityRoundTrips() throws {
        let paragraphs: [RedactionState.ParagraphState] = (0..<10).map { i in
            let visibility: RedactionState.VisibilityLevel
            let indices: [Int]

            switch i {
            case 0, 1:
                visibility = .redacted
                indices = []
            case 2, 3, 4:
                visibility = .partial
                indices = Array(stride(from: i * 5, to: i * 5 + 20, by: 3))
            case 5, 6, 7, 8:
                visibility = .redacted
                indices = []
            default:
                visibility = .visible
                indices = []
            }

            return .init(index: i, visibility: visibility, partiallyVisibleIndices: indices)
        }

        let state = RedactionState(paragraphs: paragraphs, activeParagraphIndex: 9)
        try assertRoundTrip(state)
    }

    // MARK: - All redacted

    func testAllRedactedStateRoundTrips() throws {
        let paragraphs = (0..<5).map { i in
            RedactionState.ParagraphState(index: i, visibility: .redacted, partiallyVisibleIndices: [])
        }
        let state = RedactionState(paragraphs: paragraphs, activeParagraphIndex: 4)
        try assertRoundTrip(state)
    }

    // MARK: - Partial indices preserved exactly

    func testPartiallyVisibleIndicesPreservedExactly() throws {
        let indices = [0, 1, 2, 100, 255, 1024, 9999]
        let state = RedactionState(
            paragraphs: [
                .init(index: 0, visibility: .partial, partiallyVisibleIndices: indices)
            ],
            activeParagraphIndex: 0
        )

        let data = try encoder.encode(state)
        let decoded = try decoder.decode(RedactionState.self, from: data)
        XCTAssertEqual(decoded.paragraphs[0].partiallyVisibleIndices, indices)
    }

    // MARK: - VisibilityLevel raw values

    func testVisibilityLevelRawValues() {
        XCTAssertEqual(RedactionState.VisibilityLevel.visible.rawValue, "visible")
        XCTAssertEqual(RedactionState.VisibilityLevel.partial.rawValue, "partial")
        XCTAssertEqual(RedactionState.VisibilityLevel.redacted.rawValue, "redacted")
    }
}
