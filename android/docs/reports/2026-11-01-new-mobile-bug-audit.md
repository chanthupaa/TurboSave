# Mobile bug review — 1 November 2026

**Answer: YES. Three confirmed bugs remain in the reviewed code.**

**Resolution — 2 November 2026:** B1–B3 have since been fixed and their regression checks pass. See [the repair report](2026-11-02-b1-b3-repair.md). The findings and results below describe the original reviewed commit, before those repairs.

Reviewed commit: `6076a2906a45346e2a47575b5fc7738e933cd630`.

This is a report-only review. No production code, existing tests or dependencies were changed. The APK build condition was not met, so no APK was built or installed.

## Confirmed findings

| ID | Priority | Finding | User-visible effect |
|---|---|---|---|
| B1 | P2 | Unknown native IDs cannot be removed from Activity | A failed record stays in the queue when Close/Cancel is pressed. Twenty such records prevent every new download. |
| B2 | P2 | Direct audio-only MP4/WebM ignores the inspected audio MIME | The app labels those direct files as video and opens/shares them with a video MIME instead of the reported audio MIME. |
| B3 | P2 | Native preflight treats HTTP 103 as the final response | A valid media response following Early Hints is rejected as unavailable before downloading. |

### B1 — unremovable stale records can exhaust the queue

Sources: [cancelTask](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/providers/download_provider.dart:623>), [queue capacity check](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/providers/download_provider.dart:352>), [native ownership guard](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/kotlin/com/turbosave/videodownloader/MainActivity.kt:212>).

The query path correctly returns `unknown` for an unowned ID and Dart marks that task failed. But cancelTask still sends that ID to native Cancel. The native ownership guard throws “This download does not belong to this app.” Task removal and persistence occur only after the awaited call succeeds, so the local failed record remains.

Reproductions:

1. Restore one queued record whose ID is no longer in native ownership.
2. Return native status `unknown`; the record becomes failed.
3. Invoke the same cancelTask action used by Activity's Close button.
4. Native Cancel rejects the unowned ID. Expected: remove the failed local record safely. Actual: one record remains.
5. Repeat with 20 stale records, try removing them, then start a permitted new file. Actual result: false, with “Your queue holds 20 items. Finish or remove an item first.”

Both reproductions fail their correct-behavior assertions. The method-channel mock mirrors the actual native guard; no physical-phone test is claimed. This is a residual cleanup-path bug beyond the previous stale-ID query isolation fix.

### B2 — direct audio containers are still treated as video

Sources: [direct-file inspection result](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/services/video_parser_service.dart:29>), [extension-only audio inference](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/services/video_parser_service.dart:71>), [file-action MIME selection](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/providers/download_provider.dart:709>).

Native inspect already supplies a MIME value, but the direct-file parser reads only its byte count and infers audio kind from the URL extension. MP4 and WebM are not in audioExtensions, so explicit `audio/mp4` and `audio/webm` responses lose their audio kind.

Two reproductions simulate the real native inspection payload, start and complete the transfer, then call Open:

```text
Native inspect: audio/mp4
Expected Open MIME: audio/mp4
Actual Open MIME: video/mp4

Native inspect: audio/webm
Expected Open MIME: audio/webm
Actual Open MIME: video/webm
```

The same openFile method chooses MIME for Share. File bytes are not shown to be damaged; the wrong kind can select inappropriate receiving/player apps. The earlier A7 repair correctly preserves extracted formats carrying audioOnly; this direct-file path still discards the MIME signal and was documented as a limit in that repair.

### B3 — valid final media response after Early Hints is rejected

Sources: [native response parser](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/kotlin/com/turbosave/videodownloader/PublicMediaProbe.kt:39>) and [preflight status requirement](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/kotlin/com/turbosave/videodownloader/MainActivity.kt:153>).

The parser returns immediately for the first status other than 200/206. With a 103 informational response followed by 200 and valid MP4 bytes, it therefore returns status 103 and an empty prefix. MainActivity then reports the file unavailable. A 103 response precedes the final response and must not replace its processing. [RFC 8297, section 2](https://www.rfc-editor.org/info/rfc8297/).

A small Java harness called the actual compiled Kotlin parser, using the existing generated MP4 test fixture:

```text
Plain 200 control:
observed_status=200 prefix_bytes=512 media_signature=true
exit 0

103 Early Hints, then the identical 200 response/body:
observed_status=103 prefix_bytes=0 media_signature=false
AssertionError: The final 200 media response must be processed after informational headers.
exit 1
```

This is an in-memory protocol reproduction, not evidence that a particular named provider currently sends Early Hints. No network/security checks or parser code were changed.

## Evidence and checks

- [Four failing Flutter reproductions](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/review-2026-11-01-162837/review_reproductions_test.dart>) and [their output](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/review-2026-11-01-162837/flutter-reproductions.log>). These tests are isolated in the ignored recovery folder; existing tests remain intact.
- [Native parser harness](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/review-2026-11-01-162837/EarlyHintsAudit.java>), [passing control](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/review-2026-11-01-162837/http-plain.log>) and [failing Early Hints case](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/review-2026-11-01-162837/http-early-hints.log>).
- [Tracked-file integrity check](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/review-2026-11-01-162837/source-integrity.json>): all 126 pre-existing tracked files retain their original SHA-256 hashes.
- Earlier general suite results for this same unchanged commit were 153 Restricted Flutter passes, 40 targeted Open passes and 40 Python passes. The native live check timed out initially and passed on retry. Those existing tests did not cover the cases above. See [the prior retest report](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/retest-2026-11-01-161038/report.md>).

Flutter reproduction command:

```powershell
flutter test --no-pub --flavor restricted 'C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/review-2026-11-01-162837/review_reproductions_test.dart' --reporter expanded
```

The native harness uses Android Studio's existing JDK, the existing restrictedDebug Kotlin classes under `build/app/tmp/kotlin-classes/restrictedDebug`, and the cached Kotlin 2.2.21 standard library. Its plain and early-hints arguments use the same `android/app/src/test/resources/media-signatures/leading-free.mp4` fixture.

## Scope and limits

Reviewed the current mobile download/persistence lifecycle, sharing and UI entry paths, direct/extracted format handling, native ownership/preflight checks, Python metadata/resource controls and build/source policy configuration. Static artwork was not treated as evidence of runtime correctness. This review establishes the three reproduced defects; it does not prove they are the only possible defects.

No new full-suite rerun, release build, physical-device transfer/playback, permissions/background/process-death matrix, battery/storage measurement, soak test or store-policy certification was performed in this review. Previously documented DownloadManager DNS/redirect, prefix-only validation, unknown-codec sound and process-local share-deduplication limits are not counted as new confirmed findings here.

**No fixes, APK build, installation, commit or GitHub push were performed.**
