# Remaining mobile audit findings: A6, A8, A9, A10 and A13

1 November 2026. The user's latest instruction, “just fix all”, authorizes finishing the five remaining findings together and supersedes the earlier one-finding confirmation checkpoints. Existing tests and dependencies are preserved.

## Repairs

| ID | Change | Verification |
|---|---|---|
| A6 | Track handled shares awaiting native acknowledgement separately from duplicate suppression. Retry only acknowledgement when the native inbox redelivers a pending ID on resume; serialize attempts, stop after success/disposal, and log failures. Pending bookkeeping follows the existing 32-ID bound. | Repeated failures, ordered processing, duplicate delivery during handling, overlapping resume requests, missing-plugin errors, disposal and invalid-link acknowledgement. |
| A8 | Validate a standalone HTTPS URL and return its original trimmed text, preserving meaningful trailing punctuation and brackets. Keep the existing prose-wrapper heuristic. | Path/query punctuation, encoded delimiters, balanced/unmatched brackets, wrappers, multiple links, length and source/network-policy rejection. |
| A9 | Give both the fetch arrow and loading indicator the same single accessible name, “Fetch video details”; expose “Loading” while busy. Preserve the existing disabled button and Material keyboard behavior. | Active/loading/completed semantics, disabled state, keyboard traversal and Enter activation. |
| A10 | Resolve System against platform brightness before choosing the opposite explicit theme. Retain the Settings System option and saved theme preference. | All three modes under both system appearances, visible app theme, repeated toggles and preference writes. |
| A13 | Exclude only `_private-backups/cleanup-20261009-013903/**` from active Dart analysis. Keep maintained source/tests included and preserve the backup files. | Whole-folder analysis goes from 35 archive diagnostics to no issues; all 99 archived files retain their hashes. |

Only four pre-existing source/configuration files changed: `shared_link_service.dart`, `download_provider.dart`, `downloader_screen.dart` and `analysis_options.yaml`. Two new test files add 38 regression cases. No existing test was edited, removed, skipped or weakened. No runtime package, native/Python source, policy list or dependency declaration changed.

## Test results

```text
Existing second-audit reproductions before:
5 passed, 4 failed

New tests before:
15 passed, 23 failed

Focused repaired audit/new tests:
47 passed, 0 failed

Full Restricted Flutter suite:
153 passed, 0 failed

Open edition: source-policy and new sharing/theme/accessibility checks:
40 passed, 0 failed

Full Restricted native JVM suite:
51 tests, 0 failures, 0 skipped
BUILD SUCCESSFUL

Python 3.11 unittest suite:
Ran 40 tests
OK

Whole-folder flutter analyze --no-pub:
No issues found!
```

The full Flutter suite includes all previous lifecycle, persistence, media/signature bridge, draft and sharing regressions. The native run includes the real pinned Blender HTTPS/container-prefix probe; its earlier A7 TLS timeouts did not recur in this fresh run. This is one successful live check, not a reliability guarantee for every provider or network.

Commands were run from the mobile repository:

```powershell
flutter test --no-pub --flavor restricted --reporter expanded
flutter test --no-pub --flavor unrestricted --dart-define=EXPECT_OPEN=true test/flavor_policy_test.dart test/variant_release_test.dart test/shared_link_recovery_test.dart test/theme_and_fetch_accessibility_test.dart --reporter expanded
flutter analyze --no-pub
```

Python uses the existing local Python 3.11 toolchain: `python.exe -m unittest discover -s test -p '*test.py' -v`. The native command uses the documented Java/Android/Python environment and `TURBOSAVE_LIVE_PROBE=1`: `android/gradlew.bat -p android :app:testRestrictedDebugUnitTest -x :app:compileFlutterBuildRestrictedDebug --console=plain --rerun`. It runs the native tests again but reuses existing Flutter debug assets; it is not a fresh APK build.

## Files and evidence

- [shared_link_service.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/services/shared_link_service.dart>) — A6/A8.
- [download_provider.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/providers/download_provider.dart>) — A10.
- [downloader_screen.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/screens/downloader_screen.dart>) — A9.
- [analysis_options.yaml](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/analysis_options.yaml>) — A13.
- Added [shared_link_recovery_test.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/test/shared_link_recovery_test.dart>) and [theme_and_fetch_accessibility_test.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/test/theme_and_fetch_accessibility_test.dart>).
- Updated the roadmap, root repair report and release-readiness notes to distinguish current source verification from historical APK evidence.
- [Integrity evidence and six-file source/test patch](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/remaining-audit>), including before-files, native XML, hashes, verification JSON and reverse patch validation.
- Logs under `_recovery/`: `remaining-before-flutter.log`, `remaining-new-before.log`, `remaining-focused.log`, `remaining-before-analysis.log`, `remaining-flutter-full.log`, `remaining-open-policy.log`, `remaining-analysis-full.log`, `remaining-native-full.log` and `remaining-python-full.log`.

SHA-256 comparison covers all 82 pre-existing maintained source/test/configuration files and all 99 archived files. Only the four intended source/configuration files changed. Local branch: `fix/remaining-mobile-audit`. The repository still has no initial commit; no partial initial commit, broad staging, push, deployment or installation was made. Before-files and a validated patch preserve these repairs.

## Remaining gates and limits

All 13 recorded second-audit findings are addressed in source with automated coverage. This does not prove the app has no undiscovered bugs.

No new release APK/AAB was built, signed or installed in this batch. Historical APKs do not include these latest source fixes. Physical ARM32/ARM64 navigation, TalkBack, real keyboard/share intents, update installation, process death, background completion, battery/storage measurements and soak testing remain release gates.

Share duplicate suppression and pending acknowledgement bookkeeping are process-local and bounded. A process killed before a failed acknowledgement succeeds can receive the native pending share again after restart; this repair does not claim durable exactly-once delivery. Prose punctuation remains inherently ambiguous; standalone URL text is preserved. DownloadManager's later DNS/redirect behavior and unknown-codec/container-prefix limitations documented in earlier repairs remain unchanged.
