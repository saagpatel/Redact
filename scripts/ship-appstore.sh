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
#   2. Signing. project.yml uses CODE_SIGN_STYLE: Automatic and ExportOptions.plist
#      uses signingStyle: automatic, so there is no .mobileprovision to install by
#      hand. Xcode creates and renews the distribution profile, but only when it can
#      authenticate — satisfy ONE of:
#        a. sign in to Xcode with the team in DEVELOPMENT_TEAM (see project.yml), or
#        b. export the App Store Connect API key variables below, which this script
#           passes to both the archive and the export step.
#      Both steps run with -allowProvisioningUpdates, which is what actually permits
#      profile creation and renewal. Signing happens during archive, not export, so
#      the credentials have to reach that step.
#   3. App record created in App Store Connect for `com.redact.app`, with the
#      metadata from APPSTORE-METADATA.md.
#   4. App Store Connect API key from
#      App Store Connect → Users and Access → Integrations → App Store Connect API.
#      altool looks the .p8 up by name, so the directory name matters:
#        export ASC_KEY_ID=XXXXXXXXXX
#        export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#        export ASC_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8"
#      Optional here: without them the build falls back to the Xcode signing session.
#
# ── RUN ──────────────────────────────────────────────────────────────────────
#        bash scripts/ship-appstore.sh
#
# Screenshots upload separately in App Store Connect; the .ipa does not carry them.
# APPSTORE-METADATA.md lists the sizes and counts — confirm them against Apple's
# current requirements before submitting, since which device sizes are mandatory
# changes over time. The app is iPhone-only, so no iPad set applies.
#
# For a RESUBMISSION, bump the build number before running by editing
# CURRENT_PROJECT_VERSION in project.yml. Do not use `agvtool`: it writes into
# Redact.xcodeproj, which is gitignored and which step [1/3] regenerates from
# project.yml, so the bump would be silently discarded and App Store Connect would
# reject the binary as a duplicate build number.

set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT="Redact.xcodeproj"
SCHEME="Redact"
ARCHIVE="build/${SCHEME}.xcarchive"
EXPORT_DIR="build/export"

# Passed to both xcodebuild invocations when all three are present. The `[@]+` form
# is required, not stylistic: macOS ships bash 3.2, where expanding an empty array
# under `set -u` is an unbound-variable error that would abort the default path.
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

echo "==> [2/3] archiving $SCHEME (Release, generic iOS device, distribution-signed)"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination 'generic/platform=iOS' \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  "${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"}" \
  clean archive

echo "==> [3/3] exporting signed .ipa to $EXPORT_DIR"
# Cleared first so a stale .ipa from an earlier run can never be reported as this
# run's output: `clean archive` above cleans build products, not this directory.
rm -rf "$EXPORT_DIR"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates \
  "${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"}"

# Errors suppressed so the explicit guard below reports the failure, rather than a
# bare `find: no such directory` when the export produced nothing at all.
IPA="$(find "$EXPORT_DIR" -maxdepth 1 -name '*.ipa' -print -quit 2>/dev/null || true)"
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
