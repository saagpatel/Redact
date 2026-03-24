import UIKit

final class OverlayTestViewController: UIViewController {

    private let textView: UITextView = {
        // Force TextKit 1 for reliable layoutManager access
        let tv = UITextView(usingTextLayoutManager: false)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.font = UIFont(name: "Georgia", size: 18)
        tv.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        tv.isEditable = true
        tv.isScrollEnabled = true
        tv.backgroundColor = .systemBackground
        tv.textColor = .label
        return tv
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()

    private let tracker = ParagraphTracker()
    private let renderer = OverlayRenderer()
    private let animator = RevealAnimator()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Overlay Test Harness"

        setupTextView()
        setupToolbar()
        setupStatusLabel()
        populateLoremIpsum()
        updateStatus()
    }

    // MARK: - Setup

    private func setupTextView() {
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -44),
        ])
    }

    private func setupToolbar() {
        let toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)

        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 44),
        ])

        let redactP1 = UIBarButtonItem(title: "Redact P1", style: .plain, target: self, action: #selector(redactFirstParagraph))
        let redactAll = UIBarButtonItem(title: "Redact All", style: .plain, target: self, action: #selector(redactAllParagraphs))
        let revealAll = UIBarButtonItem(title: "Reveal All", style: .plain, target: self, action: #selector(revealAllParagraphs))
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        toolbar.items = [redactP1, flex, redactAll, flex, revealAll]
    }

    private func setupStatusLabel() {
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    private func populateLoremIpsum() {
        textView.text = """
        The old typewriter sat on the desk, its keys worn smooth by years of use. \
        Each letter carried the weight of a thousand stories, typed one character at a time \
        into the quiet hum of late-night sessions.

        She preferred the resistance of the mechanical keys to the frictionless glass of her phone. \
        There was something honest about the effort — the deliberate press, the satisfying click, \
        the ink hitting paper like a small commitment.

        Outside, the rain had started again. It drummed against the window in no particular rhythm, \
        filling the gaps between sentences with a kind of music. She paused, listened, then typed faster.

        The story was about a lighthouse keeper who had stopped tending the light. \
        Not out of neglect, but because the ships had stopped coming. The harbor was empty now, \
        the town half-abandoned, and the beam swept over nothing but dark water.

        She wasn't sure how it would end. That was the point of writing this way — \
        forward only, no looking back. The ending would arrive when it was ready, \
        not when she decided it should.
        """
    }

    // MARK: - Actions

    @objc private func redactFirstParagraph() {
        guard let storage = textView.textStorage as? NSTextStorage else { return }
        let ranges = tracker.paragraphRanges(in: storage)
        guard !ranges.isEmpty else { return }

        renderer.redact(paragraphIndex: 0, paragraphRange: ranges[0], in: textView, style: .full, animated: true)
        updateStatus()
    }

    @objc private func redactAllParagraphs() {
        guard let storage = textView.textStorage as? NSTextStorage else { return }
        let ranges = tracker.paragraphRanges(in: storage)
        guard ranges.count > 1 else { return }

        // Redact all paragraphs except the last:
        // - All but second-to-last get .full
        // - Second-to-last gets .partial
        for i in 0..<(ranges.count - 1) {
            // For the partial case, generate a demo set of visible char indices (every other char)
            let demoVisibleIndices = stride(from: 0, to: 100, by: 2).map { $0 }
            let style: RedactionStyle = (i == ranges.count - 2)
                ? .partial(visibleCharIndices: demoVisibleIndices)
                : .full

            renderer.redact(paragraphIndex: i, paragraphRange: ranges[i], in: textView, style: style, animated: true)
        }
        updateStatus()
    }

    @objc private func revealAllParagraphs() {
        let overlays = renderer.allOverlayLayers()
        guard !overlays.isEmpty else { return }

        let wordCount = textView.text.wordCount
        statusLabel.text = "Revealing... (\(wordCount) words)"

        animator.animate(overlayLayers: overlays, wordCount: wordCount) { [weak self] in
            self?.renderer.removeAllOverlays()
            self?.updateStatus()
        }
    }

    // MARK: - Status

    private func updateStatus() {
        guard let storage = textView.textStorage as? NSTextStorage else { return }
        let ranges = tracker.paragraphRanges(in: storage)
        let wordCount = textView.text.wordCount
        statusLabel.text = "\(ranges.count) paragraphs · \(wordCount) words"
    }
}
