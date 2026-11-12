<p align="center"><img src="desktop/build-resources/icon.png" alt="TurboSave logo" width="76"></p>

<h1 align="center">TurboSave</h1>

<p align="center"><strong>Free, open-source downloads. Your device. Your files.</strong></p>

<p align="center">Choose the format, choose the folder, and keep media you have permission to save. TurboSave runs locally on Android and Windows without a TurboSave account.</p>

<p align="center">
  <a href="https://github.com/chanthupaa/TurboSave/releases">Releases</a> ·
  <a href="android/">Android source</a> ·
  <a href="desktop/">Windows source</a> ·
  <a href="https://github.com/chanthupaa/TurboSave/issues">Report an issue</a>
</p>

> **Release status:** The current Android and Windows GitHub prereleases contain source archives only. There is no installable APK or Windows installer attached yet. Android needs a newly signed, device-tested APK; the Windows binary needs its bundled dependencies' corresponding-source review completed. See [releases](https://github.com/chanthupaa/TurboSave/releases) for the exact status.

## See the apps

| Windows desktop | Android phone |
| --- | --- |
| <img src="docs/images/windows-source-ui.png" alt="TurboSave Windows new download screen showing a save destination, link input and format search" width="680"> | <img src="docs/images/android-source-ui.png" alt="TurboSave Android home screen showing link entry and the Home, Activity, Library and Settings navigation" width="280"> |

These are **UI previews rendered from the checked-in source** with empty or example data. They do not claim a successful download or a packaged-app test.

## Pick your platform

| | Android | Windows |
| --- | --- | --- |
| Current source | [1.5.3+13](android/) | [0.8.0-beta.5](desktop/) |
| Main flow | Share or paste a link, review quality, save to the phone | Paste a link, choose media and destination, follow progress |
| More tools | Activity and local media library | Batch downloads, YouTube playlist selection, history, pause and resume |
| Source release | [Android prerelease](https://github.com/chanthupaa/TurboSave/releases/tag/android-v1.5.3-source) | [Windows prerelease](https://github.com/chanthupaa/TurboSave/releases/tag/desktop-v0.8.0-beta.5-source) |
| Build guide | [Android README](android/README.md) | [Windows build guide](desktop/BUILD_GUIDE.md) |

Available qualities and sites depend on the source. DRM, sign-in requirements and source restrictions still apply. TurboSave does not bypass them. The separate [Web project](https://github.com/chanthupaa/turbosave-web) is maintained outside this repository.

## Build from source

Clone the repository, then use the instructions for your platform. Generated builds, recovery archives, local signing material and private user data are excluded from Git.

<details>
<summary><strong>Android</strong> · Flutter and Android SDK</summary>

From `android/`:

```powershell
flutter pub get
flutter analyze --no-pub lib test
flutter test --no-pub
```

The APK build needs local signing configuration. See the [Android README](android/README.md) and [release readiness](android/RELEASE_READINESS.md). Never commit a signing key.

</details>

<details>
<summary><strong>Windows</strong> · Node.js, Electron, yt-dlp and FFmpeg</summary>

From `desktop/`:

```powershell
npm ci
npm run tools:prepare
npm test
npm run build
```

See the [build guide](desktop/BUILD_GUIDE.md) and [dependency-source review](desktop/DEPENDENCY_SOURCES.md) before distributing the bundled installer.

</details>

## Help improve TurboSave

For a bug, [open an issue](https://github.com/chanthupaa/TurboSave/issues) with the app, version, OS and reproduction steps. Remove private URLs, usernames, paths, cookies and credentials. Security reports belong in a private channel; see [SECURITY.md](SECURITY.md). Contributions are welcome through the [Android](android/CONTRIBUTING.md) and [Windows](desktop/CONTRIBUTING.md) guides.

TurboSave's original application code is [GPL-3.0-only](LICENSE). Third-party components keep their own licenses and notices in each platform folder. Use TurboSave only for media you have permission to save.
