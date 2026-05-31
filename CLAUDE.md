# Redact

## Overview
Premium iPhone writing app that progressively hides completed paragraphs with animated black-bar redactions. Writers work forward-only — no scrolling back, no editing previous paragraphs — then long-press Done to reveal in a cascade animation. $3.99 one-time, local-only, no cloud, no accounts.

## Stack
- Language: Swift 5.9+
- UI: SwiftUI (app shell, navigation, document list, stats, settings)
- Text rendering: UIKit / UITextView wrapped in UIViewRepresentable
- Animation: Core Animation (CAShapeLayer) — GPU-accelerated per-line overlays
- Text layout: CoreText — line rect calculation for overlay positioning
- Persistence: FileManager (JSON files in app sandbox)
- Dependencies: None — zero third-party packages
- Minimum deployment: iOS 16.0
- Xcode: 15+

## Build / Test / Run
Build and run on simulator or device via Xcode. Tap **New Session** to start writing.

Run unit tests via Xcode or:
```
xcodebuild test -scheme Redact -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Conventions
- Swift strict concurrency; `@MainActor` on all store/UI-touching code
- File naming: PascalCase for types and files, camelCase for properties and methods
- Semantic system colors only (`UIColor.label`, `UIColor.systemBackground`) — no hardcoded UIColor values
- All FileManager writes are atomic: write to `.tmp`, then `FileManager.replaceItem(at:)`
- Unit tests cover all engine logic (ParagraphTracker, RedactionState, DocumentStore) before Phase 1 UI

## Constraints
- Zero external packages — use no Swift Package Manager dependencies
- Redaction rendering: per-line CAShapeLayer via CoreText line rects (not per-character CALayer)
- Storage: FileManager JSON files in the app sandbox only — not UserDefaults
- No iCloud entitlement; no network entitlements — this app makes zero network calls
- Phase gate: implement only features in the current phase of IMPLEMENTATION-ROADMAP.md; validate ParagraphTracker and OverlayRenderer with tests and the isolated test harness before any app UI

## Key Decisions
| Decision | Choice | Rationale |
|----------|--------|-----------|
| Text rendering | UITextView in UIViewRepresentable | Required for CoreText layout access and overlay rect positioning |
| Redaction rendering | CAShapeLayer per text line (CoreText metrics) | Avoids per-character layer explosion; O(lines) not O(characters) |
| Paragraph trigger | On `\n` insertion with ≥1 non-whitespace char in current paragraph | Prevents empty return presses from triggering animation |
| Session restore | Serialize RedactionState (paragraph index + VisibilityLevel) as JSON | Restores exact visibility state on relaunch without recomputing |
| Partial redaction seeding | Seed from document.id for consistent character selection across restores | Same characters hidden every time for a given document |
| Reveal duration | `min(5.0, max(2.0, wordCount / 200.0))` seconds | Proportional to document length, always feels meaningful |
| Training mode | Opt-in, fires on first document only, 4 full visible paragraphs (vs 1 default) | Reduces bounce rate from anxious new users |
| Pricing | $3.99 one-time, no IAP, no subscription | Signals quality tool, not a gimmick |
| iCloud | Disabled — no iCloud entitlement | Keeps app simple; avoids requiring iCloud account |

See IMPLEMENTATION-ROADMAP.md for phases, acceptance criteria, and submission checklist.

<!-- portfolio-context:start -->
# Portfolio Context

## What This Project Is

Redact is a premium iPhone writing app that progressively hides completed paragraphs with animated black-bar redactions as you write. Writers work forward-only — no scrolling back, no editing previous paragraphs — then long-press Done to reveal the full document in a cascade animation. The constraint eliminates re-reading and premature editing, forcing a true first-draft mindset. $3.99 one-time, local-only, no cloud, no accounts.

## Current State

**Phase 4: App Store Submission** (code complete; Phases 0–3 shipped)
See IMPLEMENTATION-ROADMAP.md for full phase details, acceptance criteria, and submission checklist.

## Stack

- Language: Swift 5.9+
- UI: SwiftUI (app shell, navigation, document list, stats, settings)
- Text rendering: UIKit / UITextView wrapped in UIViewRepresentable
- Animation: Core Animation (CAShapeLayer) — GPU-accelerated per-line overlays
- Text layout: CoreText — line rect calculation for overlay positioning
- Persistence: FileManager (JSON files in app sandbox)
- Dependencies: None — zero third-party packages
- Minimum deployment: iOS 16.0
- Xcode: 15+

## How To Run

Build and run on simulator or device. Tap **New Session** to start writing — the first paragraph stays visible until you press Return, then it redacts.

## Known Risks

- Do not add third-party Swift Package Manager dependencies — zero external packages
- Do not implement per-character CALayer overlays — use per-line CAShapeLayer via CoreText line rects
- Do not use hardcoded UIColor values — use semantic system colors for automatic dark/light adaptation
- Do not skip Phase 0 engine validation — ParagraphTracker and OverlayRenderer must pass tests and the isolated test harness before any app UI is built
- Do not add features not in the current phase of IMPLEMENTATION-ROADMAP.md
- Do not enable iCloud or any network entitlements — this app makes zero network calls
- Do not store document text in UserDefaults — use FileManager JSON files in the app sandbox only

## Next Recommended Move

Use this context plus the README and supporting docs to resume the next active task, then promote the repo beyond minimum-viable by capturing a dedicated handoff, roadmap, or discovery artifact.

<!-- portfolio-context:end -->
