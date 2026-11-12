# TurboSave mobile bug audit

Date: 29 October 2026. Source version: 1.5.0+10.

This is the historical audit snapshot. Current repairs and verification are recorded in `REPAIR_REPORT.md` for version 1.5.1+11.

Audit only: application behavior was not fixed. Added regression tests and this report. No files were deleted, no APK was installed, and nothing was pushed or deployed.

## Findings

### 1. High: an accepted download can become untracked during shutdown

`lib/providers/download_provider.dart:318` awaits native enqueue before recording the job. `_persistTasks()` at line 177 discards writes after disposal. If shutdown happens while enqueue is in flight, Android can accept the download but the next app session has no queue record for it. The native bridge also drops results after activity destruction rather than reconciling accepted jobs on startup.

Reproduced with a delayed enqueue result, provider disposal, then successful Android job ID 101: `queue_v2` remained absent. Test: `enqueue finishing after provider disposal must remain recoverable`.

### 2. High: one stale ownership ID can freeze progress for the whole queue

`android/app/src/main/kotlin/com/turbosave/videodownloader/MainActivity.kt:101` maps a whole query batch through `snapshot()`. The ownership check at line 190 throws for an unknown ID, failing the entire batch. `lib/providers/download_provider.dart:467` silently catches that failure and submits the same batch again. Other downloads can continue in Android while the app never moves them to Library.

A stale Dart ID is possible if the process exits after native cancellation removes ownership but before Dart saves its updated queue. Fault-injection reproduction used stale ID 101 alongside successful ID 102; repeated polls never recorded 102. Test: `one stale native ID must not stop other downloads from reaching Library`. This was not reproduced by killing a physical Android process.

### 3. Medium: Paste uses its text controller after the Home screen is disposed

`lib/screens/downloader_screen.dart:66` awaits clipboard access, then writes `_url.text` before checking `mounted`. Navigation to Activity during that await disposes the controller.

Reproduced framework exception: `A TextEditingController was used after being disposed.` Test: `leaving Home while clipboard access is pending must not touch a disposed controller`. This establishes a lifecycle/debug assertion bug, not proof of an Android release-process crash.

### 4. Medium: the Home header can overflow on a narrow phone

`lib/screens/downloader_screen.dart:269` puts the full wordmark, active-download counter, Sources button and theme button in one non-wrapping row. The active counter further reduces available space.

The existing 390-pixel cold-share widget test emits a 40-pixel right overflow with its default test font. A separate audit test loaded the actual bundled Manrope font and application theme: a 360-pixel viewport with an active job overflowed **57 pixels** on the right.

### 5. Medium: mobile details render twice

`lib/screens/downloader_screen.dart:99` opens a modal details sheet, while the inline `_MediaPanel` at line 242 remains in Home. Two format selectors and permission forms exist for the same video, with independent checkbox state.

Reproduced by the existing cold-share test: two `Available complete files` widgets instead of one. The duplicate implementation also applies to manually inspected media at phone widths.

### 6. Medium: dismissed shared-video details reopen on every return to Home

`lib/screens/main_navigation_screen.dart:151` unmounts Home when changing tabs. `_shareRevision` remains positive, and `DownloaderScreen.initState()` at line 40 treats it as a new share on each remount.

Reproduction: share a link, dismiss details, visit Activity, return Home. The bottom sheet opens again without another share. Test: `returning Home must not reopen an already dismissed shared-link sheet`.

### 7. Medium: available thumbnails are never displayed

`lib/services/video_parser_service.dart:192` retains extracted thumbnails, but `_MediaPanel` at `lib/screens/downloader_screen.dart:586` always uses `MediaArtwork`, whose implementation only draws a generic icon. Activity and Library use the same placeholder; persistence also drops the thumbnail URL.

Test supplied a valid nonempty thumbnail URL: details contained no Image widget. Test: `a saved page thumbnail should appear in its media details`.

### 8. Medium: different audio qualities can have identical labels

Python returns audio bitrate, but `lib/services/video_parser_service.dart:120` builds the audio label from extension only and does not retain bitrate/language in FormatOption. When sizes are unavailable, both choices can say `Audio M4A · Size unavailable`.

Reproduced with distinct 64 and 128 kbps formats. Test: `different audio bitrates should have distinguishable quality labels`.

### 9. Medium: a failed Retry leaves the old error visible

`lib/providers/download_provider.dart:538` puts a retry error in the provider-wide error field. Activity renders `task.error` at `lib/screens/downloads_screen.dart:152`, which remains the earlier failure.

Reproduced an expired-link failure followed by a storage-full error: the task still showed `Old expired link`. Test: `a failed Retry should display the latest error on Activity`.

### 10. High for x86-64 installs; storage waste for ARM: incomplete extra architecture in APK

Inspected `artifacts/apks/TurboSave-Restricted-1.5.0.apk` (85,953,083 bytes, approximately 82.0 MiB). It advertises arm64-v8a, armeabi-v7a **and x86_64**. The x86-64 directory contains 10 native libraries occupying 11.77 MiB of the APK, but has neither `libflutter.so` nor `libapp.so`. The two requested ARM directories contain both.

This creates an incomplete x86-64 installation path and adds unnecessary size to ARM downloads. The Flutter Gradle plugin resets default ABI filters to its platform list; the requested target-platform list and current `android/app/build.gradle.kts:34` do not prevent this artifact. Verified with ZIP inspection and Android `aapt2 dump badging`; no x86-64 device launch was performed.

## Additional risks requiring targeted device/network validation

- Native direct-file inspection checks DNS before opening a normal HttpURLConnection, which resolves again. DownloadManager later connects independently and follows its own redirects. This is not a pinned end-to-end public-address or restricted-host guarantee. Relevant locations: `MainActivity.kt:135`, `:137`, `:172`. No malicious DNS/redirect test was performed.
- `MainActivity.isMediaBytes()` only rejects empty data and leading `<`, `{`, `[`. It is not a media-signature or decoder check; arbitrary other bytes with a media MIME type can pass. This can produce unusable files, and should not be described as validated playable video.

## Verification

- Scoped Flutter analysis (`flutter analyze --no-pub lib test`) passed before the audit-only test additions.
- Original Flutter suite: **27 passed, 1 failed**. The one failing cold-share test exposes findings 4 and 5.
- Eight added behavioral/layout reproductions: **all eight failed as expected**, exposing findings 1, 2, 3, 4, 6, 7, 8 and 9. Assertions describe desired behavior; these are deliberately failing regression tests, not fixes.
- Combined suite before the extra real-font header case: **27 passed, 8 failed**.
- Python extractor policy suite: **6 passed**.
- Flavor policy test invoked with `flutter test --no-pub --flavor unrestricted test/flavor_policy_test.dart`: **1 passed**. This is not an installed Open-APK test.
- APK package ID, SDK levels, ARM libraries and incomplete x86-64 library set inspected locally.
- Real-font header check: failed with a 57-pixel overflow. Native JVM unit tests: **3 passed**, Gradle build successful.
- `adb devices` lists no connected Android phone. Background completion, storage permission prompts on Android 7–9, process death, battery use, 32/64-bit device installation and real share targets remain unverified.

Tests: `test/mobile_bug_audit_test.dart`, `test/sharing_and_efficiency_test.dart`, `test/pipeline_audit_test.dart`, `test/extractor_policy_test.py`.

Logs: `_recovery/mobile-bug-audit-tests.log`, `_recovery/mobile-full-audit-tests.log`, `_recovery/mobile-native-audit-tests.log`.
