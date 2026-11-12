# A4: valid MP4 and RF64/WAV download errors

30 October 2026. Scope: A4 only. The user asked to prioritize crashes/failures, then clarified that the app displays a download/error message rather than closing. This repair addresses a reproduced cause of such errors; no specific failing link was supplied and no app-process crash was claimed or reproduced.

## Problem and result

Both existing audit tests failed before the change. The native file check required an MP4 media box at the start and did not recognize RF64/WAVE. Valid files could therefore be reported as invalid/unavailable during preflight or completed-file checking.

The MP4 check now walks only permitted leading `free`, `skip` and `wide` padding boxes, then recognizes an `ftyp`, `moov` or `mdat` header. It handles ordinary 32-bit and extended 64-bit box sizes. The walk reads at most the existing 512-byte prefix and inspects at most 16 boxes. Zero/undersized/truncated padding, sizes outside the prefix, unsigned overflow cases and unknown leading boxes fail safely. A standalone padding box is not proof of media.

RF64 recognition checks the RF64 tag, all-ones size sentinel, WAVE identifier, mandatory ds64 tag and at least the 48-byte header prefix. The existing RIFF/WAVE and other supported container checks remain intact.

The shared check is still used for both preflight and saved-file snapshots. It adds no network requests, additional file reads or runtime dependency.

## Verification

```text
Before: original SecondMediaAuditTest
2 tests completed, 2 failed

After: focused signature checks
20 tests, 0 failures, 0 skipped

After: full Restricted JVM suite, live probe enabled
51 tests, 0 failures, 0 skipped
BUILD SUCCESSFUL

flutter test --no-pub --reporter expanded
85 passed, 6 failed

Python 3.11 unittest suite
Ran 40 tests
OK

flutter analyze --no-pub lib test
No issues found!
```

- Both original A4 tests pass without modification.
- Fifteen new tests cover permitted padding, extended sizes, truncation, size overflow, byte/box limits, disguised HTML/JSON, RF64 headers, short reads and the two real generated fixtures.
- The deterministic fuzz check exercises 10,000 random byte arrays and 10,000 mutated padding-header arrays. All 20,000 calls finish without exceptions or the test timeout. This is host JVM evidence, not a guarantee against every possible Android crash.
- The generated fixtures are copied into JVM test resources so tests do not depend on the private recovery directory. Their SHA-256 hashes exactly match the originals. FFprobe identifies H.264/AAC in the padded MP4 and PCM audio in the RF64/WAV; FFmpeg decodes both with exit code 0.
- The full native run includes the A12 ownership tests and the live Blender HTTPS/container-prefix probe. None are skipped.
- Flutter's six failures exactly match the A12 baseline: A5 Home input, A6 acknowledgement retry, A7 audio kind/MIME, A8 URL punctuation, A9 accessibility and A10 theme toggle. None were changed here.
- SHA-256 comparison of 74 pre-existing source/test/configuration files found only MediaSignatures.kt changed. Every existing test, other production source file, host restriction list and dependency declaration/lockfile remains unchanged. No package was added.

Native command: `android/gradlew.bat -p android :app:testRestrictedDebugUnitTest -x :app:compileFlutterBuildRestrictedDebug --console=plain`, with the documented local build environment and `TURBOSAVE_LIVE_PROBE=1`. The focused run adds the three signature test class filters.

## Files changed

- [MediaSignatures.kt](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/kotlin/com/turbosave/videodownloader/MediaSignatures.kt>) — shared prefix constant, bounded MP4 box inspection and RF64 recognition.
- [Roadmap](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/docs/plans/2026-10-30-mobile-bug-fixing-roadmap.md>) — A4 progress and next checkpoint.

Added:

- [MediaSignatureBoundsTest.kt](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/test/kotlin/com/turbosave/videodownloader/MediaSignatureBoundsTest.kt>).
- [Generated MP4 fixture](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/test/resources/media-signatures/leading-free.mp4>) and [generated RF64/WAV fixture](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/test/resources/media-signatures/rf64.wav>), about 11.5 KB combined, used only by JVM tests.
- This report and the A4 recovery evidence.

## Evidence and Git

Local branch: `fix/a4-media-signatures`. The repository still has no initial commit. No partial initial commit, push, deployment or installation was made. The before-file and validated four-file source/test/fixture patch preserve this repair relative to A12.

- [Reviewable text/binary patch](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a4-signatures/repair.patch>), validated with `git apply --reverse --check`.
- [Integrity and test comparison](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a4-signatures/verification.json>).
- [Original failures](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a4-signatures/native-before.log>) and [new-test failing-before results](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a4-signatures/native-new-red.log>).
- [Focused native checks](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a4-signatures/native-focused.log>) and [full native suite](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a4-native-full.log>), with saved XML snapshots.
- [Independent fixture decode/hash results](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a4-signatures/fixtures.json>).
- [Flutter suite](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a4-flutter.log>), [Python suite](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a4-python.log>) and [maintained-source analysis](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a4-analysis.log>).

## Limits and next checkpoint

This is bounded container-prefix recognition, not a complete MP4/RF64 parser, track verifier, DRM detector or proof of playback. RF64 ds64 payload values are not fully validated. A valid MP4 whose identifying box lies outside the 512-byte/16-box budget, or behind an unsupported leading box, can still be rejected deliberately. Unrelated restrictions, expired links, unavailable sites and network errors can still fail a download.

No release APK, fresh Flutter debug asset build, installation, physical-phone transfer/playback, battery/storage measurement or user-specific failing-link test was performed. The native tests compiled the changed Kotlin and reused the existing Flutter debug assets. Existing DownloadManager DNS/redirect and unknown-codec sound limitations are unchanged.

Seven known findings remain. A7 audio kind/persistence/MIME is next in the roadmap; wait for the user's confirmation before starting it.
