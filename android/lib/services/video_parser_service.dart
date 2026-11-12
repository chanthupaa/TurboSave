import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/format_option.dart';
import '../models/video_item.dart';
import 'android_download_service.dart';
import 'media_policy.dart';

/// Android checks public pages using the Python/yt-dlp runtime bundled in the APK.
class VideoParserService {
  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<VideoItem> extractVideoInfo(
    String url, {
    http.Client? client,
  }) async {
    final (uri, kind) = MediaPolicy.classify(url);
    if (kind == MediaLinkKind.sourcePage) {
      return _extractPage(uri);
    }
    final ext = uri.path.split('.').last.toLowerCase();
    int? bytes;
    String? mime;
    // Android checks response type and every redirect before queueing a file.
    // The browser preview cannot reliably inspect cross-origin headers.
    if (isAndroid && client == null) {
      final metadata = await AndroidDownloadService.inspect(uri.toString());
      bytes = (metadata['bytes'] as num?)?.toInt();
      mime = metadata['mime'] as String?;
    } else if (client != null) {
      final request = http.Request('HEAD', uri)..followRedirects = false;
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200 ||
          !_validMime(response.headers['content-type'] ?? '')) {
        throw const FormatException(
          'The link did not return a downloadable video or audio file.',
        );
      }
      bytes = int.tryParse(response.headers['content-length'] ?? '');
      mime = response.headers['content-type'];
    }
    final title = uri.toString() == MediaPolicy.sampleUrl
        ? 'Sintel trailer — Blender Foundation (CC BY 3.0)'
        : uri.pathSegments.last;
    final size = bytes == null || bytes < 0
        ? 'Size unavailable'
        : '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return VideoItem(
      id: uri.toString(),
      title: title,
      author: uri.host,
      authorAvatar: '',
      sourceUrl: uri.toString(),
      thumbnailUrl: '',
      duration: 'Original file',
      views: '',
      uploadDate: '',
      platform: VideoPlatform.direct,
      customPlatformName: 'Direct file',
      domain: uri.host,
      formats: [
        FormatOption(
          id: 'original',
          label: 'Original ${ext.toUpperCase()}',
          resolution: 'Original',
          ext: ext,
          estimatedSize: size,
          isAudioOnly:
              MediaPolicy.audioExtensions.contains(ext) ||
              (mime ?? '')
                  .split(';')
                  .first
                  .trim()
                  .toLowerCase()
                  .startsWith('audio/'),
          isImage:
              MediaPolicy.imageExtensions.contains(ext) ||
              (mime ?? '')
                  .split(';')
                  .first
                  .trim()
                  .toLowerCase()
                  .startsWith('image/'),
          qualityScore: 'Original',
          downloadUrl: uri.toString(),
        ),
      ],
    );
  }

  static Future<VideoItem> _extractPage(Uri uri) async {
    if (!isAndroid) {
      throw const FormatException(
        'Website links are checked locally in the Android app. The browser preview supports direct media links only.',
      );
    }
    try {
      final payload = jsonDecode(
        await AndroidDownloadService.extract(uri.toString()),
      );
      if (payload is! Map) {
        throw const FormatException(
          'The extractor returned an invalid response.',
        );
      }
      if (payload.containsKey('error')) {
        throw FormatException(
          payload['error']?.toString() ?? 'This post is unavailable.',
        );
      }
      final rawFormats = payload['formats'];
      if (rawFormats is! List) {
        throw const FormatException('No downloadable file was found.');
      }
      final formats = <FormatOption>[];
      bool? adaptiveSupported;
      for (final raw in rawFormats) {
        if (raw is! Map) continue;
        final mediaUri = Uri.tryParse(raw['url']?.toString() ?? '');
        final ext = raw['ext']?.toString().toLowerCase() ?? '';
        if (mediaUri?.scheme != 'https' ||
            !MediaPolicy.extensions.contains(ext)) {
          continue;
        }
        try {
          MediaPolicy.validate(mediaUri.toString());
        } on FormatException {
          continue;
        }
        final width = (raw['width'] as num?)?.toInt();
        final height = (raw['height'] as num?)?.toInt();
        final quality = width != null && height != null
            ? min(width, height)
            : height;
        final size = (raw['size'] as num?)?.toInt();
        final isAudio = raw['audioOnly'] == true;
        final isImage = raw['imageOnly'] == true;
        final imageIndex = (raw['imageIndex'] as num?)?.toInt();
        final bitrate = (raw['abr'] as num?)?.round();
        final language = raw['language'] as String?;
        var label = isImage
            ? [
                'Image ${imageIndex ?? formats.length + 1}',
                ext.toUpperCase(),
                if (width != null && height != null) '$width×$height',
              ].join(' · ')
            : isAudio
            ? [
                'Audio ${ext.toUpperCase()}',
                if (bitrate != null) '$bitrate kbps',
                if (language != null && language.isNotEmpty) language,
              ].join(' · ')
            : quality == null
            ? 'Video ${ext.toUpperCase()}'
            : '${quality}p ${ext.toUpperCase()}'
                  '${width != null && height != null ? ' · $width×$height' : ''}';
        if (!isAudio && raw['audioUnknown'] == true) {
          label = '$label · Sound unverified';
        }
        final rawHeaders = raw['headers'];
        final headers = <String, String>{};
        if (rawHeaders is Map) {
          for (final entry in rawHeaders.entries) {
            final key = entry.key.toString();
            if (const {
                  'user-agent',
                  'referer',
                  'accept',
                }.contains(key.toLowerCase()) &&
                entry.value is String &&
                (entry.value as String).length < 1000 &&
                !(entry.value as String).contains(RegExp(r'[\r\n\x00]'))) {
              headers[key] = entry.value as String;
            }
          }
        }
        final sessionCookie = raw['sessionCookie'];
        if (sessionCookie is String &&
            sessionCookie.isNotEmpty &&
            sessionCookie.length <= 4096 &&
            !sessionCookie.contains(RegExp(r'[\r\n\x00]'))) {
          headers['Cookie'] = sessionCookie;
        }
        final audioUri = Uri.tryParse(raw['audioUrl']?.toString() ?? '');
        final hasAudioPair =
            raw['requiresMerge'] == true &&
            ext == 'mp4' &&
            !isAudio &&
            !isImage &&
            audioUri?.scheme == 'https' &&
            const {'m4a', 'mp4'}.contains(raw['audioExt']);
        if (raw['requiresMerge'] == true && !hasAudioPair) continue;
        if (hasAudioPair) {
          adaptiveSupported ??= await AndroidDownloadService.supportsAdaptive();
          if (!adaptiveSupported) continue;
          try {
            MediaPolicy.validate(audioUri.toString());
          } on FormatException {
            continue;
          }
          label = '$label · Video + audio (merge required)';
        }
        final audioHeaders = <String, String>{};
        if (hasAudioPair && raw['audioHeaders'] is Map) {
          for (final entry in (raw['audioHeaders'] as Map).entries) {
            final key = entry.key.toString();
            final value = entry.value;
            if (const {
                  'user-agent',
                  'referer',
                  'accept',
                }.contains(key.toLowerCase()) &&
                value is String &&
                value.length < 1000 &&
                !value.contains(RegExp(r'[\r\n\x00]'))) {
              audioHeaders[key] = value;
            }
          }
        }
        final audioCookie = raw['audioSessionCookie'];
        if (hasAudioPair &&
            audioCookie is String &&
            audioCookie.isNotEmpty &&
            audioCookie.length <= 4096 &&
            !audioCookie.contains(RegExp(r'[\r\n\x00]'))) {
          audioHeaders['Cookie'] = audioCookie;
        }
        formats.add(
          FormatOption(
            id: raw['id']?.toString() ?? '$ext-${formats.length}',
            label: label,
            resolution: quality == null ? 'Original' : '${quality}p',
            ext: ext,
            estimatedSize: size == null
                ? 'Size unavailable'
                : '${(size / 1048576).toStringAsFixed(1)} MB',
            isAudioOnly: isAudio,
            isImage: isImage,
            qualityScore: quality?.toString() ?? 'Original',
            downloadUrl: mediaUri.toString(),
            httpHeaders: headers,
            audioUrl: hasAudioPair ? audioUri.toString() : null,
            audioHttpHeaders: audioHeaders,
            requiresMerge: hasAudioPair,
            extracted: true,
            bitrate: bitrate,
            language: language,
          ),
        );
      }
      if (formats.isEmpty) {
        throw const FormatException(
          'No complete downloadable file was found for this post.',
        );
      }
      final host = uri.host.toLowerCase();
      final names = {
        'instagram.com': VideoPlatform.instagram,
        'tiktok.com': VideoPlatform.tiktok,
        'facebook.com': VideoPlatform.facebook,
        'fb.watch': VideoPlatform.facebook,
        'x.com': VideoPlatform.twitter,
        'twitter.com': VideoPlatform.twitter,
        'reddit.com': VideoPlatform.reddit,
        'pinterest.com': VideoPlatform.pinterest,
        'vimeo.com': VideoPlatform.vimeo,
        'dailymotion.com': VideoPlatform.dailymotion,
        'soundcloud.com': VideoPlatform.soundcloud,
        'threads.net': VideoPlatform.threads,
      };
      VideoPlatform platform = VideoPlatform.direct;
      for (final entry in names.entries) {
        if (host == entry.key || host.endsWith('.${entry.key}')) {
          platform = entry.value;
          break;
        }
      }
      return VideoItem(
        id: uri.toString(),
        title: payload['title']?.toString() ?? 'Media',
        author: payload['author']?.toString() ?? host,
        authorAvatar: '',
        sourceUrl: uri.toString(),
        thumbnailUrl: payload['thumbnail']?.toString() ?? '',
        duration: payload['duration'] == null
            ? ''
            : '${payload['duration']} sec',
        views: '',
        uploadDate: '',
        platform: platform,
        customPlatformName: platform == VideoPlatform.direct ? host : null,
        domain: host,
        formats: formats,
      );
    } on PlatformException catch (error) {
      throw FormatException(
        error.message ?? 'Could not check this link locally.',
      );
    }
  }

  static bool _validMime(String value) {
    final mime = value.split(';').first.trim().toLowerCase();
    return mime.startsWith('video/') ||
        mime.startsWith('audio/') ||
        const {'image/jpeg', 'image/png', 'image/webp'}.contains(mime);
  }
}
