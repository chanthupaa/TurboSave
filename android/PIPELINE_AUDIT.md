# TurboSave app pipeline verification — 25 October 2026

**Verdict: partially verified; not ready to call a working rebuilt Android app.**

The recovered Flutter UI runs. The APK's exact Python/yt-dlp code can extract
some live sources on this Windows PC. Five reproducible Flutter/UI defects
remain. The recovered folder has no buildable Android project or complete native
method-channel implementation, and no phone/emulator was attached. This audit
did not repair app behavior, change the original 25 Dart files, replace the APK,
or modify the separate website.

## Executed checks

| Check | Result | Limit |
| --- | --- | --- |
| `flutter analyze --no-pub` | No issues | Static analysis cannot prove native behavior |
| Flutter pipeline suite | 17 pass, 5 fail | Android method-channel responses are simulated; one widget test checks real Flutter rendering |
| APK Python policy checks | 10 pass | Private DNS response is simulated; other rejected URLs make no site requests |
| Direct sample extraction | Pass, original MP4 format | Original APK bytecode and bundled yt-dlp 2026.08.19 run on Windows |
| Real direct sample download | HTTP 200, video/mp4, 4,372,373 bytes | Downloaded using Python HTTPS GET, not Android DownloadManager |
| Full file decode | Pass, FFmpeg exit 0 | 52.208-second 854×480 H.264 video + AAC audio |
| Browser, 390×844 | Sample details, permission-disabled button, Activity, Library, Settings and tour replay inspected | Browser cannot run the Android Python bridge |
| Source preservation | 25 Dart files and 6 assets byte-exact; 29 embedded dependency versions matched | New test support and browser helper are reconstructed additions |
| Actual Android install/background download/open/share | Not tested | No attached device/emulator; native project incomplete |

Sample: `https://download.blender.org/durian/trailer/sintel_trailer-480p.mp4`

SHA-256: `b670602fa00934ca27c4351bb0efe7ea7a07fae57284e44226025eeed7c51254`.
The sample is a Blender Foundation Sintel trailer, credited in the app as CC BY 3.0.
The downloaded test file remains under `_recovery/qa/`; it is excluded from the
source backup to avoid packaging downloaded media.

## Live source extraction probes

These use the original APK's `media_extractor.pyc` and bundled yt-dlp, with no
cookies or API keys. Social samples are metadata-only probes using yt-dlp's own
public test URLs. No Instagram/Pinterest/TikTok/Facebook media files were saved.
A single success/failure does not certify or condemn a whole platform.

| Source | Sample | Observed result |
| --- | --- | --- |
| Instagram | `https://www.instagram.com/reel/Chunk8-jurw/` | 3 MP4 formats; title only "Video by instagram"; dimensions/size unavailable |
| Pinterest | `https://www.pinterest.com/pin/1084663891475263837/` | 5 MP4 formats, reported height 1138; title returned |
| TikTok | `https://www.tiktok.com/@leenabhushan/video/6748451240264420610` | Generic unavailable/unsupported error; no formats |
| Facebook | `https://www.facebook.com/radiokicksfm/videos/3676516585958356/` | Generic unavailable/unsupported error; no formats |
| Vimeo | `https://vimeo.com/83932884` | Generic unavailable/unsupported error; no formats |

The caught generic errors do not identify whether a sample was removed, needs
login, was region/network blocked, or needs an extractor update. More diagnosis
is needed before advertising those flows as working. Source test entries in a
directory do not guarantee current downloads.

## Reproduced defects (not fixed)

1. **High: Retry can create duplicate system downloads.**
   `lib/providers/download_provider.dart:362` has no in-flight retry guard.
   Two overlapping `retryTask` calls enqueue two replacements while the task
   still has failed status. `downloads_screen.dart` leaves Retry enabled during
   this wait. The regression test records two `enqueue` calls where one is expected.

2. **High: Retry can lose control of a replacement download.**
   `lib/providers/download_provider.dart:380` queues the replacement, then line
   389 cancels the old job before line 390 records the new ID. If cancellation
   throws, the replacement exists but the queue still refers to the old ID.
   The regression test returns new ID 101, forces cleanup failure and observes
   the task still tracking ID 1.

3. **Medium: Open/share sends a generic MIME type for every file.**
   `lib/providers/download_provider.dart:402` always passes
   `application/octet-stream`, including saved MP4. Expected `video/mp4` is not
   sent. The decompiled native evidence uses this argument for VIEW/SEND intents;
   compatible player/share-target matching can therefore fail. Exact symptoms
   still require a phone test.

4. **Medium: One damaged saved record hides later valid records.**
   `lib/providers/download_provider.dart:118` catches around the entire list
   rather than each item. With valid/broken/valid records, only the first is
   restored. The regression test expects two records and gets one.

5. **UI: Download details emit a Material/ListTile assertion.**
   `lib/screens/downloader_screen.dart:519` paints a decorated card around the
   `CheckboxListTile` at line 600 without giving it its own Material surface.
   The browser log and a widget regression test both reproduce "ListTile
   background color or ink splashes may be invisible." The current Flutter debug
   build repeatedly reports this; the card still renders. This is not evidence
   of an Android release crash, but the surface/ink layering needs correction.

The test suite intentionally retains the five failing regression assertions.
Do not interpret its nonzero exit as a broken test harness or silently skip
them. The other 17 tests cover restrictions, direct response MIME/error checks,
extracted-URL/header filtering, rights confirmation, queue progress/completion,
missing-file handling, cancellation, history opt-in, stale request suppression,
visible extraction errors and unsupported preview extraction.

## Work to add/finish, in order

1. Restore `android/` Gradle configuration, resources, Chaquopy/Python packaging,
   and a complete editable Kotlin method-channel bridge. Current JADX output is
   evidence/pseudocode, not a compilable replacement. The original Python source
   was not embedded; preserved bytecode is useful for testing but not a maintained
   source substitute. Do not generate an empty Android scaffold and assume the
   extractor is restored.
2. Fix the five reproduced defects and make all 22 regression/contract tests pass.
3. Implement **receive shared links**. The saved APK's merged manifest only has
   MAIN/LAUNCHER for the app activity; no inbound ACTION_SEND text/plain filter.
   Outbound sharing of a saved file is a different existing method.
4. Diagnose failed real social samples; retain honest error messages and show
   only complete formats. The current app does not convert every video to MP3
   or merge separate sound/video streams.
5. Test the rebuilt APK on a real Android 10+ phone: real post fetch, actual saved
   bytes/playback, failed/retried downloads, offline/Wi-Fi transitions, app killed
   mid-transfer, restart restoration, cancel, open/share, share-to-app, low storage
   and source redirects to blocked/private destinations. Browser and mocked
   channel checks cannot replace these.
6. Recreate release/build automation after the native build exists: static
   checks + tests, reproducible Android build and dependency checks, followed by
   signed release AAB and device validation. No release-signing material was
   recovered and no fresh Android APK/AAB was produced here.

Known YouTube/adult hosts are blocked in both Dart and Python; YouTube Music and
OnlyFans test inputs were also visibly rejected in the preview. This is not a
guarantee that every adult video or newly created adult domain can be identified.

## Repeat and inspect

Run these in the recovered project folder:

```powershell
flutter pub get --offline
flutter analyze --no-pub
flutter test --no-pub --reporter expanded test/pipeline_audit_test.dart
python _recovery/scripts/verify_recovery.py
python -I _recovery/scripts/audit_python_pipeline.py
python -I _recovery/scripts/audit_social_samples.py
```

Last two commands access public internet samples, consume bandwidth and may
produce different results later. Their inputs contain no private credentials.

Evidence: `test/pipeline_audit_test.dart`, `_recovery/pipeline-flutter-test.log`,
`_recovery/python-pipeline-audit.json`, `_recovery/social-sample-audit.json`,
`_recovery/sample-media-probe.json`, `_recovery/sample-media-decode.log`,
`_recovery/verification.json`, `_recovery/browser-runtime-diagnostics.json`,
`_recovery/preview/pipeline-mobile.png`.
