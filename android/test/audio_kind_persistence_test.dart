import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videodownloader/providers/download_provider.dart';
import 'package:videodownloader/services/android_download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final providers = <DownloadProvider>[];
  final actions = <MethodCall>[];
  var ext = 'mp4';
  var audioOnly = true;
  var completed = false;

  Future<DownloadProvider> restore() async {
    final provider = DownloadProvider();
    providers.add(provider);
    await provider.ready;
    return provider;
  }

  void close(DownloadProvider provider) {
    provider.dispose();
    providers.remove(provider);
  }

  Future<void> checkActions(DownloadProvider provider, String mime) async {
    final task = provider.completedTasks.single;
    for (final share in [false, true]) {
      await provider.openFile(task, share: share);
      expect(actions.last.method, share ? 'share' : 'open');
      expect(actions.last.arguments, {
        'id': task.nativeDownloadId,
        'uri': task.filePath,
        'mimeType': mime,
      });
    }
  }

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    ext = 'mp4';
    audioOnly = true;
    completed = false;
    actions.clear();
    messenger.setMockMethodCallHandler(AndroidDownloadService.channel, (
      call,
    ) async {
      switch (call.method) {
        case 'extract':
          return jsonEncode({
            'formats': [
              {
                'id': 'track',
                'ext': ext,
                'url': 'https://example.com/track.$ext',
                'audioOnly': audioOnly,
              },
            ],
          });
        case 'enqueue':
          return 7;
        case 'query':
          return completed
              ? [
                  {
                    'id': 7,
                    'status': 'completed',
                    'uri': 'content://downloads/7',
                    'bytes': 1024,
                    'total': 1024,
                  },
                ]
              : [];
        case 'open':
        case 'share':
          actions.add(call);
          return null;
        case 'reconcile':
          return null;
        default:
          fail('Unexpected native call: ${call.method}');
      }
    });
  });

  tearDown(() {
    for (final provider in providers) {
      provider.dispose();
    }
    providers.clear();
    messenger.setMockMethodCallHandler(AndroidDownloadService.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  for (final container in ['mp4', 'webm']) {
    for (final isAudio in [true, false]) {
      test(
        '$container audioOnly=$isAudio survives queue and Library restart',
        () async {
          ext = container;
          audioOnly = isAudio;
          var provider = await restore();
          await provider.fetchVideoMetadata('https://vimeo.com/123456');
          expect(await provider.startDownload(rightsConfirmed: true), isTrue);
          final prefs = await SharedPreferences.getInstance();
          final queue = jsonDecode(prefs.getString('queue_v2')!) as List;
          expect(queue.single['audioOnly'], isAudio);
          close(provider);

          provider = await restore();
          expect(provider.activeTasks.single.format.isAudioOnly, isAudio);
          completed = true;
          provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
          await pumpEventQueue();
          expect(provider.activeTasks, isEmpty);
          expect(provider.completedTasks.single.format.isAudioOnly, isAudio);
          final library = jsonDecode(prefs.getString('library_v2')!) as List;
          expect(library.single['audioOnly'], isAudio);
          final mime = '${isAudio ? 'audio' : 'video'}/$container';
          await checkActions(provider, mime);
          close(provider);

          provider = await restore();
          expect(provider.completedTasks.single.format.isAudioOnly, isAudio);
          await checkActions(provider, mime);
        },
      );
    }
  }

  final legacyTypes = {
    'mp4': 'video/mp4',
    'webm': 'video/webm',
    'mov': 'video/quicktime',
    'mkv': 'video/x-matroska',
    'mp3': 'audio/mpeg',
    'm4a': 'audio/mp4',
    'ogg': 'audio/ogg',
    'oga': 'audio/ogg',
    'wav': 'audio/wav',
    'flac': 'audio/flac',
  };

  Map<String, Object?> savedRecord(String extension) => {
    'id': 'saved_7',
    'nativeId': 7,
    'title': 'Saved media',
    'sourceUrl': 'https://example.com/saved.$extension',
    'ext': extension,
    'size': '1 MB',
    'status': 'completed',
    'createdAt': '2026-10-30T00:00:00Z',
    'filePath': 'content://downloads/7',
  };

  for (final entry in legacyTypes.entries) {
    test(
      'legacy ${entry.key} without audioOnly keeps extension inference',
      () async {
        SharedPreferences.setMockInitialValues({
          'library_v2': jsonEncode([savedRecord(entry.key)]),
        });
        final provider = await restore();
        expect(
          provider.completedTasks.single.format.isAudioOnly,
          entry.value.startsWith('audio/'),
        );
        await checkActions(provider, entry.value);
      },
    );
  }

  for (final entry in {'mov': 'audio/*', 'mkv': 'audio/x-matroska'}.entries) {
    test(
      'saved audio-only ${entry.key} uses an audio player or share target',
      () async {
        SharedPreferences.setMockInitialValues({
          'library_v2': jsonEncode([
            {...savedRecord(entry.key), 'audioOnly': true},
          ]),
        });
        final provider = await restore();
        expect(provider.completedTasks.single.format.isAudioOnly, isTrue);
        await checkActions(provider, entry.value);
      },
    );
  }
}
