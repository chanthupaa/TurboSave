import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:videodownloader/services/android_download_service.dart';
import 'package:videodownloader/services/video_parser_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<Map<String, Object?>> formats;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    formats = [
      {
        'id': '720+a',
        'url': 'https://cdn.example.com/video.mp4',
        'ext': 'mp4',
        'height': 720,
        'audioOnly': false,
        'requiresMerge': true,
        'audioUrl': 'https://audio.example.com/audio.m4a',
        'audioExt': 'm4a',
        'headers': {'Referer': 'https://example.com/post'},
        'audioHeaders': {'User-Agent': 'Audio client', 'Authorization': 'bad'},
        'audioSessionCookie': 'session=temporary',
      },
      {
        'id': 'complete',
        'url': 'https://cdn.example.com/complete.mp4',
        'ext': 'mp4',
        'height': 480,
      },
    ];
    messenger.setMockMethodCallHandler(
      AndroidDownloadService.channel,
      (call) async => call.method == 'supportsAdaptive'
          ? true
          : jsonEncode({'formats': formats}),
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(AndroidDownloadService.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'composite carries independent URLs and headers with an honest label',
    () async {
      final video = await VideoParserService.extractVideoInfo(
        'https://example.com/post',
      );
      expect(video.formats, hasLength(2));
      final paired = video.formats.first;
      expect(paired.requiresMerge, isTrue);
      expect(paired.audioUrl, 'https://audio.example.com/audio.m4a');
      expect(paired.httpHeaders, {'Referer': 'https://example.com/post'});
      expect(paired.audioHttpHeaders, {
        'User-Agent': 'Audio client',
        'Cookie': 'session=temporary',
      });
      expect(paired.label, contains('merge required'));
      expect(video.formats.last.requiresMerge, isFalse);
      expect(video.formats.last.audioUrl, isNull);
    },
  );

  test(
    'invalid composite audio URL is discarded without losing complete format',
    () async {
      formats.first['audioUrl'] = 'https://localhost/audio.m4a';
      final video = await VideoParserService.extractVideoInfo(
        'https://example.com/post',
      );
      expect(video.formats.map((item) => item.id), ['complete']);
    },
  );

  test('unsupported Android version hides merge choices', () async {
    messenger.setMockMethodCallHandler(
      AndroidDownloadService.channel,
      (call) async => call.method == 'supportsAdaptive'
          ? false
          : jsonEncode({'formats': formats}),
    );
    final video = await VideoParserService.extractVideoInfo(
      'https://example.com/post',
    );
    expect(video.formats.map((item) => item.id), ['complete']);
  });
}
