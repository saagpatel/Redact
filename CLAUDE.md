# Redact

## Overview
Premium iPhone writing app that progressively hides completed paragraphs with animated black-bar redactions. Writers work forward-only — no editing previous paragraphs while writing — then long-press Done to reveal in a cascade animation. $3.99 one-time, local-only, no cloud, no accounts.

## Stack
- Language: Swift 6 (strict concurrency)
- UI: SwiftUI (app shell, navigation, document list, stats, settings)
- Text rendering: UIKit / UITextView wrapped in UIViewRepresentable
- Animation: Core Animation (CAShapeLayer) — per-line full overlays and merged glyph-run partial overlays
- Text layout: TextKit (NSLayoutManager) — line and glyph rect calculation for overlay positioning
- Persistence: FileManager (JSON files in app sandbox)
- Dependencies: None — zero third-party packages
- Minimum deployment: iOS 16.0
- Xcode: 16+ (Swift 6 language mode)

## Build / Test / Run
Build and run on simulator or device via Xcode. Tap **+**, then **Start Writing** to start writing.

Use the [README verification instructions](README.md#verification) for generated-project,
unsigned simulator tests, focused test selection and Release build commands.

## Conventions
- Swift strict concurrency; `@MainActor` on all store/UI-touching code
- File naming: PascalCase for types and files, camelCase for properties and methods
- Custom foreground/background colors come from `Redact/Views/Theme.swift` (dynamic light+dark "paper and ink" tokens at both UIKit and SwiftUI level); `StatsView.swift` also uses a black shadow. Define new custom colors in Theme.swift so dark/light adaptation stays automatic
- DocumentStore and AppState writes are atomic: write to `.tmp`, then `FileManager.replaceItemAt(_:withItemAt:)` for existing files or `moveItem(at:to:)` for new files; exports use atomic String writes
- Unit tests cover ParagraphTracker, RedactionState, DocumentStore, VisibilityEngine, OverlayRenderer and RevealAnimator

## Constraints
- Zero external packages — use no Swift Package Manager dependencies
- Redaction rendering: CAShapeLayer via TextKit rects — per line for full masks, per merged adjacent glyph run for partial masks
- Storage: FileManager JSON files in the app sandbox only — not UserDefaults
- No iCloud entitlement; no network entitlements — this app makes zero network calls
- Phase gate: implement only features in the current phase of IMPLEMENTATION-ROADMAP.md; validate ParagraphTracker and OverlayRenderer with tests and the isolated test harness before any app UI

## Key Decisions
| Decision | Choice | Rationale |
|----------|--------|-----------|
| Text rendering | UITextView in UIViewRepresentable | Required for TextKit layout access and overlay rect positioning |
| Redaction rendering | CAShapeLayer per line for full masks, per merged glyph run for partial masks (TextKit metrics) | Full masks scale with lines; partial masks can scale with characters |
| Paragraph trigger | When the paragraph count increases (including paste), with ≥1 non-whitespace char in the completed paragraph | Prevents empty return presses from triggering animation |
| Session restore | Serialize RedactionState (paragraph index + VisibilityLevel) as JSON | Restores visibility levels on relaunch; partial character masks are regenerated from document.id, paragraph index and length |
| Partial redaction seeding | Seed from document.id for consistent character selection across restores | Same characters hidden every time for a given document |
| Reveal duration | `min(5.0, max(2.0, wordCount / 200.0))` seconds | Proportional to document length, always feels meaningful |
| Training mode | Enabled by default, fires on first document only, 4 full visible paragraphs (vs 1 normally) | Reduces bounce rate from anxious new users |
| Pricing | $3.99 one-time, no IAP, no subscription | Signals quality tool, not a gimmick |
| Design language | "Paper and ink" theme in Theme.swift: warm paper surfaces, serif masthead + titles, mono-caps eyebrows, bar-shaped buttons, one stamp-red accent for live/destructive signals | Carries the redaction-bar identity through the chrome instead of default iOS styling; matches the writing surface's New York serif |
| iCloud | Disabled — no iCloud entitlement | Keeps app simple; avoids requiring iCloud account |

See IMPLEMENTATION-ROADMAP.md for phases, acceptance criteria, and submission checklist.

<!-- portfolio-context:start -->
# Portfolio Context

## What This Project Is

Redact is a premium iPhone writing app that progressively hides completed paragraphs with animated black-bar redactions as you write. Writers work forward-only — no editing previous paragraphs while writing — then long-press Done to reveal the full document in a cascade animation. The constraint prevents editing earlier paragraphs during the writing session. $3.99 one-time, local-only, no cloud, no accounts.

## Current State

**Phase 4: App Store Submission** (code complete; Phases 0–3 shipped)
See IMPLEMENTATION-ROADMAP.md for full phase details, acceptance criteria, and submission checklist.

## Distribution State (2026-08-23)

Everything App-Store-facing that can be done without operator-only input is DONE.
The app record is `com.redact.app`, App ID 6762118923, version 1.0.0 (iOS) in
`PREPARE_FOR_SUBMISSION`. Completed via the App Store Connect API this date:

- Builds 2 and 3 (1.0.0) uploaded and processed (`VALID`); **build 3 is attached**
  to the version. Build numbers 1–3 are consumed — next upload must be 4
  (`CURRENT_PROJECT_VERSION` in project.yml, kept in lockstep with
  `DK_BUILD_NUMBER` in distkit.ios.config.sh).
- Name "Redact — Forward-Only Writing", subtitle, description, keywords,
  promotional text, support + privacy-policy URLs set from APPSTORE-METADATA.md.
- 4 screenshots (1320×2868) uploaded, asset state COMPLETE.
- Age rating questionnaire answered → 4+. Categories Productivity/Reference.
- Price $3.99 USD (pre-existing schedule). Availability: all 175 territories.
- Export compliance declared (`usesNonExemptEncryption: false`).
- Content rights: does not use third-party content.
- A review submission shell exists (id `9efe1195-3ed4-4f92-aaad-40948c90f020`,
  `READY_FOR_REVIEW`, empty — the version cannot be added yet, see below).

**Update 2026-09-05:** both gates cleared. Operator published the App Privacy labels in the ASC UI and supplied the review contact phone; review detail `e5cb2d69` posted via the API, version 1.0.0 (build 3) added to submission `9efe1195` and submitted at 15:17 UTC. State: `WAITING_FOR_REVIEW`. The section below is history.

**Blocked on operator-only input (the ONLY remaining gates):**
1. **App Review contact phone number** — `appStoreReviewDetails` requires
   `contactPhone`; agents must not invent one. Once provided, POST the review
   detail (name/email/notes already drafted in APPSTORE-METADATA.md).
2. **App Privacy labels ("Data Not Collected")** — no public ASC API exposes
   privacy-label publishing (verified against Apple's OpenAPI spec 2026-08-23);
   confirm in App Store Connect UI → App Privacy. The bundled
   PrivacyInfo.xcprivacy already declares no collection/no tracking.

After both: add the version to the review submission and submit. Archive/upload
path: `distribution-kit` iOS lane with `distkit.ios.config.sh` (manual signing —
automatic archive signing fails on this team: no registered devices). Receipts
in `dist-receipts/` (gitignored) and mirrored in the Foundation Zero campaign
workspace.

## Stack

- Language: Swift 6 (strict concurrency)
- UI: SwiftUI (app shell, navigation, document list, stats, settings)
- Text rendering: UIKit / UITextView wrapped in UIViewRepresentable
- Animation: Core Animation (CAShapeLayer) — per-line full overlays and merged glyph-run partial overlays
- Text layout: TextKit (NSLayoutManager) — line and glyph rect calculation for overlay positioning
- Persistence: FileManager (JSON files in app sandbox)
- Dependencies: None — zero third-party packages
- Minimum deployment: iOS 16.0
- Xcode: 16+ (Swift 6 language mode)

## How To Run

Build and run on simulator or device. Tap **+**, then **Start Writing** — completed paragraphs become partially visible or fully redacted as they leave the configured visibility zones (training mode keeps 4 paragraphs fully visible on the first document).

## Known Risks

- Do not add third-party Swift Package Manager dependencies — zero external packages
- Use TextKit rects for CAShapeLayer overlays — per line for full masks, per merged adjacent glyph run for partial masks
- Do not add hardcoded UIColor values outside Theme.swift — use its dynamic paper and ink tokens for automatic dark/light adaptation
- Do not skip Phase 0 engine validation — ParagraphTracker and OverlayRenderer must pass tests and the isolated test harness before any app UI is built
- Do not add features not in the current phase of IMPLEMENTATION-ROADMAP.md
- Do not enable iCloud or any network entitlements — this app makes zero network calls
- Do not store document text in UserDefaults — use FileManager JSON files in the app sandbox only

## Next Recommended Move

Use this context plus the README and supporting docs to resume the next active task, then promote the repo beyond minimum-viable by capturing a dedicated handoff, roadmap, or discovery artifact.

<!-- portfolio-context:end -->

<!-- secondbrain-breadcrumb -->
## SecondBrain knowledge vault

Prior lessons, decisions, and context for this project live in SecondBrain at `wiki/maps/projects/redact.md`. The whole vault is searchable via the `engraph` MCP — query it for this project + its stack before non-trivial work.
