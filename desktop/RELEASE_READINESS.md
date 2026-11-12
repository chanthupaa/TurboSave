# Windows 0.8.0-beta.5 release readiness

Repository description: Free, open-source Windows media downloader with quality selection, playlists and local processing.

This candidate targets Windows 10/11 x64. It contains installer and portable builds with bundled tools. Local source tests, packaged runtime checks and any live-source evidence are recorded in `VALIDATION-0.8.md`; checks that did not run are not silently treated as passed.

Required before public binary publication:

- Validate the optional YouTube connection manually with an explicitly authorized real account. Synthetic session checks verify handling and isolation, not YouTube acceptance. Current support is regular Firefox profiles in the standard Windows Firefox folder; no universal browser or no-verification guarantee.
- Review `DEPENDENCY_SOURCES.md`: matching original-code source is prepared, but complete corresponding-source coverage for GPL-covered bundled dependencies must be verified from the exact build provenance.
- Test the installer on a separate clean Windows account/device/VM with no Python, yt-dlp or FFmpeg on PATH; test upgrade preservation there. An isolated profile on this developer PC is not a clean machine.
- Decide whether to distribute the clearly labelled unsigned beta or obtain signing credentials. Do not tell users to disable antivirus or browser protection.
- Check the release draft, source/archive checksums and exact packaged verification reports. App update discovery reads `chanthupaa/TurboSave` and only offers a newer `desktop-v<version>` release containing a matching Windows setup or portable executable. Source-only and Android releases are excluded.
- Review secret scan findings and distribution content. Runtime profiles, downloaded media, private keys and signing credentials do not belong in source/releases.
- For future authenticated binary delivery, provision the private Ed25519 release key and pin its public record in `build-resources/update-trust.json`. The current checker only opens the GitHub release page; it never downloads or runs a binary automatically.
- Push and confirm the configured dependency, secret, CodeQL and Dependabot checks in the intended public desktop repository. Enable GitHub private vulnerability reporting and document its actual link.

This Windows security update does not rebuild Android, redeploy Web or change the live Telegram service. Local installation after validation is separate from public publication.
