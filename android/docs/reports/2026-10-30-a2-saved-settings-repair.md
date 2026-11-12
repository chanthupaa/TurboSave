# A2 repair — malformed saved settings and startup

Date: 30 October 2026. Scope: **A2 only** from [the second mobile audit](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/SECOND_MOBILE_BUG_AUDIT.md>).
Status: verified in local automated tests. A1 remains intact; other findings await separate approval.

## What changed

- [New shared preference reader](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/services/saved_preferences.dart:5>) checks raw value types before returning booleans or strings. It validates every history-list item and copies valid string lists, including broadly typed lists received from storage.
- [Startup onboarding read](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/main.dart:25>) now treats missing or invalid onboarding values as incomplete instead of throwing before runApp.
- [Provider restoration](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/providers/download_provider.dart:139>) uses the same checks for theme, Wi-Fi-only, history, website icons, recent links and queue/Library containers.
- Invalid settings use their existing defaults. A damaged queue or Library container does not hide the other valid collection. Existing per-record validation remains in place.
- Recovery diagnostics include internal preference keys only. They do not include saved values, media URLs, JSON payloads or exception messages containing those values.

The readers do not clear preferences or rewrite damaged values during a read. Valid settings and download records are retained. Existing interrupted-enqueue reconciliation still persists reconciled task state as before; that behavior was not replaced.

No package, native bridge, downloader, source policy, signing configuration or APK was changed. No existing test was modified or weakened.

## Reproduction and verification

Before the repair, the original unchanged audit test rejected provider.ready with:

```text
type 'String' is not a subtype of type 'bool?' in type cast
SharedPreferences.getBool
DownloadProvider._restoreState
```

The new startup tests also reproduced the same problem before runApp for a string at the onboarding boolean key.

Added [17 separate recovery tests](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/test/saved_settings_recovery_test.dart>):

- Valid settings, queued tasks and Library records are preserved.
- Wrong-type theme and existing unknown-theme fallback.
- Wrong-type Wi-Fi, history and website-icon flags.
- Wrong-type history containers and non-string items.
- Valid history in a broadly typed list.
- Wrong-type queue and Library containers, each retaining the valid sibling collection.
- Malformed queue JSON and wrong-shape Library JSON.
- Actual application entry point with missing, false, true and invalid onboarding preferences.

The provider cases compare the original preference values after recovery and verify valid task IDs/content URIs. These are in-memory storage/channel tests; they do not establish physical device storage recovery.

Final results:

```powershell
flutter test --no-pub test/saved_settings_recovery_test.dart --reporter expanded
# 00:04 +17: All tests passed!

flutter test --no-pub --reporter expanded
# 00:20 +70 -6: Some tests failed.

flutter analyze --no-pub lib test
# No issues found! (ran in 17.4s)
```

The six full-suite failures match the A1 baseline after removing A2. No previously passing test failed:

- A5 — Home input lost across tabs.
- A6 — share acknowledgement retry.
- A7 — audio-only MP4 MIME.
- A8 — literal URL punctuation.
- A9 — unnamed accessible fetch action.
- A10 — System/light theme toggle.

The full suite remains red for those known findings. Native/Python audit failures and the A13 whole-folder archive-analysis issue were not repaired or rerun.

The full Flutter run preceded removal of one redundant import from the new test file. After that cosmetic change, all 17 new tests and maintained-source analysis were rerun successfully. No application logic changed after the full run.

## Files and integrity

Modified existing application files:

- [main.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/main.dart>).
- [download_provider.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/providers/download_provider.dart>).

Added application/test files:

- [saved_preferences.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/services/saved_preferences.dart>).
- [saved_settings_recovery_test.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/test/saved_settings_recovery_test.dart>).

Also added this report and verification evidence, and updated [the roadmap](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/docs/plans/2026-10-30-mobile-bug-fixing-roadmap.md>).

SHA-256 comparison of **62 pre-existing source/test/configuration files** found only main.dart and download_provider.dart changed. Existing test files, including A1's cancellation tests, dependency declarations/lockfile, native code and policy files retain their prior hashes.

## Git and evidence

Work is on the local branch `fix/a2-saved-settings`. The repository still has no initial commit and the pre-existing app source is untracked. No partial initial commit or push was made.

A2 is preserved relative to the already-repaired A1 state:

- [Main before A2](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a2-saved-settings/main.before.dart>).
- [Provider before A2, including A1](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a2-saved-settings/download_provider.before.dart>).
- [A2 source/test patch](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a2-saved-settings/repair.patch>), validated with `git apply --reverse --check`.
- [Source integrity and failure-name comparison](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a2-saved-settings/verification.json>).

Logs:

- [Original A2 reproduction before repair](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a2-before.log>).
- [17 recovery tests after repair](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a2-new-tests-after.log>).
- [Full Flutter results](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a2-full-flutter.log>).
- [Maintained-source analysis](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a2-analysis.log>).

## Not verified

No physical Android phone, corrupt Android preference file, failed storage backend, process termination, battery/storage benchmark or release installation was tested. This repair handles malformed values returned by an available SharedPreferences store; it does not claim to recover a native preferences backend that cannot load at all. No APK was built or installed.

**Next:** A11 network resource limits, only after user confirmation. Its code-review risk must be reproduced before a repair is claimed.

