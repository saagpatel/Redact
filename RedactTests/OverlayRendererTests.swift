import XCTest
import UIKit
@testable import Redact

/// Coverage for the overlay engine — the renderer that draws every redaction bar.
///
/// These exercise a real `UITextView` with real TextKit 1 layout rather than a stub, because
/// the behaviour under test *is* the CoreText geometry: line-fragment rects, glyph rects, and
/// the inset conversion between them. A mock would assert the mock.
@MainActor
final class OverlayRendererTests: XCTestCase {

    /// Lazy so the `@MainActor` initializer runs inside a test method rather than during
    /// nonisolated instance setup. XCTest builds a fresh case object per test, so each test
    /// still gets its own renderer.
    private lazy var renderer = OverlayRenderer()

    // MARK: - Helpers

    /// Mirrors `RedactTextView.makeUIView`: TextKit 1, no scrolling, same insets and padding.
    ///
    /// The font is deliberately the unscaled base font rather than the `UIFontMetrics`-scaled
    /// one production uses — scaled metrics depend on the simulator's Dynamic Type setting,
    /// which would make every rect assertion here depend on machine state.
    private func makeTextView(_ text: String, width: CGFloat = 320) -> UITextView {
        let textView = UITextView(usingTextLayoutManager: false)
        textView.font = UIFont(name: "Georgia", size: 18) ?? .systemFont(ofSize: 18)
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 24, bottom: 16, right: 24)
        textView.textContainer.lineFragmentPadding = 0
        textView.frame = CGRect(x: 0, y: 0, width: width, height: 2000)
        textView.text = text
        textView.layoutIfNeeded()
        textView.layoutManager.ensureLayout(for: textView.textContainer)
        return textView
    }

    private func fullRange(_ textView: UITextView) -> NSRange {
        NSRange(location: 0, length: (textView.text as NSString).length)
    }

    private func shapeLayers(in textView: UITextView) -> [CAShapeLayer] {
        (textView.layer.sublayers ?? []).compactMap { $0 as? CAShapeLayer }
    }

    private func hiddenTextElements(in textView: UITextView) -> [UIView] {
        textView.subviews.filter { $0.accessibilityLabel == "Hidden text" }
    }

    private func lineFragmentCount(_ textView: UITextView) -> Int {
        let layoutManager = textView.layoutManager
        let glyphRange = layoutManager.glyphRange(
            forCharacterRange: fullRange(textView),
            actualCharacterRange: nil
        )
        var count = 0
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, _, _, _, _ in
            count += 1
        }
        return count
    }

    // MARK: - Full redaction

    func testFullRedactionAddsOneLayerPerLineFragment() {
        let textView = makeTextView("A short single line.")
        renderer.redact(paragraphIndex: 0, paragraphRange: fullRange(textView),
                        in: textView, style: .full, animated: false)

        XCTAssertEqual(lineFragmentCount(textView), 1, "precondition: text should occupy one line")
        XCTAssertEqual(shapeLayers(in: textView).count, 1)
    }

    func testFullRedactionOfWrappedParagraphAddsALayerPerWrappedLine() {
        let textView = makeTextView(String(repeating: "wrapping prose ", count: 30))
        let expectedLines = lineFragmentCount(textView)

        renderer.redact(paragraphIndex: 0, paragraphRange: fullRange(textView),
                        in: textView, style: .full, animated: false)

        XCTAssertGreaterThan(expectedLines, 1, "precondition: text should wrap")
        XCTAssertEqual(shapeLayers(in: textView).count, expectedLines)
    }

    func testFullRedactionLayersAreOffsetByTextContainerInset() throws {
        let textView = makeTextView("Inset check.")
        renderer.redact(paragraphIndex: 0, paragraphRange: fullRange(textView),
                        in: textView, style: .full, animated: false)

        let layer = try XCTUnwrap(shapeLayers(in: textView).first)
        XCTAssertEqual(layer.frame.minX, textView.textContainerInset.left, accuracy: 0.5)
        XCTAssertEqual(layer.frame.minY, textView.textContainerInset.top, accuracy: 0.5)
    }

    func testUnanimatedRedactionLayersAreImmediatelyOpaque() {
        let textView = makeTextView("Opaque immediately.")
        renderer.redact(paragraphIndex: 0, paragraphRange: fullRange(textView),
                        in: textView, style: .full, animated: false)

        XCTAssertEqual(shapeLayers(in: textView).first?.opacity, 1)
    }

    func testAnimatedRedactionLayersStartTransparent() {
        let textView = makeTextView("Fades in.")
        renderer.redact(paragraphIndex: 0, paragraphRange: fullRange(textView),
                        in: textView, style: .full, animated: true)

        let layer = shapeLayers(in: textView).first
        XCTAssertEqual(layer?.opacity, 0)
        XCTAssertNotNil(layer?.animation(forKey: "redactIn"))
    }

    func testEmptyParagraphProducesNoLayers() {
        let textView = makeTextView("")
        renderer.redact(paragraphIndex: 0, paragraphRange: NSRange(location: 0, length: 0),
                        in: textView, style: .full, animated: false)

        XCTAssertTrue(shapeLayers(in: textView).isEmpty)
    }

    // MARK: - Lifecycle

    func testRedactingSameParagraphTwiceDoesNotAccumulateLayers() {
        let textView = makeTextView("Redacted twice over.")
        let range = fullRange(textView)

        renderer.redact(paragraphIndex: 0, paragraphRange: range, in: textView, style: .full, animated: false)
        let afterFirst = shapeLayers(in: textView).count
        renderer.redact(paragraphIndex: 0, paragraphRange: range, in: textView, style: .full, animated: false)

        XCTAssertEqual(shapeLayers(in: textView).count, afterFirst,
                       "re-redacting a paragraph must replace its overlays, not stack new ones")
        XCTAssertEqual(hiddenTextElements(in: textView).count, 1)
    }

    func testRemoveOverlayRemovesBothLayersAndAccessibilityElement() {
        let textView = makeTextView("Removable.")
        renderer.redact(paragraphIndex: 0, paragraphRange: fullRange(textView),
                        in: textView, style: .full, animated: false)
        XCTAssertFalse(shapeLayers(in: textView).isEmpty)

        renderer.removeOverlay(forParagraphIndex: 0)

        XCTAssertTrue(shapeLayers(in: textView).isEmpty)
        XCTAssertTrue(hiddenTextElements(in: textView).isEmpty)
    }

    func testRemoveOverlayForUntrackedParagraphIsANoOp() {
        let textView = makeTextView("Only paragraph zero is tracked.")
        renderer.redact(paragraphIndex: 0, paragraphRange: fullRange(textView),
                        in: textView, style: .full, animated: false)
        let before = shapeLayers(in: textView).count

        renderer.removeOverlay(forParagraphIndex: 99)

        XCTAssertEqual(shapeLayers(in: textView).count, before)
    }

    func testRemoveAllOverlaysClearsEveryParagraph() {
        let textView = makeTextView("First line.\nSecond line.\nThird line.")
        let tracker = ParagraphTracker()
        let ranges = tracker.paragraphRanges(in: textView.textStorage)

        for (index, range) in ranges.enumerated() {
            renderer.redact(paragraphIndex: index, paragraphRange: range,
                            in: textView, style: .full, animated: false)
        }
        XCTAssertEqual(renderer.allOverlayLayers().count, 3)

        renderer.removeAllOverlays()

        XCTAssertTrue(renderer.allOverlayLayers().isEmpty)
        XCTAssertTrue(shapeLayers(in: textView).isEmpty)
        XCTAssertTrue(hiddenTextElements(in: textView).isEmpty)
    }

    func testAllOverlayLayersAreSortedByParagraphIndex() {
        let textView = makeTextView("Alpha.\nBravo.\nCharlie.")
        let ranges = ParagraphTracker().paragraphRanges(in: textView.textStorage)

        // Deliberately redacted out of order.
        for index in [2, 0, 1] {
            renderer.redact(paragraphIndex: index, paragraphRange: ranges[index],
                            in: textView, style: .full, animated: false)
        }

        XCTAssertEqual(renderer.allOverlayLayers().map(\.paragraphIndex), [0, 1, 2])
    }

    // MARK: - Accessibility

    func testRedactedParagraphExposesAHiddenTextElementToVoiceOver() throws {
        let textView = makeTextView("Sensitive prose.")
        renderer.redact(paragraphIndex: 0, paragraphRange: fullRange(textView),
                        in: textView, style: .full, animated: false)

        let element = try XCTUnwrap(hiddenTextElements(in: textView).first)
        XCTAssertTrue(element.isAccessibilityElement)
        XCTAssertEqual(element.accessibilityTraits, .staticText)
        XCTAssertFalse(element.isUserInteractionEnabled,
                       "the overlay must not intercept touches meant for the text view")
    }

    func testAccessibilityElementSpansAllRedactedLines() throws {
        let textView = makeTextView(String(repeating: "wrapping prose ", count: 30))
        renderer.redact(paragraphIndex: 0, paragraphRange: fullRange(textView),
                        in: textView, style: .full, animated: false)

        let element = try XCTUnwrap(hiddenTextElements(in: textView).first)
        let layerUnion = shapeLayers(in: textView)
            .map(\.frame)
            .reduce(CGRect.null) { $0.union($1) }

        XCTAssertEqual(element.frame.height, layerUnion.height, accuracy: 0.5)
    }

    // MARK: - Partial redaction

    func testPartialRedactionWithAllCharactersVisibleProducesNoLayers() {
        let textView = makeTextView("Every character stays visible.")
        let length = (textView.text as NSString).length

        renderer.redact(paragraphIndex: 0, paragraphRange: fullRange(textView), in: textView,
                        style: .partial(visibleCharIndices: Array(0..<length)), animated: false)

        XCTAssertTrue(shapeLayers(in: textView).isEmpty)
    }

    func testPartialRedactionWithNoVisibleCharactersMasksTheParagraph() {
        let textView = makeTextView("Nothing stays visible.")
        renderer.redact(paragraphIndex: 0, paragraphRange: fullRange(textView), in: textView,
                        style: .partial(visibleCharIndices: []), animated: false)

        XCTAssertFalse(shapeLayers(in: textView).isEmpty)
    }

    func testPartialRedactionNeverMasksWhitespace() {
        // "ab cd" with nothing visible → two runs ("ab", "cd"), the space is skipped.
        let textView = makeTextView("ab cd")
        renderer.redact(paragraphIndex: 0, paragraphRange: fullRange(textView), in: textView,
                        style: .partial(visibleCharIndices: []), animated: false)

        XCTAssertEqual(shapeLayers(in: textView).count, 2,
                       "the space must break the run rather than be covered")
    }

    /// Regression guard for the fixed 100-character masking cap.
    func testPartialRedactionMasksBeyondTheFirstHundredCharacters() {
        // Ends on a non-whitespace character: spaces are intentionally never masked,
        // so the final glyph has to be a real one for this assertion to mean anything.
        let textView = makeTextView(String(repeating: "redacted prose ", count: 40) + "end")
        let length = (textView.text as NSString).length
        XCTAssertGreaterThan(length, 400, "precondition: paragraph must exceed the old cap")

        renderer.redact(paragraphIndex: 0, paragraphRange: fullRange(textView), in: textView,
                        style: .partial(visibleCharIndices: []), animated: false)

        // The glyph at the very end of the paragraph must be covered by some layer.
        let layoutManager = textView.layoutManager
        let lastGlyph = layoutManager.glyphIndexForCharacter(at: length - 1)
        let lastRect = layoutManager.boundingRect(
            forGlyphRange: NSRange(location: lastGlyph, length: 1),
            in: textView.textContainer
        ).offsetBy(dx: textView.textContainerInset.left, dy: textView.textContainerInset.top)

        let covered = shapeLayers(in: textView).contains { $0.frame.insetBy(dx: -1, dy: -1).contains(lastRect.center) }
        XCTAssertTrue(covered, "the tail of a long paragraph must be masked, not left readable")
    }

    /// Changing which characters stay visible must change what gets masked. Guards against a
    /// renderer that ignores `visibleCharIndices` and masks the paragraph uniformly.
    func testDifferentVisibleSetsProduceDifferentMasks() {
        let text = String(repeating: "masked output ", count: 6)

        func frames(visible: [Int]) -> [CGRect] {
            let textView = makeTextView(text)
            let renderer = OverlayRenderer()
            renderer.redact(paragraphIndex: 0, paragraphRange: fullRange(textView), in: textView,
                            style: .partial(visibleCharIndices: visible), animated: false)
            return shapeLayers(in: textView).map(\.frame)
        }

        XCTAssertNotEqual(frames(visible: [0, 5, 9, 14, 22, 31]),
                          frames(visible: [1, 6, 10, 15, 23, 32]))
    }

    // MARK: - mergeContiguousRects

    func testMergeCollapsesAdjacentCharactersIntoOneRect() {
        let glyphs = [
            (charIndex: 0, rect: CGRect(x: 0, y: 0, width: 10, height: 20)),
            (charIndex: 1, rect: CGRect(x: 10, y: 0, width: 10, height: 20)),
            (charIndex: 2, rect: CGRect(x: 20, y: 0, width: 10, height: 20)),
        ]
        XCTAssertEqual(OverlayRenderer.mergeContiguousRects(glyphs),
                       [CGRect(x: 0, y: 0, width: 30, height: 20)])
    }

    func testMergeKeepsNonAdjacentCharactersSeparate() {
        let glyphs = [
            (charIndex: 0, rect: CGRect(x: 0, y: 0, width: 10, height: 20)),
            (charIndex: 5, rect: CGRect(x: 50, y: 0, width: 10, height: 20)),
        ]
        XCTAssertEqual(OverlayRenderer.mergeContiguousRects(glyphs).count, 2)
    }

    func testMergeOfEmptyInputIsEmpty() {
        XCTAssertTrue(OverlayRenderer.mergeContiguousRects([]).isEmpty)
    }

    func testMergeOfSingleGlyphReturnsThatGlyph() {
        let rect = CGRect(x: 4, y: 8, width: 10, height: 20)
        XCTAssertEqual(OverlayRenderer.mergeContiguousRects([(charIndex: 3, rect: rect)]), [rect])
    }

    func testMergeProducesFewerLayersThanMaskedCharacters() {
        let glyphs = (0..<40).map {
            (charIndex: $0, rect: CGRect(x: CGFloat($0) * 10, y: 0, width: 10, height: 20))
        }
        XCTAssertEqual(OverlayRenderer.mergeContiguousRects(glyphs).count, 1,
                       "40 adjacent masked characters must collapse to a single bar")
    }

    // MARK: - Reposition

    func testRepositionRebuildsOverlaysForEveryTrackedParagraph() {
        let textView = makeTextView("First line.\nSecond line.")
        let ranges = ParagraphTracker().paragraphRanges(in: textView.textStorage)

        for (index, range) in ranges.enumerated() {
            renderer.redact(paragraphIndex: index, paragraphRange: range,
                            in: textView, style: .full, animated: false)
        }
        let before = shapeLayers(in: textView).count

        renderer.repositionOverlays(in: textView, paragraphRanges: ranges)

        XCTAssertEqual(renderer.allOverlayLayers().map(\.paragraphIndex), [0, 1])
        XCTAssertEqual(shapeLayers(in: textView).count, before,
                       "reposition must replace overlays, not duplicate them")
        XCTAssertEqual(hiddenTextElements(in: textView).count, 2)
    }

    func testRepositionPreservesPartialStyle() {
        let textView = makeTextView("Partially masked paragraph text.")
        let range = fullRange(textView)
        renderer.redact(paragraphIndex: 0, paragraphRange: range, in: textView,
                        style: .partial(visibleCharIndices: [0, 1, 2]), animated: false)
        let before = shapeLayers(in: textView).count

        renderer.repositionOverlays(in: textView, paragraphRanges: [range])

        // A full-style rebuild would collapse to one layer per line; partial keeps the runs.
        XCTAssertEqual(shapeLayers(in: textView).count, before)
        XCTAssertGreaterThan(before, lineFragmentCount(textView))
    }

    func testRepositionUpdatesFramesAfterTheTextViewNarrows() {
        let textView = makeTextView(String(repeating: "reflowing prose ", count: 20))
        let range = fullRange(textView)
        renderer.redact(paragraphIndex: 0, paragraphRange: range, in: textView, style: .full, animated: false)
        let wideCount = shapeLayers(in: textView).count

        textView.frame = CGRect(x: 0, y: 0, width: 160, height: 2000)
        textView.layoutIfNeeded()
        textView.layoutManager.ensureLayout(for: textView.textContainer)
        renderer.repositionOverlays(in: textView, paragraphRanges: [range])

        XCTAssertGreaterThan(shapeLayers(in: textView).count, wideCount,
                             "narrower text wraps onto more lines, so it needs more bars")
    }

    func testRepositionDropsOverlaysForParagraphsThatNoLongerExist() {
        let textView = makeTextView("First line.\nSecond line.")
        let ranges = ParagraphTracker().paragraphRanges(in: textView.textStorage)
        for (index, range) in ranges.enumerated() {
            renderer.redact(paragraphIndex: index, paragraphRange: range,
                            in: textView, style: .full, animated: false)
        }

        // Simulates deleting across a paragraph boundary: two paragraphs merge into one.
        renderer.repositionOverlays(in: textView, paragraphRanges: [ranges[0]])

        XCTAssertEqual(renderer.allOverlayLayers().map(\.paragraphIndex), [0])
        XCTAssertEqual(hiddenTextElements(in: textView).count, 1,
                       "the dropped paragraph must not leave an orphaned VoiceOver element")
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
