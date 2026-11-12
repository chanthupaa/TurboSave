# TurboSave Android — release preparation

Repository: `turbosave-android`. Recovered application version: 1.4.1+9. Description: A Flutter Android interface for locally managed media downloads.

## Current source milestone: 1.5.2+12 — 3 November 2026

Signed Restricted and Open release APKs for `1.5.2+12` were built and verified on 3 November 2026. Both contain ARM32 and ARM64 libraries, pass signature and ZIP-alignment checks, and the exact release source passes 170 Flutter tests with clean analysis. See `docs/reports/2026-11-03-release-1.5.2.md` for paths, sizes and SHA-256 hashes.

The native bridge/extractor have been reconstructed. All 13 findings in `SECOND_MOBILE_BUG_AUDIT.md` and the three later findings B1–B3 are now addressed in source: 166 Flutter tests, 61 native JVM tests (including the live pinned probe), 40 Python tests and 53 targeted Open-edition checks pass; whole-folder analysis is clean. Existing tests/dependencies and recovery archives are preserved. See `docs/reports/2026-11-02-b1-b3-repair.md` for the current evidence and limits, and `docs/reports/2026-11-01-remaining-audit-repairs.md` for earlier repairs.

These latest fixes have been packaged into APKs but have not been installed on a phone. No AAB was built. Passing tests and package verification do not establish a bug-free app or store approval. The remaining text below records the earlier recovery milestone.

Before publication, test physical ARM 32/64-bit phones: installation/update, real cold/warm share intents, Android 7–9 storage permissions, background completion, process death during enqueue, notifications, Wi-Fi restrictions, file open/share, slow networks, battery and storage. Configure developer identity, support contact and public privacy-policy URL. Source blocking alone does not establish Google Play approval.

DownloadManager is retained by user choice. Preflight pins checked IP addresses, verifies the original HTTPS hostname, checks redirects and recognised container signatures. DownloadManager makes its own subsequent DNS/redirect decisions; Flutter fetches thumbnails. These later connections are not pinned by preflight. Container headers do not prove full-file integrity or playback.

Interrupted starts remain visible as failed with a warning to check Android Downloads before retrying; Android may already have accepted the file. They are not automatically retried. Keep signing material and original recovery archives private and outside source control.

## Historical recovery milestone

Read `RECOVERY.md` and `PIPELINE_AUDIT.md`. The Dart/assets are recovered source; the original native Android project and complete method-channel implementation are missing. Do not advertise a rebuilt Android release based on a browser preview or Dart analysis.

Before publication: reconstruct the Android project/native bridge and editable extractor source; fix the five recorded pipeline defects; verify dependency licensing and scan source/recovery evidence for credentials and private configuration; build and test signed APK/AAB on physical devices. Device background downloads, storage, open/share MIME handling and lifecycle recovery remain gates. Distribution-channel requirements require their own review.

`_private-backups/` holds original APKs and archives and is excluded from Git. Keep recovery URI strings as historical evidence rather than replacing them with the new local folder. New work should preserve an untouched recovery baseline.

Developer checks: `flutter pub get`, `flutter analyze --no-pub lib`, `flutter test`. The audit suite contains known failing regression cases until the mobile repair milestone. Full build steps cannot be supplied honestly until the missing native layer is rebuilt.
