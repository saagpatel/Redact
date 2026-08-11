import UIKit

/// Largest horizontal gap between two glyph rects still treated as touching. Absorbs sub-point
/// kerning and layout rounding; the narrowest glyph that could sit in a gap is far wider.
private let glyphAdjacencyTolerance: CGFloat = 0.5

enum RedactionStyle {
    case full
    case partial(visibleCharIndices: [Int])  // Character positions (0-based within paragraph) to leave uncovered
}

@MainActor
protocol OverlayRendering {
    /// Places animated redaction overlays for a given paragraph index + NSRange in the UITextView
    func redact(paragraphIndex: Int, paragraphRange: NSRange, in textView: UITextView, style: RedactionStyle, animated: Bool)

    /// Removes overlays for a specific paragraph index
    func removeOverlay(forParagraphIndex index: Int)

    /// Repositions all overlays after text reflow — call debounced 50ms after textViewDidChange
    func repositionOverlays(in textView: UITextView, paragraphRanges: [NSRange])
}

@MainActor
final class OverlayRenderer: OverlayRendering {

    /// Tracks overlay layers keyed by paragraph index
    private var overlayLayers: [Int: (style: RedactionStyle, layers: [CAShapeLayer])] = [:]

    /// Transparent UIView elements for VoiceOver — one per redacted paragraph
    private var accessibilityViews: [Int: UIView] = [:]

    // MARK: - Redact

    func redact(paragraphIndex: Int, paragraphRange: NSRange, in textView: UITextView, style: RedactionStyle, animated: Bool) {
        removeOverlay(forParagraphIndex: paragraphIndex)

        let layoutManager = textView.layoutManager

        switch style {
        case .full:
            redactFull(
                paragraphIndex: paragraphIndex,
                paragraphRange: paragraphRange,
                in: textView,
                layoutManager: layoutManager,
                animated: animated
            )
        case .partial(let visibleCharIndices):
            redactPartial(
                paragraphIndex: paragraphIndex,
                paragraphRange: paragraphRange,
                in: textView,
                layoutManager: layoutManager,
                visibleCharIndices: visibleCharIndices,
                animated: animated
            )
        }
    }

    // MARK: - Full Redaction

    private func redactFull(
        paragraphIndex: Int,
        paragraphRange: NSRange,
        in textView: UITextView,
        layoutManager: NSLayoutManager,
        animated: Bool
    ) {
        let lineRects = lineRectsForRange(paragraphRange, in: textView, layoutManager: layoutManager)
        guard !lineRects.isEmpty else { return }

        var layers: [CAShapeLayer] = []

        for (lineIndex, rect) in lineRects.enumerated() {
            let layer = makeLayer(frame: rect, opacity: animated ? 0 : 1)
            textView.layer.addSublayer(layer)
            layers.append(layer)

            if animated {
                animateLayerIn(layer, lineIndex: lineIndex, targetOpacity: 1)
            }
        }

        overlayLayers[paragraphIndex] = (style: .full, layers: layers)
        addAccessibilityView(for: paragraphIndex, lineRects: lineRects, in: textView)
    }

    // MARK: - Partial Redaction (per-glyph masking)

    private func redactPartial(
        paragraphIndex: Int,
        paragraphRange: NSRange,
        in textView: UITextView,
        layoutManager: NSLayoutManager,
        visibleCharIndices: [Int],
        animated: Bool
    ) {
        guard !textView.textContainer.size.width.isZero else { return }

        let inset = textView.textContainerInset
        let visibleSet = Set(visibleCharIndices)
        let paragraphLength = paragraphRange.length

        // Build per-line groups of glyph rects to mask
        let glyphRange = layoutManager.glyphRange(
            forCharacterRange: paragraphRange,
            actualCharacterRange: nil
        )

        var lineGroups: [[CGRect]] = []

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { [weak textView] _, _, textContainer, lineGlyphRange, _ in
            guard let textView else { return }
            // Convert line glyph range to character range
            let lineCharRange = layoutManager.characterRange(forGlyphRange: lineGlyphRange, actualGlyphRange: nil)
            var lineGlyphRects: [CGRect] = []

            let lineCharStart = lineCharRange.location
            let lineCharEnd = lineCharRange.location + lineCharRange.length

            // Iterate characters in this line that belong to the paragraph
            for absCharIndex in lineCharStart..<lineCharEnd {
                let relCharIndex = absCharIndex - paragraphRange.location
                guard relCharIndex >= 0, relCharIndex < paragraphLength else { continue }

                // Skip if this character is in the visible set (should NOT be masked)
                if visibleSet.contains(relCharIndex) { continue }

                // Skip whitespace — no visual value in covering spaces
                let charRange = NSRange(location: absCharIndex, length: 1)
                if let swiftRange = Range(charRange, in: textView.text) {
                    let char = textView.text[swiftRange]
                    if char.unicodeScalars.allSatisfy({ CharacterSet.whitespacesAndNewlines.contains($0) }) {
                        continue
                    }
                }

                let charGlyphIndex = layoutManager.glyphIndexForCharacter(at: absCharIndex)

                // enumerateEnclosingRects, not boundingRect. For a glyph inside a
                // right-to-left run, boundingRect returns a rect spanning the entire run —
                // measured at 118pt for a 13-character Arabic line whose glyphs sit 5pt apart
                // — so masking one character blacked out every character beside it, and an RTL
                // paragraph rendered solid rather than half visible. This is the API selection
                // highlighting uses, and it returns tight, bidi-correct rects.
                layoutManager.enumerateEnclosingRects(
                    forGlyphRange: NSRange(location: charGlyphIndex, length: 1),
                    withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                    in: textContainer
                ) { glyphRect, _ in
                    let converted = glyphRect.offsetBy(dx: inset.left, dy: inset.top)
                    if !converted.isEmpty && converted.width > 0 {
                        lineGlyphRects.append(converted)
                    }
                }
            }

            let merged = Self.mergeAdjacentRects(lineGlyphRects)
            if !merged.isEmpty {
                lineGroups.append(merged)
            }
        }

        guard !lineGroups.isEmpty else { return }

        var layers: [CAShapeLayer] = []
        let allRects = lineGroups.flatMap { $0 }

        for (lineIndex, lineRects) in lineGroups.enumerated() {
            for rect in lineRects {
                let layer = makeLayer(frame: rect, opacity: animated ? 0 : 1)
                textView.layer.addSublayer(layer)
                layers.append(layer)
            }

            if animated {
                // Animate all layers in this line group together (staggered by line, not glyph)
                for layer in layers.suffix(lineRects.count) {
                    animateLayerIn(layer, lineIndex: lineIndex, targetOpacity: 1)
                }
            }
        }

        overlayLayers[paragraphIndex] = (style: .partial(visibleCharIndices: visibleCharIndices), layers: layers)
        addAccessibilityView(for: paragraphIndex, lineRects: allRects, in: textView)
    }

    // MARK: - Remove

    func removeOverlay(forParagraphIndex index: Int) {
        if let entry = overlayLayers[index] {
            for layer in entry.layers {
                layer.removeAllAnimations()
                layer.removeFromSuperlayer()
            }
            overlayLayers.removeValue(forKey: index)
        }

        if let view = accessibilityViews[index] {
            view.removeFromSuperview()
            accessibilityViews.removeValue(forKey: index)
        }
    }

    // MARK: - Reposition

    func repositionOverlays(in textView: UITextView, paragraphRanges: [NSRange]) {
        let currentEntries = overlayLayers

        for (index, entry) in currentEntries {
            for layer in entry.layers {
                layer.removeFromSuperlayer()
            }
            overlayLayers.removeValue(forKey: index)
        }

        for view in accessibilityViews.values {
            view.removeFromSuperview()
        }
        accessibilityViews.removeAll()

        for (index, entry) in currentEntries {
            guard index < paragraphRanges.count else { continue }
            redact(paragraphIndex: index, paragraphRange: paragraphRanges[index], in: textView, style: entry.style, animated: false)
        }
    }

    // MARK: - Access for RevealAnimator

    /// Returns all tracked overlay layers sorted by paragraph index
    func allOverlayLayers() -> [(paragraphIndex: Int, layers: [CAShapeLayer])] {
        overlayLayers
            .sorted { $0.key < $1.key }
            .map { (paragraphIndex: $0.key, layers: $0.value.layers) }
    }

    /// Removes all tracked layers and accessibility views
    func removeAllOverlays() {
        for (index, _) in overlayLayers {
            removeOverlay(forParagraphIndex: index)
        }
    }

    // MARK: - Private Helpers

    private func makeLayer(frame: CGRect, opacity: Float) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.path = UIBezierPath(rect: CGRect(origin: .zero, size: frame.size)).cgPath
        layer.fillColor = UIColor.redactInk.cgColor
        layer.frame = frame
        layer.opacity = opacity
        return layer
    }

    private func animateLayerIn(_ layer: CAShapeLayer, lineIndex: Int, targetOpacity: Float) {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 0
        animation.toValue = targetOpacity
        animation.duration = 0.25
        animation.beginTime = CACurrentMediaTime() + Double(lineIndex) * 0.08
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        layer.add(animation, forKey: "redactIn")
    }

    private func lineRectsForRange(_ range: NSRange, in textView: UITextView, layoutManager: NSLayoutManager) -> [CGRect] {
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var rects: [CGRect] = []
        let inset = textView.textContainerInset

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, _, _ in
            let converted = CGRect(
                x: usedRect.origin.x + inset.left,
                y: usedRect.origin.y + inset.top,
                width: usedRect.width,
                height: usedRect.height
            )
            rects.append(converted)
        }

        return rects
    }

    /// Collapses glyph rects that visually abut into single bars.
    ///
    /// Merging is decided on geometry, never on character index. Characters *k* and *k+1* are
    /// usually side by side, but not always: across a bidirectional boundary — English quoted
    /// inside Arabic, say — they can sit at opposite ends of the line, and unioning those two
    /// would black out every visible glyph between them. Comparing the drawn rectangles asks
    /// the only question that actually matters, is there a gap to leave uncovered, and so it
    /// holds for left-to-right, right-to-left, mixed runs, ligatures, and zero-width marks
    /// alike.
    ///
    /// One bar instead of one per glyph renders identically with far fewer layers, and reads
    /// as a redaction bar rather than a row of slivers. This reduces the layer count by roughly
    /// 4x; it does not bound it. The mask selects each character independently at ~50%, so run
    /// lengths are geometrically distributed with a mean of 2 and the total stays linear in
    /// paragraph length: roughly 100 layers for a 400-character paragraph, about 1,300 for a
    /// 5,000-character one. Ordinary paragraphs are comfortable; nothing here bounds a writer
    /// who never presses return.
    nonisolated static func mergeAdjacentRects(_ rects: [CGRect]) -> [CGRect] {
        guard let first = rects.first else { return [] }

        var merged: [CGRect] = []
        var runRect = first

        for rect in rects.dropFirst() {
            if abuts(runRect, rect) {
                runRect = runRect.union(rect)
            } else {
                merged.append(runRect)
                runRect = rect
            }
        }
        merged.append(runRect)

        return merged
    }

    /// Two rects abut when they share a line and leave no meaningful horizontal gap.
    /// Direction-agnostic: right-to-left runs advance leftward and still abut.
    nonisolated private static func abuts(_ a: CGRect, _ b: CGRect) -> Bool {
        let sharesLine = a.minY < b.maxY && b.minY < a.maxY
        let horizontalGap = max(a.minX, b.minX) - min(a.maxX, b.maxX)
        return sharesLine && horizontalGap <= glyphAdjacencyTolerance
    }

    private func addAccessibilityView(for paragraphIndex: Int, lineRects: [CGRect], in textView: UITextView) {
        guard !lineRects.isEmpty else { return }

        let unionRect = lineRects.reduce(lineRects[0]) { $0.union($1) }
        let view = UIView(frame: unionRect)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = true
        view.accessibilityLabel = "Hidden text"
        view.accessibilityTraits = .staticText
        textView.addSubview(view)
        accessibilityViews[paragraphIndex] = view
    }
}
