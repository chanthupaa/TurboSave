import '../services/media_policy.dart';

class LegalContent {
  static const developer = String.fromEnvironment('TURBOSAVE_DEVELOPER_NAME');
  static const supportEmail = String.fromEnvironment('TURBOSAVE_SUPPORT_EMAIL');
  static const privacyUrl = String.fromEnvironment('TURBOSAVE_PRIVACY_URL');
  static const version = '1.5.3';

  static String get privacy =>
      '''TurboSave Privacy Policy
Effective date: 28 October 2026

TurboSave lets you save downloadable video, audio and supported public slideshow images that you own or have permission to download. It accepts direct HTTPS media links and attempts extraction from public HTTPS media pages across many sites. The Sources directory is a set of examples, not an allowlist or a guarantee. Not every page, post or format works. No account is required. This version includes no advertising or analytics SDK.

Information on your device
Theme, Wi-Fi preference, optional recent links, and download records are kept in app preferences. Download records contain the file name, source URL, progress and saved-file location. Android's download manager also retains its own transfer records. Files are saved in Downloads/TurboSave and may be visible to other apps you allow to access your media.

Network requests
Android checks public media-page links locally using Python and yt-dlp bundled in the installed app. Your phone contacts the source site to find media files and downloads directly from the media host. On Android 10 or newer, compatible separate MP4 video and AAC audio files may be combined locally after both finish downloading. There is no TurboSave extraction server and no account is required. Source sites and media hosts receive the requested URL and ordinary connection information such as your IP address, and manage their own logs. Internet access is required. Do not paste links containing passwords or private access tokens.

Optional site icons
If you enable website favicons in Settings, Google receives the fixed directory domain requested and connection information to retrieve that icon. User-entered URLs are not sent to Google by this feature. Icons are off by default. Google handles these requests under its own privacy policy at https://policies.google.com/privacy.

Clipboard
TurboSave reads the clipboard only when you tap Paste. It does not monitor copied text in the background.

Retention and control
Recent-link history is off by default. You can clear it and remove local library records under Settings > Privacy. This removes TurboSave's records; saved media and Android's download records remain in the system Downloads app. Clear or uninstall the app to remove its remaining preferences. Manage saved files in Android Downloads. Android device backups are disabled for app preferences.

Sharing
Open and Share send only the selected saved-file URI to the app you choose in Android. The recipient app manages the file under its own privacy practices. TurboSave does not upload your library.

Security and scope
Only public HTTPS direct media links and media pages are accepted. ${MediaPolicy.restricted ? 'This edition blocks identified YouTube/adult domains and reported adult metadata. Unknown domains and mislabelled content cannot always be detected.' : 'Open edition has no YouTube/adult domain filter. It does not bypass login, age checks, payment or protection.'} Private and DRM-protected media are excluded. Subscription services are not blocked merely by name, but paywalled or unsupported media cannot be saved. Metadata and domain checks cannot detect every explicit video, unknown adult domain or copyright violation. Google Play does not provide a list of approved downloader websites; copyright permission must be checked for each file. No broad storage, contacts, location, microphone or camera permission is requested. On Android 7–9 only, saving in the shared Downloads folder needs the legacy storage permission. A shared text link is held in a short local inbox until reviewed; downloads never start automatically. The local library keeps at most 100 records and thumbnail memory is capped at 20 MB.

Contact
${developer.isEmpty ? 'Developer identity must be configured before public release.' : developer}
${supportEmail.isEmpty ? 'Support and privacy contact must be configured before public release.' : supportEmail}
${privacyUrl.isEmpty ? 'A public URL for this policy must be configured before public release.' : privacyUrl}
''';

  static String get terms =>
      '''TurboSave Terms of Use
Effective date: 28 October 2026

Permitted use
Save only content you created, content whose owner has allowed downloading, public-domain works, or works covered by a licence that permits your intended use. Check the individual file's licence and preserve any required credit. Permission must also comply with the source site's terms. Confirm this for every download.

Restrictions
Do not use TurboSave for copyright infringement, unlawful content, private-account access, paywall or DRM circumvention. ${MediaPolicy.restricted ? 'YouTube and identified adult sources are excluded in this edition.' : 'Open edition allows supported public sources without a YouTube/adult domain filter; you remain responsible for permission and applicable age/access requirements.'} Encrypted streams, ordinary playlists and live streams are excluded. A supported TikTok or Instagram slideshow may expose up to 20 separately selectable images. Public HTTPS media pages may be inspected for complete files or compatible MP4 video and AAC audio pairs on Android 10 or newer; private or unsupported posts fail. The app does not remove watermarks or convert formats.

Sources and independence
The source directory contains examples the local Android extractor may attempt, not Google Play-approved sites or guaranteed downloads. Direct HTTPS media files and media pages may also work from other public sites. Check permission for the individual file. TurboSave is independent of those organisations and is not endorsed by them. Availability and source terms can change. Site icons are used for identification.

Files and availability
Android's download manager handles transfers. Failed downloads display their actual state. You can cancel or retry a failed transfer. Browser previews hand the link to the browser; they cannot confirm that a file was saved. Check the browser download list. No warranties are made about source availability, media compatibility or permission to reuse a particular file.

Support and copyright concerns
${supportEmail.isEmpty ? 'A support and copyright contact must be configured before public release.' : 'Contact: $supportEmail'}
Report the source URL, the relevant rights and the issue. Do not send passwords or private tokens. Content remains hosted by its original source.
''';
}
