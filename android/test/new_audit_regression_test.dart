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
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  var unknown = false;
  var completed = false;
  var mime = 'video/mp4';
  late DownloadProvider provider;

  Map<String, Object?> record(int id) => {
    'id': 'saved_$id',
    'nativeId': id,
    'title': 'Clip $id',
    'sourceUrl': 'https://example.com/clip.mp4',
    'ext': 'mp4',
    'formatId': 'original',
    'size': '1 MB',
    'status': 'queued',
    'createdAt': '2026-11-01T00:00:00Z',
  };

  void audit(
    String name,
    Future<void> Function(WidgetTester) body, {
    int staleRecords = 0,
  }) {
    testWidgets(name, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      SharedPreferences.setMockInitialValues({
        'queue_v2': jsonEncode(List.generate(staleRecords, (i) => record(i + 1))),
      });
      calls.clear();
      unknown = staleRecords > 0;
      completed = false;
      mime = 'video/mp4';
      messenger.setMockMethodCallHandler(AndroidDownloadService.channel, (call) async {
        calls.add(call);
        switch (call.method) {
          case 'inspect':
            return {'bytes': 4096, 'mime': mime, 'url': call.arguments['url']};
          case 'enqueue':
            return 1000;
          case 'query':
            return [
              for (final id in call.arguments['ids'] as List)
                if (unknown)
                  {'id': id, 'status': 'unknown'}
                else if (completed)
                  {'id': id, 'status': 'completed', 'uri': 'content://downloads/$id',
                   'bytes': 4096, 'total': 4096},
            ];
          case 'cancel':
            if (unknown) {
              throw PlatformException(
                code: 'MEDIA_ERROR',
                message: 'This download does not belong to this app.',
              );
            }
            return null;
          case 'reconcile':
          case 'open':
          case 'share':
            return null;
          default:
            throw StateError('Unexpected native call: ${call.method}');
        }
      });
      provider = DownloadProvider();
      try {
        await provider.ready;
        await body(tester);
      } finally {
        provider.dispose();
        messenger.setMockMethodCallHandler(AndroidDownloadService.channel, null);
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  audit('B1 unknown native tasks must still be removable from Activity', (tester) async {
    expect(provider.activeTasks.single.status, TaskStatus.failed);
    await provider.cancelTask(provider.activeTasks.single.id);
    final prefs = await SharedPreferences.getInstance();
    expect(provider.activeTasks, isEmpty,
        reason: 'Unknown ownership must not trap an already failed local record.');
    expect(jsonDecode(prefs.getString('queue_v2')!), isEmpty);
  }, staleRecords: 1);

  audit('B1 stale records must not permanently occupy all 20 queue slots', (tester) async {
    expect(provider.activeTasks, hasLength(20));
    for (final task in provider.activeTasks.toList()) {
      await provider.cancelTask(task.id);
    }
    await provider.fetchVideoMetadata('https://example.com/new.mp4');
    final started = await provider.startDownload(rightsConfirmed: true);
    expect(started, isTrue, reason: provider.errorMessage);
  }, staleRecords: 20);

  for (final ext in ['mp4', 'webm']) {
    audit('B2 direct audio/$ext must open with the audio MIME returned by native inspect', (tester) async {
      mime = 'audio/$ext';
      await provider.fetchVideoMetadata('https://example.com/audio.$ext');
      expect(await provider.startDownload(rightsConfirmed: true), isTrue);
      completed = true;
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      await provider.openFile(provider.completedTasks.single);
      expect(calls.last.method, 'open');
      expect(calls.last.arguments['mimeType'], 'audio/$ext',
          reason: 'The inspected direct-file audio MIME is currently ignored.');
      expect(provider.completedTasks.single.format.isAudioOnly, isTrue);
    });
  }
}
