import 'format_option.dart';

enum VideoPlatform {
  tiktok,
  instagram,
  twitter,
  facebook,
  reddit,
  pinterest,
  vimeo,
  dailymotion,
  soundcloud,
  threads,
  direct,
}

class VideoItem {
  final String id;
  final String title;
  final String author;
  final String authorAvatar;
  final String sourceUrl;
  final String thumbnailUrl;
  final String duration;
  final String views;
  final String uploadDate;
  final VideoPlatform platform;
  final List<FormatOption> formats;
  final String? customPlatformName;
  final String? domain;

  const VideoItem({
    required this.id,
    required this.title,
    required this.author,
    required this.authorAvatar,
    required this.sourceUrl,
    required this.thumbnailUrl,
    required this.duration,
    required this.views,
    required this.uploadDate,
    required this.platform,
    required this.formats,
    this.customPlatformName,
    this.domain,
  });

  String get platformName {
    if (customPlatformName != null && customPlatformName!.isNotEmpty) {
      return customPlatformName!;
    }
    switch (platform) {
      case VideoPlatform.tiktok:
        return 'TikTok';
      case VideoPlatform.instagram:
        return 'Instagram';
      case VideoPlatform.twitter:
        return 'X (Twitter)';
      case VideoPlatform.facebook:
        return 'Facebook';
      case VideoPlatform.reddit:
        return 'Reddit';
      case VideoPlatform.pinterest:
        return 'Pinterest';
      case VideoPlatform.vimeo:
        return 'Vimeo';
      case VideoPlatform.dailymotion:
        return 'Dailymotion';
      case VideoPlatform.soundcloud:
        return 'SoundCloud';
      case VideoPlatform.threads:
        return 'Threads';
      case VideoPlatform.direct:
        return 'Direct Link';
    }
  }
}
