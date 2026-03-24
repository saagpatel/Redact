# Redact

## Overview
Redact is a premium iPhone writing app that progressively hides completed paragraphs with animated black-bar redactions as you write. Writers work forward-only — no scrolling back, no editing previous paragraphs — then long-press Done to reveal the full document in a cascade animation. The constraint eliminates re-reading and premature editing, forcing a true first-draft mindset. $3.99 one-time, local-only, no cloud, no accounts.

## Tech Stack
- Language: Swift 5.9+
- UI: SwiftUI (app shell, navigation, document list, stats, settings)
- Text rendering: UIKit / UITextView wrapped in UIViewRepresentable
- Animation: Core Animation (CAShapeLayer) — GPU-accelerated per-line overlays
- Text layout: CoreText — line rect calculation for overlay positioning
- Persistence: FileManager (JSON files in app sandbox)
- Dependencies: None — zero third-party packages
- Minimum deployment: iOS 16.0
- Xcode: 15+

## Development Conventions
- Swift strict concurrency where applicable; `@MainActor` on all store/UI-touching code
- File naming: PascalCase for types and files, camelCase for properties and methods
- No hardcoded colors — use `UIColor.label`, `UIColor.systemBackground`, semantic system colors only
- All FileManager writes are atomic: write to `.tmp`, then `FileManager.replaceItem(at:)`
- Unit tests for all engine logic (ParagraphTracker, RedactionState, DocumentStore) before Phase 1 UI

## Current Phase
**Phase 0: Core Engine**
See IMPLEMENTATION-ROADMAP.md for full phase details, acceptance criteria, and verification checklist.

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

## Do NOT
- Do not add third-party Swift Package Manager dependencies — zero external packages
- Do not implement per-character CALayer overlays — use per-line CAShapeLayer via CoreText line rects
- Do not use hardcoded UIColor values — use semantic system colors for automatic dark/light adaptation
- Do not skip Phase 0 engine validation — ParagraphTracker and OverlayRenderer must pass tests and the isolated test harness before any app UI is built
- Do not add features not in the current phase of IMPLEMENTATION-ROADMAP.md
- Do not enable iCloud or any network entitlements — this app makes zero network calls
- Do not store document text in UserDefaults — use FileManager JSON files in the app sandbox only
