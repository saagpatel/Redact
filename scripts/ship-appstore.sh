#!/usr/bin/env bash
#
# ship-appstore.sh — build a distribution-signed Redact archive and export the .ipa.
#
# This gets you to an uploadable binary in one command. It deliberately stops short
# of uploading: ExportOptions.plist sets destination=export, and pushing a build to
# App Store Connect is an outward-facing step that stays a conscious decision. The
# exact upload command is printed at the end.
#
# ── ONE-TIME PREREQUISITES ───────────────────────────────────────────────────
#   0. Full Xcode installed and selected:
#        sudo xcode-select -s /Applications/Xcode.app
#   1. Bundle id `com.redact.app` registered in the Apple Developer portal.
#   2. Signed in to Xcode with the team in DEVELOPMENT_TEAM (see project.yml).
#      project.yml uses CODE_SIGN_STYLE: Automatic, so Xcode creates and renews the
#      distribution profile itself — there is no .mobileprovision to install by hand.
#   3. App record created in App Store Connect for `com.redact.app`, with the
#      metadata from APPSTORE-METADATA.md.
#   4. For uploading, an App Store Connect API key from
#      App Store Connect → Users and Access → Integrations → App Store Connect API.
#      Export these (the .p8 lives wherever you saved it):
#        export ASC_KEY_ID=XXXXXXXXXX
#        export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#        export ASC_KEY_PATH="$HOME/.appstoreconnect/private/AuthKey_XXXXXXXXXX.p8"
#      They are optional here: when set they are passed through so automatic signing
#      can resolve distribution certificates without an interactive Xcode session.
#
# ── RUN ──────────────────────────────────────────────────────────────────────
#        bash scripts/ship-appstore.sh
#
# Screenshots upload separately in App Store Connect; the .ipa does not carry them.
# Redact is iPhone-only (TARGETED_DEVICE_FAMILY=1), so only the iPhone 6.9"
# (1320x2868) set is required.
#
# For a RESUBMISSION, bump the build number first so App Store Connect accepts a
# new binary:
#        agvtool next-version -all   # or edit CURRENT_PROJECT_VERSION in project.yml

set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="Redact"
ARCHIVE="build/${SCHEME}.xcarchive"
EXPORT_DIR="build/export"

# Optional: forwarded to -exportArchive only when all three are present.
AUTH_ARGS=()
if [[ -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" && -n "${ASC_KEY_PATH:-}" ]]; then
  AUTH_ARGS=(
    -authenticationKeyID "$ASC_KEY_ID"
    -authenticationKeyIssuerID "$ASC_ISSUER_ID"
    -authenticationKeyPath "$ASC_KEY_PATH"
  )
  echo "==> using App Store Connect API key $ASC_KEY_ID for signing"
else
  echo "==> no ASC API key in the environment; relying on the Xcode signing session"
fi

echo "==> [1/3] regenerating Xcode project from project.yml"
xcodegen generate

echo "==> [2/3] archiving $SCHEME (Release, generic iOS device)"
xcodebuild \
  -scheme "$SCHEME" \
  -destination 'generic/platform=iOS' \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  clean archive

echo "==> [3/3] exporting signed .ipa to $EXPORT_DIR"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath "$EXPORT_DIR" \
  "${AUTH_ARGS[@]}"

IPA="$(find "$EXPORT_DIR" -name '*.ipa' -maxdepth 1 -print -quit)"
if [[ -z "$IPA" ]]; then
  echo "!! export finished but no .ipa was produced in $EXPORT_DIR" >&2
  exit 1
fi

echo
echo "==> done. Signed build: $IPA"
echo
echo "    To upload it, run:"
echo
echo "      xcrun altool --upload-app -f \"$IPA\" -t ios \\"
echo "        --apiKey \"\$ASC_KEY_ID\" --apiIssuer \"\$ASC_ISSUER_ID\""
echo
echo "    Then watch App Store Connect → TestFlight for processing, attach"
echo "    screenshots, and submit for review."
