import SwiftUI
import UIKit

struct RedactTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var redactionState: RedactionState
    @Binding var shouldReveal: Bool
    let documentID: UUID
    let visibilityFullParagraphs: Int
    let visibilityPartialParagraphs: Int
    var isEditable: Bool = true
    var onTextChange: (() -> Void)?
    var onRevealComplete: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView(usingTextLayoutManager: false)
        textView.delegate = context.coordinator

        // Typography — New York preferred, Georgia fallback
        let baseFont = UIFont(name: "NewYork-Regular", size: 18)
            ?? UIFont(name: "Georgia", size: 18)
            ?? UIFont.systemFont(ofSize: 18, weight: .regular)
        textView.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: baseFont)
        textView.adjustsFontForContentSizeCategory = true

        // Layout
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 24, bottom: 16, right: 24)
        textView.textContainer.lineFragmentPadding = 0

        // Appearance
        textView.backgroundColor = .clear
        textView.textColor = .label
        textView.tintColor = .label

        // Keyboard
        textView.autocorrectionType = .default
        textView.autocapitalizationType = .sentences

        // Populate text
        if !text.isEmpty {
            textView.text = text
            // Defer overlay restoration until layout completes
            DispatchQueue.main.async {
                context.coordinator.restoreOverlays(in: textView)
            }
        }

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.isEditable = isEditable
        uiView.isUserInteractionEnabled = isEditable || !shouldReveal

        context.coordinator.parent = self

        // Handle reveal trigger
        if shouldReveal && !context.coordinator.isRevealing {
            context.coordinator.performReveal(in: uiView)
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: RedactTextView

        let tracker = ParagraphTracker()
        let renderer = OverlayRenderer()
        let visibilityEngine = VisibilityEngine()
        let animator = RevealAnimator()

        var previousParagraphRanges: [NSRange] = []
        var repositionWorkItem: DispatchWorkItem?
        var isRevealing = false
        private var isRestoring = false

        // 1000-word single-paragraph hint
        private var singleParagraphHintLabel: UILabel?
        private var singleParagraphHintWordCount = 0

        init(_ parent: RedactTextView) {
            self.parent = parent
        }

        // MARK: - UITextViewDelegate

        func textViewDidChange(_ textView: UITextView) {
            guard !isRestoring else { return }

            // 1. Sync text to SwiftUI
            parent.text = textView.text

            // 2. Compute paragraph ranges
            let currentRanges = tracker.paragraphRanges(in: textView.textStorage)

            // 3. Check for paragraph completion
            if tracker.didCompleteParagraph(previous: previousParagraphRanges, current: currentRanges) {
                handleParagraphCompletion(textView: textView, currentRanges: currentRanges)
            }

            // 4. Debounced overlay reposition (50ms)
            scheduleRepositionOverlays(textView: textView, ranges: currentRanges)

            // 5. Update previous ranges
            previousParagraphRanges = currentRanges

            // 6. Check for single-paragraph hint
            updateSingleParagraphHint(textView: textView, ranges: currentRanges)

            // 7. Notify parent
            parent.onTextChange?()
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            let currentRanges = tracker.paragraphRanges(in: textView.textStorage)
            guard !currentRanges.isEmpty else { return true }

            // Only the last paragraph is editable (forward-only writing)
            let lastParagraphIndex = currentRanges.count - 1
            let lastRange = currentRanges[lastParagraphIndex]

            // Allow changes that start at or after the last paragraph's start
            // Also allow changes at the very end of text (appending)
            if range.location >= lastRange.location {
                return true
            }

            // Allow if this is a newline being appended at the end of the last paragraph
            // (creating a new paragraph)
            let lastParagraphEnd = lastRange.location + lastRange.length
            if range.location == lastParagraphEnd && text == "\n" {
                return true
            }

            return false
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isRestoring, !isRevealing else { return }
            let currentRanges = tracker.paragraphRanges(in: textView.textStorage)
            guard !currentRanges.isEmpty else { return }

            let cursorPosition = textView.selectedRange.location
            let lastRange = currentRanges[currentRanges.count - 1]

            // Snap cursor to last paragraph if it's in an earlier one
            if cursorPosition < lastRange.location {
                textView.selectedRange = NSRange(location: lastRange.location, length: 0)
            }
        }

        // MARK: - Paragraph Completion

        private func handleParagraphCompletion(textView: UITextView, currentRanges: [NSRange]) {
            // Verify the completed paragraph has content (not just an empty return)
            let completedIndex = currentRanges.count - 2
            guard completedIndex >= 0, completedIndex < currentRanges.count else { return }

            let completedRange = currentRanges[completedIndex]
            let completedText = (textView.text as NSString).substring(with: completedRange)
            guard !completedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

            let activeIndex = currentRanges.count - 1
            let paragraphsAdded = currentRanges.count - previousParagraphRanges.count
            let isPaste = paragraphsAdded > 1

            // Compute new visibility
            let previousVisibility = parent.redactionState.paragraphs
            let newVisibility = visibilityEngine.computeVisibility(
                paragraphCount: currentRanges.count,
                activeParagraphIndex: activeIndex,
                fullVisible: parent.visibilityFullParagraphs,
                partialVisible: parent.visibilityPartialParagraphs,
                documentSeed: parent.documentID
            )

            // Apply changes
            let changes = visibilityEngine.visibilityChanges(
                previous: previousVisibility,
                current: newVisibility
            )

            for change in changes {
                guard change.index < currentRanges.count else { continue }
                let range = currentRanges[change.index]

                switch change.to {
                case .redacted:
                    let shouldAnimate = !isPaste && change.from != .redacted
                    renderer.redact(
                        paragraphIndex: change.index,
                        paragraphRange: range,
                        in: textView,
                        style: .full,
                        animated: shouldAnimate
                    )
                case .partial:
                    let shouldAnimate = !isPaste && change.from != .partial
                    let visibleIndices = newVisibility
                        .first(where: { $0.index == change.index })?
                        .partiallyVisibleIndices ?? []
                    renderer.redact(
                        paragraphIndex: change.index,
                        paragraphRange: range,
                        in: textView,
                        style: .partial(visibleCharIndices: visibleIndices),
                        animated: shouldAnimate
                    )
                case .visible:
                    renderer.removeOverlay(forParagraphIndex: change.index)
                }
            }

            // Update redaction state
            parent.redactionState = RedactionState(
                paragraphs: newVisibility,
                activeParagraphIndex: activeIndex
            )

            // Haptic feedback
            UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.5)

            // Dismiss 1000-word hint once a second paragraph is created
            dismissSingleParagraphHint(animated: true)
        }

        // MARK: - Debounce

        private func scheduleRepositionOverlays(textView: UITextView, ranges: [NSRange]) {
            repositionWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.renderer.repositionOverlays(in: textView, paragraphRanges: ranges)
            }
            repositionWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
        }

        // MARK: - Single-Paragraph Hint

        private func updateSingleParagraphHint(textView: UITextView, ranges: [NSRange]) {
            guard ranges.count == 1 else {
                dismissSingleParagraphHint(animated: true)
                return
            }

            let wordCount = textView.text.wordCount
            if wordCount >= 200 {
                showSingleParagraphHint(in: textView)
            } else if wordCount < 200 {
                dismissSingleParagraphHint(animated: false)
            }
        }

        private func showSingleParagraphHint(in textView: UITextView) {
            guard singleParagraphHintLabel == nil else { return }

            let label = UILabel()
            label.text = "Press return to start a new paragraph"
            label.font = UIFont.preferredFont(forTextStyle: .footnote)
            label.textColor = .secondaryLabel
            label.textAlignment = .center
            label.numberOfLines = 1
            label.alpha = 0

            // Position at the bottom of the text view's visible area
            let labelWidth = textView.bounds.width - 32
            label.frame = CGRect(
                x: 16,
                y: textView.contentSize.height + 8,
                width: labelWidth,
                height: 24
            )

            textView.addSubview(label)
            singleParagraphHintLabel = label

            UIView.animate(withDuration: 0.3) {
                label.alpha = 1
            }
        }

        private func dismissSingleParagraphHint(animated: Bool) {
            guard let label = singleParagraphHintLabel else { return }
            singleParagraphHintLabel = nil

            if animated {
                UIView.animate(withDuration: 0.2, animations: {
                    label.alpha = 0
                }, completion: { _ in
                    label.removeFromSuperview()
                })
            } else {
                label.removeFromSuperview()
            }
        }

        // MARK: - Session Restore

        func restoreOverlays(in textView: UITextView) {
            isRestoring = true
            defer { isRestoring = false }

            let currentRanges = tracker.paragraphRanges(in: textView.textStorage)
            previousParagraphRanges = currentRanges

            for paragraphState in parent.redactionState.paragraphs {
                guard paragraphState.index < currentRanges.count else { continue }
                let range = currentRanges[paragraphState.index]

                switch paragraphState.visibility {
                case .redacted:
                    renderer.redact(
                        paragraphIndex: paragraphState.index,
                        paragraphRange: range,
                        in: textView,
                        style: .full,
                        animated: false
                    )
                case .partial:
                    renderer.redact(
                        paragraphIndex: paragraphState.index,
                        paragraphRange: range,
                        in: textView,
                        style: .partial(visibleCharIndices: paragraphState.partiallyVisibleIndices),
                        animated: false
                    )
                case .visible:
                    break
                }
            }

            // Position cursor at end
            textView.selectedRange = NSRange(location: textView.text.count, length: 0)
        }

        // MARK: - Reveal

        func performReveal(in textView: UITextView) {
            isRevealing = true
            textView.isEditable = false
            textView.isUserInteractionEnabled = false

            let overlays = renderer.allOverlayLayers()
            let wordCount = textView.text.wordCount

            UINotificationFeedbackGenerator().notificationOccurred(.success)

            animator.animate(overlayLayers: overlays, wordCount: wordCount) { [weak self] in
                self?.renderer.removeAllOverlays()
                self?.isRevealing = false
                self?.parent.onRevealComplete?()
            }
        }
    }
}
