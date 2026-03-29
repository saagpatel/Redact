# Redact — Forward-Only Writing

[![Swift](https://img.shields.io/badge/Swift-f05138?style=flat-square&logo=swift)](#) [![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](#)

> Write without looking back.

Redact is an iOS writing app built around a single constraint: as you finish each paragraph, it disappears behind a black bar. You cannot scroll back. You cannot edit what you've written. You can only move forward. When you're done, hold the Done button and watch your entire document reveal itself — read as a reader, not as the writer who second-guessed every sentence.

## Features

- **Progressive redaction** — completed paragraphs hide behind black bars as you write the next
- **Configurable visibility zone** — set how many partially-visible paragraphs appear as a buffer
- **Hold-to-reveal** — long-pressing Done triggers a cascade reveal animation proportional to document length
- **Writing stats** — word count, paragraph count, session WPM, and longest uninterrupted streak shown after reveal
- **Word count targets** — set a goal before writing with live progress during the session
- **Export** — plain text, Markdown with YAML front matter, or the system share sheet
- **Zero dependencies** — pure Swift with no third-party packages

## Quick Start

### Prerequisites
- Xcode 15+, iOS 16.0+
- XcodeGen (`brew install xcodegen`)

### Installation
```bash
git clone https://github.com/saagpatel/Redact.git
cd Redact
xcodegen generate
open Redact.xcodeproj
```

### Usage
Build and run on simulator or device. Tap **New Session** to start writing — the first paragraph stays visible until you press Return, then it redacts.

## Tech Stack

| Layer | Technology |
|-------|------------|
| Language | Swift 5.9 (strict concurrency) |
| UI | SwiftUI |
| Persistence | JSON files via DocumentStore |
| Testing | XCTest (unit tests for engine, models, store) |
| Build | XcodeGen (project.yml) |
| Dependencies | Zero |

## License

MIT
