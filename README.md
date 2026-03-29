# Redact — Forward-Only Writing

[![Platform](https://img.shields.io/badge/platform-iOS%2016%2B-lightgrey?logo=apple)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/swift-5.9-orange?logo=swift)](https://swift.org)
[![Xcode](https://img.shields.io/badge/xcode-15%2B-blue?logo=xcode)](https://developer.apple.com/xcode/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

Write without looking back.

Redact is an iOS writing app built around a single constraint: as you finish each paragraph, it disappears behind a black bar. You cannot scroll back. You cannot edit what you've written. You can only move forward. When you're ready, hold the Done button and watch your entire document reveal itself — read as a reader, not as the writer who second-guessed every sentence.

---

## Screenshot

> _Screenshot placeholder — add a simulator capture of the WriteView with redacted paragraphs here._

---

## Features

- **Progressive redaction** — completed paragraphs hide behind black bars as you write the next one
- **Partial visibility zone** — configurable buffer of partially-visible paragraphs between fully-visible and fully-redacted text
- **Hold-to-reveal** — long-pressing Done triggers a cascade reveal animation proportional to document length
- **Writing stats** — word count, paragraph count, session duration, WPM, and longest uninterrupted streak shown after reveal
- **Optional word count targets** — set a goal before writing; live progress shown during the session
- **Training mode** — first-time users see more visible paragraphs to learn the mechanic before the constraint tightens
- **Session persistence** — force-quit and return exactly where you left off
- **Export** — plain text, Markdown with YAML front matter, or the system share sheet
- **No account. No cloud. No subscription.** All data stays on-device in the app sandbox.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Swift 5.9 (strict concurrency) |
| UI | SwiftUI |
| Persistence | JSON files in app sandbox via `DocumentStore` |
| Project generation | XcodeGen (`project.yml`) |
| Testing | XCTest (unit tests for engine, models, store) |

Zero third-party dependencies.

---

## Prerequisites

- Xcode 15 or later
- iOS 16+ device or simulator
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

---

## Getting Started

```bash
# Clone
git clone https://github.com/<your-username>/Redact.git
cd Redact

# Generate the Xcode project
xcodegen generate

# Open in Xcode
open Redact.xcodeproj
```

Select the `Redact` scheme, choose a simulator or connected device, and press **Run** (⌘R).

---

## Project Structure

```
Redact/
├── App/
│   ├── RedactApp.swift          # App entry point
│   └── AppState.swift           # Settings persistence (@MainActor ObservableObject)
├── Models/
│   ├── Document.swift           # Core data model (id, rawText, redactionState, stats)
│   ├── RedactionState.swift     # Per-paragraph visibility levels
│   └── WritingStats.swift       # Word count, WPM, duration, streak
├── Engine/
│   ├── VisibilityEngine.swift   # Computes paragraph visibility from active index
│   ├── ParagraphTracker.swift   # Detects paragraph boundaries in live text
│   ├── RevealAnimator.swift     # Cascade reveal sequencing
│   └── OverlayRenderer.swift   # Renders redaction bars over text
├── Store/
│   └── DocumentStore.swift      # Atomic JSON read/write, in-progress restore
├── Views/
│   ├── WriteView.swift          # Main writing screen
│   ├── DocumentListView.swift   # Document history list
│   ├── StatsView.swift          # Post-reveal stats card
│   ├── EditView.swift           # Full editing after reveal
│   ├── NewDocumentSheet.swift   # Title + word count target setup
│   ├── RedactTextView.swift     # UITextView wrapper with overlay
│   └── SettingsView.swift       # Visibility buffer configuration
├── Extensions/
│   ├── String+WordCount.swift
│   └── Date+RelativeFormat.swift
RedactTests/                      # Unit tests for engine + models + store
RedactTestHarness/                # Standalone harness app for engine testing
project.yml                       # XcodeGen project spec
```

---

## Running Tests

```bash
xcodegen generate
xcodebuild test \
  -scheme Redact \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

---

## License

MIT — see [LICENSE](LICENSE).
