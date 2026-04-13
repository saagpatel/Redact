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

*(100 character limit — these are 89 characters)*

---

## Description

Re-reading while you write kills momentum. Every writer knows it. Most writing apps make it worse — infinite scroll, visible history, the pull of the cursor backwards.

Redact is different. As you write, completed paragraphs are progressively hidden behind black bars. You can't scroll back. You can't edit what you've written. You can only move forward. The constraint is the point.

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
• No account. No cloud. No subscription. Your writing stays on your device.

$3.99, once. That's it.

---

## Promotional Text

*(Optional — appears above description, can be updated without new app version)*

```
The writing app that hides your work until you're done. Train yourself to write forward.
```

---

## Support URL

*(Enter your support URL — e.g. a GitHub repo or personal site)*

---

## Privacy Policy URL

*(Required — can be a simple page stating no data is collected)*

---

## Screenshots

### Required Sizes
- **6.7" Display** — 1290 × 2796 px (iPhone 16 Pro Max / iPhone 15 Pro Max)
- **6.1" Display** — 1179 × 2556 px (iPhone 16 / iPhone 15)

### Screenshot Plan (4 screenshots per size)

| # | Screen | Simulator State | Headline Overlay |
|---|--------|-----------------|------------------|
| 1 | WriteView | 3 paragraphs: first 2 fully redacted (black bars), 3rd partially visible, cursor active in 4th | "Write without looking back." |
| 2 | WriteView mid-reveal | Overlay layers partially faded — text beginning to appear behind dissolving black bars | "Then see everything at once." |
| 3 | StatsView | Stats card visible: e.g. 247 words, 3 paragraphs, 14m 32s, 82 WPM | "Discover what you actually wrote." |
| 4 | DocumentListView | 3 completed documents listed with titles + metadata | "Every first draft. Saved." |

### How to Take Screenshots
1. Open Xcode → Simulator → select iPhone 16 Pro Max
2. Build and run the Redact target
3. Navigate to each screen state
4. **Xcode menu: Product → Simulator → Take Screenshot** (saves to Desktop)
   OR: `xcrun simctl io booted screenshot ~/Desktop/screenshot.png`
5. Repeat for iPhone 16 (6.1") by switching simulator
6. Add marketing text overlays in Sketch, Figma, or Canva before uploading

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
- [ ] All 8 screenshots uploaded (4 per required size)
- [ ] Description, keywords, subtitle filled in App Store Connect
- [ ] Price set to $3.99 (Tier 5) in Pricing and Availability
- [ ] Age rating questionnaire complete (4+)
- [ ] Support URL and Privacy Policy URL provided
- [ ] TestFlight internal test complete (5 documents written, revealed, exported)
- [ ] Submit for Review

## Copyright
© 2026 saagpatel
