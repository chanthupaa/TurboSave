# A3: missing codec metadata

30 October 2026. Scope: A3 only. A1, A2 and A11 are preserved. A4 and all other findings remain for their own sessions.

## Result

The original audit reproduction returned zero formats for an ordinary HTML5 MP4. `normalized_formats` treated missing `acodec` as confirmed absence of audio. The installed yt-dlp 2026.10.26 HTML5 parser reproduces that exact metadata shape: `vcodec: null` and no audio codec field.

The extractor now distinguishes unreported codecs from the explicit `none` value. It retains an uncertain candidate only when both codecs are unreported, its supported MP4/WebM/MOV/MKV suffix matches the file URL, the protocol is a direct HTTP(S) file protocol, and no manifest, fragments, fragment base, requested-format combination or DASH container is reported. The public HTTPS validator still runs; HTTP URLs fail it.

Explicit `acodec: none` remains rejected. A known video codec with unknown audio, or explicit audio-only video container with unknown audio, is not assumed complete. Existing known complete video/audio formats retain their behavior. Known complete candidates take priority over uncertain duplicates. Existing DRM, restricted-edition, credential, public-network, request-header and deadline checks remain active.

The payload carries `audioUnknown`, and Dart adds **Sound unverified** to an uncertain video's visible format label. Existing payloads without this field remain compatible. This change makes the generic file selectable without claiming that its extension proves an audio track exists.

## Verification

Commands and observed output:

```text
Python 3.11: -m unittest discover -s test -p '*test.py' -v
Ran 40 tests
OK

flutter test --no-pub --reporter expanded
73 passed, 6 failed

flutter analyze --no-pub lib test
No issues found!
```

- The original A3 test passes unchanged. All 12 new Python regression tests and three new Dart parser tests pass. The failing-before logs are retained.
- The six Flutter failures match the previous A11 run by full test name: A5 Home draft, A6 share acknowledgement retry, A7 audio-only MP4 MIME, A8 literal URL punctuation, A9 accessible fetch action, and A10 theme toggle. None were fixed or weakened here.
- The actual installed yt-dlp HTML5 parser produces the original fixture and the modified normalizer retains it with `audioUnknown: true`.
- The installed yt-dlp HTTP transport passes identity, gzip and deflate decoding and oversized-gzip rejection checks inherited from A11.
- A live host-side `ffprobe` read of Blender's public Sintel MP4 reports H.264 video and AAC audio. The first probe attempt failed with exit 1; a retry with diagnostic capture passed. This verifies this fixture's tracks, not mobile playback or universal network reliability.
- SHA-256 comparison of 69 pre-existing source/test/configuration files found only the intended two source files changed. Every pre-existing test, the dependency declarations/lockfile and restricted-host data remain unchanged.
- No packages were added. JVM tests were not rerun: no Kotlin/native configuration was changed. Their last recorded A11 result includes the two known A4 signature failures.

## Files

Changed:

- [media_extractor.py](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/android/app/src/main/python/media_extractor.py>) — conservative unknown-codec handling, uncertainty flag and known-format priority.
- [video_parser_service.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/services/video_parser_service.dart>) — visible sound uncertainty label.
- [Roadmap](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/docs/plans/2026-10-30-mobile-bug-fixing-roadmap.md>) — A3 progress and next checkpoint.

Added:

- [unknown_codecs_test.py](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/test/unknown_codecs_test.py>) — 12 positive, negative, policy, deduplication and cancellation regression tests.
- [unknown_codecs_test.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/test/unknown_codecs_test.dart>) — three parser/label compatibility tests.
- This report and the A3 recovery evidence directory.

## Evidence and Git

Local branch: `fix/a3-codec-metadata`. This repository still has no initial commit. No partial initial commit, push or deployment was made; the before-files and validated four-file source/test patch preserve the repair relative to A11.

- [Source/test patch](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a3-codec/repair.patch>) — `git apply --reverse --check` passes, including the existing Windows line endings.
- [Scope and failure comparison](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a3-codec/verification.json>).
- [Original A3 failing log](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a3-before.log>).
- [Python suite](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a3-python-full.log>).
- [Flutter suite](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a3-flutter.log>).
- [Dart analysis](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a3-analysis.log>).
- [Installed HTML5 parser and live host probe](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a3-html5.log>).
- [Installed yt-dlp transport](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a3-transport.log>).

## Limits

The production app does not parse uncertain media tracks or bundle ffprobe. An unreported codec can still hide a silent file; the UI explicitly states that sound is unverified. Extensionless uncertain URLs, codec-incomplete adaptive streams and uncertain audio-only files remain unavailable. A track-aware parser would require a separately reviewed change if guaranteed audio detection becomes necessary.

DownloadManager and existing native MIME/container-signature preflight remain in place. Those checks do not establish audio presence. A4's valid-container false negatives remain unfixed, and the previously accepted DownloadManager DNS/redirect limitation is unchanged.

No release APK, physical ARM32/ARM64 playback, actual Android transfer, battery/storage measurement or broad platform compatibility was verified. No APK was built or installed.

Next: wait for the user's confirmation before A4.
