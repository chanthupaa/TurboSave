# TurboSave In-App Media Player Design

## Scope

Downloaded video and audio open inside TurboSave from the Library. Sharing and deleting remain unchanged. Unsupported or missing media shows a clear error and does not crash the app.

## Design

Use an Android-only, non-exported `PlayerActivity` built from platform `VideoView`, `SeekBar`, and basic playback widgets. `MainActivity` keeps the existing ownership, completion, content-URI, and MIME checks before starting the player, so the new activity never accepts arbitrary external files. The activity is a dedicated fullscreen surface, pauses with the lifecycle, and releases playback when closed.

Library cards become tappable and use the existing `DownloadProvider.openFile` route. The existing menu's Open action uses the same route; Share remains an Android share intent.

## Validation

- Flutter widget test: tapping a saved Library card sends the native `open` request.
- Kotlin unit test: only video and audio MIME types are eligible for the internal player.
- Full Flutter tests, Flutter analysis, both Android flavor JVM tests, unrestricted APK build, and a physical-phone open/play check.

## Deliberate Limits

- Android only; the current app is Android-only.
- No playlists, subtitles, picture-in-picture, casting, or background audio.
- No new dependency.
