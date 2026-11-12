enum MediaLinkKind { directFile, sourcePage }

class MediaPolicy {
  /// Set by --flavor, never by a runtime settings switch.
  static const restricted =
      String.fromEnvironment(
        'FLUTTER_APP_FLAVOR',
        defaultValue: 'restricted',
      ) !=
      'unrestricted';
  static const variantLabel = restricted ? 'Restricted' : 'Open';

  static const extensions = {
    'mp4',
    'webm',
    'mov',
    'mkv',
    'mp3',
    'm4a',
    'ogg',
    'oga',
    'wav',
    'flac',
    'jpg',
    'jpeg',
    'png',
    'webp',
  };
  static const audioExtensions = {'mp3', 'm4a', 'ogg', 'oga', 'wav', 'flac'};
  static const imageExtensions = {'jpg', 'jpeg', 'png', 'webp'};
  static const unsupportedFileExtensions = {
    'apk',
    'exe',
    'dmg',
    'zip',
    'pdf',
    'm3u8',
    'mpd',
  };
  static const sampleUrl =
      'https://download.blender.org/durian/trailer/sintel_trailer-480p.mp4';

  static Uri validate(String value) => classify(value).$1;

  static (Uri, MediaLinkKind) classify(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 443)) {
      throw const FormatException(
        'Use a public HTTPS link without login details.',
      );
    }
    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'\.+$'), '');
    if (host == 'localhost' ||
        host.endsWith('.localhost') ||
        host.endsWith('.local') ||
        host.endsWith('.internal') ||
        host.endsWith('.onion') ||
        host.contains(':') ||
        RegExp(r'^[0-9.]+$').hasMatch(host)) {
      throw const FormatException('Private network links are not supported.');
    }
    if (restricted && _blocked(host)) {
      throw const FormatException(
        'YouTube and identified adult sites are excluded.',
      );
    }
    final ext = uri.path.split('.').last.toLowerCase();
    if (extensions.contains(ext)) {
      return (uri, MediaLinkKind.directFile);
    }
    if (unsupportedFileExtensions.contains(ext)) {
      throw const FormatException(
        'This file type is not a downloadable video, audio, or image source.',
      );
    }
    return (uri, MediaLinkKind.sourcePage);
  }

  static bool _blocked(String host) =>
      const {
        'youtube.com',
        'youtu.be',
        'youtube-nocookie.com',
        'googlevideo.com',
        'ytimg.com',
        '4tube.com',
        'alphaporno.com',
        'beeg.com',
        'cam4.com',
        'chaturbate.com',
        'chaturbate.eu',
        'chaturbate.global',
        'empflix.com',
        'eporner.com',
        'hclips.com',
        'hdzog.com',
        'hdzog.tube',
        'hellporno.com',
        'hellporno.net',
        'hotmovs.com',
        'hotmovs.tube',
        'manyvids.com',
        'nubiles-porn.com',
        'pornbox.com',
        'pornerbros.com',
        'pornflip.com',
        'pornhub.com',
        'pornhub.net',
        'pornhub.org',
        'pornhubpremium.com',
        'pornotube.com',
        'porntop.com',
        'porntube.com',
        'redtube.com',
        'redtube.com.br',
        'spankbang.com',
        'stripchat.com',
        'sunporno.com',
        'thumbzilla.com',
        'tnaflix.com',
        'tube8.com',
        'xhday.com',
        'xvideos.com',
        'xnxx.com',
        'xhamster.com',
        'xhvid.com',
        'xnxx3.com',
        'onlyfans.com',
        'fansly.com',
        'youporn.com',
        'zenporn.com',
      }.any((domain) => host == domain || host.endsWith('.$domain')) ||
      RegExp(
        r'(^|[.\-])(pornhub|porno|porn|xxx|xvideos|xnxx|redtube|erotic)([.\-]|$)',
      ).hasMatch(host);
}
