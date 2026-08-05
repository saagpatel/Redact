import XCTest
@testable import Redact

/// Coverage for `String.wordCount`.
///
/// This one number is load-bearing in three places: it gates the Done button at 50 words
/// (`WriteView`), triggers the single-paragraph hint at 200 (`RedactTextView`), and feeds the
/// stats card and reveal duration. An off-by-one here is visible to the writer.
final class StringWordCountTests: XCTestCase {

    // MARK: - Empty and whitespace

    func testEmptyStringHasNoWords() {
        XCTAssertEqual("".wordCount, 0)
    }

    func testWhitespaceOnlyStringHasNoWords() {
        XCTAssertEqual("   ".wordCount, 0)
        XCTAssertEqual("\n\n".wordCount, 0)
        XCTAssertEqual("\t \n ".wordCount, 0)
    }

    // MARK: - Basic counting

    func testSingleWord() {
        XCTAssertEqual("Hello".wordCount, 1)
    }

    func testTwoWordsSeparatedByASingleSpace() {
        XCTAssertEqual("Hello world".wordCount, 2)
    }

    func testLeadingAndTrailingWhitespaceIsIgnored() {
        XCTAssertEqual("   Hello world   ".wordCount, 2)
        XCTAssertEqual("\n\tHello world\n".wordCount, 2)
    }

    func testRunsOfWhitespaceDoNotCreatePhantomWords() {
        XCTAssertEqual("Hello     world".wordCount, 2)
        XCTAssertEqual("one  two   three    four".wordCount, 4)
    }

    // MARK: - Separators

    func testNewlinesSeparateWords() {
        XCTAssertEqual("Hello\nworld".wordCount, 2)
    }

    func testParagraphBreaksDoNotCreatePhantomWords() {
        // The writing surface is paragraph-separated, so this is the common real input.
        XCTAssertEqual("First paragraph.\n\nSecond paragraph.".wordCount, 4)
    }

    func testTabsSeparateWords() {
        XCTAssertEqual("Hello\tworld".wordCount, 2)
    }

    func testNonBreakingSpaceSeparatesWords() {
        XCTAssertEqual("Hello\u{00A0}world".wordCount, 2)
    }

    // MARK: - Punctuation and hyphenation

    func testPunctuationAttachedToWordsDoesNotSplitThem() {
        XCTAssertEqual("Hello, world!".wordCount, 2)
        XCTAssertEqual("Really? Yes. Absolutely.".wordCount, 3)
    }

    func testHyphenatedWordCountsAsOne() {
        XCTAssertEqual("well-considered".wordCount, 1)
    }

    func testEmDashWithoutSpacesJoinsWords() {
        // Documents current behavior: no whitespace means no split.
        XCTAssertEqual("word—word".wordCount, 1)
    }

    func testEllipsisAndQuotesDoNotSplitWords() {
        XCTAssertEqual("\"Wait...\" she said".wordCount, 3)
    }

    // MARK: - Realistic prose

    func testProseParagraphCountsCorrectly() {
        let text = "The quick brown fox jumps over the lazy dog."
        XCTAssertEqual(text.wordCount, 9)
    }

    func testCountIsExactAtTheDoneButtonThreshold() {
        // WriteView reveals Done at wordCount >= 50; an off-by-one is user-visible.
        let fortyNine = Array(repeating: "word", count: 49).joined(separator: " ")
        let fifty = Array(repeating: "word", count: 50).joined(separator: " ")

        XCTAssertEqual(fortyNine.wordCount, 49)
        XCTAssertEqual(fifty.wordCount, 50)
    }

    func testCountIsExactAtTheSingleParagraphHintThreshold() {
        // RedactTextView shows the "press return" hint at wordCount >= 200.
        let text = Array(repeating: "word", count: 200).joined(separator: " ")
        XCTAssertEqual(text.wordCount, 200)
    }

    func testMultilineDocumentWithMixedSpacingCountsCorrectly() {
        let text = """
        First line here.

            Indented second line.
        \tTabbed third line.
        """
        // 3 lines x 3 words: "First line here." / "Indented second line." / "Tabbed third line."
        XCTAssertEqual(text.wordCount, 9)
    }

    // MARK: - Unicode

    func testEmojiCountsAsAWord() {
        XCTAssertEqual("hello 👋 world".wordCount, 3)
    }

    func testAccentedAndNonLatinTextCounts() {
        XCTAssertEqual("café société".wordCount, 2)
        XCTAssertEqual("こんにちは 世界".wordCount, 2)
    }
}
