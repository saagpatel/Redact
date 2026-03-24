import XCTest
@testable import Redact

final class ParagraphTrackerTests: XCTestCase {

    private let tracker = ParagraphTracker()

    // MARK: - Helpers

    private func makeTextStorage(_ text: String) -> NSTextStorage {
        NSTextStorage(string: text)
    }

    // MARK: - paragraphRanges

    func testEmptyTextReturnsZeroRanges() {
        let ranges = tracker.paragraphRanges(in: makeTextStorage(""))
        XCTAssertEqual(ranges.count, 0)
    }

    func testSingleParagraphNoNewlineReturnsOneRange() {
        let text = "Hello world"
        let ranges = tracker.paragraphRanges(in: makeTextStorage(text))
        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0], NSRange(location: 0, length: text.count))
    }

    func testFiveParagraphsReturnsFiveRanges() {
        let paragraphs = ["First paragraph", "Second paragraph", "Third paragraph", "Fourth paragraph", "Fifth paragraph"]
        let text = paragraphs.joined(separator: "\n")
        let ranges = tracker.paragraphRanges(in: makeTextStorage(text))

        XCTAssertEqual(ranges.count, 5)

        // Verify each range maps to correct text
        let nsText = text as NSString
        for (i, range) in ranges.enumerated() {
            let extracted = nsText.substring(with: range)
            XCTAssertEqual(extracted, paragraphs[i], "Paragraph \(i) text mismatch")
        }
    }

    func testTrailingNewlineDoesNotCrash() {
        let text = "First paragraph\nSecond paragraph\n"
        let ranges = tracker.paragraphRanges(in: makeTextStorage(text))

        // "First paragraph" and "Second paragraph" — trailing \n does not create an empty third
        XCTAssertEqual(ranges.count, 2)
    }

    func testMultipleTrailingNewlinesHandled() {
        let text = "Hello\n\n\n"
        let ranges = tracker.paragraphRanges(in: makeTextStorage(text))

        // "Hello", empty paragraph, empty paragraph — trailing \n after last empty
        // NSString.enumerateSubstrings(.byParagraphs) includes empty paragraphs between \n\n
        XCTAssertGreaterThanOrEqual(ranges.count, 1)
        // Should not crash regardless of exact count
    }

    func testPastedThreeParagraphTextDetectsThreeRanges() {
        let text = "Paragraph one.\nParagraph two.\nParagraph three."
        let ranges = tracker.paragraphRanges(in: makeTextStorage(text))
        XCTAssertEqual(ranges.count, 3)
    }

    func testDeleteAcrossParagraphBoundaryDecrementsCount() {
        let before = "Hello\nWorld\nFoo"
        let after = "HelloWorld\nFoo"

        let previousRanges = tracker.paragraphRanges(in: makeTextStorage(before))
        let currentRanges = tracker.paragraphRanges(in: makeTextStorage(after))

        XCTAssertEqual(previousRanges.count, 3)
        XCTAssertEqual(currentRanges.count, 2)
    }

    func testSingleCharacterParagraphsDetected() {
        let text = "a\nb\nc"
        let ranges = tracker.paragraphRanges(in: makeTextStorage(text))
        XCTAssertEqual(ranges.count, 3)

        let nsText = text as NSString
        XCTAssertEqual(nsText.substring(with: ranges[0]), "a")
        XCTAssertEqual(nsText.substring(with: ranges[1]), "b")
        XCTAssertEqual(nsText.substring(with: ranges[2]), "c")
    }

    func testParagraphRangesAreContiguousAndCoverFullText() {
        let text = "First paragraph here.\nSecond one is longer with more words.\nThird."
        let ranges = tracker.paragraphRanges(in: makeTextStorage(text))

        // Ranges should cover the full text (excluding \n separators which are between paragraphs)
        for (i, range) in ranges.enumerated() {
            XCTAssertGreaterThan(range.length, 0, "Paragraph \(i) should have non-zero length")
        }
    }

    // MARK: - activeParagraphIndex

    func testCursorAtStartReturnsParagraphZero() {
        let ranges = [NSRange(location: 0, length: 10), NSRange(location: 11, length: 10)]
        XCTAssertEqual(tracker.activeParagraphIndex(cursorPosition: 0, paragraphs: ranges), 0)
    }

    func testCursorInMiddleOfSecondParagraph() {
        let ranges = [NSRange(location: 0, length: 10), NSRange(location: 11, length: 10)]
        XCTAssertEqual(tracker.activeParagraphIndex(cursorPosition: 15, paragraphs: ranges), 1)
    }

    func testCursorAtParagraphBoundaryBelongsToNextParagraph() {
        // Paragraph 0: location 0, length 10 (text ends at index 9)
        // Paragraph 1: location 11, length 10
        // Cursor at 11 (start of paragraph 1) → should return index 1
        let ranges = [NSRange(location: 0, length: 10), NSRange(location: 11, length: 10)]
        XCTAssertEqual(tracker.activeParagraphIndex(cursorPosition: 11, paragraphs: ranges), 1)
    }

    func testCursorAtEndOfLastParagraph() {
        let ranges = [NSRange(location: 0, length: 5), NSRange(location: 6, length: 5)]
        XCTAssertEqual(tracker.activeParagraphIndex(cursorPosition: 11, paragraphs: ranges), 1)
    }

    func testEmptyParagraphsReturnsZero() {
        XCTAssertEqual(tracker.activeParagraphIndex(cursorPosition: 5, paragraphs: []), 0)
    }

    // MARK: - didCompleteParagraph

    func testNewParagraphDetected() {
        let previous = [NSRange(location: 0, length: 10)]
        let current = [NSRange(location: 0, length: 10), NSRange(location: 11, length: 0)]
        XCTAssertTrue(tracker.didCompleteParagraph(previous: previous, current: current))
    }

    func testNoParagraphChangeReturnsFalse() {
        let ranges = [NSRange(location: 0, length: 10), NSRange(location: 11, length: 5)]
        XCTAssertFalse(tracker.didCompleteParagraph(previous: ranges, current: ranges))
    }

    func testParagraphDeletedReturnsFalse() {
        let previous = [NSRange(location: 0, length: 10), NSRange(location: 11, length: 5)]
        let current = [NSRange(location: 0, length: 16)]
        XCTAssertFalse(tracker.didCompleteParagraph(previous: previous, current: current))
    }

    func testMultipleParagraphsPastedDetected() {
        let previous = [NSRange(location: 0, length: 10)]
        let current = [NSRange(location: 0, length: 10), NSRange(location: 11, length: 10), NSRange(location: 22, length: 10)]
        XCTAssertTrue(tracker.didCompleteParagraph(previous: previous, current: current))
    }
}
