# TurboSave 1.4.1 source recovery

Recovered on 25 October 2026 into this separate folder. The original APK and the
Cloudflare website were not edited. Nothing was uploaded or published.

## Recovered exactly

- All **25 application Dart source files embedded in the APK**, totalling 7,923
  lines: `lib/main.dart`, models, provider, screens, services, theme and widgets.
- **6 original app assets:** Manrope font and its OFL license, logo image, and
  Python/Chaquopy/yt-dlp license notices.
- Original Python application bundle (`_recovery/app.imy`) containing
  `media_extractor.pyc`, `restricted_sources_shared.pyc` and `requirements.txt`.
  The requirement specifies `yt-dlp==2026.8.19`. These are compiled Python 3.14
  modules, not recovered editable `.py` source.

The Dart files contain their original source text, comments and formatting.
They were read from the Kernel source table using the matching Dart SDK format
138 and commit prefix `b530c21f7d`; they were not rewritten by an AI decompiler.
The extractor and verification scripts are in `_recovery/scripts/`. Each recovered
file has its original Kernel offset, URI, byte count and SHA-256 recorded in
`_recovery/recovered-files.json`.

## Reconstructed or decoded, not original source

- `pubspec.yaml`: reconstructed from imports, APK version `1.4.1+9`, embedded
  package paths, font usage and bundled assets. `flutter pub get --offline`
  generated a **new** lockfile. All 29 package versions visible in the original
  Kernel agree with the resolved versions.
- `analysis_options.yaml`, `.gitignore`, `instructions.txt` and this report are
  new recovery support files; the originals were not available.
- `_recovery/native-decompiled/MainActivity.java`: readable Java reconstructed
  from the original compiled Kotlin Android activity. **One method is unresolved**:
  `configureFlutterEngine$lambda$0`, the method-channel dispatch handler. The
  alternative `.simple.java` output preserves lower-level branches with `goto`
  pseudocode and is **not compilable Java**. Neither file is a drop-in native
  source replacement. Other decompiled Java also needs compilation and review.
- `_recovery/android-decoded/resources/AndroidManifest.xml` and its `res/` folder:
  decoded **merged APK resources**, including launch icons and backup rules.
  These are evidence/reference files, not the original Android source layout.
- `_recovery/python-disassembly/`: complete local disassembly of the preserved
  Python modules. The disassembler did not execute the application code and does
  not recreate the original Python comments or source text.

## Verified

- The original APK SHA-256 is unchanged:
  `2f54f5b96c7421adbace323a53dd73ef77621eda2124376983071cb79a97b7c6`.
- All 25 recovered Dart files and all 6 app assets match the original APK bytes.
- All recovered Dart relative imports resolve to available files.
- `flutter pub get --offline` succeeds.
- `flutter analyze --no-pub lib`: **No issues found**.
- `flutter build bundle --debug --no-pub --target-platform android-arm64` succeeds
  and emits a new compiled Dart Kernel with the declared font and logo assets.
- `python _recovery/scripts/verify_recovery.py` records independent checks in
  `_recovery/verification.json`.

The first broad analysis run also scanned the standalone Dart SDK reference
reader and reported its missing SDK-internal imports. That reference is not app
code; the recovery analysis configuration now excludes `_recovery/`, and app-only
analysis passes. No recovered app source was altered to silence diagnostics.

## Still missing or unverified

- Original `pubspec.yaml`, `pubspec.lock`, app tests and project documentation.
- Original Kotlin/Java Android source and the original `.py` extractor sources.
- Original Android Gradle/settings/wrapper configuration, plugin versions,
  build variants and release build scripts. No new `android/` scaffold has been
  presented as recovered source.
- A compile-ready replacement for the unresolved native dispatch method and
  verification of the rest of the decompiled activity.
- Release/upload keystore, passwords and signing configuration. An APK's public
  certificate cannot restore its private signing key.
- Build-time values for `TURBOSAVE_DEVELOPER_NAME`, `TURBOSAVE_SUPPORT_EMAIL` and
  `TURBOSAVE_PRIVACY_URL`, which remain declarations in the recovered Dart source.
- A rebuilt Android APK/AAB, startup/download/share tests on a real phone, and
  Play Store release validation.

**This is an analyzable recovery of the Flutter layer, not a fully restored
Android build or a Play-ready release.** The next engineering step is to restore
the Android project and native method channel, then integrate the Python 3.14
runtime and test on Android. Keep the original APK as a reference and a fallback.

## Use and backup

A minimal new `web/index.html` was added for a localhost browser preview. This is
a reconstructed web scaffold, not an original recovered file. The Android APK
also omitted the conditional browser-only `lib/utils/web_downloader_web.dart`;
that helper was reconstructed using `package:web` 1.1.1. It opens a validated
HTTPS media link through the browser. The 25 APK-recovered Dart files are still
byte-exact; the additional helper is newly written. Run:

```powershell
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 4186 --no-pub
```

Open `http://127.0.0.1:4186/`. Website-page extraction and Android native downloads
are unavailable in this browser preview. The recovered Dart files remain exact.

Open this folder as the Flutter project. To recheck the recovered layer:

```powershell
flutter pub get --offline
flutter analyze --no-pub lib
flutter build bundle --debug --no-pub --target-platform android-arm64
python _recovery/scripts/verify_recovery.py
```

The source backup ZIP is saved beside the original APK in `TurboSave-artifacts`
as `TurboSave-recovered-source-20261025.zip`. It contains app source/assets,
reconstructed manifests, recovery scripts/reports, Python bytecode/disassembly,
and native decoded reference files. It excludes generated Flutter builds,
dependency caches, the large Kernel evidence blob and downloaded decompiler tools.
Keep the original APK too; the source ZIP does not contain another APK copy.

## Functional audit, 25 October 2026

See `PIPELINE_AUDIT.md` for live extraction/download results, five reproduced
unfixed defects, the 22-test audit suite (17 pass, 5 fail), mobile preview checks,
and the native/device work still required. Original recovered Dart files remain
byte-exact. Test success on simulated native responses is not an Android device
or release-build certification.

Official format reference:
https://github.com/dart-lang/sdk/blob/b530c21f7d/pkg/kernel/binary.md

Official native decompiler:
https://github.com/skylot/jadx
