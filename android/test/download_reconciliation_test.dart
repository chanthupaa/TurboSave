import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videodownloader/models/download_task.dart';
import 'package:videodownloader/providers/download_provider.dart';
import 'package:videodownloader/services/android_download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const source = 'https://example.com/clip.mp4';

  for (final legacy in [false, true]) {
    testWidgets(
      'unknown ID is persisted as failed and leaves polling (legacy: $legacy)',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        SharedPreferences.setMockInitialValues({});
        final queries = <List<int>>[];
        var id = 100;
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(AndroidDownloadService.channel, (
          call,
        ) async {
          switch (call.method) {
            case 'inspect':
              return {'bytes': 1024};
            case 'enqueue':
              return ++id;
            case 'query':
              final ids = List<int>.from(call.arguments['ids']);
              queries.add(ids);
              if (legacy && ids.contains(101)) {
                throw PlatformException(
                  code: 'MEDIA_ERROR',
                  message: 'This download does not belong to this app.',
                );
              }
              return ids
                  .map(
                    (id) => id == 101
                        ? {'id': id, 'status': 'unknown'}
                        : {
                            'id': id,
                            'status': 'completed',
                            'uri': 'content://downloads/$id',
                          },
                  )
                  .toList();
            default:
              return null;
          }
        });
        final provider = DownloadProvider();
        try {
          await provider.ready;
          await provider.fetchVideoMetadata(source);
          await provider.startDownload(rightsConfirmed: true);
          await provider.startDownload(rightsConfirmed: true);
          await tester.pump(const Duration(seconds: 2));
          await tester.pump();
          final stale = provider.activeTasks.single;
          expect(stale.nativeDownloadId, 101);
          expect(stale.status, TaskStatus.failed);
          expect(
            stale.error,
            contains('Android no longer recognises this download'),
          );
          expect(provider.completedTasks.single.nativeDownloadId, 102);
          final prefs = await SharedPreferences.getInstance();
          final saved = jsonDecode(prefs.getString('queue_v2')!) as List;
          expect(saved.single['status'], 'failed');
          expect(provider.isPolling, isFalse);
          final queryCount = queries.length;
          await tester.pump(const Duration(seconds: 10));
          expect(queries.length, queryCount);
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

  testWidgets(
    'transient per-item errors preserve the job and do not block completion of others',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      SharedPreferences.setMockInitialValues({});
      var id = 100;
      var recover = false;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(AndroidDownloadService.channel, (
        call,
      ) async {
        switch (call.method) {
          case 'inspect':
            return {'bytes': 1024};
          case 'enqueue':
            return ++id;
          case 'query':
            return (call.arguments['ids'] as List)
                .map(
                  (id) => id == 101 && !recover
                      ? {
                          'id': id,
                          'status': 'error',
                          'errorType': 'SecurityException',
                        }
                      : {
                          'id': id,
                          'status': 'completed',
                          'uri': 'content://downloads/$id',
                        },
                )
                .toList();
          default:
            return null;
        }
      });
      final provider = DownloadProvider();
      try {
        await provider.ready;
        await provider.fetchVideoMetadata(source);
        await provider.startDownload(rightsConfirmed: true);
        await provider.startDownload(rightsConfirmed: true);
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
        expect(provider.completedTasks.single.nativeDownloadId, 102);
        expect(provider.activeTasks.single.status, TaskStatus.queued);
        expect(provider.isPolling, isTrue);
        recover = true;
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
        expect(provider.completedTasks, hasLength(2));
        expect(provider.activeTasks, isEmpty);
        expect(provider.isPolling, isFalse);
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
