# Mobile full recheck — 2 November 2026

Result: one additional confirmed defect (C1). This check does not establish that it is the only possible defect. No production fixes or existing test edits were made.

Follow-up: C1 was subsequently repaired; see [the C1 repair report](2026-11-02-c1-library-removal-repair.md). The findings below describe the pre-repair recheck.

## C1 — Library removal leaves storage failures unhandled (P2)

Location: `lib/providers/download_provider.dart:747–751`; caller: `lib/screens/library_screen.dart`, Library card delete action.

`deleteCompletedTask` removes the record in memory, notifies listeners, then calls `unawaited(_persistTasks())`. `_persistTasks` throws if SharedPreferences rejects either write. The returned future has no error handler, and the synchronous UI callback cannot await it. Thus a storage write failure escapes as an uncaught asynchronous error. No failure message is shown by this path, and successful durable removal is not established even though the card disappears. The downloaded file itself is intentionally retained.

Reproduction uses a real DownloadProvider with one restored Library record and an existing SharedPreferences platform test double. The control accepts storage writes; the failing case makes `setValue` return false, as permitted by its API. An error zone captures errors escaping the Library removal operation.

```text
Library removal handles storage failure: reject=false   PASS
Library removal handles storage failure: reject=true    FAIL
Expected: empty
Actual: [StateError: Bad state: Could not save download records. Check device storage.]
```

Evidence: `_recovery/full-check-2026-11-02/library_write_repro_test.dart`, `library-write.log`, `library-write.exit` (1). These are isolated in the ignored recovery directory; the maintained suite was not modified. This demonstrates an unhandled Dart error, not a reproduced Android process crash.

Suggested repair, not applied: return/await the removal operation and handle persistence errors with a visible message and a consistent retained/restored Library record. Add a regression covering rejected writes without weakening existing checks.

## Verification

Fresh evidence is recorded in `_recovery/full-check-2026-11-02/`.

| Check | Result |
|---|---|
| Full Restricted Flutter suite | 166 passed |
| Targeted Open-edition checks | 53 passed |
| Python unittest discovery | 40 passed |
| Full Restricted native JVM suite, live probe enabled | 60 passed, 1 failed, 0 skipped |
| Static analysis | Incomplete: launcher attempts stalled and were stopped; no clean result claimed |
| Separate C1 reproduction | Control passed; rejected-write case failed as reported above |

The native failure was `PublicMediaProbeLiveTest.publicBlenderMediaPassesPinnedTlsAndContainerCheck`: `java.net.UnknownHostException: No such host is known (download.blender.org)`. This run did not verify the real network probe; it must not be reported as an all-green native result. JUnit XML was copied into the evidence directory.

The Flutter analysis wrapper stalled before producing analysis output and was stopped. Analysis was then launched directly with the existing Flutter Dart SDK; it printed `Analyzing MOBILE APP...` but did not complete and was stopped too. Outputs are `analysis.log`, `analysis-direct.log` and `analysis-status.txt`. The previous repair's clean analysis is historical evidence, not a fresh result for this check.

Commands: `flutter test --no-pub --flavor restricted --reporter expanded`; the same six-file Open test selection listed in the B1–B3 repair report; `python -m unittest discover -s test -p '*test.py' -v`; `android/gradlew.bat -p android :app:testRestrictedDebugUnitTest -x :app:compileFlutterBuildRestrictedDebug --console=plain --rerun` with `TURBOSAVE_LIVE_PROBE=1`; `dart analyze`. Native testing reuses existing Flutter debug assets and does not build a release APK.

## Scope and limits

Reviewed persistence, enqueue/retry/cancel/query/completion handling, direct/extracted format parsing, native ownership and response handling, sharing lifecycle, URL policy, extractor resource guards, manifest and packaging entry points. The full maintained Restricted Flutter, native JVM and Python suites, targeted Open-edition tests and whole-folder analysis were requested again. The isolated C1 reproduction runs separately from the maintained suite.

No physical-phone installation/playback, background/process-death matrix, battery/storage benchmark, long soak, release APK/AAB or publication review was performed. Existing DownloadManager DNS/redirect and prefix-only media-validation limits remain documented; they are not new findings. No packages, existing tests or production files were changed during this check.
