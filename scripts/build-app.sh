#!/bin/bash
set -euo pipefail
# 0.1.10: reliable drag hover, per-app exclusions and two-second notch dismissal.
cd "$(dirname "$0")/.."
app="$PWD/dist/Open Tangerine.app"
module_cache="$PWD/.build/module-cache"
mkdir -p "$app/Contents/MacOS" "$module_cache" "$PWD/.build"

# macOS 15 (Sequoia) is the minimum supported release. Intel (x86_64) builds are
# first-class; set BUILD_UNIVERSAL=1 to produce one app for Intel and Apple silicon.
MIN_MACOS="${MACOSX_DEPLOYMENT_TARGET:-15.0}"
MARKETING_VERSION="${MARKETING_VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
if [[ "${BUILD_UNIVERSAL:-0}" == "1" || "${ARCHS:-}" == "universal" ]]; then
  archs=(x86_64 arm64)
else
  read -r -a archs <<< "${ARCHS:-$(uname -m)}"
fi

binaries=()
for arch in "${archs[@]}"; do
  binary="$PWD/.build/OpenTangerine-$arch"
  find NativeApp/Sources -name '*.swift' -print0 | xargs -0 xcrun swiftc \
    -swift-version 5 -O -parse-as-library \
    -target "$arch-apple-macosx$MIN_MACOS" \
    -module-cache-path "$module_cache" \
    -o "$binary"
  binaries+=("$binary")
done

if (( ${#binaries[@]} > 1 )); then
  xcrun lipo -create "${binaries[@]}" -output "$app/Contents/MacOS/OpenTangerine"
else
  cp "${binaries[0]}" "$app/Contents/MacOS/OpenTangerine"
fi
chmod +x "$app/Contents/MacOS/OpenTangerine"

# Preserve the legacy bundle identifier so existing settings and login registration survive updates.
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>OpenTangerine</string>
<key>CFBundleIdentifier</key><string>com.syntaxerror.opentangerine</string>
<key>CFBundleName</key><string>Open Tangerine</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>${MARKETING_VERSION}</string>
<key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
<key>LSMinimumSystemVersion</key><string>15.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
mkdir -p "$app/Contents/Resources"
xcrun swiftc -module-cache-path "$module_cache" NativeApp/Sources/UI/BrandArtwork.swift scripts/make-icon.swift -o .build/make-icon
.build/make-icon "$PWD/.build/AppIcon.iconset"
python3 scripts/package-icon.py .build/AppIcon.iconset "$app/Contents/Resources/AppIcon.icns"
cp LICENSE "$app/Contents/Resources/GPL-3.0.txt"
cp NativeApp/LICENSE "$app/Contents/Resources/Satsuma-MIT.txt"
cp THIRD_PARTY_NOTICES.md "$app/Contents/Resources/THIRD_PARTY_NOTICES.md"
# File-provider sync paths add Finder metadata that makes codesign refuse the bundle.
xattr -cr "$app" 2>/dev/null || true
# Developer trials use ad-hoc signing. Developer ID + notarization is required for trusted public distribution.
if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$app"
else
  # File-provider synced folders re-attach FinderInfo right after it is cleared, so sign
  # and verify in one retry loop instead of trusting a single codesign call.
  signed=0
  for attempt in 1 2 3 4 5 6 7 8; do
    xattr -cr "$app" 2>/dev/null || true
    if codesign --force --sign - "$app" 2>/dev/null && codesign --verify --deep --strict "$app" 2>/dev/null; then
      signed=1
      break
    fi
    sleep 1
  done
  if [[ "$signed" != "1" ]]; then
    echo "codesign failed after retries; check extended attributes on $app" >&2
    exit 1
  fi
fi
# Verify in a retry loop: the synced workspace can re-attach FinderInfo between
# signing and verification, which makes a single codesign check flaky.
verified=0
for attempt in 1 2 3 4 5 6 7 8; do
  xattr -cr "$app" 2>/dev/null || true
  if codesign --verify --deep --strict --verbose=2 "$app" 2>/dev/null; then
    verified=1
    break
  fi
  sleep 1
done
if [[ "$verified" != "1" ]]; then
  echo "codesign verification failed after retries" >&2
  exit 1
fi
test -x "$app/Contents/MacOS/OpenTangerine"
plutil -lint "$app/Contents/Info.plist"
printf 'Built %s (%s, macOS %s+, version %s build %s)\n' "$app" "$(xcrun lipo -archs "$app/Contents/MacOS/OpenTangerine")" "$MIN_MACOS" "$MARKETING_VERSION" "$BUILD_NUMBER"
