# A1 repair — cancellation/completion race

Date: 30 October 2026. Scope: **A1 only** from [the second mobile audit](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/SECOND_MOBILE_BUG_AUDIT.md>).
Status: repaired and verified in local automated tests. Other findings await separate approval.

## What changed

In [DownloadProvider](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/providers/download_provider.dart:39>), cancellation now has a per-task in-flight guard.

- Polling omits tasks being cancelled and ignores late snapshots for those tasks.
- Successful cancellation removes and persists the task without allowing a late completion to add it to Library.
- Failed cancellation clears the guard and resumes normal polling so the existing job can still complete.
- Repeated Cancel requests do not send duplicate native cancellations.
- Retry cannot enqueue a replacement while cancellation is pending. A Retry already checking a page rechecks cancellation after the lookup; Cancel remains usable during that lookup.
- Other downloads continue to reach Library while one cancellation waits.

No Kotlin, Python, channel contract, dependencies, Android policy or APK was changed. No existing test was edited or weakened.

## Evidence

The original unmodified reproduction failed before the repair:

```text
Expected: empty
Actual: [Instance of 'DownloadTask']
Native cancel removed the file; it must not remain marked Saved.
```

It now passes in the full suite.

Added [eight separate cancellation tests](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/test/cancellation_race_test.dart>) covering:

1. Cancellation finishing before a stale completion response.
2. A completion response arriving during cancellation, including persisted-state restoration.
3. Cancellation failure followed by successful normal completion.
4. Duplicate Cancel requests.
5. Another download reaching Library while cancellation waits.
6. Completion winning before Cancel, without deleting that saved file.
7. Retry attempted during cancellation.
8. Cancel during an already-running Retry source lookup, without an orphan replacement.

Final commands and results:

```powershell
flutter test --no-pub test/cancellation_race_test.dart --reporter expanded
# 00:01 +8: All tests passed!

flutter test --no-pub --reporter expanded
# 00:21 +52 -7: Some tests failed.

flutter analyze --no-pub lib test
# No issues found! (ran in 27.6s)
```

The full suite is **not globally green**. Its seven remaining failures exactly match the previous audit baseline after removing A1:

- A2 — malformed setting prevents initialization.
- A5 — Home loses the typed link across tabs.
- A6 — failed share acknowledgement is not retried.
- A7 — audio-only MP4 gets a video MIME type.
- A8 — literal shared URL punctuation changes.
- A9 — primary fetch action has no accessible name.
- A10 — System/light theme does not toggle on the first tap.

No new failure names appeared, and all previously passing tests still pass. The earlier native/Python audit failures remain untouched; those suites were not rerun because this repair changes only Dart download state.

## Files and integrity

Changed existing files:

- [download_provider.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/providers/download_provider.dart>) — cancellation ownership and Retry coordination.
- [roadmap](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/docs/plans/2026-10-30-mobile-bug-fixing-roadmap.md>) — A1 progress and next approval checkpoint.

Added:

- [cancellation_race_test.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/test/cancellation_race_test.dart>).
- This report.
- Before-file, patch, integrity evidence and verification logs under _recovery.

SHA-256 comparison of **61 pre-existing source/test/configuration files** found only download_provider.dart changed. All existing test files, policy files and dependency declarations/lockfile retain their original hashes.

## Local Git deviation

The repository has no initial commit and its application files were already untracked. Work is on the local branch `fix/a1-cancellation-race`.

A partial root commit containing only the provider would not establish a useful buildable baseline. No commit or push was made. Instead:

- [Original provider before A1](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a1-cancellation/download_provider.before.dart>).
- [Reviewable provider patch](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a1-cancellation/provider.patch>), validated with `git apply --reverse --check` against the repaired file.
- [Integrity and failure-name comparison](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a1-cancellation/verification.json>).

The roadmap's usual per-finding commit step remains pending a proper initial repository baseline. This does not block reviewing/testing the A1 repair; no unrelated files were staged.

## Logs

- [Original A1 reproduction before repair](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a1-before.log>).
- [Eight cancellation tests after repair](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a1-new-tests-after.log>).
- [Final full Flutter run](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a1-full-flutter.log>).
- [Final maintained-source analysis](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a1-analysis.log>).

## Not verified

Physical Android timing, real DownloadManager cancellation, process termination, battery/storage behavior and installation were not tested. Native calls and completion responses in these tests are mocked. No new APK was built or installed. Whole-folder analysis still has the separate A13 archive issue.

**Next:** A2 only after the user confirms. No other audit finding was repaired in this session.

