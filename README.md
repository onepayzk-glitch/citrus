# Citrus（假宝玉 fork）

A local file converter and toolbox for **macOS**. Drag files in Finder, tap a modifier key, and pick what you need from the wheel around your pointer. Everything runs on your Mac: no account, no upload, no telemetry.

- **Author / maintainer:** 假宝玉 · [github.com/onepayzk-glitch](https://github.com/onepayzk-glitch)
- **Version:** 1.0.0 · macOS 15+ · arm64
- **License:** GPL-3.0-only (fork), upstream Satsuma code under MIT (see [License and credits](#license-and-credits))

> This is a **fork** of the GPL-3.0 project [Open Tangerine](https://github.com/sintaxerrorpvtltd/Open-Tangerine) by **Sintax Error Private Limited**, which in turn builds on [Satsuma](https://github.com/plyght/satsuma) by **plyght** (MIT). The original copyright notices are preserved; the upstream project is not affiliated with this fork. Not affiliated with the commercial app Tangerine either.

## What this fork adds

- **275 conversion routes** mirroring Tangerine's matrix, 26 tools plus QR reading, six file actions (AirDrop / Float / Copy / Move / Copy Path / Terminal), and remappable ⇧ / ⌘ / ⌃ drag wheels.
- **Assembly build (1.0):** external engines are not bundled. The app detects LibreOffice, FFmpeg and Pages when a feature needs them, explains what is missing and helps install it. Office conversions can fall back to the built-in text engine.
- **中文 / English UI** (switchable in Settings → General → Language), six-step first-run guide, sound and haptic feedback, compatibility matrix and per-format settings.
- **Privacy-first feedback:** diagnostics contain only version, macOS version, architecture, language and whether optional engines are installed — never file names, paths or personal data.

## Build from source

Requires macOS 15+, Xcode / Command Line Tools. No package manager or third-party Swift dependencies.

```bash
git clone <your-repository-url> Citrus
cd Citrus
./scripts/build-app.sh            # version 1.0.0 by default
open "dist/Citrus.app"
```

Local builds are **ad-hoc signed**. macOS may ask you to confirm the first launch.

## Tests

```bash
./scripts/test.sh                 # 12 suites, includes matrix coverage and dependency logic
```

See [parity/test-report-1.0.md](parity/test-report-1.0.md) for the full report, and [parity/manual-verification-checklist.md](parity/manual-verification-checklist.md) for the five-minute human drag-and-drop check.

## Release build (signed ZIP + DMG)

```bash
MARKETING_VERSION=1.0.0 BUILD_NUMBER=1 \
DEVELOPER_ID_APPLICATION="Developer ID Application: <Name> (TEAMID)" \
NOTARY_PROFILE="open-tangerine-notary" \
./scripts/package-release.sh
```

The script builds, signs with hardened runtime, packages ZIP and DMG, notarizes and staples both, then writes `SHA256SUMS.txt`. Without a Developer ID certificate it produces ad-hoc artifacts for local testing only. Prerequisites, GitHub Actions secrets and troubleshooting: [parity/release-1.0.md](parity/release-1.0.md). CI workflow: `.github/workflows/release.yml` (tag `v*`).

## Optional external engines

| Engine | Used for | If missing |
|---|---|---|
| LibreOffice | High-fidelity DOCX/PPTX/XLSX/ODS → PDF/PNG/JPG | Prompt + install help; built-in text engine fallback |
| FFmpeg | MP3/FLAC/OGG/Opus/WMA/MKV/WebM/AVI/WMV/GIF | Prompt + install help; those routes unavailable |
| Pages | `.pages` export | Prompt + Mac App Store link |

Policy and manual check: [parity/dependencies.md](parity/dependencies.md).

## Product documents

- [Product requirements (PRD)](PRD.md) · [Roadmap](ROADMAP.md)
- Status: 1.0 source is public and tested; a signed and notarized release is pending the author's Apple Developer credentials.

## Documentation

- [Feature parity matrix](parity/parity-matrix.md) · [Verification](parity/verification.md) · [Test report 1.0](parity/test-report-1.0.md)
- [Dependency policy](parity/dependencies.md) · [Release and notarization](parity/release-1.0.md)
- [Manual drag checklist](parity/manual-verification-checklist.md)
- [Static REA evidence](parity/tangerine-static-evidence.md) · [Runtime evidence](parity/tangerine-runtime-evidence.md)

## Feedback

Use **Feedback…** in the menu bar or Settings → About. Please do not attach private files. The copied diagnostics contain only environment information.

## License and credits

- **This fork (1.0):** modifications and documentation © 2026 假宝玉, licensed under **GPL-3.0-only**. See [LICENSE](LICENSE).
- **Open Tangerine (upstream):** © 2026 Sintax Error Private Limited, GPL-3.0-only — [repository](https://github.com/sintaxerrorpvtltd/Open-Tangerine).
- **Satsuma:** © 2026 plyght, MIT — see [NativeApp/LICENSE](NativeApp/LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- Contributors retain copyright in their contributions. The license does not grant rights to company names, product names or logos.
