# TurboSave In-App Media Player Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use the executing-plans skill to implement this plan task-by-task.

**Goal:** Open completed Library video and audio inside TurboSave with native playback controls.

**Architecture:** Keep Flutter responsible for Library interaction and keep Android responsible for validating owned download URIs. After existing ownership checks, `MainActivity` starts a non-exported `PlayerActivity` that uses platform `VideoView`, `SeekBar`, and playback widgets.

**Tech Stack:** Flutter, Dart, Android Kotlin, Android `VideoView`, Android `SeekBar`, JUnit.

---

### Task 1: Specify the Library tap and MIME boundary

**Files:**
- Create: `test/library_player_test.dart`
- Modify: `android/app/src/test/kotlin/com/turbosave/videodownloader/PublicMediaProbeTest.kt`

1. Add a widget test that restores one completed item, taps its Library card, and expects an `open` method-channel call with its owned content URI.
2. Add a Kotlin test requiring `video/*` and `audio/*`, while rejecting images and generic binary MIME types.
3. Run the focused tests and verify that they fail before implementation.

### Task 2: Add the native player

**Files:**
- Create: `android/app/src/main/kotlin/com/turbosave/videodownloader/PlayerActivity.kt`
- Modify: `android/app/src/main/kotlin/com/turbosave/videodownloader/MainActivity.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`

1. Add pure `isPlayableMime` validation.
2. Add a non-exported fullscreen `PlayerActivity` using `VideoView` and native playback controls.
3. Start it explicitly from `MainActivity` only after the existing download ownership and completion checks.
4. Pause on backgrounding, release on destruction, and show a clear Toast for invalid or unreadable files.
5. Run the Kotlin tests; expect PASS.

### Task 3: Make Library cards open the internal player

**Files:**
- Modify: `lib/screens/library_screen.dart`

1. Add one shared `_open` handler with the existing unavailable-file SnackBar.
2. Make each media card keyboard/touch accessible with `InkWell` and an Open tooltip/semantic action.
3. Route the existing Open menu item through the same handler; leave Share and Delete unchanged.
4. Run `flutter test test/library_player_test.dart`; expect PASS.

### Task 4: Regression and device verification

**Files:** none

1. Run `flutter test`; expect all tests PASS.
2. Run `flutter analyze`; expect no issues.
3. Run restricted and unrestricted Android JVM tests; expect BUILD SUCCESSFUL.
4. Build the unrestricted debug APK, install it over `com.turbosave.mobile.open.test`, and open the freshly downloaded Library video.
5. Verify visible playback controls and confirm the Activity does not crash when backgrounded and reopened.
