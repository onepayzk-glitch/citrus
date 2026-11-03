#!/bin/bash
# Build signed release artifacts (ZIP + DMG) and, when credentials are available,
# notarize and staple them with Apple's notary service.
#
# Usage:
#   MARKETING_VERSION=1.0.0 BUILD_NUMBER=1 \
#   DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
#   NOTARY_PROFILE="open-tangerine-notary" \
#   ./scripts/package-release.sh
#
# Without DEVELOPER_ID_APPLICATION the script produces ad-hoc signed artifacts and
# prints a warning; without NOTARY_PROFILE it skips notarization.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Citrus"
MARKETING_VERSION="${MARKETING_VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
APP="dist/$APP_NAME.app"
RELEASE_DIR="dist/release"
IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
BUNDLE_ID="${BUNDLE_ID:-com.onepayzk.citrus}"
GITHUB_REPO="${GITHUB_REPO:-onepayzk-glitch/citrus}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

mkdir -p "$RELEASE_DIR"
ZIP="$RELEASE_DIR/Citrus-$MARKETING_VERSION.zip"
DMG="$RELEASE_DIR/Citrus-$MARKETING_VERSION.dmg"
SHA="$RELEASE_DIR/SHA256SUMS.txt"
rm -f "$ZIP" "$DMG" "$SHA"

echo "== 1/7 Build (version $MARKETING_VERSION, build $BUILD_NUMBER)"
MARKETING_VERSION="$MARKETING_VERSION" BUILD_NUMBER="$BUILD_NUMBER" \
  BUNDLE_ID="$BUNDLE_ID" GITHUB_REPO="$GITHUB_REPO" \
  DEVELOPER_ID_APPLICATION="$IDENTITY" ./scripts/build-app.sh

echo "== 2/7 Verify app signature"
xattr -cr "$APP" 2>/dev/null || true
codesign --verify --deep --strict --verbose=2 "$APP"
if [[ -z "$IDENTITY" ]]; then
  echo "WARN: ad-hoc signature only."
  echo "WARN: external users will see Gatekeeper warnings until the app is signed with a"
  echo "WARN: Developer ID Application certificate and notarized (see parity/release-1.0.md)."
fi

make_zip() {
  rm -f "$ZIP"
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
}

make_dmg() {
  rm -f "$DMG"
  local staging
  staging="$(mktemp -d)"
  ditto "$APP" "$staging/$APP_NAME.app"
  ln -s /Applications "$staging/Applications"
  xattr -cr "$staging" 2>/dev/null || true
  hdiutil create -quiet -volname "$APP_NAME" -srcfolder "$staging" -ov -format UDZO "$DMG"
  rm -rf "$staging"
}

echo "== 3/7 Package ZIP"
make_zip
echo "== 4/7 Package DMG"
make_dmg

if [[ -n "$NOTARY_PROFILE" ]]; then
  if [[ -z "$IDENTITY" ]]; then
    echo "ERROR: NOTARY_PROFILE is set but DEVELOPER_ID_APPLICATION is empty." >&2
    exit 1
  fi
  echo "== 5/7 Notarize app and staple"
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  echo "== 6/7 Rebuild artifacts from the stapled app and notarize the DMG"
  make_zip
  make_dmg
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"

  echo "== 7/7 Gatekeeper assessment"
  spctl --assess --type execute --verbose=2 "$APP"
  echo "Notarization complete. Artifacts are ready for distribution."
else
  echo "== 5-7/7 Notarization skipped (NOTARY_PROFILE not set)"
  echo "Next: create a Developer ID Application certificate, store notarytool credentials,"
  echo "then rerun with DEVELOPER_ID_APPLICATION and NOTARY_PROFILE. See parity/release-1.0.md."
fi

echo "== Checksums"
( cd "$RELEASE_DIR" && shasum -a 256 "$(basename "$ZIP")" "$(basename "$DMG")" | tee "$(basename "$SHA")" )

echo "== Artifacts"
ls -lh "$RELEASE_DIR"
