# TurboSave

Free, open-source media downloads on your own device. TurboSave has separate Android and Windows apps in this repository. It does not require a TurboSave account or hosted download service.

| App | Source | Current source version | Platform |
| --- | --- | --- | --- |
| Android | [android/](android/) | 1.5.3+13 | Android |
| Desktop | [desktop/](desktop/) | 0.8.0-beta.5 | Windows 10/11 x64 |

## Download and release status

See [Releases](https://github.com/chanthupaa/TurboSave/releases) for platform-specific source tags and any tested installers. Read each release's notes before installing. Android 1.5.3 currently includes changes that need physical-device validation. The Windows beta is unsigned, and its bundled dependencies need a corresponding-source review before public binary redistribution. A source release is not a finished installer.

## What the apps do

- Choose a save folder and media format before downloading.
- Download supported public links using local tools. Available formats depend on the source; DRM and site restrictions remain in effect.
- Windows includes single, batch and YouTube playlist workflows, download history, pause/resume, and optional remembered Firefox YouTube sessions.
- Android supports sharing a link into the app, reviewing available qualities, local downloads and an in-app media library.

Use TurboSave only for media you have permission to save. The apps cannot bypass DRM, account restrictions or source availability.

## Build from source

### Android

The [Android README](android/README.md) lists the Flutter, Android SDK, Python and signing prerequisites. From `android/`:

```powershell
flutter pub get
flutter analyze --no-pub lib test
flutter test --no-pub
```

The APK build requires local signing configuration that is not in this repository. Do not commit signing keys.

### Windows

The [Windows build guide](desktop/BUILD_GUIDE.md) and [dependency-source review](desktop/DEPENDENCY_SOURCES.md) explain packaging and redistribution. From `desktop/`:

```powershell
npm ci
npm run tools:prepare
npm test
npm run build
```

## Contribute and report issues

Open a GitHub issue with the app, version, OS version and steps to reproduce. Remove private links, usernames, local paths, cookies and credentials from reports. See each app's contributing guide and [security policy](SECURITY.md).

## License

TurboSave's original application code is [GPL-3.0-only](LICENSE). Third-party components retain their own licenses and notices in the platform folders. Publishing source does not resolve the additional obligations for redistributed binary dependencies.

The Web app remains a [separate project](https://github.com/chanthupaa/turbosave-web).
