#!/usr/bin/env python3
"""Seed a simulator's Redact container with the document state the App Store
screenshots need.

The four required shots (see APPSTORE-METADATA.md) depend on app state that would
otherwise take several minutes of typing to reach by hand, and would differ slightly
every time. Writing the store's own JSON files directly makes the capture
reproducible: same documents, same word counts, same stats, every run.

This writes only into a simulator's data container. It never touches a real device
and never runs as part of the app or its tests.

Usage:
    python3 scripts/seed-screenshot-state.py <container-path>

where <container-path> comes from:
    xcrun simctl get_app_container <udid> com.redact.app data
"""

from __future__ import annotations

import json
import pathlib
import shutil
import sys
import uuid
from datetime import datetime, timedelta, timezone

# Matches DocumentStore's encoder: .iso8601
ISO = "%Y-%m-%dT%H:%M:%SZ"

# Fixed base time so repeated runs produce identical files. The list sorts by
# revealedAt descending, so these land newest-first in the order written below.
BASE = datetime(2026, 3, 14, 9, 41, 0, tzinfo=timezone.utc)


def stamp(offset_hours: float) -> str:
    return (BASE - timedelta(hours=offset_hours)).strftime(ISO)


def paragraph_states(count: int, active: int, full_visible: int, partial_visible: int):
    """Mirrors VisibilityEngine.computeVisibility.

    Kept deliberately in step with the engine rather than importing it — this is a
    fixture generator, and a screenshot that disagrees with the real engine is a
    signal worth seeing rather than one to paper over.
    """
    visible_start = max(0, active - full_visible + 1)
    partial_start = max(0, visible_start - partial_visible)

    states = []
    for i in range(count):
        if visible_start <= i <= active:
            visibility = "visible"
        elif partial_start <= i < visible_start:
            visibility = "partial"
        else:
            visibility = "redacted"
        # partiallyVisibleIndices is left empty on purpose: session restore
        # regenerates the mask from the document seed, so seeding it would be
        # writing a value the app immediately recomputes.
        states.append({"index": i, "visibility": visibility, "partiallyVisibleIndices": []})
    return states


def redaction_state(count: int, active: int, full_visible=1, partial_visible=1):
    return {
        "schemaVersion": 2,
        "paragraphs": paragraph_states(count, active, full_visible, partial_visible),
        "activeParagraphIndex": active,
    }


def document(doc_id, title, paragraphs, revealed_offset, duration_seconds, longest_streak):
    text = "\n".join(paragraphs)
    return {
        "id": doc_id,
        "title": title,
        "rawText": text,
        "redactionState": redaction_state(len(paragraphs), len(paragraphs) - 1),
        "isComplete": True,
        "createdAt": stamp(revealed_offset + 0.4),
        "lastModifiedAt": stamp(revealed_offset),
        "revealedAt": stamp(revealed_offset),
        "stats": stats_for(paragraphs, duration_seconds, longest_streak),
    }


def word_count(text):
    """Matches String.wordCount: split on any whitespace run, drop empties."""
    return len(text.split())


def stats_for(paragraphs, duration_seconds, longest_streak):
    """Derives stats from the actual text rather than taking them on faith.

    The document list computes its word count from rawText, so a hand-written
    stats.wordCount silently disagrees with what the screen shows — the first pass
    here claimed 247 words next to a list rendering 134. Deriving both from one
    source keeps every number in the screenshot set consistent.
    """
    words = word_count("\n".join(paragraphs))
    return {
        "wordCount": words,
        "paragraphCount": len(paragraphs),
        "durationSeconds": duration_seconds,
        "wordsPerMinute": round(words / (duration_seconds / 60.0), 1),
        "longestStreakSeconds": longest_streak,
    }


# Deterministic ids so the mask is identical between runs — the mask is seeded from
# the document id, so a random UUID would reshuffle which characters show.
IDS = {
    "in_progress": "8B1F2C7A-4D5E-4A21-9C33-000000000001",
    "morning": "8B1F2C7A-4D5E-4A21-9C33-000000000002",
    "argument": "8B1F2C7A-4D5E-4A21-9C33-000000000003",
    "letter": "8B1F2C7A-4D5E-4A21-9C33-000000000004",
}

IN_PROGRESS_PARAGRAPHS = [
    "The trouble with a first draft is that you can read it. You write a sentence "
    "and your eye slides back to the one before it, and then you are editing "
    "instead of writing, and the thing you were about to say is gone.",
    "I have tried everything. Turning off the monitor. Writing longhand and typing "
    "it up after. A friend suggested covering the screen with a towel, which works "
    "until you need to see the line you are actually on.",
    "What I wanted was something that let me see the sentence I am writing and "
    "almost nothing else. Not a blank page, which is its own kind of terror, but a "
    "page that closes behind me as I go.",
    "So this is the fourth paragraph, and by now the first two are gone entirely",
]

COMPLETED = [
    document(
        IDS["morning"],
        "The trouble with a first",
        IN_PROGRESS_PARAGRAPHS[:3]
        + ["And then it was finished, which is the only way a draft ever ends."],
        revealed_offset=2.5,
        duration_seconds=372,
        longest_streak=148,
    ),
    document(
        IDS["argument"],
        "Notes toward an argument",
        [
            "Every argument I have ever lost was lost in the rewriting. The first "
            "version is angry and clear. The fourth is careful and says nothing.",
            "There is a version of caution that is really just fear wearing better "
            "clothes, and I can never tell which one I am doing until much later.",
            "So: write it angry. Fix it tomorrow. Tomorrow is a better editor than "
            "tonight is, and tonight is a better writer than tomorrow will be.",
        ],
        revealed_offset=27.0,
        duration_seconds=214,
        longest_streak=96,
    ),
    document(
        IDS["letter"],
        "A letter I will not send",
        [
            "It has been four years and I still draft this letter in my head on the "
            "train, which is a waste of four years and a great many train rides.",
            "The useful part is not the sending. The useful part is finding out what "
            "I actually think, which turns out to be different from what I rehearse.",
        ],
        revealed_offset=76.0,
        duration_seconds=176,
        longest_streak=71,
    ),
]

IN_PROGRESS = {
    "id": IDS["in_progress"],
    "title": "The trouble with a first",
    "rawText": "\n".join(IN_PROGRESS_PARAGRAPHS),
    # 4 paragraphs, cursor in the last: 0 and 1 redacted, 2 partial, 3 visible.
    "redactionState": redaction_state(4, 3),
    "isComplete": False,
    # The gap between these two is the session duration the stats card reports, since
    # WriteView resumes the tracker from them. ~6 minutes for ~135 words reads as a
    # believable 22 wpm; a wider gap makes the screenshot advertise a 4 wpm session.
    "createdAt": stamp(0.1517),
    "lastModifiedAt": stamp(0.05),
    "stats": None,
}

# Training mode shows four fully-visible paragraphs and a banner, which would hide
# the redaction the screenshots exist to show. Marking the first document complete
# turns it off.
SETTINGS = {
    "visibilityFullParagraphs": 1,
    "visibilityPartialParagraphs": 1,
    "hasCompletedFirstDocument": True,
    "trainingModeEnabled": True,
}


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2

    container = pathlib.Path(sys.argv[1])
    if not container.is_dir():
        print(f"not a directory: {container}", file=sys.stderr)
        return 1

    base = container / "Documents" / "redact"
    documents = base / "documents"
    in_progress = documents / "in-progress"

    if base.exists():
        shutil.rmtree(base)
    in_progress.mkdir(parents=True)

    (base / "settings.json").write_text(json.dumps(SETTINGS, indent=2))

    for doc in COMPLETED:
        (documents / f"{doc['id']}.json").write_text(json.dumps(doc, indent=2))

    (in_progress / f"{IN_PROGRESS['id']}.json").write_text(json.dumps(IN_PROGRESS, indent=2))

    print(f"seeded {base}")
    print(f"  settings.json          training mode off")
    print(f"  documents/             {len(COMPLETED)} completed")
    for doc in COMPLETED:
        s = doc["stats"]
        print(f"    {doc['title']!r} — {s['wordCount']} words, {s['wordsPerMinute']} wpm")
    print(f"  documents/in-progress/ 1 session, 4 paragraphs (2 redacted, 1 partial, 1 visible)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
