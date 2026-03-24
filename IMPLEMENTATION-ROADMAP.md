# Redact — Implementation Roadmap

---

## Architecture

### System Overview

```
[WriteView (SwiftUI)]
    └── [RedactTextView (UIViewRepresentable)]
            └── [UITextView (UIKit)] ← user types here
            └── [RedactionOverlayEngine]
                    ├── [ParagraphTracker]   → detects paragraph boundaries in NSTextStorage
                    ├── [OverlayRenderer]    → places/animates CAShapeLayer overlays per text line
                    └── [RevealAnimator]     → cascade dismiss of all overlays on Done

[DocumentStore] (@MainActor)
    └── FileManager → <sandbox>/Documents/redact/
            ├── settings.json         (AppSettings)
            ├── documents/<uuid>.json (completed Documents)
            └── documents/in-progress/<uuid>.json (active session)

[DocumentListView (SwiftUI)] → reads DocumentStore
[StatsView (SwiftUI)]        → shown post-reveal over revealed text
[EditView (SwiftUI)]         → standard editor for completed documents
[SettingsView (SwiftUI)]     → visibility rules, training mode toggle
[NewDocumentSheet (SwiftUI)] → word count target + title before writing starts
```

### File Structure

```
Redact/
├── Redact.xcodeproj/
├── Redact/
│   ├── App/
│   │   ├── RedactApp.swift                  # @main entry point, app lifecycle
│   │   └── AppState.swift                   # ObservableObject: AppSettings, first-launch flag
│   ├── Models/
│   │   ├── Document.swift                   # Document struct, Codable, Identifiable
│   │   ├── RedactionState.swift             # ParagraphState, VisibilityLevel enums + Codable
│   │   └── WritingStats.swift               # WPM, duration, word count, streak — Codable
│   ├── Store/
│   │   └── DocumentStore.swift              # CRUD + atomic FileManager I/O, @MainActor
│   ├── Engine/
│   │   ├── ParagraphTracker.swift           # NSTextStorage paragraph boundary detection
│   │   ├── OverlayRenderer.swift            # CAShapeLayer creation + CoreText rect positioning
│   │   └── RevealAnimator.swift             # Cascade animation sequence (all overlays → opacity 0)
│   ├── Views/
│   │   ├── DocumentListView.swift           # Home: list of completed docs + in-progress card
│   │   ├── WriteView.swift                  # Main writing screen (SwiftUI shell)
│   │   ├── RedactTextView.swift             # UIViewRepresentable wrapping UITextView
│   │   ├── RevealView.swift                 # Full-screen reveal animation → transitions to EditView
│   │   ├── StatsView.swift                  # Post-reveal stats card (overlaid on revealed text)
│   │   ├── EditView.swift                   # Standard editor for completed documents
│   │   ├── SettingsView.swift               # Visibility rules stepper, training mode toggle
│   │   └── NewDocumentSheet.swift           # Pre-writing sheet: title + word count target
│   ├── Extensions/
│   │   ├── String+WordCount.swift           # wordCount computed property (split on whitespace)
│   │   └── UITextView+ParagraphRects.swift  # CoreText helpers: line rects for NSRange
│   └── Resources/
│       ├── Assets.xcassets/                 # App icon, accent color
│       └── Info.plist
└── RedactTests/
    ├── ParagraphTrackerTests.swift
    ├── OverlayRendererTests.swift
    ├── DocumentStoreTests.swift
    └── RedactionStateTests.swift
```

### Data Model

```swift
// Models/Document.swift
struct Document: Codable, Identifiable {
    let id: UUID
    var title: String                    // Auto: first 5 words of first paragraph. Editable post-reveal.
    var rawText: String                  // Full plain text content
    var redactionState: RedactionState   // Per-paragraph visibility — serialized for session restore
    var isComplete: Bool                 // false = in-progress, true = revealed
    var wordCountTarget: Int?            // nil = open-ended
    var createdAt: Date
    var lastModifiedAt: Date
    var revealedAt: Date?                // nil until revealed
    var stats: WritingStats?             // nil until revealed
}

// Models/RedactionState.swift
struct RedactionState: Codable {
    struct ParagraphState: Codable {
        let index: Int
        let visibility: VisibilityLevel
        let partiallyVisibleIndices: [Int]  // character indices visible in .partial state
    }

    enum VisibilityLevel: String, Codable {
        case visible   // current + previous paragraph — 100% shown
        case partial   // 50% of chars visible, seeded from document.id
        case redacted  // fully hidden, 100% covered
    }

    var paragraphs: [ParagraphState]
    var activeParagraphIndex: Int
}

// Models/WritingStats.swift
struct WritingStats: Codable {
    let wordCount: Int
    let paragraphCount: Int
    let durationSeconds: TimeInterval       // first keystroke → Done tap
    let wordsPerMinute: Double              // wordCount / (durationSeconds / 60)
    let longestStreakSeconds: TimeInterval  // longest uninterrupted typing (no pause > 30s)
}

// App/AppState.swift — persisted as settings.json
struct AppSettings: Codable {
    var visibilityFullParagraphs: Int = 1    // paragraphs shown at 100%
    var visibilityPartialParagraphs: Int = 1 // paragraphs shown at ~50%
    var hasCompletedFirstDocument: Bool = false
    var trainingModeEnabled: Bool = true
}
```

### FileManager Storage Schema

```
<app-sandbox>/Documents/redact/
├── settings.json                     # AppSettings (Codable → JSON)
└── documents/
    ├── <uuid>.json                   # Completed Document (isComplete = true)
    └── in-progress/
        └── <uuid>.json               # Active session (isComplete = false, includes RedactionState)
```

All writes are atomic:
```swift
// Atomic write pattern — use everywhere in DocumentStore
let data = try JSONEncoder().encode(document)
let tmpURL = destinationURL.appendingPathExtension("tmp")
try data.write(to: tmpURL, options: .atomic)
_ = try FileManager.default.replaceItemAt(destinationURL, withItemAt: tmpURL)
```

### Internal Interfaces

```swift
// Engine/ParagraphTracker.swift
protocol ParagraphTracking {
    /// Returns array of paragraph NSRanges from NSTextStorage
    func paragraphRanges(in textStorage: NSTextStorage) -> [NSRange]
    /// Returns index of paragraph containing cursorPosition
    func activeParagraphIndex(cursorPosition: Int, paragraphs: [NSRange]) -> Int
    /// Returns true if a new paragraph was just created (current.count > previous.count)
    func didCompleteParagraph(previous: [NSRange], current: [NSRange]) -> Bool
}

// Engine/OverlayRenderer.swift
enum RedactionStyle {
    case full                      // 100% opacity black fill
    case partial(seed: UUID)       // 50% of characters masked, seeded for consistency
}

protocol OverlayRendering {
    /// Places animated redaction overlays for a given paragraph NSRange in the UITextView
    func redact(paragraphRange: NSRange, in textView: UITextView, style: RedactionStyle, animated: Bool)
    /// Removes overlays for a paragraph (used during reveal)
    func reveal(paragraphRange: NSRange, in textView: UITextView, delay: TimeInterval)
    /// Repositions all overlays after text reflow — call debounced 50ms after textViewDidChange
    func repositionOverlays(in textView: UITextView, paragraphRanges: [NSRange])
}

// Engine/RevealAnimator.swift
struct RevealAnimator {
    /// Duration formula: min(5.0, max(2.0, Double(wordCount) / 200.0))
    func animate(overlayLayers: [(paragraphRange: NSRange, layers: [CAShapeLayer])],
                 wordCount: Int,
                 completion: @escaping () -> Void)
}
```

### No External APIs

This app makes zero network calls. No API contracts needed.

### Dependencies

```bash
# No dependencies to install.
# Create project in Xcode 15+:
# File > New > Project > iOS > App
# Interface: SwiftUI
# Language: Swift
# Minimum Deployment: iOS 16.0
# Do NOT add any Swift Package Manager dependencies.
```

---

## Scope Boundaries

**In scope (v1):**
- Progressive paragraph redaction with wave animation (CAShapeLayer per line)
- Reveal cascade animation with proportional duration
- Training mode (first document only, 4 fully visible paragraphs)
- Optional word count targets per document
- Post-reveal writing stats (WPM, duration, word count, paragraph count)
- Document list with completed and in-progress documents
- Post-reveal standard editing
- Export: plain text (.txt), Markdown (.md with YAML front matter), copy to clipboard, iOS Share Sheet
- Settings: visibility rule adjustments, training mode toggle
- Session persistence: force-quit and restore to exact redaction state
- App Store submission (Phase 4)

**Out of scope (v1):**
- iPad layout (deferred to v1.1)
- Sound design
- iCloud sync
- Writing prompts
- Streak tracking / calendar
- Export as video/animation
- Collaborative writing mode
- Multiple redaction modes (sentence-based, time-based)

**Deferred:**
- iPad layout → v1.1 post-launch
- Writing prompts → v2
- Streak / calendar → v2
- Alternative redaction modes (sentence, time-based) → v2

---

## Security & Credentials

- **No credentials.** Zero network calls. No API keys, tokens, or accounts of any kind.
- **Data location:** `<app-sandbox>/Documents/redact/` exclusively. iOS sandboxing prevents other app access.
- **iCloud:** Disabled. Do not add iCloud entitlement. No `NSUbiquitousKeyValueStore`, no `CloudKit`.
- **Data leaving device:** Only on explicit user action (share sheet, Files export). Nothing automatic.
- **Encryption at rest:** iOS provides file-level encryption when device is locked via `NSFileProtectionComplete` — this is the iOS default. Do not override it. Verify the entitlement is not downgraded.
- **Sensitive data:** No PII beyond user-written text. No logging of document content anywhere.
- **UserDefaults:** Do not use for document storage. Use FileManager JSON files only.

---

## Phase 0: Core Engine (Week 1)

**Objective:** Validate the two riskiest technical components — paragraph boundary detection and redaction overlay rendering — in isolation before any app UI is built. Phase 0 has no app chrome. It produces passing unit tests and a working isolated test harness.

**Tasks:**

1. Create Xcode project `Redact`, iOS 16.0 target, SwiftUI, no CoreData, no Swift packages.
   - **Acceptance:** `xcodebuild build -scheme Redact` completes with 0 errors on a blank SwiftUI `ContentView`.

2. Implement `ParagraphTracker.swift` conforming to `ParagraphTracking`:
   - `paragraphRanges(in:)` using `NSString.enumerateSubstrings(in: textStorage.string.nsRange, options: .byParagraphs)`
   - `activeParagraphIndex(cursorPosition:paragraphs:)` — linear search through NSRange array
   - `didCompleteParagraph(previous:current:)` — returns `current.count > previous.count`
   - **Acceptance:** `ParagraphTrackerTests` all pass: empty text → 0 ranges; single paragraph no newline → 1 range; 5 paragraphs → 5 ranges; trailing newline → handled without crash; paste of 3-paragraph text → 3 ranges detected; delete paragraph → count decrements.

3. Implement `OverlayRenderer.swift` conforming to `OverlayRendering`:
   - Use `UITextView.layoutManager.enumerateLineFragments(forGlyphRange:using:)` to get per-line `CGRect` for a given `NSRange`
   - Create one `CAShapeLayer` per line, `fillColor = UIColor.label.cgColor`, frame set to line rect
   - Wave animation: `CABasicAnimation(keyPath: "opacity")` from 0→1, stagger delay = `lineIndex * 0.08` seconds, duration 0.25s per layer
   - `repositionOverlays`: clear and redraw all overlay layers — call this debounced 50ms after `textViewDidChange`
   - `partial(seed:)` style: derive a `seededRandom` from the seed UUID, select 50% of character glyph rects to leave uncovered
   - **Acceptance:** Isolated test harness (a bare `UIViewController` with one `UITextView` and "Redact Paragraph 1" button): tapping button fills first paragraph with animated black bars, wave left-to-right, within 150ms of tap. Instruments → Core Animation → 60fps on iPhone 13 simulator.

4. Implement `RevealAnimator.swift`:
   - Input: ordered array of `(paragraphRange: NSRange, layers: [CAShapeLayer])`
   - Duration: `min(5.0, max(2.0, Double(wordCount) / 200.0))`
   - Per-layer delay: `layerIndex * (totalDuration / totalLayers)`
   - Animate `opacity` 1→0 via `CABasicAnimation`, completion fires after last layer finishes
   - **Acceptance:** In the same test harness, "Reveal All" button cascades all overlays off: 100-word sim → ~2.5s total; 400-word sim → ~4.5s total. No main thread block (verify: UI remains interactive during reveal).

5. Implement `RedactionState.swift` (Codable round-trip):
   - All three `VisibilityLevel` cases serialize to/from JSON correctly
   - `partiallyVisibleIndices` survives encode → decode as identical `[Int]`
   - **Acceptance:** `RedactionStateTests`: 10-paragraph document with mixed visibility states → `encode()` → `decode()` → all fields identical. Test with empty paragraphs array, single paragraph, and all-redacted state.

6. Implement `DocumentStore.swift` skeleton (no UI yet):
   - Creates directory structure on first run: `/Documents/redact/documents/in-progress/`
   - `save(document:)` → atomic write to `documents/<uuid>.json`
   - `saveInProgress(document:)` → atomic write to `documents/in-progress/<uuid>.json`
   - `loadInProgress()` → returns most recently modified file in `in-progress/`, decoded as `Document`
   - `loadAll()` → returns all completed documents sorted by `revealedAt` descending
   - **Acceptance:** `DocumentStoreTests` using a temp directory: save → load returns identical document; saveInProgress → force simulate relaunch → loadInProgress returns same document; save 3 documents → loadAll returns 3 sorted correctly.

**Phase 0 Verification Checklist:**
- [ ] `xcodebuild test -scheme Redact` → `ParagraphTrackerTests`: all pass
- [ ] `xcodebuild test -scheme Redact` → `RedactionStateTests`: all pass
- [ ] `xcodebuild test -scheme Redact` → `DocumentStoreTests`: all pass
- [ ] Manual (test harness): type 3 paragraphs, each prior paragraph fills with animated black bars, no lag perceptible
- [ ] Manual (Instruments → Core Animation): 60fps maintained during wave redaction animation on iPhone 13 simulator
- [ ] Manual (test harness): "Reveal All" → cascade completes in expected duration range, UI stays responsive

**Risks:**
- `layoutManager.enumerateLineFragments` returns incorrect rects when UITextView has horizontal padding → Mitigation: account for `textContainerInset` and `lineFragmentPadding` in rect calculation. Fallback: use `UITextView.caretRect(for:)` per paragraph start position + estimated line height.
- Per-character partial redaction via CoreText glyph rects is complex → Mitigation: defer per-character partial to Phase 3 polish. In Phase 0, implement partial as 50% opacity on the full line overlay (simpler, still communicates the concept).

---

## Phase 1: Writing Experience (Weeks 2–3)

**Objective:** Full writing flow works end-to-end on a real device: write → redact → reveal → stats → saved. Training mode and word count targets are included. No document list yet — single active document on launch.

**Tasks:**

1. Implement `RedactTextView.swift` (UIViewRepresentable):
   - Wraps `UITextView`: `isScrollEnabled = false`, `.document` content type, Georgia or New York font, 18pt scaled with Dynamic Type (use `UIFontMetrics(.body).scaledFont(for:)`)
   - `Coordinator` conforms to `UITextViewDelegate`, holds `ParagraphTracker` and `OverlayRenderer`
   - `textViewDidChange`: compute paragraph ranges → `repositionOverlays` (debounced 50ms) → if `didCompleteParagraph` → compute new `RedactionState` → call `redact` for newly-redacted paragraphs
   - Passes `Binding<String>` and `Binding<RedactionState>` back to SwiftUI
   - **Acceptance:** Type 4 paragraphs — paragraph 1 fully redacted (black bars), paragraph 2 fully redacted, paragraph 3 partially redacted (~50% visible), paragraph 4 fully visible. No scroll jump on redaction trigger. Input lag < 100ms at 80 WPM (verify: type rapidly, no missed characters).

2. Implement `WriteView.swift`:
   - Full-screen SwiftUI: `RedactTextView` fills safe area, 24pt horizontal padding
   - Live word count: `Text("\(wordCount) words")` top-right (if target: `"\(wordCount) / \(target)"`, turns green at target)
   - "Done" button: hidden until ≥ 50 words; long-press gesture (0.8s minimum duration) triggers reveal
   - Short tap on "Done": no-op (show brief tooltip: "Hold to reveal")
   - On appear: `DocumentStore.loadInProgress()` → restore document + `RedactionState` if exists; else create new `Document`
   - Auto-save in-progress: on every `textViewDidChange`, debounce 2s → `DocumentStore.saveInProgress`
   - **Acceptance:** Done button invisible at 0–49 words, visible at 50. Short tap → tooltip. Long-press 0.8s → triggers reveal flow. Auto-save: type 3 paragraphs, force-quit, relaunch → state restored.

3. Implement Training Mode in `WriteView`:
   - On `WriteView.onAppear`: if `AppSettings.hasCompletedFirstDocument == false` and `trainingModeEnabled == true` → use training visibility rules: `visibilityFullParagraphs = 4`, `visibilityPartialParagraphs = 2`
   - Show dismissible banner at bottom: "Training mode — you can see more of your writing. Dismisses after your first reveal." Auto-dismiss after 5s.
   - `hasCompletedFirstDocument = true` is set in `DocumentStore` when the first document is marked complete
   - **Acceptance:** Fresh install simulation (delete app, reinstall): training banner visible, 4 full paragraphs visible before redaction starts. Complete first reveal → flag persists in `settings.json`. Second document: normal visibility (1 full, 1 partial).

4. Implement `RevealView.swift`:
   - Triggered by long-press Done in WriteView
   - Disables UITextView editing (`isUserInteractionEnabled = false`)
   - Calls `RevealAnimator.animate` → on completion: `isComplete = true`, `stats` computed, `DocumentStore.save(document)`, `DocumentStore.deleteInProgress()`
   - Transitions to `StatsView` overlaid on now-fully-visible text
   - **Acceptance:** Reveal animation completes, no UI freeze. Stats card appears. `documents/<uuid>.json` exists in FileManager. `in-progress/<uuid>.json` is deleted.

5. Implement `StatsView.swift`:
   - Overlay card (bottom sheet style, `RoundedRectangle` with shadow): word count, paragraph count, duration formatted as `"Xm Ys"`, WPM as integer
   - Two buttons: "Start Editing" → dismiss card, transition to `EditView`; "Share" → `UIActivityViewController` with `rawText`
   - **Acceptance:** All four stats accurate. "Start Editing" opens EditView with full document text. "Share" opens share sheet with plain text.

6. Implement `NewDocumentSheet.swift`:
   - Sheet with optional title field (placeholder "Untitled") and optional numeric word count target field (placeholder "No target — write until done")
   - "Start Writing" button always enabled
   - Creates new `Document(id: UUID(), ...)` and passes to `WriteView`
   - **Acceptance:** Set target 300 → WriteView shows "0 / 300", turns green at 300. Leave target blank → WriteView shows word count only.

**Phase 1 Verification Checklist:**
- [ ] Manual: write 10 paragraphs → visibility state correct at each step (full, full, partial, redacted×7)
- [ ] Manual: force-quit at paragraph 5 → relaunch → exact same paragraphs visible, overlays in correct state
- [ ] Manual: long-press Done → reveal cascade → stats card shows correct word count, duration ≥ actual time
- [ ] Manual: `documents/<uuid>.json` exists in Files app after reveal; `in-progress/` directory is empty
- [ ] Manual: fresh install → training banner → 4 full visible paragraphs
- [ ] Manual: first reveal → second document → normal visibility (1 full, 1 partial)
- [ ] Manual: set 200-word target → counter turns green at 200
- [ ] Instruments → Memory: 20-paragraph write session → heap growth < 30MB

---

## Phase 2: Document Management + Settings (Week 4)

**Objective:** Full document lifecycle: list, edit completed documents, adjust settings. Writers can manage their library.

**Tasks:**

1. Implement `DocumentListView.swift`:
   - Navigation root: list of completed documents sorted by `revealedAt` descending
   - Each row: title, word count, relative date ("Yesterday", "Mar 18"), writing duration
   - Top card (if in-progress exists): "Continue Writing →" with title + progress bar (wordCount / target, or just word count if no target)
   - "New" button → presents `NewDocumentSheet`
   - Swipe-to-delete with `UISwipeActionsConfiguration` → confirmation alert → `DocumentStore.delete(document)`
   - Tap row → `EditView` for that document
   - **Acceptance:** Create 3 documents via TestFlight build → all appear sorted correctly. Delete one → confirm alert → removed from list and FileManager. In-progress card shows if session exists, tapping resumes WriteView.

2. Implement `EditView.swift`:
   - Standard `UITextView` (editable, scrollable, same Georgia/New York font, same 24pt margins)
   - Navigation: Back button + "Export" button (action sheet: "Copy Text", "Save as .txt", "Save as .md", "Share")
   - Auto-save: debounced 2s after last keystroke → `DocumentStore.save`
   - Title editable via inline tap on title at top of view
   - **Acceptance:** Edit text → wait 3s → force-quit → relaunch → open same document → edit persisted. All 4 export options work.

3. Implement all export paths in `EditView`:
   - **Copy:** `UIPasteboard.general.string = document.rawText`
   - **Save as .txt:** `UIDocumentPickerViewController` in export mode, filename = `document.title.txt`
   - **Save as .md:** same picker, `.md` extension, content = YAML front matter + rawText:
     ```
     ---
     title: [document.title]
     date: [ISO8601 date]
     wordCount: [Int]
     wpm: [Int]
     ---
     [rawText]
     ```
   - **Share:** `UIActivityViewController(activityItems: [document.rawText])`
   - **Acceptance:** Each path tested. .md file opened in a Markdown viewer shows correct front matter.

4. Implement `SettingsView.swift`:
   - Section "Visibility Rules": `Stepper("Fully visible: \(n)", value: $settings.visibilityFullParagraphs, in: 1...5)` and `Stepper("Partially visible: \(n)", value: $settings.visibilityPartialParagraphs, in: 0...3)`
   - Section "Training Mode": `Toggle("Enable on first document", isOn: $settings.trainingModeEnabled)`
   - Section "About": app version from `Bundle.main.infoDictionary["CFBundleShortVersionString"]`, one-sentence philosophy
   - All changes persist immediately via `AppState.save()` → `settings.json`
   - **Acceptance:** Change full paragraphs to 3 → new document respects setting. Toggle training mode off → reset `hasCompletedFirstDocument` (debug-only reset button in Settings for testing) → no banner on next document.

**Phase 2 Verification Checklist:**
- [ ] Manual: 5 completed documents → correct sort, metadata accurate
- [ ] Manual: swipe delete → alert → document removed from list + FileManager confirmed via Files app
- [ ] Manual: edit completed document → auto-save → force-quit → reopen → edit persisted
- [ ] Manual: all 4 export paths work (copy verified by paste, .txt/.md verified in Files, share sheet opens)
- [ ] Manual: .md export → correct YAML front matter + full document text
- [ ] Manual: change visibility to 3 full → new document → 3 paragraphs visible before redaction starts
- [ ] Manual: in-progress card tapped → resumes WriteView in correct state

---

## Phase 3: Polish + Accessibility (Week 5)

**Objective:** App passes accessibility audit, dark/light mode is flawless, edge cases are handled, partial redaction is visually refined with per-character glyph masking.

**Tasks:**

1. VoiceOver accessibility:
   - Redacted paragraph overlays: set `layer.accessibilityLabel = "Hidden text"`, `isAccessibilityElement = true` on the overlay container view
   - WriteView: "Done" button `accessibilityHint = "Hold to reveal your document"`
   - StatsView: each stat has explicit `accessibilityLabel` ("Word count: 247", "Duration: 14 minutes 32 seconds", etc.)
   - **Acceptance:** VoiceOver enabled → navigate WriteView → redacted paragraphs announce "Hidden text". All interactive elements reachable and correctly labeled without visual reference.

2. Dynamic Type:
   - Replace fixed 18pt font with `UIFontMetrics(.body).scaledFont(for: UIFont(name: "Georgia", size: 18)!)`
   - WriteView layout reflows correctly at all Dynamic Type sizes (test: Accessibility → Larger Text → maximum size)
   - **Acceptance:** System text size at maximum → WriteView readable, no clipped text, overlays reposition correctly on font size change.

3. Dark/light mode:
   - Audit every UIColor usage: zero hardcoded hex values allowed
   - Overlay fill: `UIColor.label.cgColor` (black in light, white in dark)
   - WriteView background: `UIColor.systemBackground`
   - StatsView card: `UIColor.secondarySystemBackground`
   - Word count text: `UIColor.secondaryLabel`
   - **Acceptance:** Toggle dark mode in Control Center during active write session → all colors adapt immediately, no mismatch. Overlay color flips correctly.

4. Edge case handling (all must be tested manually):
   - **1-paragraph document:** No redaction fires. "Done" appears at 50 words. Reveal shows single paragraph.
   - **Return key on empty paragraph:** `didCompleteParagraph` returns false (≥1 non-whitespace char required). No animation triggers.
   - **Paste of multi-paragraph text:** Detect in `textViewDidChange`: if `current.count - previous.count > 1`, all newly-added paragraphs except the last are immediately redacted (no wave animation, instant).
   - **1000-word single paragraph (no returns):** No redaction fires. Show a hint label that auto-appears after 200 words without a return: "Press return to start a new paragraph" (auto-dismisses on next return).
   - **Aggressive backspace (delete across paragraph boundary):** `ParagraphTracker` re-evaluates, overlays for now-merged paragraph are removed.
   - **Acceptance:** Each edge case confirmed with specific behavior above.

5. Partial redaction — per-character glyph masking (upgrade from Phase 0 line-opacity fallback):
   - Use `CTRunGetPositions` and `CTRunGetAdvances` to get per-glyph origin + width for characters in the partial paragraph
   - Seed a deterministic random from `document.id`: `var rng = SeededRandom(seed: document.id.hashValue)`; select 50% of glyphs to mask
   - Place small `CAShapeLayer` rectangles over masked glyph rects (height = line height, width = glyph advance)
   - **Acceptance:** Partial paragraph looks like a redacted document with random word-fragments visible. Force-quit + restore → same glyphs masked (seed consistency verified).

6. Haptic feedback:
   - New paragraph redaction trigger: `UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.5)`
   - Reveal begins: `UINotificationFeedbackGenerator().notificationOccurred(.success)`
   - **Acceptance:** Both haptics confirmed on physical iPhone. Does not fire in simulator (expected).

**Phase 3 Verification Checklist:**
- [ ] VoiceOver: complete WriteView + reveal + stats flow without visual — all controls reachable
- [ ] Dark mode: toggle mid-session → zero hardcoded color artifacts
- [ ] Dynamic Type maximum → WriteView readable, overlays correct
- [ ] Each edge case from task 4 manually verified with expected behavior
- [ ] Partial redaction: per-glyph masking visible, same glyphs after restore
- [ ] Haptics: both fire at correct moments on physical device

---

## Phase 4: App Store Submission (Week 6)

**Objective:** App passes App Review on first submission. All metadata, privacy manifest, and screenshots complete.

**Tasks:**

1. App icon design and export:
   - Concept: solid black rectangle with single thin white horizontal line across the center (the visible line in a redacted page)
   - Generate all required sizes via Xcode asset catalog (1024×1024 source, Xcode generates the rest)
   - **Acceptance:** Asset catalog shows 0 missing icon warnings. Icon renders clearly at 60×60pt home screen size.

2. App Store screenshots — required sizes: 6.7" (1290×2796px) and 6.1" (1179×2556px):
   - Screenshot 1 (WriteView): 3 paragraphs with first 2 fully redacted, 3rd partially — headline overlay: "Write without looking back."
   - Screenshot 2 (Reveal mid-animation): overlays partially dissolved — headline: "Then see everything at once."
   - Screenshot 3 (StatsView): stats card visible — headline: "Discover what you actually wrote."
   - Screenshot 4 (DocumentListView): 3+ completed documents — headline: "Every first draft. Saved."
   - **Acceptance:** All 8 screenshots (4 per size) exported at correct resolution and uploaded to App Store Connect.

3. Privacy manifest (`PrivacyInfo.xcprivacy`):
   - Declare: no data collected, no tracking
   - Required reasons APIs: `NSPrivacyAccessedAPICategoryFileTimestamp` (FileManager date access) → reason `C617.1` (display to user)
   - Do not include `NSUserDefaultsUsageDescription` — use FileManager only
   - **Acceptance:** Xcode → Product → Archive → Validate App → 0 privacy errors. Xcode privacy report shows only FileManager access, correctly declared.

4. App Store Connect metadata:
   ```
   Name:        Redact — Forward-Only Writing
   Subtitle:    Write without looking back
   Category:    Productivity (primary), Reference (secondary)
   Price:       $3.99 (Tier 5)
   Age Rating:  4+
   Keywords:    writing,journal,focus,distraction-free,drafting,freewrite,first draft,prose,creativity
   ```
   Description (3 paragraphs):
   - P1: The problem — re-reading while writing kills momentum. Every writer knows it. Most writing apps make it worse.
   - P2: How Redact works — as you write, completed paragraphs are progressively hidden behind black bars. No scrolling back. No editing earlier paragraphs. Only forward.
   - P3: The reveal — when you're done, hold the button. Watch your full document appear for the first time. You meet your own writing as a reader, not an author.
   - **Acceptance:** All fields filled. Description reads correctly in App Store page preview mockup.

5. TestFlight internal testing:
   - Install on personal iPhone via TestFlight
   - Complete 5 full documents end-to-end: write → reveal → export
   - Verify: training mode fires on fresh install, stats accurate, all export formats work, settings persist
   - Verify: no crashes, no data loss, no animation glitches on physical device
   - **Acceptance:** 5 documents written and revealed without crash or data loss. All flows confirmed on device.

6. Submit for App Review.
   - **Acceptance:** Submission accepted. If rejected: document rejection reason, apply fix, resubmit within 48 hours.

**Phase 4 Verification Checklist:**
- [ ] `xcodebuild archive -scheme Redact` → 0 errors, 0 warnings
- [ ] Validate App → 0 privacy errors, 0 missing entitlements
- [ ] TestFlight build installs and runs on physical iPhone without crash
- [ ] All 8 screenshots uploaded to App Store Connect at correct resolutions
- [ ] All metadata fields complete — 0 placeholder text remaining
- [ ] $3.99 price tier set and confirmed in Pricing and Availability
