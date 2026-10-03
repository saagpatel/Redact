# Redact — Forward-Only Writing

[![Swift](https://img.shields.io/badge/Swift-f05138?style=flat-square&logo=swift)](#) [![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](#)

> Write without looking back.

Redact is an iOS writing app built around a single constraint: completed paragraphs become partially visible or disappear behind black bars as they leave the configured visibility zones. You cannot edit previous paragraphs while writing. Only the last paragraph remains editable. When you're done, hold the Done button and watch your entire document reveal itself — read as a reader, not as the writer who second-guessed every sentence.

## Features

- **Progressive redaction** — completed paragraphs become partially visible or hide behind black bars as they leave the configured visibility zones
- **Configurable visibility zone** — set how many partially-visible paragraphs appear as a buffer
- **Hold-to-reveal** — at 50+ words, long-pressing Done triggers a cascade reveal animation proportional to document length
- **Writing stats** — word count, paragraph count, session duration, and WPM shown after reveal
- **Word count targets** — set a goal before writing with live progress during the session
- **Export** — plain text, Markdown with YAML front matter, or the system share sheet
- **Zero dependencies** — pure Swift with no third-party packages

## Quick Start

### Prerequisites
- macOS with full Xcode 16+ selected (Swift 6 language mode), iOS 16.0+
- An installed iOS Simulator runtime and an available device matching your destination
- XcodeGen (`brew install xcodegen`)

### Installation
```bash
git clone https://github.com/saagpatel/Redact.git
cd Redact
xcodegen generate
open Redact.xcodeproj
```

### Usage
Build and run on simulator or device. Tap **+**, then **Start Writing** — completed paragraphs become partially visible or fully redacted as they leave the configured visibility zones (training mode keeps 4 paragraphs fully visible on the first document).

## Verification

Run from the repository root. The Makefile regenerates the gitignored Xcode
project before every build/test; do not test a stale generated project. Full
Xcode is required, not only Command Line Tools. CI uses the same unsigned lanes:

```sh
make test
make release
```

`make test` defaults to the `iPhone 17 Pro` simulator without pinning its OS
version. If that device is unavailable, choose a device/runtime installed in your
Xcode and override the destination, for example:

```sh
make test SIMULATOR='platform=iOS Simulator,name=iPhone 16 Pro'
```

For a focused engine test, generate first and select the test class:

```sh
make generate
xcodebuild test -project Redact.xcodeproj -scheme Redact \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:RedactTests/OverlayRendererTests CODE_SIGNING_ALLOWED=NO
```

Adjust that destination as above. `make build` compiles for the simulator;
`make release` compiles unsigned Release for generic iOS. The project has no
configured lint/format command. For writing, redaction, reveal, restore or app-chrome
changes, also exercise the affected flow with synthetic documents in a simulator
(including light/dark mode and relevant text direction). Unit tests and compilation
do not establish visual usability. Browser checks do not apply to this native app.

App Store screenshot capture, signing, archive/export and `scripts/ship-appstore.sh`
are separate release operations; routine verification does not upload or submit.

## Tech Stack

| Layer | Technology |
|-------|------------|
| Language | Swift 6 (strict concurrency) |
| UI | SwiftUI |
| Persistence | JSON files via DocumentStore |
| Testing | XCTest (unit tests for engine, models, store) |
| Build | XcodeGen (project.yml) |
| Dependencies | Zero |

## License

MIT
