# macshot Offline

Screenshot & screen recording tool for macOS that **cannot connect to the
internet** — the sandbox denies every outbound socket and no network code
ships in the binary. Your captures never leave your Mac.

Independent fork of [sw33tLie/macshot](https://github.com/sw33tLie/macshot), GPLv3.

## Install

1. Download `macshot-Offline.dmg` from [Releases](../../releases) and drag the app to `/Applications`.
2. First launch: **right-click → Open** (unsigned/ad-hoc build — Gatekeeper warns once).
3. Grant **Screen Recording** when prompted. Capture: `Cmd+Shift+X`.

No accounts, no sign-in, no update checks — there is no updater at all.

## Features (all on-device)

Capture & annotate (19+ tools) · screen recording + video editor · scroll
capture · Vision OCR · PII auto-redact · beautify · local history · on-device
translation (Apple, macOS 15+) · on-device speech captions.

Removed vs upstream: cloud uploads (imgbb/Drive/S3), Sparkle auto-updates,
Google Translate, OAuth — every feature that needed a connection. Also removed
the only third-party dependency (Swift-WebP/libwebp), so the fork has **zero
external packages**; the only casualty is exporting still images as `.webp`
(PNG/JPEG/HEIC/AVIF remain).

## Why it's actually offline

1. **No network code** — the only `URLSession` uses lived in uploads and
   Google Translate; both are gone. Uploads are also compiled out (`#if !OFFLINE`).
2. **No network permission** — `com.apple.security.network.client` was
   removed from the entitlements, so macOS' sandbox refuses any socket the
   process tries to open. Even a future bug can't phone home.
3. **Verified per build** — CI asserts the entitlement is absent, no Sparkle
   is linked, and no endpoints remain in the binary.

## Verify it yourself

```bash
codesign -d --entitlements :- "/Applications/macshot Offline.app" | grep -c network.client   # → 0
lsof -i -nP -p "$(pgrep -f 'macshot Offline')"                                              # → no sockets, while using it
```

## Build from source

The project relies on Swift 6.2's default-`@MainActor` isolation, so it needs a
**Swift 6.2+ toolchain** even though it builds against the macOS 15 SDK:

1. Install any Xcode with the macOS 15 SDK (Xcode 16.4 works).
2. If your Xcode is < 26, install a Swift 6.2+ toolchain from
   [swift.org/install](https://www.swift.org/install/) — `build-local.sh`
   detects it automatically in `~/Library/Developer/Toolchains`.

```bash
./build-local.sh   # builds, ad-hoc signs, runs the verification above, packs the DMG
```

Compatibility changes vs upstream (cosmetic, needed for the 15 SDK / Xcode 16):

- Removed the macOS-26-only screenshot fast path — the standard pre-26 capture
  path is used everywhere, identical on macOS ≤15.
- Removed the Swift-WebP package (see Features note above).
- `import _Translation_SwiftUI` + two small type-inference fixes for SDK 15.

## License

GPL-3.0 — same as upstream ([LICENSE](LICENSE)); original copyright preserved.
This fork removed: Sparkle (package, `SU*` keys, update UI), the Google
Translate provider, `network.client`, the OAuth URL scheme, and upstream's
signed-release workflow. Details and history:
[upstream repo](https://github.com/sw33tLie/macshot).
