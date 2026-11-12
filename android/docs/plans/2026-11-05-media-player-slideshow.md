# Media Player and Slideshow Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use the executing-plans skill to implement this plan task-by-task.

**Goal:** Add selectable TikTok/Instagram slideshow downloads and a polished in-app viewer for saved video, audio, and image collections.

**Architecture:** Extend the existing extractor and `FormatOption` pipeline with an image media flag, then enqueue selected images through the existing durable Android DownloadManager flow. Persist collection identity on each task so Library can group a slideshow and pass verified content URIs to the native player/gallery. Upgrade the existing native `PlayerActivity` without adding a media dependency.

**Tech Stack:** Flutter/Dart, Android Kotlin views and DownloadManager, Chaquopy Python with yt-dlp, SharedPreferences, Flutter/Kotlin/Python tests.

---

### Task 1: Normalize image slideshow entries

**Files:**
- Modify: `android/app/src/main/python/media_extractor.py`
- Modify: `android/app/src/main/kotlin/com/turbosave/videodownloader/MediaSignatures.kt`
- Modify: `android/app/src/main/kotlin/com/turbosave/videodownloader/LinkRules.kt`
- Test: `test/extractor_policy_test.py`
- Test: `android/app/src/test/kotlin/com/turbosave/videodownloader/MediaSignaturesTest.kt`

1. Write failing tests for a TikTok/Instagram-style multi-entry image collection, URL validation, the 20-image cap, and arbitrary playlist rejection.
2. Add image extensions and normalize only direct HTTPS image entries from supported slideshow platforms.
3. Add JPEG, PNG, and WebP signature checks and image MIME acceptance.
4. Run the Python and Kotlin focused tests; expect all to pass.

### Task 2: Parse and persist image formats

**Files:**
- Modify: `lib/models/format_option.dart`
- Modify: `lib/models/download_task.dart`
- Modify: `lib/services/media_policy.dart`
- Modify: `lib/services/video_parser_service.dart`
- Modify: `lib/providers/download_provider.dart`
- Test: `test/slideshow_download_test.dart`

1. Write failing Dart tests for `imageOnly`, image labels, collection identity, restart persistence, and a selected-image batch.
2. Add `isImage` to `FormatOption` and collection ID/index/count to `DownloadTask` with backward-compatible defaults.
3. Parse extractor `imageOnly` records and persist the new task fields.
4. Add a batch-start provider method that validates selection, enforces the queue limit, and records each task before native enqueue.
5. Run `flutter test test/slideshow_download_test.dart`; expect all tests to pass.

### Task 3: Add selectable image review UI

**Files:**
- Modify: `lib/screens/downloader_screen.dart`
- Modify: `lib/widgets/media_artwork.dart`
- Test: `test/slideshow_download_test.dart`

1. Add failing widget tests for Images, selected count, Select all, Clear all, individual selection, and disabled download with zero selected.
2. Add an Images segment only when image formats exist.
3. Render a responsive image grid using existing network-image behavior, 48dp selection controls, semantic selected state, and stable loading/error placeholders.
4. Wire Download selected to the provider batch method and clear the matching clipboard only after Android accepts the batch.
5. Run the focused widget tests; expect all to pass.

### Task 4: Group slideshow images in Library

**Files:**
- Modify: `lib/screens/library_screen.dart`
- Modify: `lib/services/android_download_service.dart`
- Modify: `lib/providers/download_provider.dart`
- Test: `test/library_player_test.dart`

1. Write failing tests for one album card per collection and a gallery-open method call containing ordered verified IDs/URIs/MIME types.
2. Group completed image tasks by collection ID while leaving video/audio cards unchanged.
3. Add provider and method-channel gallery opening using only completed TurboSave-owned tasks.
4. Run the Library tests; expect all to pass.

### Task 5: Upgrade native player and gallery

**Files:**
- Modify: `android/app/src/main/kotlin/com/turbosave/videodownloader/MainActivity.kt`
- Modify: `android/app/src/main/kotlin/com/turbosave/videodownloader/PlayerActivity.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Test: `android/app/src/test/kotlin/com/turbosave/videodownloader/PlayerActivityTest.kt`

1. Write JVM-testable validation tests for playable image MIME types, ordered gallery items, and invalid/foreign URI rejection helpers.
2. Add verified gallery dispatch to `MainActivity` and grant read access only to owned completed downloads.
3. Upgrade player controls with 10-second back/forward, accessible play/pause, elapsed/total time, tap-to-toggle controls, lifecycle-safe pause, and orientation-safe state restoration.
4. Add image display with swipe plus previous/next buttons and an `n / total` counter; avoid full-resolution duplicate bitmaps.
5. Run native JVM tests; expect all to pass.

### Task 6: Full verification and APK

**Files:**
- No source changes expected.

1. Run `dart format` and `flutter analyze`; expect no issues.
2. Run the full Flutter suite; expect all tests to pass.
3. Run all Python extractor tests; expect all tests to pass.
4. Run `gradlew testUnrestrictedDebugUnitTest`; expect all JVM tests to pass.
5. Run `git diff --check`; expect no whitespace errors.
6. Build the unrestricted ARM/ARM64 debug APK and report its path and SHA-256. Do not interact with the phone.
