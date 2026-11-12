# A11 repair — bounded metadata networking

Date: 30 October 2026. Scope: **A11 only** from [the second mobile audit](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/SECOND_MOBILE_BUG_AUDIT.md>).
Status: implemented and verified by controlled resource tests, a live native HTTPS probe and the installed yt-dlp transport. Physical-device and remaining platform limits are listed below.

## Reproduction before repair

Added controlled Python transport tests against the original extractor. Six of seven tests failed: a simulated slow body and post-extraction DNS/format validation could exceed the intended deadline, oversized metadata and compressed expansion were accepted, and aggregate metadata work was uncapped. The normal-response control passed.

The tests advance a fake monotonic clock rather than waiting a real minute. They use synthetic HTTPS responses and public-address DNS fixtures; they do not contact an attacker-controlled site or weaken production URL validation.

Evidence: [baseline resource failures](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a11-python-before.log>).

## What changed

### Shared native deadline

[NetworkBudget](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/kotlin/com/turbosave/videodownloader/NetworkBudget.kt:15>) establishes a 65-second deadline when an operation is dispatched. The same budget is passed through queued network work, DNS checks, header validation, redirects and connection attempts.

- DNS waits use a fixed two-worker JVM pool with no queued backlog. Exhausted lookup capacity returns a clear retry error.
- Expired queued network operations do not start a new lookup.
- A watchdog closes the preflight socket at its deadline, including while connection/TLS/read/write work is blocked.
- Stream reads check the budget, so a continuous trickle cannot restart the overall deadline.
- The remaining duration is passed into Python; redirects and address retries do not receive fresh budgets.
- Android DownloadManager receives the request only after bounded preflight succeeds.

### Bounded Python metadata

[MetadataBudget](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/python/metadata_budget.py:23>) applies the remaining operation budget to request entry, socket work, response reading, DNS validation and later format/thumbnail processing.

| Limit | Behavior |
|---|---|
| Operation budget | Up to 65 seconds, reduced by time already used in native work |
| Each encoded/decoded response reader | 4 MiB maximum |
| Aggregate decoded metadata | 16 MiB per operation |
| Accepted metadata response headers | 64 KiB |
| Metadata requests | 80 maximum |
| New DNS lookups | 64 maximum |
| Addresses in one DNS answer | 64 maximum; excessive answers are rejected, not truncated |
| Python DNS helpers | Two fixed workers; capacity is held until underlying work actually exits |
| Body reads | Chunks no larger than 64 KiB |

The byte limits apply to details/metadata extraction, not Android's subsequent video transfer. A test verifies that reading a 512-byte prefix from a larger media response remains possible.

Identity, gzip and deflate/raw-deflate are handled with bounded reads and bounded decompression output. Oversized expansion cannot evade the decoded-size limit. Unsupported encodings are rejected before decoding. HEAD responses retain their representation headers without being mistaken for a body download.

Requests ask for identity encoding. A default urllib gate also rejects non-HTTPS subrequests, preventing alternate URI schemes from escaping the metadata checks. Existing domain blocks, private-network rejection, pinned destination connections, hostname/certificate validation, header sanitization and complete-file filtering remain in force.

Timeout and size failures close tracked sockets/streams and produce clear messages. A new valid operation succeeds after a timed-out operation. Diagnostics do not dump media response bodies or credentials.

## Limit selection

The initial 4 MiB response cap was exercised at the boundary, above it, with compressed expansion, and with repeated requests crossing the aggregate limit.

A bounded live HTML measurement read the TurboSave homepage successfully: **19,224 bytes, identity encoding**. The Blender homepage and Vimeo measurement attempts returned URLError and HTTPError respectively, so no size result is claimed for those pages. This is a small measurement sample, not a full provider corpus. The cap is a conservative initial guard; legitimate providers requiring larger metadata can return a size error and need measured follow-up.

Evidence: [metadata size measurements](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a11-network/metadata-sizes.json>).

## Verification

**All 28 new resource tests pass:** seven JVM tests and 21 Python tests.

| Check | Result |
|---|---|
| New native deadline/socket tests | 7 passed |
| New Python resource/reader tests | 21 passed |
| Full native JVM suite, live probe enabled | **21 passed, 2 known failures, 0 skipped** |
| Full Python suite on Python 3.11 | **27 passed, 1 known failure** |
| Full Flutter suite | **70 passed, 6 unchanged known failures** |
| Maintained Dart analysis | No issues found |
| Installed yt-dlp 2026.10.26 HTTP transport | Identity/gzip/deflate decoded correctly; oversized gzip expansion rejected |
| Existing live native pinned HTTPS probe | Passed |

Native tests verify a socket actually closes while a read is blocked, fake-clock slow streams stop, redirects/stages share one deadline, expired queued work avoids DNS, DNS time counts against the budget, excessive DNS answers are rejected, and a worker accepts a later valid operation.

Python tests cover slow reads, bounded allocation/read sizes, decoded and aggregate limits, gzip/deflate expansion, zero-length decoder reads, oversized headers, HEAD semantics, request limits, DNS cache/helper bounds, socket release, non-HTTPS subrequests and recovery after timeout.

The installed yt-dlp check uses its **real HTTP handler/response stack with a controlled HTTPS response**, not a live source-platform extraction. The separate live native probe checks real TLS and the existing Blender media prefix; it does not download the whole video.

No prior passing test regressed. The remaining failures are exactly:

- Flutter: A5 Home draft, A6 acknowledgement retry, A7 audio MIME, A8 URL punctuation, A9 accessible action label and A10 theme toggle.
- Native: A4 leading-free MP4 and RF64/WAV signature false negatives.
- Python: A3 missing codec metadata.

The full suites remain red for those findings. A1/A2 remain intact. No existing test was edited, removed, skipped or weakened.

Commands/output:

```powershell
& (Join-Path $env:LOCALAPPDATA 'TurboSaveBuildTools/python311/python.exe') -m unittest discover -s test -p '*test.py' -v
# Ran 28 tests ... FAILED (failures=1): the existing A3 test only.

$env:TURBOSAVE_LIVE_PROBE = '1'
& '.\android\gradlew.bat' -p android :app:testRestrictedDebugUnitTest -x :app:compileFlutterBuildRestrictedDebug --console=plain
# 23 tests completed, 2 failed: the existing A4 cases only.

flutter test --no-pub --reporter expanded
# 00:24 +70 -6: Some tests failed.

flutter analyze --no-pub lib test
# No issues found! (ran in 38.3s)
```

Native testing reused existing Flutter debug assets while compiling native sources/tests and generating Python assets. Python logic was also exercised directly on 3.11, matching the bundled runtime version. Later Python-only refinements were retested with the Python suite and installed yt-dlp transport; JVM and Dart code did not change after their full runs. This is not a release APK build.

## Files changed

Modified existing sources:

- [MainActivity.kt](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/kotlin/com/turbosave/videodownloader/MainActivity.kt>).
- [PublicMediaProbe.kt](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/kotlin/com/turbosave/videodownloader/PublicMediaProbe.kt>).
- [LinkRules.kt](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/kotlin/com/turbosave/videodownloader/LinkRules.kt>).
- [media_extractor.py](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/python/media_extractor.py>).

Added:

- [NetworkBudget.kt](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/kotlin/com/turbosave/videodownloader/NetworkBudget.kt>).
- [metadata_budget.py](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/python/metadata_budget.py>).
- [NetworkBudgetTest.kt](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/test/kotlin/com/turbosave/videodownloader/NetworkBudgetTest.kt>).
- [extractor_resources_test.py](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/test/extractor_resources_test.py>).
- [metadata_budget_test.py](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/test/metadata_budget_test.py>).
- This report, roadmap progress and evidence files.

A SHA-256 comparison of **64 pre-existing source/test/configuration files** found only the four intended source files changed. All prior tests, Dart application code, dependency declarations/lockfile and blocked-host data remain unchanged. No new package was added.

## Git and evidence

Local branch: `fix/a11-network-budgets`. The repository still has no initial commit; no partial initial commit, push or deployment was made. Before-files and a validated nine-file source/test patch preserve this repair relative to A2.

- [Reviewable source/test patch](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a11-network/repair.patch>), validated with `git apply --reverse --check`.
- [Integrity and test comparison](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a11-network/verification.json>).
- [Python suite log](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a11-python-full.log>).
- [Native suite and live probe log](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a11-native.log>).
- [Flutter suite log](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a11-flutter.log>).
- [Dart analysis log](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a11-analysis.log>).
- [Installed yt-dlp transport check](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a11-real-ytdlp.log>).

## Remaining limits and unverified behavior

- An OS DNS call cannot always be forcibly interrupted. Callers stop waiting at their deadline, and stale work is confined to two JVM and two Python lookup helpers. New lookups can report busy until the OS work ends; no per-timeout worker proliferation is allowed.
- Socket deadlines are enforced and bytecode/pipeline checkpoints are checked. Arbitrary CPU-bound work inside Python/native parser libraries is **not forcibly preempted**. This is not a claim that every possible parser computation must stop at exactly 65 seconds.
- The Python header cap is checked after the standard HTTP parser receives headers, which also has its own fixed parsing limits. The cap is not a promise that process RSS never exceeds 64 KiB or 4 MiB.
- Restricted/Open source rules and DownloadManager are retained. DownloadManager's later DNS/redirect behavior and Flutter thumbnail requests remain outside the pinned preflight architecture already accepted by the user.
- Physical ARM32/ARM64 behavior, real Android TLS stacks, process death, battery, peak RAM, storage, broad source-platform compatibility and full video transfers were not tested here. No APK was built or installed.

**Next:** A3 missing codec metadata, only after the user confirms.

