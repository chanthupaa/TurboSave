# TurboSave Mobile Bug-Fixing Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use the executing-plans skill to implement this plan task-by-task.

**Goal:** Repair the 10 reproduced bugs, investigate and resolve the two code-review risks, restore useful repository checks, and validate both Android editions before release.

**Architecture:** Keep the local Flutter → Kotlin → yt-dlp/Python architecture and Android DownloadManager. Fix each root cause where its state is owned; preserve existing security checks and existing tests. Work on one finding per session and use one independently reviewable local commit per completed finding.

**Tech Stack:** Flutter/Dart, SharedPreferences, Kotlin, Android DownloadManager, Chaquopy/Python, yt-dlp, Flutter tests, JUnit 4 and Python unittest. No new package is planned.

Plan created: 30 October 2026. Execution update (1 November 2026): all 13 recorded findings are addressed in source and automated checks. The latest user instruction, “just fix all”, authorized completing A6, A8, A9, A10 and A13 together and superseded their individual confirmation checkpoints. Platform/device and fresh-release-build gates remain open.

Audit: [second audit with reproductions and evidence](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/SECOND_MOBILE_BUG_AUDIT.md>).
Repository: `C:\Users\HP OFFICIAL\Desktop\app\TurboSave\MOBILE APP`.

---

## Ground rules

- Pause new features and visual redesigns until the functional fixes pass.
- Original workflow: one audit ID per session. On 1 November the user authorized all five remaining findings together; their scope and evidence remain identified separately.
- Never delete, skip, weaken or change an existing test to make it pass. Add separate coverage where needed. If a test appears wrong, stop and explain the conflict.
- Ask before adding a package. Do not replace DownloadManager or change Restricted/Open policy as a shortcut.
- Preserve physical downloads, queue records, signing identity, private keys and recovery backups.
- Before each repair, search the affected function's callers and inspect the current working tree. Stage only that repair's files; never use a broad add of the entire folder. No GitHub push or installation is part of this roadmap request.
- Record failing test names, command output, files changed and unverified behavior for each session. Finish with one local commit after the checks below.
- Keep the old audit as evidence. Record resolutions in this plan or a separate repair log rather than rewriting what was originally found.

## Baseline and how progress is judged

These are the **saved audit results**, inspected while planning, not new test runs:

| Check | Current baseline |
|---|---|
| Flutter | 43 passed, 8 failed |
| Native JVM | 13 passed, 2 failed, 1 opt-in network test skipped |
| Python | 6 passed, 1 failed |
| Analysis of maintained lib/test | Clean |
| Whole-folder analysis | 35 errors in historical backup code |

A full-suite exit code of 1 is currently expected. After a single repair, the intended failing case must pass and no previously passing case may fail. Identify the remaining failures individually; do not accept any red run merely because its total failure count looks familiar. Added tests can change totals.

The **final gate requires zero unexplained failures**, not an exception for the current audit failures. A single finding can be committed before other findings are repaired only when the remaining failures match the documented baseline and belong to other findings.

## Repair order

| Stage | Separate sessions, in order | Exit condition |
|---|---|---|
| 1. Lifecycle and startup | A1, A2 | Cancellation cannot leave false Saved records; bad settings cannot block startup |
| 2. Network resource safety | A11 | Measured request deadlines/body limits and recovery work without weakening public-network checks |
| 3. Media correctness | A3, A4, A7 | Valid supported media survives checking and opens/shares with the right media type |
| 4. Input, sharing and accessibility | A5, A6, A8, A9, A10 | Inputs survive navigation, shares are reliable, actions are named and theme switching works |
| 5. Long-term state and tooling | A12, A13 | Native bookkeeping is reconciled; normal repository analysis works |
| 6. Release validation | Device checks, builds, measured soak | Both editions pass the release checklist; remaining limits are documented |

A11 and A12 started as code-review risks. Write deterministic reproductions before claiming either is fixed or a confirmed device crash. This is an order of work, not a promised number of days.

## Standard steps for every finding

1. Re-read that audit section and inspect every caller/state owner listed in the task.
2. Run the focused reproduction and save its output. If no reproduction exists, add a small deterministic one first.
3. Make the smallest repair for that ID only. Preserve error handling, source validation and persisted user data.
4. Rerun the focused check, the full Flutter suite, maintained-source analysis, and the affected native/Python suite.
5. Compare the named failures against the baseline. Stop on new regressions; do not change unrelated code to force the run green.
6. Review the diff, record verification and limits, then commit only the repair. Mark its checklist item complete only when the acceptance criteria are met.

## Stage 1 — lifecycle and startup

### Session 1: A1 — cancellation/completion race

**Files:** [lib/providers/download_provider.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/providers/download_provider.dart>); [Dart audit tests](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/test/second_audit_test.dart>).
**Callers to check:** polling/completion, cancelTask, retryTask, persisted queue/Library, Activity cancel action.

- Run the existing cancellation race reproduction.
- Track cancellation while its native call is pending so a delayed completion snapshot cannot leave a Saved record for a removed file. Handle cancellation errors without discarding a valid transfer.
- Add separate tests for reversed timing, cancel failure and duplicate cancel; retain the existing reproduction unchanged.
- Verify that cancellation is isolated to its own task and persisted state is consistent.

**Done:** the deleted file is absent from Activity and Library after successful cancellation, including after state restoration; other downloads still finish.
**Focused command:** `flutter test --no-pub test/second_audit_test.dart --plain-name "cancelling during a completion query must not leave the deleted file in Library"`.
**Commit:** `fix: reconcile cancellation with completion snapshots`.

**Completed 30 October 2026:** original reproduction and eight new cancellation tests pass. Full Flutter: 52 passed, seven unchanged failures belonging to other audit IDs. Maintained-source analysis is clean. [Repair report](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/docs/reports/2026-10-30-a1-cancellation-repair.md>).

**Git deviation:** the repository has no initial commit and the existing source is untracked. A1 is preserved as a before-file and validated patch on `fix/a1-cancellation-race`; no partial initial commit or push was made. A proper initial baseline is needed for the normal per-finding commit workflow. Physical-device verification remains pending.

### Session 2: A2 — malformed settings

**Files:** [lib/providers/download_provider.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/providers/download_provider.dart>), [lib/main.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/main.dart>); [Dart audit tests](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/test/second_audit_test.dart>); add a startup test if needed.

- Reproduce wrong-type wifi_only and onboarding settings.
- Check raw preference types before typed reads, use existing defaults for only the invalid setting, and log/report recoverable state errors.
- Cover wrong types for theme, booleans and history/queue preference containers. Retain valid sibling records and files; do not reset all preferences.
- Verify first-run onboarding and returning-user startup still work.

**Done:** provider.ready completes and startup renders with safe defaults; valid downloads/settings are preserved.
**Focused command:** `flutter test --no-pub test/second_audit_test.dart --plain-name "one malformed saved setting should not prevent download initialization"`.
**Commit:** `fix: recover safely from malformed saved settings`.

**Completed 30 October 2026:** the original A2 reproduction and 17 new recovery tests pass, including actual startup/onboarding, wrong-type settings, valid history and retained queue/Library records. Full Flutter: 70 passed, six unchanged failures belonging to other IDs. Maintained-source analysis is clean. Added a shared saved-preference reader and separate tests; existing tests are unchanged. [Repair report](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/docs/reports/2026-10-30-a2-saved-settings-repair.md>).

**Git/device status:** as with A1, no partial initial commit was made in the unborn repository. A validated source/test patch and before-files are preserved on `fix/a2-saved-settings`. Phone/storage-backend verification and APK builds remain pending.

## Stage 2 — bounded network work

### Session 3: A11 — prove and bound resource use

**Files:** [android/app/src/main/kotlin/com/turbosave/videodownloader/PublicMediaProbe.kt](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/kotlin/com/turbosave/videodownloader/PublicMediaProbe.kt>), [android/app/src/main/kotlin/com/turbosave/videodownloader/MainActivity.kt](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/kotlin/com/turbosave/videodownloader/MainActivity.kt>), [android/app/src/main/python/media_extractor.py](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/python/media_extractor.py>); [android/app/src/test/kotlin/com/turbosave/videodownloader/PublicMediaProbeTest.kt](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/test/kotlin/com/turbosave/videodownloader/PublicMediaProbeTest.kt>); new isolated Python resource tests if needed.

- First reproduce slow continuous reads, oversized metadata and repeated validation using fake clocks/streams or a controlled test transport. Avoid flaky tests that wait for real minute-long timeouts.
- Enforce an overall operation budget, including body reads, redirects, address attempts and format validation. Use the existing 65-second extraction target as the initial deadline; explicitly record the native operation limit.
- Add a bounded metadata-body limit. Choose and document its value after measuring representative fixtures; do not cap actual video downloads at that metadata limit.
- Confirm an error releases workers/resources and allows the next valid operation. A Dart timeout that leaves the native/Python work running is insufficient.
- Preserve DNS checks, pinned TLS/hostname validation and existing parser limits. If the installed yt-dlp integration cannot be bounded without a dependency or architecture change, report that specific blocker rather than silently changing architecture.

**Done:** controlled slow/large responses terminate within their defined budgets, workers become reusable, normal media works, and existing policy tests pass.
**Checks:** full native JVM and Python suites plus Flutter lifecycle tests.
**Commit:** `fix: bound media inspection resource use`.

**Completed 30 October 2026:** the risk was reproduced with controlled extraction tests. Added a shared native/Python time budget, socket deadlines, bounded DNS helpers and metadata read/decompression limits. All 28 new resource tests pass (7 JVM, 21 Python); real native HTTPS and installed yt-dlp transport checks pass. Full suites: Flutter 70 passed/6 unchanged failures, JVM 21 passed/2 A4 failures, Python 27 passed/1 A3 failure. Dart analysis is clean. [Repair report and limits](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/docs/reports/2026-10-30-a11-network-resource-repair.md>).

**Limits/Git:** OS DNS calls and arbitrary CPU-bound parser work cannot be forcibly terminated; lookup capacity is bounded and I/O is closed on expiry. No device battery/RAM proof or release APK was produced. With the repository still unborn, a validated source/test patch is preserved on `fix/a11-network-budgets`; no partial initial commit or push was made.

## Stage 3 — media correctness

### Session 4: A3 — missing codec metadata

**Files:** [android/app/src/main/python/media_extractor.py](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/python/media_extractor.py>); [test/second_extractor_audit_test.py](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/test/second_extractor_audit_test.py>); [test/extractor_policy_test.py](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/test/extractor_policy_test.py>) remains unchanged.

- Reproduce the GenericIE HTML5 format shape from the audit.
- Distinguish unknown codecs from explicitly absent tracks. Establish a safe way to identify supported complete files using the existing extractor/probe pipeline.
- Keep explicit video-only tracks, DRM, restricted sources, credentials and private-network URLs rejected. Unknown metadata alone must not become permission to return every stream.
- Add positive complete-file and negative separate-stream/malformed cases. Ask before any new media-parsing package.

**Done:** the known complete HTML5 fixture is accepted; established policy and complete-file tests still pass.
**Focused command:** `python -m unittest discover -s test -p 'second_extractor_audit_test.py' -v`.
**Commit:** `fix: handle unknown codec metadata for complete media`.

**Completed 30 October 2026:** the original HTML5 reproduction and 12 new Python regression tests pass. Ordinary standalone MP4/WebM/MOV/MKV files with both codecs unreported are retained and labelled **Sound unverified**; explicit silent tracks and uncertain manifest/fragment streams stay rejected. Known complete formats take priority over uncertain duplicates. Full Python: 40 passed. Full Flutter: 73 passed, the same six failures belonging to other IDs. Maintained-source analysis is clean. Installed yt-dlp HTML5/transport checks pass, and a host-side live probe confirms video and audio in the Blender fixture. This fallback does not prove sound in every unknown file. Existing tests and dependencies are unchanged. [Repair report and limits](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/docs/reports/2026-10-30-a3-codec-metadata-repair.md>).

### Session 5: A4 — signature false negatives

**Files:** [android/app/src/main/kotlin/com/turbosave/videodownloader/MediaSignatures.kt](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/kotlin/com/turbosave/videodownloader/MediaSignatures.kt>); [native media audit tests](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/test/kotlin/com/turbosave/videodownloader/SecondMediaAuditTest.kt>); generated fixtures in [audit media fixtures](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/second-audit-media>).

- Keep both failing reproductions.
- Parse permitted leading MP4 boxes within explicit byte/box-count limits; recognise RF64/WAVE structurally.
- Add tests for truncated/oversized boxes and disguised HTML/JSON. Preserve existing rejection tests.
- Recheck the independently generated fixtures with FFprobe/FFmpeg.

**Done:** both valid layouts pass; malformed inputs stay rejected; no unbounded scan/read is introduced.
**Focused check:** native `SecondMediaAuditTest`; then the full native suite.
**Commit:** `fix: recognise valid padded MP4 and RF64 containers`.

**Completed locally 30 October 2026:** both original failure tests now pass unchanged. Added a bounded MP4 box walk (512 bytes, at most 16 boxes) and RF64/WAVE prefix recognition. The independently generated MP4 and RF64 fixtures pass the actual reader and decode successfully with host FFmpeg. All 15 new bounds/fixture/fuzz tests pass, including 20,000 random/mutated header checks with no exceptions/timeouts. Full JVM: 51 passed, none skipped, including the live preflight probe. Full Flutter: 85 passed, six unchanged failures for other IDs. Python: 40 passed. Maintained-source analysis is clean. Only MediaSignatures.kt changed in the existing production code; existing tests and dependencies are unchanged. No APK or physical-device test, and the user's specific failing URL was not supplied. [Repair report and limits](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/docs/reports/2026-10-30-a4-media-signatures-repair.md>).

### Session 6: A7 — preserve media kind

**Files:** [lib/providers/download_provider.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/providers/download_provider.dart>), [lib/models/format_option.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/models/format_option.dart>) if necessary; [Dart audit tests](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/test/second_audit_test.dart>).
**Callers:** task serialization/restoration, openFile, share action, native MIME validation.

- Persist the audio-only flag and keep backward-compatible inference for records that lack it.
- Choose open/share MIME using both container and media kind; do not rename files or transcode.
- Add new tests for audio-only MP4/WebM after restart and ordinary video, alongside the existing open-file reproduction.

**Done:** audio-only media stays audio in Library after restoration and is opened/shared with a compatible audio MIME; old records remain readable.
**Focused command:** `flutter test --no-pub test/second_audit_test.dart --plain-name "audio-only MP4 should open with an audio MIME type"`.
**Commit:** `fix: preserve audio kind across saved tasks and file actions`.

**Completed locally 1 November 2026:** saved queue and Library records now preserve the audio-only flag, and Open/Share select MIME using kind and container. Old records retain extension inference. The existing A7 reproduction and all 16 new persistence/action tests pass; existing tests/dependencies are unchanged. Full Flutter: 102 passed, five unchanged failures belonging to other IDs. Python: 40 passed. Maintained-source analysis is clean. The full JVM run passed 50 tests with one live-network TLS timeout; a separate retry also timed out, so the external native check remains unverified and the native suite is not fully green. See the [repair report and evidence](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/docs/reports/2026-11-01-a7-audio-kind-repair.md>). No APK build/installation or device playback/share test. The unborn Git repository still uses a before-file and validated patch rather than a partial initial commit.

## Stage 4 — reliable interaction

### Session 7: A5 — preserve Home input

**Files:** [lib/screens/main_navigation_screen.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/screens/main_navigation_screen.dart>), [lib/screens/downloader_screen.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/screens/downloader_screen.dart>); [Dart audit tests](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/test/second_audit_test.dart>).

- Keep the draft URL in the existing navigation/state owner and restore it when Home remounts.
- Avoid retaining every hidden screen solely to preserve one text field; keep the existing hidden-tab efficiency.
- Test manual URL → tab change → Home, and shared URL → edited URL → tab change → Home. Preserve the passing second-fast-share test.

**Done:** typed text returns unchanged and old shared text cannot overwrite the user's later edit.
**Focused command:** `flutter test --no-pub test/second_audit_test.dart --plain-name "Home should preserve the typed link across tab changes"`.
**Commit:** `fix: preserve the Home link draft across tabs`.

**Completed locally 1 November 2026:** the navigation screen owns the draft string; Home restores/reports it while hidden screens still unmount. Typing, paste, sample/recent links, edited/cleared shared links and new shares use that same draft. The original A5 reproduction and all eight new regression tests pass, including phone/wide navigation and repeated shares. Full Flutter: 111 passed, four unchanged failures for other IDs. Maintained-source analysis is clean; existing tests and dependencies are unchanged. No disk persistence, native/Python change, APK build/installation or physical-device verification. Before-files and a validated patch preserve this repair in the unborn repository. [Repair report and verification limits](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/docs/reports/2026-11-01-a5-home-draft-repair.md>).

### Session 8: A6 — retry acknowledgements

**Files:** [lib/services/shared_link_service.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/services/shared_link_service.dart>); [Dart audit tests](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/test/second_audit_test.dart>); native inbox contract in [android/app/src/main/kotlin/com/turbosave/videodownloader/MainActivity.kt](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/kotlin/com/turbosave/videodownloader/MainActivity.kt>).

- Separate already-handled links from acknowledgements still waiting to succeed.
- Retry only the acknowledgement on resume; do not refetch/reopen the same share.
- Add repeated-failure and disposal cases while preserving queue order and bounded bookkeeping.

**Done:** the existing test observes two acknowledgement attempts and one link handling; successful acknowledgement removes native pending state.
**Focused command:** `flutter test --no-pub test/second_audit_test.dart --plain-name "failed native share acknowledgement must be retried on resume"`.
**Commit:** `fix: retry failed share acknowledgements without replay`.

**Completed locally 1 November 2026:** separate bounded pending-acknowledgement state retries failed native acknowledgement without handling the link again. Attempts serialize and stop after success/disposal; errors are logged. Original reproduction and new repeated-failure, ordering, duplicate, missing-plugin and disposal cases pass. Durable exactly-once delivery across process death is not claimed. See the [combined repair report](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/docs/reports/2026-11-01-remaining-audit-repairs.md>).

### Session 9: A8 — preserve literal URLs

**Files:** [lib/services/shared_link_service.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/services/shared_link_service.dart>); [Dart audit tests](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/test/second_audit_test.dart>); existing share/policy tests.

- Preserve meaningful punctuation in a literal URL. Define surrounding-prose handling explicitly rather than stripping every matching final character.
- Add tests for query/path punctuation, balanced parentheses, prose wrappers and multiple URLs.
- Keep HTTPS, length, source-policy and public-destination restrictions.

**Done:** the existing hello! URL survives exactly; malformed/multi-link shares remain rejected; existing share tests are unchanged.
**Focused command:** `flutter test --no-pub test/second_audit_test.dart --plain-name "sharing a literal URL must preserve its trailing query punctuation"`.
**Commit:** `fix: preserve meaningful punctuation in shared URLs`.

**Completed locally 1 November 2026:** standalone HTTPS URLs retain their exact trimmed text after policy validation. Path/query punctuation and brackets survive; existing wrapper handling and source/network restrictions remain in place. Original reproduction and new parser cases pass. Prose punctuation remains heuristic; see the combined repair report.

### Session 10: A9 — name the primary action

**Files:** [lib/screens/downloader_screen.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/screens/downloader_screen.dart>); [Dart audit tests](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/test/second_audit_test.dart>).

- Add one clear accessible action name, such as “Fetch video details”, using existing Flutter semantics/tooltip APIs.
- Cover loading/disabled behavior and avoid duplicate spoken labels.
- Check keyboard focus and TalkBack on a phone during the device stage.

**Done:** the existing semantics test passes and the action remains identifiable while loading.
**Focused command:** `flutter test --no-pub test/second_audit_test.dart --plain-name "primary fetch button should have a screen-reader label"`.
**Commit:** `fix: label the primary fetch action for accessibility`.

**Completed locally 1 November 2026:** fetch arrow/loading states expose one accessible name and preserve disabled/keyboard behavior. Original semantics reproduction plus loading-state and keyboard activation checks pass. Physical TalkBack verification remains pending.

### Session 11: A10 — toggle the visible theme

**Files:** [lib/providers/download_provider.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/providers/download_provider.dart>), [lib/screens/downloader_screen.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/screens/downloader_screen.dart>) if needed for current brightness; [Dart audit tests](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/test/second_audit_test.dart>).

- Resolve System against current platform brightness before selecting the opposite theme.
- Keep Settings' System option and preference persistence.
- Add System/dark and explicit light/dark cases without changing the existing System/light test.

**Done:** the first tap visibly changes either System appearance and explicit modes keep toggling correctly.
**Focused command:** `flutter test --no-pub test/second_audit_test.dart --plain-name "theme toggle should switch from system-light to dark on the first tap"`.
**Commit:** `fix: toggle from the resolved system appearance`.

**Completed locally 1 November 2026:** toggling resolves System against current platform brightness. All three modes under both system appearances visibly switch, persist and retain the System setting. Original reproduction and six new appearance cases pass.

## Stage 5 — long-term state and useful tooling

### Session 12: A12 — bounded native bookkeeping

**Files:** [android/app/src/main/kotlin/com/turbosave/videodownloader/MainActivity.kt](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/kotlin/com/turbosave/videodownloader/MainActivity.kt>), [lib/services/android_download_service.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/services/android_download_service.dart>), [lib/providers/download_provider.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/providers/download_provider.dart>); new focused native tests and Dart bridge tests if needed.

- First reproduce bookkeeping growth and count DownloadManager lookups for opening a retained file.
- Pass/verify the known task ID with its content URI instead of scanning every historical transfer. A supplied ID alone must not establish ownership.
- Reconcile metadata for removed/pruned Library records while retaining active and recoverable tasks. Preserve physical files and source validation.
- Add tests for prune/clear, restart, unauthorized IDs/URIs and a large synthetic history. Do not delete Downloads as a cleanup mechanism.

**Done:** opening a retained file uses a bounded number of native queries; old metadata is reconciled without orphaning live work or deleting files.
**Checks:** full native suite, bridge/persistence tests, then a measured device history scenario.
**Commit:** `fix: reconcile native ownership metadata and avoid history scans`.

**Completed locally 30 October 2026:** reproduced the old growth/scan algorithms with a source-checked synthetic model, then added ownership reconciliation after durable Dart saves and on startup. Removed Library metadata and cached verification are pruned without deleting physical files. Active and unacknowledged accepted jobs are preserved, including across native-state restart. Open/share validate the supplied owned ID and its exact Android URI instead of scanning history. All 13 new JVM and 12 new Dart checks passed twice. Both final Flutter runs: 85 passed, the same six existing failures. JVM runs: 34 passed/2 A4 failures, then 33 passed/2 A4 failures plus an external DNS failure; the live probe passed on retry. Python 40 passed; maintained-source analysis clean. Existing tests/dependencies unchanged. No connected Android device, APK build or installation; the physical-device history/performance gate remains pending. [Repair report and limits](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/docs/reports/2026-10-30-a12-native-records-repair.md>).

### Session 13: A13 — whole-folder analysis

**Files:** [analysis_options.yaml](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/analysis_options.yaml>) only, unless inspection identifies a different archive boundary.

- Reproduce the 35 diagnostics and confirm all originate in the historical private backup.
- Exclude only the archived backup path. Do not exclude maintained app code or tests; do not delete the backup.
- Run whole-folder analysis and the full Flutter suite.

**Done:** `flutter analyze --no-pub` succeeds, and maintained-source checks/test discovery remain intact.
**Commit:** `chore: exclude historical backups from active analysis`.

**Completed locally 1 November 2026:** all 35 reproduced diagnostics originated in `_private-backups/cleanup-20261009-013903/`. Only that archive is newly excluded. Whole-folder analysis now passes; all 99 archived files and all existing tests are unchanged. Full Flutter: 153 passed. Native JVM: 51 passed, none skipped, including the live probe. Python: 40 passed. Open-edition policy/new regressions: 40 passed. No new APK build or physical-device verification. See the combined repair report.

## Common verification commands

Run from the repository directory shown above. Capture output and exit status per command; do not chain a failure into an apparent success.

```powershell
flutter test --no-pub --reporter expanded
flutter analyze --no-pub lib test
python -m unittest discover -s test -p '*test.py' -v
```

For native checks, use the already configured local tools; these assignments contain no secret values:

```powershell
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:GRADLE_USER_HOME = Join-Path $env:USERPROFILE '.gradle'
$env:JAVA_TOOL_OPTIONS = '-Djdk.net.unixdomain.tmpdir=C:\gradle-uds -Djava.net.preferIPv4Stack=true -Djava.net.preferIPv6Addresses=false'
$env:ANDROID_HOME = Join-Path $env:LOCALAPPDATA 'TurboSaveBuildTools\android-sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:TURBOSAVE_BUILD_PYTHON = Join-Path $env:LOCALAPPDATA 'TurboSaveBuildTools\python311\python.exe'
& '.\android\gradlew.bat' -p android :app:testRestrictedDebugUnitTest --console=plain
```

The full task may rebuild Flutter debug assets. The prior audit used `-x :app:compileFlutterBuildRestrictedDebug` to reuse already-built Flutter debug assets. Use that shortcut only when appropriate and label it in the evidence; it is not a substitute for a final full build.

After A13, whole-folder analysis must also pass:

```powershell
flutter analyze --no-pub
```

The existing native live-network smoke test is opt-in with `TURBOSAVE_LIVE_PROBE=1`. Run it separately at the final gate; report it as skipped or externally blocked if it cannot run, never as passed.

## Stage 6 — physical-device and release gates

Do this after the repair sessions, using a release candidate of both editions. Build/install only when implementation reaches this stage and is authorized; this planning request does not install anything.

- **Automated gate:** Flutter/Python/native suites pass with no unexplained failures; current and whole-folder analysis pass. Confirm the Open edition policy separately as well as Restricted behavior.
- **Build gate:** use [existing APK build script](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/scripts/build-apks.ps1>) for both editions after checking its versioned filenames against the intended release version. Preserve signing identity and increment version code for an update; verify signatures, ARM32/ARM64 contents and 16 KiB alignment. No new “ready” claim from old APKs.
- **Device gate:** physical ARM32 and ARM64 devices; fresh install and update; cold/warm share; permission rejection/retry on applicable older Android; valid video and audio; playback/share; cancelled/completed timing; app background/lock/process kill; Wi-Fi loss/recovery; low storage. No destructive reset of existing user downloads.
- **Resource gate:** use a fixed harmless media workload; record idle/background CPU, network activity, peak memory, wake-lock behavior and storage before/after on the same device. Compare measurements against the unmodified baseline when available; do not claim battery optimization from mock tests.
- **Soak gate:** at least 24 hours of controlled idle/background use with several scripted downloads and resume/restart checks. Record device/OS, workload and failures. A clean soak is evidence for that workload, not a guarantee of all-day battery life or universal site support.
- **Documentation gate:** update [REPAIR_REPORT.md](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/REPAIR_REPORT.md>) and [RELEASE_READINESS.md](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/RELEASE_READINESS.md>) so previous “findings repaired” wording is scoped to the correct milestone. Record the new audit resolutions, current test output and every remaining device/provider limitation.
- **Publication gate:** treat store policy, developer/business details and distribution requirements as separate checks. Domain blocking and green tests do not establish store approval.

If a test fails, return to the matching finding in its own session. Roll back only that repair's commit if necessary; preserve prior verified fixes.

## Progress checklist

- [x] A1 cancellation race — local automated checks complete; device checks pending
- [x] A2 malformed settings/startup — local automated checks complete; device checks pending
- [x] A11 network resource limits implemented and tested — OS/parser and device limits documented
- [x] A3 unknown codec metadata — conservative standalone-file fallback and honest sound label; device checks pending
- [x] A4 MP4/RF64 signatures — valid bounded layouts and malformed-header handling verified; device checks pending
- [x] A7 audio kind/persistence/MIME — saved media kind and open/share types verified; device checks pending
- [x] A5 Home draft — text survives tab changes without retaining hidden screens; device checks pending
- [x] A6 share acknowledgement retry — bounded process-local retry coverage; device checks pending
- [x] A8 literal URL preservation — exact standalone text and policy checks pass
- [x] A9 accessible fetch action — semantics/loading/keyboard checks pass; TalkBack pending
- [x] A10 resolved theme toggle — both system appearances and preference persistence pass
- [x] A12 native metadata/query cost — reconciled ownership and direct ID lookup checked twice; device history/performance check pending
- [x] A13 archive analysis exclusion — exact historical archive excluded; backup unchanged
- [x] All automated checks green — full Flutter/Python/JVM, live probe, whole analysis and targeted Open checks
- [ ] Both release APKs verified
- [ ] ARM32/ARM64 device matrix passed
- [ ] Resource measurements and soak completed
- [x] Repair/release documentation updated — current source results distinguished from historical APKs

**Next stage:** release validation on fresh builds and physical devices. There are no open IDs in the recorded 13-finding audit; undiscovered bugs remain possible. No new APK was built or installed for these audit repairs, and no current release-readiness claim is made from automated tests alone.

