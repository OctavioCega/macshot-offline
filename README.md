# macshot Offline (fork)

> **Independent, network-free fork of [sw33tLie/macshot](https://github.com/sw33tLie/macshot) (GPLv3).**
> Every screenshot, recording and OCR result stays on your Mac. The application
> **cannot open a network connection** — not because we promise it, but because
> the macOS sandbox denies it at kernel level and no network code ships in the binary.

Upstream "Offline" builds still checked for updates (Sparkle) and could call
Google Translate. This fork removes every remaining network capability:

| Component | Upstream `OFFLINE` build | This fork |
|---|---|---|
| Uploads (imgbb / Google Drive / S3) | compiled out (`#if !OFFLINE`) | compiled out **and** `network.client` removed |
| Sparkle auto-updater | active (checks `appcast-offline.xml`) | **removed** — package, code, `SU*` keys, mach exceptions |
| Google Translate (`URLSession`) | active | **removed** — only on-device Apple Translation remains |
| `com.apple.security.network.client` | present | **removed** — kernel blocks every outbound socket |
| Google OAuth URL scheme | stripped at build time | **removed** from `Info.plist` |
| Telemetry / crash reporting | none upstream | none |

Everything else is intact: capture, 19+ annotation tools, screen recording +
editor, scroll capture, Vision OCR, PII auto-redact, beautify, local history —
all on-device, all free.

> Translation still works, via Apple's on-device Translation framework (macOS 15+).
> Language packs are managed by macOS in System Settings, outside this app.
> Speech-to-captions already forced `requiresOnDeviceRecognition = true`.

---

## Install (unsigned build)

1. Download `macshot-Offline.dmg` from [Releases](../../releases) (or the latest
   [Actions artifact](../../actions/workflows/build-offline.yml)), drag to `/Applications`.
2. First launch: **right-click → Open** (Gatekeeper warns because the binary is
   ad-hoc signed — there is no paid Developer ID / notarization in this fork).
3. Grant **Screen Recording** when prompted (System Settings → Privacy & Security).

> The app does not update itself — that is the point. Check Releases for new builds.

## Build it yourself

Requires Xcode 26+ and macOS 26 SDK:

```bash
xcodebuild \
  -project macshot.xcodeproj \
  -scheme macshot \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS="OFFLINE" \
  MACSHOT_BUNDLE_ID="com.octaviocega.macshot.offline" \
  MACSHOT_PRODUCT_NAME="macshot Offline" \
  INFOPLIST_KEY_CFBundleDisplayName="macshot Offline" \
  INFOPLIST_KEY_CFBundleName="macshot Offline" \
  build
codesign --force --deep --sign - "build/Build/Products/Release/macshot Offline.app"
```

## Verify it cannot connect

The CI workflow runs these checks on every build — you can run them too:

```bash
APP="build/Build/Products/Release/macshot Offline.app"

# 1. Sandbox on, network.client absent
codesign -d --entitlements :- "$APP" | grep -c "network.client"   # → 0

# 2. No Sparkle
otool -L "$APP/Contents/MacOS/"* | grep -i sparkle                # → nothing
ls "$APP/Contents/Frameworks/" | grep -i sparkle                  # → nothing

# 3. No network endpoints left in the binary
strings "$APP/Contents/MacOS/"* | grep -Ei \
  "googleapis|imgbb|amazonaws|appcast"                            # → nothing

# 4. Runtime proof: watch it emit zero packets while you use it
sudo tcpdump -i any -n host <app-pid> 2>/dev/null &               # or lsof -i -P -p <pid>
```

Expected result of every check: **nothing**. `lsof -i -nP -p $(pgrep -f "macshot Offline")`
shows no sockets while capturing, annotating, OCR-ing or recording.

## What was changed (GPLv3 notice of modifications)

This fork is based on `sw33tLie/macshot` and remains under **GPL-3.0**
(see [LICENSE](LICENSE); original copyright notices preserved in sources).

- Removed the Sparkle package dependency and all `SPU*` updater code,
  `SU*` `Info.plist` keys, and Sparkle mach-lookup exceptions.
- Removed `com.apple.security.network.client` from `macshot.entitlements`.
- Removed the Google Translate provider and its `URLSession` code; only
  on-device Apple Translation remains.
- Removed the Google OAuth `CFBundleURLTypes` entry.
- Replaced the upstream release workflow (requires signing/notarization
  secrets) with `build-offline.yml`, which builds, verifies and publishes
  the offline `.app`/`.dmg` unsigned.
- Bundle identifier changed to `com.octaviocega.macshot.offline`.
- Upload sources (`macshot/Upload/`) remain in-tree but are compiled out of
  every build of this fork via `SWIFT_ACTIVE_COMPILATION_CONDITIONS="OFFLINE"`;
  the kernel-level sandbox blocks them regardless.

---

### macshot (upstream description)

*The most feature-rich open-source screenshot tool on macOS — 19+ annotation
tools, screen recording with a full video editor, OCR + translation, auto-redact
PII, scroll capture, beautify. Native Swift + AppKit, no Electron, no
subscription.* Full upstream docs and credits:
[sw33tLie/macshot](https://github.com/sw33tLie/macshot).
