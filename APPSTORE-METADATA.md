# Redact — App Store Connect Metadata

## Identity

| Field | Value |
|-------|-------|
| **Name** | Redact — Forward-Only Writing |
| **Subtitle** | Write without looking back |
| **Bundle ID** | com.redact.app |
| **SKU** | REDACT-001 |
| **Primary Category** | Productivity |
| **Secondary Category** | Reference |
| **Age Rating** | 4+ |
| **Price** | $3.99 (Tier 5) |
| **Availability** | All territories |

---

## Keywords

```
writing,journal,focus,distraction-free,drafting,freewrite,first draft,prose,creativity
```

*(100 character limit — these are 86 characters)*

---

## Description

Re-reading while you write kills momentum. Every writer knows it. Most writing apps make it worse — infinite scroll, visible history, the pull of the cursor backwards.

Redact is different. As you write, completed paragraphs are progressively hidden behind black bars. You can't revisit or edit the hidden text. You can only move forward. The constraint is the point.

When you're done, hold the Done button. Watch your full document cascade back into view — this time as a reader, not as the writer second-guessing every sentence. That moment of rediscovery is what first drafts are supposed to feel like.

**What you get:**
• Progressive paragraph redaction as you write
• Reveal animation proportional to your document's length
• Writing stats: word count, WPM, duration, paragraph count
• Optional word count targets with live progress
• Training mode for first-time users
• Full document editing and export after reveal
• Export as plain text, Markdown (with YAML front matter), or share
• Session persistence — force-quit and come back exactly where you left off
• No account, no app-operated cloud sync, and no subscription. Your writing stays in Redact unless you export it.

$3.99, once. That's it.

---

## Promotional Text

*(Optional — appears above description, can be updated without new app version)*

```
The writing app that hides your work until you're done. Train yourself to write forward.
```

---

## Support URL

*https://github.com/saagpatel/Redact/issues*

---

## Privacy Policy URL

*https://github.com/saagpatel/Redact/blob/main/PRIVACY.md*

---

## Screenshots

### Required Sizes

- **iPhone 6.9"** — 1320 × 2868 px

One size, four screenshots. The 6.7" and 6.1" sets this file previously listed are no
longer the required device classes. The iPad 13" set (2064 × 2752) does **not** apply:
Redact is iPhone-only (`TARGETED_DEVICE_FAMILY: "1"` in `project.yml`), so no iPad
screenshots are required or accepted.

### Screenshot Plan (4 screenshots)

Captured and committed under `screenshots/iphone-69/`. Each entry records what is
actually on screen in the committed PNG, not an intended state — the overlay copy
below is written against those pixels.

Overlay copy is for conversion, not search. App Store indexes the app name,
subtitle, and keywords field; it does not index screenshot text. Write these to
stop the scroll and explain the mechanic, not to repeat keywords.

**1 — `01-writing.png` · WriteView, mid-session**
On screen: 4 paragraphs. The first two are solid black bars, the third is
partially masked, the fourth is fully legible and being typed. Header reads
"135 words" with the Done button live. Bottom half is empty.
> **You can't reread it.**
> That's the entire point.

**2 — `02-reveal.png` · WriteView, mid-reveal**
On screen: the same document with the bars dissolving. The first two paragraphs
have returned in full, the third is halfway out from under grey and black runs.
Done has left the header. Bottom half is empty.
> **Hold Done. It all comes back.**
> Your draft returns in one cascade.

**3 — `03-stats.png` · StatsView**
On screen: the fully revealed document with the Writing Complete card docked at
the bottom — 135 Words, 4 Paragraphs, 6m 7s, 22 WPM — plus Start Editing and
Share. The card occupies the lower third.
> **135 words. Zero second-guessing.**
> Words, pace, time. Every session.

**4 — `04-library.png` · DocumentListView**
On screen: the Redact title, an In Progress card ("Continue Writing", 135 words),
and three Completed documents with word counts, dates, and durations. Bottom 40%
is empty.
> **Every first draft, kept.**
> On your phone. No account, no cloud.

### Overlay Composition

- Screenshots 1, 2, and 4 have empty space below the content — anchor the overlay
  to the bottom. Screenshot 3's stats card fills the lower third, so its overlay
  goes above the text block, under the status bar.
- Keep overlays clear of the top 120 px (status bar) and the bottom 90 px (home
  indicator) at 1320 × 2868.
- Headline in the app's serif at a weight that reads at thumbnail size; subhead
  one step down in grey. The screenshots are near-monochrome, so the overlay
  needs contrast from size and weight, not colour.
- Composite into copies. Never overwrite the raw PNGs in `screenshots/iphone-69/`
  — those are the reproducible output of `scripts/capture-screenshots.sh`.

### How to Take Screenshots

Run the `screenshot` skill — it owns the capture pipeline, boots the right simulator,
writes to `screenshots/iphone-69/`, and verifies each PNG is exactly 1320 × 2868 with
`sips`. Doing it by hand risks shipping the wrong pixel dimensions, which App Store
Connect rejects on upload.

Manually, if needed:
1. Boot the latest iPhone Pro Max simulator (iPhone 17 Pro Max on this machine) — that
   is the 6.9" class.
2. Build and run the Redact target.
3. Navigate to each screen state in the plan above.
4. `xcrun simctl io booted screenshot ~/Desktop/screenshot.png`
5. Verify dimensions: `sips -g pixelWidth -g pixelHeight <file>` → 1320 × 2868.
6. Add marketing text overlays before uploading.

---

## App Review Notes

```
This is a writing productivity app. No login, no network access, no special permissions required.
All data is stored locally in the app sandbox.

To test the core flow:
1. Tap + to create a new document
2. Write several paragraphs — notice each completed paragraph redacts as you start the next
3. Long-press "Done" (appears after 50 words) to trigger the reveal animation
4. Review stats, then tap "Start Editing" to see the completed document

Training mode is active on first launch (shows more visible paragraphs to help new users understand the mechanic).
```

---

## Checklist Before Submission

- [ ] Bundle ID `com.redact.app` registered in Apple Developer portal
- [ ] App icon 1024×1024 appears correctly in Xcode asset catalog (no warnings)
- [ ] Archive succeeds: `Product → Archive` with no errors
- [ ] Validate App passes with 0 errors (check privacy manifest, entitlements)
- [ ] All 4 screenshots uploaded at iPhone 6.9" (1320 × 2868); no iPad set required
- [ ] Description, keywords, subtitle filled in App Store Connect
- [ ] Price set to $3.99 (Tier 5) in Pricing and Availability
- [ ] Age rating questionnaire complete (4+)
- [ ] Support URL and Privacy Policy URL provided
- [ ] TestFlight internal test complete (5 documents written, revealed, exported)
- [ ] Submit for Review

## Copyright
© 2026 saagpatel
