#!/bin/bash
# Local build for the offline fork — mirrors .github/workflows/build-offline.yml
# Usage: ./build-local.sh
set -euo pipefail
cd "$(dirname "$0")"

# Use the full Xcode even when xcode-select still points at Command Line Tools.
if [ -d /Applications/Xcode.app ]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
# The project sets SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor, which requires
# Swift 6.2+ (Xcode 16.4 ships Swift 6.1.2 and ignores that setting). Prefer a
# locally installed swift.org 6.2+ toolchain when Xcode's compiler is older.
SWIFT_VER=$("$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc" -version | sed -n 's/.*Swift version \([0-9.]*\).*/\1/p' | head -1)
SWIFT_FLAGS=""
if [ "$(printf '%s\n' "$SWIFT_VER" "6.2" | sort -V | head -1)" != "6.2" ]; then
  TC_ID=$(defaults read ~/Library/Developer/Toolchains/swift-latest.xctoolchain/Info CFBundleIdentifier 2>/dev/null \
    || find ~/Library/Developer/Toolchains -name "swift-6.2*.xctoolchain" -maxdepth 1 | head -1 | xargs -I{} defaults read "{}/Info" CFBundleIdentifier)
  export TOOLCHAINS="${TC_ID:?Swift 6.2+ toolchain required — install one from swift.org/install}"
  echo "==> Using toolchain: $TOOLCHAINS (Xcode's Swift $SWIFT_VER is too old)"
  # The build setting is dropped silently on Xcode 16 — pass it to the
  # frontend directly. -disable-round-trip-debug-types works around a
  # swift-frontend assertion crash on SIL box debug types in 6.2.1.
  SWIFT_FLAGS="-Xfrontend -default-isolation -Xfrontend MainActor -Xfrontend -disable-round-trip-debug-types"
fi
xcodebuild -version

APP="build/Build/Products/Release/macshot Offline.app"
VERSION="0.0.0-local"

echo "==> Building offline variant"
xcodebuild \
  -project macshot.xcodeproj \
  -scheme macshot \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  MARKETING_VERSION="$VERSION" \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS="OFFLINE" \
  MACSHOT_BUNDLE_ID="com.octaviocega.macshot.offline" \
  MACSHOT_PRODUCT_NAME="macshot Offline" \
  INFOPLIST_KEY_CFBundleDisplayName="macshot Offline" \
  INFOPLIST_KEY_CFBundleName="macshot Offline" \
  OTHER_SWIFT_FLAGS="$SWIFT_FLAGS" \
  build

echo "==> Ad-hoc signing (stable identity for TCC permissions)"
# Sign nested code first, then the bundle WITH entitlements — without the
# embedded entitlements the app runs unsandboxed.
codesign --force --sign - "$APP/Contents/XPCServices/macshotOCR.xpc"
codesign --force --sign - --entitlements macshot/macshot.entitlements "$APP"
codesign --verify --deep --strict --verbose "$APP"

echo "==> Verifying offline guarantees"
BIN="$APP/Contents/MacOS/$(defaults read "$PWD/$APP/Contents/Info" CFBundleExecutable)"

codesign -d --entitlements :- "$APP" > /tmp/ents.plist 2>/dev/null
if /usr/libexec/PlistBuddy -c "Print :com.apple.security.network.client" /tmp/ents.plist 2>/dev/null; then
  echo "FAIL: network.client present"; exit 1
fi
echo "  ✓ network.client absent, sandbox: $(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' /tmp/ents.plist)"

[ ! -d "$APP/Contents/Frameworks/Sparkle.framework" ] || { echo "FAIL: Sparkle embedded"; exit 1; }
! otool -L "$BIN" | grep -i sparkle || { echo "FAIL: Sparkle linked"; exit 1; }
echo "  ✓ no Sparkle"

! /usr/libexec/PlistBuddy -c "Print :SUFeedURL" "$APP/Contents/Info.plist" 2>/dev/null || { echo "FAIL: SUFeedURL"; exit 1; }
echo "  ✓ no Sparkle keys in Info.plist"

! strings "$BIN" | grep -Ei "translate\.googleapis|imgbb\.com|amazonaws\.com|googleapis\.com/o/oauth|appcast" \
  || { echo "FAIL: network endpoints in binary"; exit 1; }
echo "  ✓ no network endpoints in binary"

XPC=$(ls -d "$APP/Contents/XPCServices/"*.xpc | head -1)
codesign -d --entitlements :- "$XPC" > /tmp/xpc-ents.plist 2>/dev/null || true
! /usr/libexec/PlistBuddy -c "Print :com.apple.security.network.client" /tmp/xpc-ents.plist 2>/dev/null \
  || { echo "FAIL: XPC has network.client"; exit 1; }
echo "  ✓ XPC service clean"

echo "==> Packaging DMG"
hdiutil create -volname "macshot Offline" -srcfolder "$APP" -ov -format UDZO "macshot-Offline.dmg"
shasum -a 256 macshot-Offline.dmg | tee SHA256.txt

echo ""
echo "DONE. App: $APP"
echo "DMG:  $(pwd)/macshot-Offline.dmg"
echo "Install: drag to /Applications, first launch via right-click → Open"
