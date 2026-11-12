# TurboSave mobile app — second bug audit

Date: 30 October 2026. Version: 1.5.1+11.

This is an audit, not a repair. **10 distinct bugs were reproduced, two additional risks were identified by code review, and one repository-tooling problem was reproduced.** These are new audit IDs A1–A13; they do not renumber the findings in the original MOBILE_BUG_AUDIT.md.

No application logic, existing tests, dependency declarations, APKs or signing configuration were changed. Added only audit tests, this report, small generated media fixtures and evidence logs. SHA-256 comparison confirms all **42 captured production text files** under lib, android/app/src/main, scripts and web are unchanged.

## Scope and limits

Reviewed the maintained Dart application, screens/widgets, models, download lifecycle and persistence, share inbox, restricted/open policy, Kotlin bridge and HTTPS preflight, Python extractor, Android manifest/build settings, packaging scripts, browser-preview boundary and existing tests. Followed operations across Dart, the method channel, Kotlin and Python rather than treating each file in isolation.

Generated builds, historical APK/decompilation snapshots, private backups, downloaded dependencies, font/image binaries and signing secrets are not a new application codebase to audit. Static branding/vector coordinates were not individually visually verified. This report concerns the mobile project, not the sibling website, Windows app or Telegram bot.

Unit/widget tests mock Android and network boundaries where stated. No physical Android device, real process kill, Android DownloadManager race, slow-server/OOM attack, battery benchmark, full source-platform matrix or release installation was tested in this session. A repository audit cannot prove there are no other bugs.

P2 = functional or robustness issue worth fixing; P3 = minor interaction/tooling issue. Code-path risks are explicitly separated from reproduced behavior.

## Reproduced application bugs

### A1 — P2: cancelling while a completion query returns leaves a deleted file in Library

Source: [polling/completion handling](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/providers/download_provider.dart:428>) and [cancelTask](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/providers/download_provider.dart:570>).

The poller can be awaiting Android while Cancel starts awaiting native cancellation. If the completion snapshot returns first, the task is moved from Activity to Library. Native cancellation then removes the Android download/file, but cancelTask only removes the task from the active list. It leaves the completed record behind and persists it as Saved.

**Reproduction:** hold a query response; start cancelling ID 101; release a successful completion snapshot; then release cancellation. Library still contains one completed task. The test models Android cancellation deleting the file; actual device timing has not been exercised.

Test: `cancelling during a completion query must not leave the deleted file in Library` — expected empty, actual one DownloadTask.

Repair direction, not implemented: give cancellation an explicit in-flight state and reconcile completion/cancellation against both task collections.

### A2 — P2: a wrong-type saved setting prevents provider initialization

Source: [_restoreState](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/providers/download_provider.dart:138>) and [onboarding preference read](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/main.dart:26>).

Settings are read with typed SharedPreferences getters outside a recovery boundary. A stored string at the boolean wifi_only key throws a TypeError, rejects provider.ready, and prevents methods awaiting ready from working. A wrong-type onboarding preference has the same unguarded pattern before runApp.

**Reproduction:** seed `wifi_only = 'invalid'`; instantiate DownloadProvider and await ready. Actual error: `type 'String' is not a subtype of type 'bool?' in type cast`.

This is **fault-injection evidence**, not proof that normal current writes create corrupt settings or that a phone crashed in this session. Queue/library JSON already has per-record handling; ordinary settings do not.

Test: `one malformed saved setting should not prevent download initialization` — fails with TypeError.

### A3 — P2: complete HTML5 videos are discarded when yt-dlp omits codec metadata

Source: [normalized_formats](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/python/media_extractor.py:37>), especially the audio decision at line 45.

The code treats unknown/missing acodec as definitely no audio and discards the format. yt-dlp's GenericIE HTML5 parser can return an ordinary MP4 source with vcodec = None and no acodec field. That metadata does not establish that the actual MP4 lacks sound.

**Reproduction:** obtain that format shape from the installed GenericIE HTML5 parser for a video/source element without a codecs attribute; pass it to normalized_formats with a public-URL validation stub. A known complete MP4 yields zero formats. The fixture uses Blender's public Sintel trailer URL; this audit does not claim a new live download from that URL or every generic website fails.

Test: `test_html5_video_without_codec_metadata_is_not_discarded` — expected one format, actual zero.

Repair direction, not implemented: distinguish unknown codecs from explicitly absent tracks and verify uncertain complete files safely. Do not blindly admit separate video-only streams.

### A4 — P2: valid MP4 and RF64/WAV containers fail the file check

Source: [hasMediaSignature](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/kotlin/com/turbosave/videodownloader/MediaSignatures.kt:18>); used by preflight and completed-file snapshots in MainActivity.

The MP4 check requires one of a small set of first atom types. A legal leading free box is rejected even when a valid ftyp/moov/mdat sequence follows. WAV accepts only RIFF/WAVE and rejects RF64/WAVE.

**Independent media evidence:** generated a small H.264/AAC MP4, moved its existing free atom to the front without changing the mdat offset, and generated a small RF64 PCM WAV. FFprobe identifies both correctly; FFmpeg decodes both with exit code 0. Their prefixes fail the native check. A valid file can therefore be called an error page/unavailable file.

Tests: `acceptsMp4WithAValidLeadingFreeBox` and `acceptsRf64WaveFiles` — both fail. These are two container cases of one signature false-negative finding.

Fixtures: [leading-free.mp4](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/second-audit-media/leading-free.mp4>) and [rf64.wav](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/second-audit-media/rf64.wav>).

The existing header-only validation limitation is not the finding here; the finding is rejecting independently valid files.

### A5 — P2: switching tabs destroys the typed Home URL

Source: [page construction](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/screens/main_navigation_screen.dart:97>), [KeyedSubtree](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/screens/main_navigation_screen.dart:157>), [Home text controller](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/screens/downloader_screen.dart:34>).

Tabs deliberately unmount their screens, but the typed URL lives only in Home's controller. Returning Home reconstructs it from the last shared URL or an empty string.

**Reproduction:** type a link; switch to Activity; return Home. Expected original link, actual empty text.

The same code can restore an older shared link after a later manually entered link. That additional mismatch follows from the source; only the empty-text sequence was exercised.

Test: `Home should preserve the typed link across tab changes` — fails.

### A6 — P2: failed share acknowledgement is never retried on resume

Source: [_seen guard](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/services/shared_link_service.dart:75>) and [acknowledgement](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/services/shared_link_service.dart:90>).

An ID enters _seen before acknowledgement. If the native acknowledgement throws, the native inbox retains the item, but the next resume suppresses it because it is already in _seen. The comment saying it is retained for a later resume does not match the behavior.

**Reproduction:** native inbox returns one item; its first acknowledgement throws PlatformException; call resume again. The link is handled once, but acknowledgement count remains one rather than two.

The item can replay after process restart because native storage retained it and the new process has an empty _seen set. The restart replay is a code-path consequence, not a physical-device experiment.

Test: `failed native share acknowledgement must be retried on resume` — expected two acknowledgements, actual one.

### A7 — P2: audio-only MP4 is opened/shared as video and loses its kind after restoration

Source: [saved task fields](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/providers/download_provider.dart:207>), [restored media kind](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/providers/download_provider.dart:237>) and [openFile MIME map](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/providers/download_provider.dart:650>).

The parser supports a separate audioOnly flag, including for an MP4 container. openFile ignores that flag and chooses video/mp4 from the extension. Saved tasks also omit the flag and infer it from extension on restoration. Audio-only WebM has the same extension-versus-kind issue.

**Reproduction:** return an extracted audioOnly MP4; finish it; open it. The native request receives video/mp4 instead of audio/mp4. This can choose the wrong receiving/player apps. Persisted-kind loss is verified by inspecting the serialized/restored fields, not a separate restart test.

Test: `audio-only MP4 should open with an audio MIME type` — fails.

### A8 — P2: share parsing changes valid literal URLs

Source: [trailing punctuation removal](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/services/shared_link_service.dart:27>).

The parser strips trailing punctuation unconditionally, including when the shared text consists only of a literal URL. Such characters can be meaningful in path/query values.

**Reproduction:** share `https://example.com/watch?id=hello!`. Actual parsed URL ends in hello, not hello!. A source whose ID/signature requires that character will receive a different URL.

Test: `sharing a literal URL must preserve its trailing query punctuation` — fails. No real service at the example URL was contacted.

### A9 — P2: the primary fetch button has no accessible name

Source: [icon-only FilledButton](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/screens/downloader_screen.dart:374>).

The main link action contains an arrow icon and no text, Tooltip or Semantics label. A screen reader sees a button without an action name.

**Reproduction:** build Home with semantics enabled; inspect the primary FilledButton's semantics label. Actual label is empty.

Test: `primary fetch button should have a screen-reader label` — fails. TalkBack on a physical phone was not tested.

### A10 — P3: the theme toggle does nothing on its first tap in System/light mode

Source: [toggleTheme](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/providers/download_provider.dart:697>).

The toggle compares the stored enum only. System is treated like Dark and switched to Light, even when the resolved system theme is already Light. The user expects the visible theme to change.

**Reproduction:** set System theme while platform brightness is Light; tap Toggle theme. Stored mode becomes Light rather than Dark, so the visible appearance remains light.

Test: `theme toggle should switch from system-light to dark on the first tap` — fails.

## Additional code-review risks — not reproduced device failures

### A11 — P2 risk: the network work has no reliable overall time/body-size budget

Sources: [response reader](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/kotlin/com/turbosave/videodownloader/PublicMediaProbe.kt:13>), [per-address timeouts](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/kotlin/com/turbosave/videodownloader/PublicMediaProbe.kt:71>), [two-worker pool](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/kotlin/com/turbosave/videodownloader/MainActivity.kt:27>), [extractor deadline](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/python/media_extractor.py:72>).

Native preflight has useful byte limits and per-read socket timeouts, but no overall deadline across addresses, redirects and reads. A peer delivering bytes just before each read timeout can keep it occupied much longer than a user expects. During enqueuing, cancelTask returns without cancelling that operation.

The Python deadline is checked on request/connection entry; it does not bound a response body read or the later format-validation DNS loop. The installed yt-dlp HTML reader uses urlh.read() without a body limit at that call. Large/slow pages can therefore occupy the extraction worker or consume excessive memory despite the nominal 65-second check.

This is source-backed resource-exhaustion risk. **No OOM, sustained battery drain, malicious-server transfer or 65-second violation was experimentally triggered on a phone.** Do not describe it as a confirmed crash.

### A12 — P2 risk: native download records grow for the lifetime of use, and opening a file scans them

Sources: [owned/verified state](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/kotlin/com/turbosave/videodownloader/MainActivity.kt:33>), [ID persistence](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/kotlin/com/turbosave/videodownloader/MainActivity.kt:174>), [openFile ownership scan](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/kotlin/com/turbosave/videodownloader/MainActivity.kt:212>), [record deletion/clearing](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/providers/download_provider.dart:671>).

Successful download IDs remain in the persisted owned set, and verification results remain in the activity's map. The 100-record Dart Library limit, Delete record and Clear private records do not prune that native bookkeeping. Only native cancel removes it.

Opening/sharing searches owned.firstOrNull and calls DownloadManager for each candidate. Cost grows with all historical transfers rather than the visible Library. A long-used installation may therefore have increasing storage/bookkeeping and slow file opening.

This is an unbounded-growth/linear-query code-path finding. **No measured phone latency, thousands-of-download benchmark or OOM was produced.** Physical files should not be deleted as a shortcut to pruning metadata.

## Repository tooling

### A13 — P3: whole-folder analysis includes broken historical backups

Source: [analysis exclusions](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/analysis_options.yaml:1>).

`flutter analyze` scans _private-backups/cleanup-20261009-013903/lib because that archive path is not excluded. It returns **35 diagnostics, all in the old backup code**, including missing imports. This prevents a clean repository-wide analysis check even though the maintained app compiles independently of those archives.

`flutter analyze --no-pub lib test` succeeds with **No issues found**. These 35 archive errors are not 35 APK bugs. No backup was deleted and no exclusions were changed during this audit.

## Test results and evidence

| Check | Result |
|---|---|
| Original Flutter suite before audit additions | 42 passed, 0 failed |
| Full Flutter suite including nine new audit tests | **43 passed, 8 failed** |
| Native JVM suite including two new audit tests | **16 total: 13 passed, 2 failed, 1 skipped** |
| Python suite including one new audit test | **6 passed, 1 failed** |
| Whole-folder flutter analyze | 35 diagnostics, all in historical private backups |
| Maintained lib/test analysis | No issues found |
| Generated leading-free MP4 and RF64 WAV | FFprobe identifies tracks; FFmpeg decodes both, exit 0 |
| Captured production source hashes | 42 compared, 0 changed |

The eight new Flutter failures, two new JVM failures and one new Python failure correspond to the **10 bug findings** above: the two JVM cases share A4. The ninth new Flutter test (a second fast shared link after closing the first sheet) **passes**; that hypothesis is not reported as a bug. The native live-network test is opt-in and was skipped in this audit; other native tests ran. No existing test was modified, deleted or weakened.

Console result excerpts:

```text
Flutter baseline: 00:10 +42: All tests passed!
Flutter with audit probes: 00:41 +43 -8: Some tests failed.
Native JVM: 16 tests completed, 2 failed, 1 skipped
Python: Ran 7 tests ... FAILED (failures=1)
Maintained analysis: No issues found! (ran in 14.4s)
```

Evidence files:

- [Dart audit reproductions](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/test/second_audit_test.dart>).
- [JVM audit reproductions](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/test/kotlin/com/turbosave/videodownloader/SecondMediaAuditTest.kt>).
- [Python audit reproduction](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/test/second_extractor_audit_test.py>).
- [Original Flutter suite log](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/second-audit-baseline.log>).
- [Full Flutter log](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/second-audit-full-flutter.log>).
- [JVM log](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/second-audit-native.log>).
- [Python log](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/second-audit-python.log>).
- [Whole-folder analysis log](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/second-audit-analysis.log>).
- [Maintained-source analysis log](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/second-audit-current-analysis.log>).
- [Source-integrity evidence](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/second-audit-source-integrity.json>).

From the mobile project directory, the Flutter and Python checks are:

```powershell
flutter test --reporter expanded
flutter analyze --no-pub lib test
python -m unittest discover -s test -p '*test.py' -v
```

Native testing uses the existing Android SDK/JDK/Chaquopy tool configuration and the Gradle task `:app:testRestrictedDebugUnitTest`. The run reused existing Flutter debug assets by excluding `:app:compileFlutterBuildRestrictedDebug`; native sources/tests were compiled and executed. It is not a new release-build result.

## Already-known constraints, not new bug counts

The user explicitly chose to keep Android DownloadManager. Its eventual DNS/redirect connections and Flutter thumbnail requests remain outside pinned preflight. That accepted architectural limit was documented in the previous repair report and is not counted again here.

Container signatures are header checks, not a full decode/integrity guarantee. The new fixture decodes establish those particular false negatives, not universal playback support.

Public-site extraction can fail because of sign-in requirements, DRM, geo restrictions, upstream changes or missing complete formats. This audit did not try every advertised site and does not turn expected upstream restrictions into app bugs.

No fixes, rebuilt release APKs, installation, deployment or GitHub changes were made. Recommended first repairs: A1 lifecycle race, A2 startup robustness, A3/A4 valid-media rejection, followed by the share/state/accessibility issues.

