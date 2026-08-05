#!/usr/bin/env bash
#
# capture-screenshots.sh — produce the four App Store screenshots for Redact.
#
# Redact is iPhone-only, so only the iPhone 6.9" set (1320x2868) is required; there
# is no iPad set. See APPSTORE-METADATA.md for the shot plan.
#
# The library screenshot is the launch screen and is taken directly with simctl. The
# other three need the app driven — a tap into the writing view, a long-press, and a
# mid-reveal frame that lasts about two seconds — so they come from the
# RedactScreenshots UI-test scheme and are extracted from its result bundle.
#
# Document state is seeded rather than typed, so every run produces identical word
# counts, stats, and redaction masks. The mask is seeded from the document id, which
# the seeder pins.
#
#   bash scripts/capture-screenshots.sh [simulator-name]
#
# Default simulator is the latest iPhone Pro Max, which is the 6.9" class. Output
# lands in screenshots/iphone-69/ and every file is dimension-checked before the
# script reports success.

set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE_NAME="${1:-iPhone 17 Pro Max}"
BUNDLE_ID="com.redact.app"
SCHEME="RedactScreenshots"
OUT_DIR="screenshots/iphone-69"
WORK_DIR="$(mktemp -d)"
RESULT_BUNDLE="$WORK_DIR/screenshots.xcresult"

# Kept on failure: the error paths below point the reader at logs inside WORK_DIR,
# and deleting it unconditionally would delete the evidence along with the scratch.
cleanup() {
  if [ "$?" -eq 0 ]; then
    rm -rf "$WORK_DIR"
  else
    echo "!! work directory kept for diagnosis: $WORK_DIR" >&2
  fi
}
trap cleanup EXIT

EXPECTED_W=1320
EXPECTED_H=2868

echo "==> [1/6] locating simulator: $DEVICE_NAME"
UDID=$(xcrun simctl list devices available --json | python3 -c "
import sys, json
name = sys.argv[1]
for runtime, devices in json.load(sys.stdin)['devices'].items():
    for d in devices:
        if d['name'] == name:
            print(d['udid'])
            raise SystemExit
raise SystemExit('no available simulator named ' + name)
" "$DEVICE_NAME")
echo "    $UDID"

echo "==> [2/6] booting"
xcrun simctl bootstatus "$UDID" -b > /dev/null 2>&1 || xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b > /dev/null

echo "==> [3/6] building and installing"
xcodegen generate > /dev/null
xcodebuild \
  -project Redact.xcodeproj \
  -scheme Redact \
  -configuration Debug \
  -destination "id=$UDID" \
  -derivedDataPath "$WORK_DIR/dd" \
  build > "$WORK_DIR/build.log" 2>&1 \
  || { echo "!! build failed — see $WORK_DIR/build.log" >&2; tail -30 "$WORK_DIR/build.log" >&2; exit 1; }

APP=$(find "$WORK_DIR/dd/Build/Products" -name "Redact.app" -not -path "*/PlugIns/*" | head -1)
[ -n "$APP" ] || { echo "!! build succeeded but produced no Redact.app" >&2; exit 1; }
xcrun simctl install "$UDID" "$APP"

echo "==> [4/6] seeding document state"
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
CONTAINER=$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)
python3 scripts/seed-screenshot-state.py "$CONTAINER"

mkdir -p "$OUT_DIR"

echo "==> [5/6] capturing"
# The library is the launch screen: no navigation needed, so simctl takes it directly.
xcrun simctl launch "$UDID" "$BUNDLE_ID" > /dev/null
sleep 5
xcrun simctl io "$UDID" screenshot "$OUT_DIR/04-library.png" > /dev/null 2>&1
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true

# The UI tests relaunch the app themselves; re-seed so they meet the same state the
# library shot did, rather than whatever the previous launch left behind.
python3 scripts/seed-screenshot-state.py "$CONTAINER" > /dev/null

xcodebuild \
  -project Redact.xcodeproj \
  -scheme "$SCHEME" \
  -destination "id=$UDID" \
  -derivedDataPath "$WORK_DIR/dd" \
  -resultBundlePath "$RESULT_BUNDLE" \
  test > "$WORK_DIR/test.log" 2>&1 \
  || { echo "!! UI capture failed — see $WORK_DIR/test.log" >&2; grep -E "error:|XCTAssert" "$WORK_DIR/test.log" | head -20 >&2; exit 1; }

xcrun xcresulttool export attachments \
  --path "$RESULT_BUNDLE" \
  --output-path "$WORK_DIR/attachments" > /dev/null

# Attachments are exported under generated names; the manifest maps them back to the
# names the tests set.
python3 - "$WORK_DIR/attachments" "$OUT_DIR" <<'PY'
import json, pathlib, shutil, sys

src = pathlib.Path(sys.argv[1])
dst = pathlib.Path(sys.argv[2])
manifest = json.loads((src / "manifest.json").read_text())

wanted = {"01-writing": "01-writing.png", "02-reveal": "02-reveal.png", "03-stats": "03-stats.png"}
found = {}

for test in manifest:
    for att in test.get("attachments", []):
        name = (att.get("suggestedHumanReadableName") or att.get("exportedFileName") or "")
        for key, out in wanted.items():
            if key in name:
                found[key] = src / att["exportedFileName"]

missing = sorted(set(wanted) - set(found))
if missing:
    raise SystemExit(f"missing attachments: {missing}")

for key, path in found.items():
    shutil.copyfile(path, dst / wanted[key])
    print(f"    {wanted[key]}")
PY

echo "==> [6/6] verifying dimensions"
FAIL=0
for f in "$OUT_DIR"/*.png; do
  W=$(sips -g pixelWidth "$f" | awk '/pixelWidth/{print $2}')
  H=$(sips -g pixelHeight "$f" | awk '/pixelHeight/{print $2}')
  if [ "$W" = "$EXPECTED_W" ] && [ "$H" = "$EXPECTED_H" ]; then
    echo "    OK    $(basename "$f")  ${W}x${H}"
  else
    echo "    WRONG $(basename "$f")  ${W}x${H}  (expected ${EXPECTED_W}x${EXPECTED_H})" >&2
    FAIL=1
  fi
done

[ "$FAIL" -eq 0 ] || { echo "!! dimension check failed — App Store Connect rejects these at upload" >&2; exit 1; }

COUNT=$(find "$OUT_DIR" -name '*.png' | wc -l | tr -d ' ')
echo
echo "==> $COUNT screenshots in $OUT_DIR, all ${EXPECTED_W}x${EXPECTED_H}"
echo "    Add the headline overlays from APPSTORE-METADATA.md before uploading."
