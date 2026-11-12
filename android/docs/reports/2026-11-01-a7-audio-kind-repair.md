# A7: preserve audio kind in saved tasks and file actions

1 November 2026. Scope: A7 only. This repairs audio-only files being matched to video players/share targets; it does not claim to fix every download error or an app-process crash.

## Change

`download_provider.dart` now saves `audioOnly` in both `queue_v2` and `library_v2`, and restores that value instead of guessing solely from the extension. Records created before this field existed retain the old extension-based inference.

Open and Share use the task's media kind together with its container: audio-only MP4 uses `audio/mp4`, WebM uses `audio/webm`, and Matroska uses `audio/x-matroska`. Audio-only MOV uses the broader `audio/*` intent type. Ordinary video and the existing audio-extension MIME mappings remain unchanged. Native ID/URI ownership checking is preserved.

No files are renamed, transcoded, deleted or re-downloaded by this repair. There is no new package or native/Python source change.

## Verification

```text
Existing A7 test before the change:
Expected: audio/mp4
Actual:   video/mp4
0 passed, 1 failed

New regression tests against the old source:
10 passed, 6 failed

New regression tests after the repair:
16 passed, 0 failed

flutter test --no-pub --reporter expanded
102 passed, 5 failed

Python 3.11 unittest suite:
Ran 40 tests
OK

flutter analyze --no-pub lib test
No issues found!

Full Restricted JVM run, live probe enabled:
51 tests completed, 1 failed
50 passed; the live Blender probe hit a TLS read timeout.

Separate live-probe retry:
1 test completed, 1 failed
The same TLS read timeout occurred again.
```

The new tests cover audio-only and ordinary MP4/WebM from extraction through a saved queue, provider restart, completed Library save, another restart, and both Open and Share. They assert the media kind, native ID, exact URI and MIME. Ten legacy-record cases cover every supported extension, and two cases cover saved audio-only MOV/Matroska.

The existing A7 reproduction passes in the full Flutter run. The five remaining failures match the previous baseline after removing A7: A5 Home draft, A6 share acknowledgement retry, A8 URL punctuation, A9 accessible fetch action and A10 theme toggle. Existing tests were not edited, skipped or weakened. A13 whole-folder archive analysis remains a separate finding; only maintained `lib`/`test` analysis was run here.

Native command: `android/gradlew.bat -p android :app:testRestrictedDebugUnitTest -x :app:compileFlutterBuildRestrictedDebug --console=plain --rerun`, with the documented local environment and `TURBOSAVE_LIVE_PROBE=1`. It reuses existing Flutter debug assets. The sole failure was `PublicMediaProbeLiveTest.publicBlenderMediaPassesPinnedTlsAndContainerCheck`, with `java.net.SocketTimeoutException: Read timed out` during TLS negotiation. No deterministic native test failed. A separate retry with `--tests '*PublicMediaProbeLiveTest'` failed with the same TLS read timeout. The test, timeout and network checks were not changed. The native suite is **not fully green**; the live external check remains unverified.

## Files and evidence

- Changed [download_provider.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/providers/download_provider.dart>) and the [roadmap](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/docs/plans/2026-10-30-mobile-bug-fixing-roadmap.md>).
- Added [audio_kind_persistence_test.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/test/audio_kind_persistence_test.dart>) and this report.
- [Recovery evidence](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a7-audio>): before-source copy, original/new failing-before logs, focused results, Flutter/Python/native logs, native XML snapshots, analysis and integrity results. The repair patch contains only the source change and new test file.

SHA-256 comparison of 80 pre-existing maintained source/test/configuration files found only `download_provider.dart` changed. Existing tests, native/Python code and dependency files are unchanged.

Local branch: `fix/a7-audio-kind`. The repository still has no initial commit; no partial initial commit or broad staging was made. The repair is retained as a before-file and reviewable patch. Nothing was pushed or deployed.

## Limits and next checkpoint

An old MP4/WebM record that never saved its audio kind cannot be reliably repaired from the extension alone; it keeps the previous video inference. This change prevents that information loss for newly saved tasks. It does not inspect tracks or prove that a receiving app can decode a particular codec. Direct-link extraction still uses its existing extension-based kind inference.

No APK was built or installed. No physical-phone download, process restart, playback/share chooser, ARM32/ARM64, battery or storage measurements were performed. Provider restarts and the native bridge were exercised in automated tests with mocked platform calls; these do not establish device/release readiness. The live native-network timeout needs a successful fresh check before claiming that gate passed.

Six findings remain: A5, A6, A8, A9, A10 and A13. Stop here. A5 Home draft is next, only after the user confirms.
