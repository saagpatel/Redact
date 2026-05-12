# Redact — Portfolio Disposition

**Status:** Release Frozen (iOS App Store) — SwiftUI "forward-only
writing" iOS app on `origin/main` with full App Store submission
scaffolding (`APPSTORE-METADATA.md`, `PRIVACY.md` on canonical
main, DEVELOPMENT_TEAM, Privacy Manifest, scheme generation,
copyright in metadata + ExportOptions, App Store archive prep).
Classified as **Productivity** (primary) + **Reference** (secondary)
at **$3.99 paid up-front**. Seventh iOS App Store cluster member —
and the **second paid iOS cluster member** (after Liminal). Notable
during audit: privacy policy artifact reflects a **merge conflict
resolution** between local and remote variants (`30b65d6 chore:
resolve merge — keep remote privacy policy and metadata URLs`),
indicating multi-environment edits converged through normal merge
flow.

> Disposition uses strict `origin/main` verification.

---

## Verification posture

This repo has **only `origin`** (`saagpatel/Redact`) — no
`legacy-origin` remote. Clean migration state.

Specifically verified on `origin/main`:

- Tip: `d32f10a` chore: app store archive prep (signing, icons,
  screenshots)
- Substantive App Store prep commits:
  - `d32f10a` app store archive prep (signing, icons, screenshots)
  - `30b65d6` **chore: resolve merge — keep remote privacy policy
    and metadata URLs** (interesting: privacy policy was edited in
    two places, remote won)
  - `1d5bf98` privacy policy + metadata URLs
  - `d2e21e3` Update APPSTORE-METADATA.md
  - `c0f5dcd` Add privacy policy to PRIVACY.md
  - `171fb18` copyright in metadata + ExportOptions
  - `388ee64` App Store prep — DEVELOPMENT_TEAM, Privacy Manifest,
    scheme generation
- **Release scaffolding on canonical main:** `APPSTORE-METADATA.md`,
  `PRIVACY.md`, DEVELOPMENT_TEAM, Privacy Manifest,
  ExportOptions.plist, archive prep
- App Store identity:
  - Name: **Redact — Forward-Only Writing**
  - Subtitle: **Write without looking back**
  - Bundle ID: `com.redact.app`, SKU: `REDACT-001`
  - Categories: **Productivity** + **Reference**
  - Age Rating: 4+, **Price: $3.99 (Tier 5)**, All territories
- Default branch: `main`

---

## Current state in one paragraph

Redact is a SwiftUI iOS app that enforces "forward-only writing" —
prose drafts where the user cannot navigate back to edit; words
written are committed. The use case is freewriting / first drafts /
distraction-free composition. Categories: Productivity + Reference.
Per memory: Phases 0-2 complete, Phase 3 next. The canonical commit
cadence shows full App Store prep cadence (DEVELOPMENT_TEAM +
Privacy Manifest + APPSTORE-METADATA + PRIVACY.md + archive prep),
matching the established iOS App Store cluster signature. The
`30b65d6 chore: resolve merge` commit is notable: it records the
operator merging two privacy-policy variants (local working copy
+ remote canonical), preferring the remote version. This is a
healthy merge-driven workflow, not a trap.

For full detail see `README.md` + `APPSTORE-METADATA.md` +
`PRIVACY.md` on `origin/main`.

---

## Why "Release Frozen (iOS App Store, paid)" — seventh cluster member

The cluster signature continues to hold. Redact is the second paid
iOS cluster member alongside Liminal, both at premium pricing
tiers ($3.99 / $4.99). This solidifies "paid" as a real operator
concern axis worth tracking.

Per-row pricing visibility now:

| Repo | Pricing |
|---|---|
| Calibrate | Free (StoreKit IAP for upgrades) |
| Chromafield | Free |
| Ghost Routes | Free |
| Nocturne | Free |
| Tide Engine | Free (?) |
| Liminal | **$4.99 paid** |
| **Redact** | **$3.99 paid** |

The portfolio's iOS App Store cluster splits roughly: 5 Free + 2
Paid in current accounting. Pricing decision is per-app and not a
cluster sub-shape division.

---

## Cluster taxonomy update

| Cluster | Count | Notes |
|---|---|---|
| Signing (Apple desktop) | 24 | … |
| **iOS App Store** | **7** | 5 local-first + 1 cloud-backed + 1 local-first-paid sub-class growing (now 2) |
| Static-host (web) | 3 | … |
| Self-hosted service | 1 | … |
| PyPI distribution | 2 | … |
| Local-first pipeline | 1 | … |
| Operator-tool / dogfood | 1 | … |
| Chrome MV3 extension | 2 | … |
| Game (Godot) | 1 | … |

---

## Unblock trigger (operator)

When ready to ship:

1. **App Store Connect record + Tier 5 pricing** ($3.99).
2. **Privacy nutrition labels** — local-first, no analytics
   expected (verify). The `PRIVACY.md` on canonical main is the
   single source; reconcile labels to it.
3. **Productivity-category review** — Apple's productivity
   reviewers may scrutinize "forward-only writing" UX claims;
   prepare a short demo video showing the no-edit behavior to
   accompany the submission notes if rejection risk is non-zero.
4. **Screenshots have been refreshed locally** (stash shows
   modified `screenshot-1.png`, `screenshot-2.png`, two
   `screenshot-check` variants) — operator should decide whether
   to commit refreshed screenshots and re-run fastlane deliver
   before submission.
5. **Submit for Review.**

Estimated operator time: ~3-4 hours.

---

## Portfolio operating system instructions

| Aspect | Posture |
|---|---|
| Portfolio status | `Release Frozen (iOS App Store, local-first, paid)` |
| Distribution channel | **App Store Connect** — Productivity + Reference, $3.99 |
| Review cadence | Suspend overdue counting |
| Resurface conditions | (a) Screenshot refresh decision + submission, (b) review feedback, (c) Phase 3 scope packet (per memory: Phase 3 was the next item), or (d) pricing change |
| Co-batch with | iOS App Store cluster — **now 7 repos** |
| Special concern | **Screenshots modified locally but uncommitted.** Resolve before submission so the App Store listing reflects current UI. |
| Special concern | **Privacy policy merge history.** The `30b65d6 chore: resolve merge` commit indicates two privacy-policy variants existed; verify the kept version is the operator-intended one before announce. |
| Special concern | **Productivity-category UX review.** "Forward-only writing" is an unusual interaction model; a demo video in submission notes reduces rejection risk. |

---

## Reactivation procedure

1. Verify `git branch -vv` shows `main` tracking `origin/main`.
2. Review stash `r14-redact-stash` — contains CLAUDE.md mods +
   modified screenshot PNGs (1, 2, check, check2). **Decide
   whether to commit refreshed screenshots before App Store
   submission.**
3. Open Xcode → confirm DEVELOPMENT_TEAM valid.
4. **Audit `PRIVACY.md` matches operator-intended privacy
   posture** (merge history shows two variants existed).
5. Run XCTest target.

---

## Last known reference

| Field | Value |
|---|---|
| `origin/main` tip | `d32f10a` chore: app store archive prep (signing, icons, screenshots) |
| Default branch | `main` |
| Build system | iOS / Swift / SwiftUI / XCTest |
| Bundle ID | `com.redact.app` |
| App Store category | Productivity + Reference |
| Price | **$3.99 (Tier 5)** — second paid iOS cluster member |
| Phases shipped | 0-2 per memory; Phase 3 was next item |
| Migration state | No `legacy-origin` remote |
| Distinguishing feature | **Seventh iOS App Store cluster member; second paid app.** Privacy policy merge resolution (`30b65d6`) recorded as healthy multi-environment edit convergence, not a trap. |
