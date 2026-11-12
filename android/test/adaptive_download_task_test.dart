import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videodownloader/models/format_option.dart';
import 'package:videodownloader/models/download_task.dart';
import 'package:videodownloader/providers/download_provider.dart';
import 'package:videodownloader/services/android_download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('adaptive request survives queue, restart, retry and final URI', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final enqueues = <Map<Object?, Object?>>[];
    var nextId = 40;
    var completed = false;
    messenger.setMockMethodCallHandler(AndroidDownloadService.channel, (
      call,
    ) async {
      switch (call.method) {
        case 'inspect':
          return {'bytes': 1024};
        case 'enqueue':
          enqueues.add(Map<Object?, Object?>.from(call.arguments as Map));
          return ++nextId;
        case 'query':
          if (!completed) return [];
          return [
            {
              'id': nextId,
              'status': 'completed',
              'finalUri': 'content://media/41',
            },
          ];
        default:
          return null;
      }
    });
    DownloadProvider? provider;
    try {
      provider = DownloadProvider();
      await provider.ready;
      await provider.fetchVideoMetadata('https://example.com/video.mp4');
      expect(
        await provider.startDownloads(const [
          FormatOption(
            id: 'adaptive',
            label: 'Adaptive MP4',
            resolution: '720p',
            ext: 'mp4',
            estimatedSize: '1 MB',
            qualityScore: '720',
            downloadUrl: 'https://example.com/video.mp4',
            extracted: true,
            audioUrl: 'https://example.com/audio.m4a',
            audioHttpHeaders: {'Referer': 'https://example.com/'},
          ),
        ], rightsConfirmed: true),
        isTrue,
      );
      expect(enqueues.single['audioUrl'], 'https://example.com/audio.m4a');
      expect(enqueues.single['audioHeaders'], {
        'Referer': 'https://example.com/',
      });
      final prefs = await SharedPreferences.getInstance();
      var record = (jsonDecode(prefs.getString('queue_v2')!) as List).single;
      expect(record['audioUrl'], 'https://example.com/audio.m4a');
      expect(record['audioHeaders'], {'Referer': 'https://example.com/'});
      provider.dispose();

      provider = DownloadProvider();
      await provider.ready;
      final restored = provider.activeTasks.single;
      expect(restored.audioUrl, 'https://example.com/audio.m4a');
      expect(restored.audioHeaders, {'Referer': 'https://example.com/'});
      restored.status = TaskStatus.failed;
      await provider.retryTask(restored.id);
      expect(enqueues.last['audioUrl'], 'https://example.com/audio.m4a');
      expect(enqueues.last['audioHeaders'], {
        'Referer': 'https://example.com/',
      });
      record = (jsonDecode(prefs.getString('queue_v2')!) as List).single;
      expect(record['audioUrl'], 'https://example.com/audio.m4a');

      completed = true;
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(provider.completedTasks.single.filePath, 'content://media/41');
      expect(prefs.getString('library_v2'), contains('content://media/41'));
    } finally {
      provider?.dispose();
      messenger.setMockMethodCallHandler(AndroidDownloadService.channel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('legacy queue record restores without adaptive fields', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({
      'queue_v2': jsonEncode([
        {
          'id': 'old',
          'nativeId': 7,
          'status': 'failed',
          'title': 'Old file',
          'sourceUrl': 'https://example.com/video.mp4',
          'ext': 'mp4',
          'size': '1 MB',
          'createdAt': '2026-10-29T00:00:00Z',
        },
      ]),
    });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      AndroidDownloadService.channel,
      (call) async => null,
    );
    final provider = DownloadProvider();
    try {
      await provider.ready;
      expect(provider.activeTasks.single.audioUrl, isNull);
      expect(provider.activeTasks.single.audioHeaders, isEmpty);
    } finally {
      provider.dispose();
      messenger.setMockMethodCallHandler(AndroidDownloadService.channel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
