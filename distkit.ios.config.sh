# distribution-kit iOS lane contract for Redact.
# Consumed by <distribution-kit>/lanes/ios.sh; every Redact-specific value
# lives here, none in the lane. No secrets: the ASC issuer id stays in the
# Keychain and is fetched by the lane at runtime.
DK_PRODUCT_NAME="Redact"
DK_BUNDLE_ID="com.redact.app"
DK_VERSION="1.0.0"
DK_BUILD_NUMBER="3"
DK_PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DK_SCHEME="Redact"
DK_XCODE_PROJECT="Redact.xcodeproj"
DK_GENERATE_CMD="xcodegen generate"
DK_EXPORT_OPTIONS="$DK_PROJECT_DIR/ExportOptions.plist"
DK_IOS_SIGN_STYLE="manual"
DK_SIGNING_IDENTITY="Apple Distribution"
DK_PROFILE_NAME="Redact App Store"
DK_REQUIRE_PRIVACY_MANIFEST=1
DK_ASC_KEY_ID="6NPVH55ZWG"
DK_ASC_ISSUER_SERVICE="asc-radar"
DK_ASC_ISSUER_ACCOUNT="issuer_id"
