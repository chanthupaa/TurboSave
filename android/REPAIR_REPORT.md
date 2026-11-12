# Mobile source repair status — 2 November 2026

Release update — 3 November 2026: signed Restricted and Open `1.5.2+12` APKs were built after the B1–B3 and C1 repairs. Final source verification is 170 Flutter tests passed with clean analysis. Artifact hashes and package checks are in `docs/reports/2026-11-03-release-1.5.2.md`.

All 13 findings in the second mobile audit have been addressed in source. The subsequent review found three additional defects (B1–B3), which are now repaired: removal of failed stale downloads, direct audio-container MIME handling, and final HTTP response handling after informational headers.

Current checks: **166 Flutter tests passed; 61 native JVM tests passed with no skips, including the live pinned probe; 40 Python tests passed; 53 targeted Open-edition policy/new regression tests passed; whole-folder analysis clean.** No existing tests were edited or weakened and no package was added.

See [the B1–B3 repair report](docs/reports/2026-11-02-b1-b3-repair.md), [earlier repairs](docs/reports/2026-11-01-remaining-audit-repairs.md) and [roadmap](docs/plans/2026-10-30-mobile-bug-fixing-roadmap.md) for per-finding evidence. These are source/test results. No fresh APK build, installation, physical-device matrix, battery/storage measurement or soak was performed for these repairs. Historical APKs described below do not contain the latest source changes.

# Historical mobile repair milestone — 29 October 2026

Version 1.5.1+11. No existing tests were edited or removed; no packages were added. No device installation, GitHub push or deployment was performed.

## Repairs

1. Starts receive a random local ID and are persisted as `enqueuing` before Android enqueue. The returned native ID is persisted even after provider disposal. Interrupted starts are retained as failed on startup with a warning to inspect Android Downloads before retrying. Retry and Cancel handle ID-less records safely.
2. Retained the per-ID native isolation and Dart reconciliation/logging fix, including legacy batch-error fallback.
3. Paste checks screen lifetime before touching its text controller.
4. The narrow header uses a shrinking wordmark and compact accessible icon controls.
5. Phones show one details sheet, with a Review formats button underneath rather than a second permission/format form. Larger layouts keep inline details.
6. The navigation parent remembers which share revision was presented; returning Home does not reopen a dismissed share.
7. Details, Activity and Library render returned thumbnails with bounded image caching and icon fallback. Thumbnail URLs survive saved-record restoration.
8. Audio formats retain and display bitrate and available language.
9. Retry clears the old task error and records a new failure on that same task.
10. ARM-only Gradle filtering overrides Flutter's default ABI expansion; final APK contents and size are checked after packaging.

Media checks recognise MP4/M4A/MOV, WebM/MKV, MP3, WAV, FLAC and Ogg signatures. Short reads are accumulated. Preflight HTTPS connections use checked IP addresses, verify the original TLS hostname, validate redirects, and parse bounded response headers/body prefixes.

## Changed areas

- Download lifecycle: `lib/providers/download_provider.dart`, `lib/models/download_task.dart`, `lib/screens/downloads_screen.dart`.
- Sharing/layout: `lib/screens/downloader_screen.dart`, `lib/screens/main_navigation_screen.dart`.
- Metadata/artwork: `lib/models/format_option.dart`, `lib/services/video_parser_service.dart`, `lib/widgets/media_artwork.dart`, `lib/screens/library_screen.dart`, native Python extractor.
- Native checks: `MainActivity.kt`, `LinkRules.kt`, new `MediaSignatures.kt` and `PublicMediaProbe.kt`.
- Packaging/version: `android/gradle.properties`, `pubspec.yaml`, `lib/data/legal_content.dart`, `scripts/build-apks.ps1`.
- New tests: enqueue recovery, independent edition policy, signatures, preflight parser/address validation and opt-in real HTTPS probe.

## Evidence

Final results:

```text
Flutter full suite: 42 passed, 0 failed
Static analysis: No issues found
Native JVM suite: 14 passed, 0 failures/errors/skips (live probe enabled)
Python extractor policy: 6 passed
Open edition independent policy test: 1 passed
Live pinned HTTPS probe: HTTP 206, 512-byte MP4 prefix accepted
Release APK builds: both successful; signatures and ZIP alignment verified
```

The eight test files present at the start of this repair session retain their original SHA-256 hashes. New tests were added separately. Native JVM testing reused the existing Flutter debug assets while compiling/running the native tests; the separate Flutter suite and both release builds also completed.

| APK | Size | Architectures | Package |
|---|---:|---|---|
| `artifacts/apks/TurboSave-Restricted-1.5.1.apk` | 70,400,836 bytes / 67.14 MiB | armeabi-v7a + arm64-v8a | com.turbosave.mobile.restricted |
| `artifacts/apks/TurboSave-Open-1.5.1.apk` | 70,399,112 bytes / 67.14 MiB | armeabi-v7a + arm64-v8a | com.turbosave.mobile.open |

Both are version 1.5.1, version code 11. Each ARM directory contains `libflutter.so` and `libapp.so`; neither APK advertises x86-64. All arm64 loadable native libraries passed the 16 KiB ELF alignment check. Both APKs passed `apksigner verify` and `zipalign -c -P 16 4`.

The previous Restricted APK was 85,953,083 bytes / 81.97 MiB. The new Restricted APK is **18.09% smaller**, saving 15,552,247 bytes (14.83 MiB).

SHA-256:

```text
Restricted a8c31ef67155157f606d1c46fcda24c880cd6ab4926767fdbb8fda5940e8f819
Open       672ed82b528a74c605234c09a90906e09638b96dbe8d0df73088892a36bb3472
```

Logs: `_recovery/all-fixes-flutter.log`, `all-fixes-analysis.log`, `all-fixes-native-final.log`, `all-fixes-live-probe.log`, `all-fixes-apks.log`, `all-fixes-final-restricted.log`. Machine-readable APK checks: `_recovery/all-fixes-apk-verification.json`.

## Limits

The user chose DownloadManager. Its final DNS/redirect connections, and Flutter thumbnail requests, are outside pinned preflight; this remaining limitation is documented. Signatures recognise headers, not full playback. Physical-device background behavior, process death, battery, storage and publication approval remain unverified. See `RELEASE_READINESS.md`.
