import XCTest
@testable import Redact

final class VisibilityEngineTests: XCTestCase {

    private let engine = VisibilityEngine()
    private let seed = UUID(uuidString: "DEADBEEF-1234-5678-ABCD-000000000000")!

    // MARK: - Zero paragraphs

    func testZeroParagraphsReturnsEmpty() {
        let result = engine.computeVisibility(
            paragraphCount: 0,
            activeParagraphIndex: 0,
            fullVisible: 1,
            partialVisible: 1,
            documentSeed: seed
        )
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Single paragraph

    func testSingleParagraphActiveZeroIsVisible() {
        let result = engine.computeVisibility(
            paragraphCount: 1,
            activeParagraphIndex: 0,
            fullVisible: 1,
            partialVisible: 1,
            documentSeed: seed
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].visibility, .visible)
        XCTAssertEqual(result[0].index, 0)
    }

    // MARK: - Standard 3-paragraph layout

    func testThreeParagraphsF1P1Active2() {
        let result = engine.computeVisibility(
            paragraphCount: 3,
            activeParagraphIndex: 2,
            fullVisible: 1,
            partialVisible: 1,
            documentSeed: seed
        )
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].visibility, .redacted)
        XCTAssertEqual(result[1].visibility, .partial)
        XCTAssertEqual(result[2].visibility, .visible)
    }

    // MARK: - 5-paragraph standard layout

    func testFiveParagraphsF1P1Active4() {
        let result = engine.computeVisibility(
            paragraphCount: 5,
            activeParagraphIndex: 4,
            fullVisible: 1,
            partialVisible: 1,
            documentSeed: seed
        )
        XCTAssertEqual(result.count, 5)
        XCTAssertEqual(result[0].visibility, .redacted)
        XCTAssertEqual(result[1].visibility, .redacted)
        XCTAssertEqual(result[2].visibility, .redacted)
        XCTAssertEqual(result[3].visibility, .partial)
        XCTAssertEqual(result[4].visibility, .visible)
    }

    // MARK: - Training mode: 8 paragraphs F=4 P=2 active=7

    func testTrainingModeEightParagraphsF4P2Active7() {
        let result = engine.computeVisibility(
            paragraphCount: 8,
            activeParagraphIndex: 7,
            fullVisible: 4,
            partialVisible: 2,
            documentSeed: seed
        )
        XCTAssertEqual(result.count, 8)
        // visibleStart = max(0, 7 - 4 + 1) = 4, partialStart = max(0, 4 - 2) = 2
        XCTAssertEqual(result[0].visibility, .redacted)
        XCTAssertEqual(result[1].visibility, .redacted)
        XCTAssertEqual(result[2].visibility, .partial)
        XCTAssertEqual(result[3].visibility, .partial)
        XCTAssertEqual(result[4].visibility, .visible)
        XCTAssertEqual(result[5].visibility, .visible)
        XCTAssertEqual(result[6].visibility, .visible)
        XCTAssertEqual(result[7].visibility, .visible)
    }

    // MARK: - Training mode: fewer paragraphs than window

    func testTrainingModeF4P2FourParagraphsActive3AllVisible() {
        let result = engine.computeVisibility(
            paragraphCount: 4,
            activeParagraphIndex: 3,
            fullVisible: 4,
            partialVisible: 2,
            documentSeed: seed
        )
        XCTAssertEqual(result.count, 4)
        // visibleStart = max(0, 3 - 4 + 1) = 0, partialStart = max(0, 0 - 2) = 0
        // All paragraphs fall in [0..3] visible range
        XCTAssertEqual(result[0].visibility, .visible)
        XCTAssertEqual(result[1].visibility, .visible)
        XCTAssertEqual(result[2].visibility, .visible)
        XCTAssertEqual(result[3].visibility, .visible)
    }

    // MARK: - Custom F=3 P=2 active=7 with 8 paragraphs

    func testCustomF3P2EightParagraphsActive7() {
        let result = engine.computeVisibility(
            paragraphCount: 8,
            activeParagraphIndex: 7,
            fullVisible: 3,
            partialVisible: 2,
            documentSeed: seed
        )
        XCTAssertEqual(result.count, 8)
        // visibleStart = max(0, 7 - 3 + 1) = 5, partialStart = max(0, 5 - 2) = 3
        XCTAssertEqual(result[0].visibility, .redacted)
        XCTAssertEqual(result[1].visibility, .redacted)
        XCTAssertEqual(result[2].visibility, .redacted)
        XCTAssertEqual(result[3].visibility, .partial)
        XCTAssertEqual(result[4].visibility, .partial)
        XCTAssertEqual(result[5].visibility, .visible)
        XCTAssertEqual(result[6].visibility, .visible)
        XCTAssertEqual(result[7].visibility, .visible)
    }

    // MARK: - Edge: active=0 with F=3

    func testActiveZeroWithLargeFullWindowNoCrash() {
        let result = engine.computeVisibility(
            paragraphCount: 5,
            activeParagraphIndex: 0,
            fullVisible: 3,
            partialVisible: 2,
            documentSeed: seed
        )
        XCTAssertEqual(result.count, 5)
        // visibleStart = max(0, 0 - 3 + 1) = 0, active=0 → only index 0 is visible
        XCTAssertEqual(result[0].visibility, .visible)
        // Remaining are redacted (no room for partial since visibleStart=0=partialStart)
        XCTAssertEqual(result[1].visibility, .redacted)
        XCTAssertEqual(result[2].visibility, .redacted)
        XCTAssertEqual(result[3].visibility, .redacted)
        XCTAssertEqual(result[4].visibility, .redacted)
    }

    // MARK: - 2 paragraphs active=1 F=1 P=1

    func testTwoParagraphsF1P1Active1() {
        let result = engine.computeVisibility(
            paragraphCount: 2,
            activeParagraphIndex: 1,
            fullVisible: 1,
            partialVisible: 1,
            documentSeed: seed
        )
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].visibility, .partial)
        XCTAssertEqual(result[1].visibility, .visible)
    }

    // MARK: - Zero partial paragraphs

    func testZeroPartialWindowF1P0FourParagraphsActive3() {
        let result = engine.computeVisibility(
            paragraphCount: 4,
            activeParagraphIndex: 3,
            fullVisible: 1,
            partialVisible: 0,
            documentSeed: seed
        )
        XCTAssertEqual(result.count, 4)
        // visibleStart = 3, partialStart = 3 (same) → nothing in partial band
        XCTAssertEqual(result[0].visibility, .redacted)
        XCTAssertEqual(result[1].visibility, .redacted)
        XCTAssertEqual(result[2].visibility, .redacted)
        XCTAssertEqual(result[3].visibility, .visible)
    }

    // MARK: - Partial indices

    func testPartialParagraphsHaveNonEmptyIndices() {
        let result = engine.computeVisibility(
            paragraphCount: 3,
            activeParagraphIndex: 2,
            fullVisible: 1,
            partialVisible: 1,
            documentSeed: seed
        )
        let partialStates = result.filter { $0.visibility == .partial }
        XCTAssertFalse(partialStates.isEmpty)
        for state in partialStates {
            XCTAssertFalse(state.partiallyVisibleIndices.isEmpty, "Partial paragraph \(state.index) should have non-empty indices")
        }
    }

    func testPartialIndicesAreDeterministicWithSameSeed() {
        let result1 = engine.computeVisibility(
            paragraphCount: 3,
            activeParagraphIndex: 2,
            fullVisible: 1,
            partialVisible: 1,
            documentSeed: seed
        )
        let result2 = engine.computeVisibility(
            paragraphCount: 3,
            activeParagraphIndex: 2,
            fullVisible: 1,
            partialVisible: 1,
            documentSeed: seed
        )
        XCTAssertEqual(result1[1].partiallyVisibleIndices, result2[1].partiallyVisibleIndices)
    }

    func testPartialIndicesDifferWithDifferentSeeds() {
        let seed2 = UUID()
        let result1 = engine.computeVisibility(
            paragraphCount: 3,
            activeParagraphIndex: 2,
            fullVisible: 1,
            partialVisible: 1,
            documentSeed: seed
        )
        let result2 = engine.computeVisibility(
            paragraphCount: 3,
            activeParagraphIndex: 2,
            fullVisible: 1,
            partialVisible: 1,
            documentSeed: seed2
        )
        // Different seeds almost certainly produce different indices
        XCTAssertNotEqual(result1[1].partiallyVisibleIndices, result2[1].partiallyVisibleIndices)
    }

    // MARK: - Paragraph indices match position

    func testParagraphIndicesMatchPosition() {
        let result = engine.computeVisibility(
            paragraphCount: 5,
            activeParagraphIndex: 4,
            fullVisible: 1,
            partialVisible: 1,
            documentSeed: seed
        )
        for (position, state) in result.enumerated() {
            XCTAssertEqual(state.index, position, "Paragraph at position \(position) should have index \(position)")
        }
    }

    // MARK: - visibilityChanges: no changes

    func testVisibilityChangesNoChangesReturnsEmpty() {
        let states: [RedactionState.ParagraphState] = [
            .init(index: 0, visibility: .redacted, partiallyVisibleIndices: []),
            .init(index: 1, visibility: .partial, partiallyVisibleIndices: [1, 2, 3]),
            .init(index: 2, visibility: .visible, partiallyVisibleIndices: []),
        ]
        let changes = engine.visibilityChanges(previous: states, current: states)
        XCTAssertTrue(changes.isEmpty)
    }

    // MARK: - visibilityChanges: single transition detected

    func testVisibilityChangesSingleTransitionDetected() {
        let previous: [RedactionState.ParagraphState] = [
            .init(index: 0, visibility: .visible, partiallyVisibleIndices: []),
            .init(index: 1, visibility: .visible, partiallyVisibleIndices: []),
        ]
        let current: [RedactionState.ParagraphState] = [
            .init(index: 0, visibility: .partial, partiallyVisibleIndices: [0, 1]),
            .init(index: 1, visibility: .visible, partiallyVisibleIndices: []),
        ]
        let changes = engine.visibilityChanges(previous: previous, current: current)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes[0].index, 0)
        XCTAssertEqual(changes[0].from, .visible)
        XCTAssertEqual(changes[0].to, .partial)
    }

    // MARK: - visibilityChanges: multiple transitions on paragraph completion

    func testVisibilityChangesMultipleTransitionsOnCompletion() {
        // Simulate pressing enter: paragraph 1 transitions partial→redacted, paragraph 2 visible→partial, new paragraph 3 appears as visible
        let previous: [RedactionState.ParagraphState] = [
            .init(index: 0, visibility: .redacted, partiallyVisibleIndices: []),
            .init(index: 1, visibility: .partial, partiallyVisibleIndices: [1, 2]),
            .init(index: 2, visibility: .visible, partiallyVisibleIndices: []),
        ]
        let current: [RedactionState.ParagraphState] = [
            .init(index: 0, visibility: .redacted, partiallyVisibleIndices: []),
            .init(index: 1, visibility: .redacted, partiallyVisibleIndices: []),
            .init(index: 2, visibility: .partial, partiallyVisibleIndices: [1, 2]),
            .init(index: 3, visibility: .visible, partiallyVisibleIndices: []),
        ]
        let changes = engine.visibilityChanges(previous: previous, current: current)
        // Paragraph 1: partial→redacted, paragraph 2: visible→partial, paragraph 3: new (defaults from .visible) → visible = no change
        XCTAssertEqual(changes.count, 2)

        let change1 = changes.first { $0.index == 1 }
        XCTAssertNotNil(change1)
        XCTAssertEqual(change1?.from, .partial)
        XCTAssertEqual(change1?.to, .redacted)

        let change2 = changes.first { $0.index == 2 }
        XCTAssertNotNil(change2)
        XCTAssertEqual(change2?.from, .visible)
        XCTAssertEqual(change2?.to, .partial)
    }

    // MARK: - visibilityChanges: new paragraph defaults from visible

    func testVisibilityChangesNewParagraphDefaultsFromVisible() {
        let previous: [RedactionState.ParagraphState] = [
            .init(index: 0, visibility: .visible, partiallyVisibleIndices: []),
        ]
        let current: [RedactionState.ParagraphState] = [
            .init(index: 0, visibility: .visible, partiallyVisibleIndices: []),
            .init(index: 1, visibility: .visible, partiallyVisibleIndices: []),
        ]
        let changes = engine.visibilityChanges(previous: previous, current: current)
        // New paragraph 1 defaults from .visible and remains .visible → no change
        XCTAssertTrue(changes.isEmpty)
    }

    func testVisibilityChangesNewParagraphDefaultsFromVisibleDetectsChange() {
        let previous: [RedactionState.ParagraphState] = [
            .init(index: 0, visibility: .redacted, partiallyVisibleIndices: []),
        ]
        let current: [RedactionState.ParagraphState] = [
            .init(index: 0, visibility: .redacted, partiallyVisibleIndices: []),
            .init(index: 1, visibility: .partial, partiallyVisibleIndices: [0, 1]),
        ]
        let changes = engine.visibilityChanges(previous: previous, current: current)
        // New paragraph 1 defaults from .visible, now .partial → change detected
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes[0].index, 1)
        XCTAssertEqual(changes[0].from, .visible)
        XCTAssertEqual(changes[0].to, .partial)
    }
}
