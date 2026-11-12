import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videodownloader/models/download_task.dart';
import 'package:videodownloader/providers/download_provider.dart';
import 'package:videodownloader/services/android_download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const source = 'https://example.com/clip.mp4';
  testWidgets(
    'start is saved before native handoff and late Android ID survives disposal',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      SharedPreferences.setMockInitialValues({});
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final accepted = Completer<Object?>();
      var called = false;
      String? localId;
      messenger.setMockMethodCallHandler(AndroidDownloadService.channel, (
        call,
      ) async {
        if (call.method == 'inspect') return {'bytes': 1024};
        if (call.method == 'enqueue') {
          final prefs = await SharedPreferences.getInstance();
          final saved =
              (jsonDecode(prefs.getString('queue_v2')!) as List).single;
          expectSync(saved['status'], 'enqueuing');
          expectSync(saved['nativeId'], isNull);
          localId = saved['id'];
          expectSync(localId, startsWith('local_'));
          called = true;
          return accepted.future;
        }
        if (call.method == 'query') return [];
        return null;
      });
      final provider = DownloadProvider();
      try {
        await provider.ready;
        await provider.fetchVideoMetadata(source);
        final start = provider.startDownload(rightsConfirmed: true);
        for (var attempt = 0; attempt < 10 && !called; attempt++) {
          await tester.pump();
        }
        expect(
          called,
          isTrue,
          reason:
              'Native handoff not reached: ${provider.errorMessage}; tasks: ${provider.activeTasks.map((task) => task.status.name).toList()}',
        );
        expect(provider.isPolling, isFalse);
        provider.dispose();
        accepted.complete(777);
        expect(await start, isTrue);
        final prefs = await SharedPreferences.getInstance();
        final saved = (jsonDecode(prefs.getString('queue_v2')!) as List).single;
        expect(saved['id'], localId);
        expect(saved['nativeId'], 777);
        expect(saved['status'], 'queued');
      } finally {
        messenger.setMockMethodCallHandler(
          AndroidDownloadService.channel,
          null,
        );
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'interrupted idless start is retained, failed, removable and never queried',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      SharedPreferences.setMockInitialValues({
        'queue_v2': jsonEncode([
          {
            'id': 'local_interrupted',
            'nativeId': null,
            'status': 'enqueuing',
            'title': 'Interrupted clip',
            'sourceUrl': source,
            'ext': 'mp4',
            'formatId': 'original',
            'size': '1 MB',
            'createdAt': '2026-10-29T00:00:00Z',
          },
        ]),
      });
      final calls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(AndroidDownloadService.channel, (
        call,
      ) async {
        calls.add(call.method);
        return null;
      });
      final provider = DownloadProvider();
      try {
        await provider.ready;
        expect(provider.activeTasks.single.status, TaskStatus.failed);
        expect(
          provider.activeTasks.single.error,
          contains('Check Android Downloads before retrying'),
        );
        final prefs = await SharedPreferences.getInstance();
        expect(
          (jsonDecode(prefs.getString('queue_v2')!) as List).single['status'],
          'failed',
        );
        expect(provider.isPolling, isFalse);
        await provider.cancelTask('local_interrupted');
        expect(provider.activeTasks, isEmpty);
        expect(calls, isEmpty);
      } finally {
        provider.dispose();
        messenger.setMockMethodCallHandler(
          AndroidDownloadService.channel,
          null,
        );
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
