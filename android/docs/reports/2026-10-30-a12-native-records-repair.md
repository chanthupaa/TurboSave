# A12: native download bookkeeping

30 October 2026. The user explicitly chose A12 next and requested two verification passes. Only A12 was repaired. A4 and the other findings remain untouched.

## Result

Native ownership and cached file-verification records now follow the retained Dart Library/queue. Startup reconciles legacy history, and subsequent cleanup follows successful preference writes. Unchanged ID sets do not trigger repeat cleanup. Cleanup failures are logged and retried on a later save or startup; they do not discard the saved task records.

Cleanup queries candidate Android records in batches of 100, preserving pending/running/paused or otherwise nonterminal transfers. Only unretained completed/failed or missing records are forgotten. No DownloadManager removal is used for reconciliation. The existing explicit Cancel action still removes its transfer as before.

Newly accepted native IDs are persisted as unacknowledged until Dart has durably saved and retained them. They survive a stale concurrent cleanup and activity/native-state restart. This protects the enqueue/disposal window. Ownership and verification-cache changes are synchronized, and a failed status query makes no partial ownership change.

Open/share now receives the selected native ID, requires existing ownership, compares the exact content URI with Android's URI for that ID, and keeps the completed-state/media verification checks. A supplied ID alone grants no ownership. It performs one ownership URI lookup; the following snapshot adds its existing fixed query/URI check. Cost no longer scales with historical IDs.

## Reproduction and verification

Before changing source, a deterministic model checked the old algorithms against the saved source. With 10,000 historical transfers and 100 visible Library items, clearing the Library left 10,000 native records; a worst-case open required 10,000 URI lookups. This was an algorithm reproduction, not an actual Android timing or OOM measurement.

The production `DownloadRecords` helper is tested with 10,000-record pruning and a 100,000-record direct lookup, unauthorized IDs/URIs, queue preservation, restart, concurrent enqueue/cleanup, query failure, cancellation and verification-cache pruning. Dart bridge tests cover startup, delete/clear, Library overflow, persistence-before-pruning, open/share, late enqueue after disposal, failure/retry, unchanged-ID suppression and non-Android previews.

Observed results on final source:

| Check | First pass | Second pass |
|---|---|---|
| New A12 JVM tests | 13 passed, none skipped | 13 passed, none skipped |
| New A12 Dart tests, within full suite | 12 passed | 12 passed |
| Full Flutter suite | 85 passed, 6 failed | 85 passed, 6 failed |
| Full Restricted JVM suite | 34 passed, 2 failed | 33 passed, 3 failed |

- Both Flutter failure sets exactly match A3's saved baseline: A5 Home input, A6 share acknowledgement, A7 audio-only MP4 MIME, A8 literal URL punctuation, A9 accessibility and A10 theme toggle.
- Both JVM runs retain the two A4 MP4/RF64 signature failures. The second run additionally failed the live Blender smoke test with `UnknownHostException` for `download.blender.org`. A focused live retry passed. The external DNS failure is retained in the evidence, not concealed as a successful full run.
- The second full native run used Gradle's `--rerun`, so tests actually executed; XML timestamps differ.
- Python: `Ran 40 tests`, `OK`.
- `flutter analyze --no-pub lib test`: `No issues found!`.
- The first broad Flutter attempt exposed unnecessary reconciliation for an ID-less interrupted enqueue and a startup wait on cleanup. That run was interrupted, the implementation was corrected, and the existing enqueue/pipeline tests passed unchanged. The two complete final runs above were after that correction.
- SHA-256 comparison of 71 pre-existing source/test/configuration files found changes only in MainActivity, the Dart bridge and DownloadProvider. Every pre-existing test and all package declarations/lockfiles remain unchanged. No new package was added.

Commands used:

```text
flutter test --no-pub --reporter expanded
flutter analyze --no-pub lib test
python311 -m unittest discover -s test -p '*test.py' -v
android/gradlew.bat -p android :app:testRestrictedDebugUnitTest \
  -x :app:compileFlutterBuildRestrictedDebug --console=plain
# Second native pass additionally used --rerun; TURBOSAVE_LIVE_PROBE=1 in both.
```

## Files

Changed:

- [MainActivity.kt](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/kotlin/com/turbosave/videodownloader/MainActivity.kt>) — reconcile dispatch, batched status lookups, persisted unacknowledged IDs and direct owned-ID/URI checks.
- [android_download_service.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/services/android_download_service.dart>) — reconciliation method and native ID in open/share calls.
- [download_provider.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/providers/download_provider.dart>) — serialized cleanup after successful saves, startup reconciliation, unchanged-set suppression, diagnostics and ID forwarding.
- [Roadmap](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/docs/plans/2026-10-30-mobile-bug-fixing-roadmap.md>) — A12 progress; A4 remains the next unapproved repair.

Added:

- [DownloadRecords.kt](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/kotlin/com/turbosave/videodownloader/DownloadRecords.kt>).
- [DownloadRecordsTest.kt](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/test/kotlin/com/turbosave/videodownloader/DownloadRecordsTest.kt>).
- [native_records_reconciliation_test.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/test/native_records_reconciliation_test.dart>).
- This report and A12 recovery evidence.

## Evidence and Git

Local branch: `fix/a12-native-records`. The repository still has no initial commit. No partial initial commit, push, deployment or installation was made. A six-file source/test patch and before-files preserve the repair relative to A3.

- [Validated patch](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a12-records/repair.patch>) — `git apply --reverse --check` passes with the existing line endings.
- [Integrity, full failure names and two-run results](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a12-records/verification.json>).
- [Source-backed old algorithm model](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a12-records/before.json>).
- [Flutter pass 1](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a12-flutter-pass1.log>) and [pass 2](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a12-flutter-pass2.log>).
- [Native pass 1](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a12-native-1.log>), [pass 2](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a12-native-2.log>) and [live retry](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a12-native-live-retry.log>). XML snapshots are retained separately for both full runs.
- [Dart analysis](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a12-analysis.log>) and [Python suite](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a12-python.log>).

## Limits and remaining checks

Normal retained bookkeeping follows the 100-item Library and 20-item queue. Unlisted active and unacknowledged accepted native jobs are deliberately preserved; there is no hard global cap that could silently orphan recoverable work. Repeated interrupted handoffs can leave extra protected metadata until the job is acknowledged or explicitly cancelled. This repair does not add a recovery UI for such orphaned handoffs.

The status query runs on native workers with budget checks between batches/rows. Those checks do not forcibly interrupt an Android Binder call. Physical-device history size, latency, battery, storage usage, process death and actual DownloadManager file preservation still need device testing. `adb devices -l` found no connected Android devices. The file-preservation claim here is based on the metadata-only code path and bridge tests, not a phone transfer test.

No APK was built or installed. Restricted native debug tests compiled the affected Kotlin/Python integration while reusing Flutter debug build assets; this is not release-build or both-edition validation. A13's whole-folder analysis issue remains open; only maintained `lib` and `test` analysis was run.

Eight known audit findings remain. Wait for confirmation before starting another finding.
