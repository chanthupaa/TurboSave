import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:videodownloader/services/android_download_service.dart';
import 'package:videodownloader/services/video_parser_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Map<String, Object> format;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    format = {
      'id': 'original',
      'url': 'https://cdn.example.com/clip.mp4',
      'ext': 'mp4',
      'audioOnly': false,
      'audioUnknown': true,
    };
    messenger.setMockMethodCallHandler(AndroidDownloadService.channel, (
      call,
    ) async {
      expect(call.method, 'extract');
      return jsonEncode({
        'title': 'HTML5 video',
        'formats': [format],
      });
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(AndroidDownloadService.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'unknown-codec video stays selectable with an honest sound label',
    () async {
      final video = await VideoParserService.extractVideoInfo(
        'https://example.com/post',
      );
      expect(video.formats.single.isAudioOnly, isFalse);
      expect(video.formats.single.label, 'Video MP4 · Sound unverified');
      expect(video.formats.single.downloadUrl, format['url']);
      expect(video.formats.single.extracted, isTrue);
    },
  );

  test('known complete formats retain their existing labels', () async {
    format['audioUnknown'] = false;
    format['height'] = 720;
    final video = await VideoParserService.extractVideoInfo(
      'https://example.com/post',
    );
    expect(video.formats.single.label, '720p MP4');
  });

  test('old native payloads without the new field remain compatible', () async {
    format.remove('audioUnknown');
    final video = await VideoParserService.extractVideoInfo(
      'https://example.com/post',
    );
    expect(video.formats.single.label, 'Video MP4');
  });
}
