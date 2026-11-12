# TurboSave Android

Flutter Android app with local yt-dlp/Python extraction and Android-managed downloads. Current source version: **1.5.3+13**. Original recovery files are preserved in `_private-backups/`; current source includes repairs and a reconstructed native bridge.

Source lives in the [combined TurboSave repository](https://github.com/chanthupaa/TurboSave). Source, tests, build configuration and license notices are included. Private recovery evidence, original archives, generated builds and signing configuration stay local. Earlier repair reports describe the audit work before the initial source commit; their local evidence paths are not uploaded.

Restricted and Open editions install side by side and support ARM 32-bit and ARM 64-bit phones. Restricted blocks identified YouTube/adult sources; Open has no such domain filter. Access permissions, DRM and source availability still apply. Share a text link, review details/quality, then explicitly start downloading. Browser previews cannot verify Android extraction, sharing or background behavior.

Adaptive HD support in the current source is limited to Android 10 or newer and direct HTTPS MP4 video tracks paired with compatible AAC audio tracks. Android downloads both parts, merges them locally, and publishes one MP4 under `Downloads/TurboSave`. Complete single-file formats remain available. Fragmented streams, DRM, sign-in-only media, unsupported codecs and other container combinations are not offered as merged choices. The new merge path has passed source tests and a debug APK build; it still needs a real device transfer and playback check before release.

From this folder with the matching Flutter SDK:

```powershell
flutter pub get
flutter analyze --no-pub lib test
flutter test --no-pub
python -m unittest discover -s test -p '*test.py' -v
powershell.exe -NoProfile -File scripts/build-apks.ps1 -Variant both
```

The Windows build script requires the configured local SDK, JBR, Python 3.11 build host and private signing configuration outside the repository. No downloader API key or server is required. See `REPAIR_REPORT.md` for current repairs, test/build evidence and limits; `RELEASE_READINESS.md` lists remaining device/publication checks. `RECOVERY.md` and `PIPELINE_AUDIT.md` are historical baseline records. `SOURCE_ORIGIN.md` covers source/license provenance.

Original APKs and recovery archives are in `_private-backups/`, excluded from Git. Do not publish them as a new rebuilt release. Keep the existing font and dependency license notices.
