import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videodownloader/providers/download_provider.dart';
import 'package:videodownloader/services/android_download_service.dart';
import 'package:videodownloader/services/video_parser_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final providers = <DownloadProvider>[];
  final calls = <MethodCall>[];
  String? mime;
  PlatformException? cancelError;
  var complete = false;

  Future<DownloadProvider> restore() async {
    final provider = DownloadProvider();
    providers.add(provider);
    await provider.ready;
    return provider;
  }

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    mime = null;
    cancelError = null;
    complete = false;
    calls.clear();
    messenger.setMockMethodCallHandler(AndroidDownloadService.channel, (
      call,
    ) async {
      calls.add(call);
      switch (call.method) {
        case 'inspect':
          return {'bytes': 1024, if (mime != null) 'mime': mime};
        case 'enqueue':
          return 7;
        case 'query':
          return complete
              ? [
                  {
                    'id': 7,
                    'status': 'completed',
                    'uri': 'content://downloads/7',
                  },
                ]
              : [];
        case 'cancel':
          if (cancelError != null) throw cancelError!;
          return null;
        case 'reconcile':
        case 'open':
        case 'share':
          return null;
        default:
          throw StateError('Unexpected native call: ${call.method}');
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

  for (final scenario in [
    ('failed', 'MEDIA_ERROR', 'The source could not be reached.'),
    ('failed', 'BUSY', 'This download does not belong to this app.'),
    ('queued', 'MEDIA_ERROR', 'This download does not belong to this app.'),
  ]) {
    test(
      'cancel preserves ${scenario.$1} task for ${scenario.$2}: ${scenario.$3}',
      () async {
        final record = {
          'id': 'saved_7',
          'nativeId': 7,
          'title': 'Clip',
          'sourceUrl': 'https://example.com/clip.mp4',
          'ext': 'mp4',
          'size': '1 MB',
          'status': scenario.$1,
          'createdAt': '2026-11-01T00:00:00Z',
        };
        SharedPreferences.setMockInitialValues({
          'queue_v2': jsonEncode([record]),
        });
        cancelError = PlatformException(
          code: scenario.$2,
          message: scenario.$3,
        );
        final p = await restore();
        await p.cancelTask('saved_7');
        expect(p.activeTasks.single.nativeDownloadId, 7);
        expect(p.errorMessage, contains(scenario.$3));
        final prefs = await SharedPreferences.getInstance();
        expect(
          (jsonDecode(prefs.getString('queue_v2')!) as List).single['nativeId'],
          7,
        );
      },
    );
  }

  for (final ext in ['mp4', 'webm']) {
    test(
      'direct $ext audio MIME survives saved queue restart and Share',
      () async {
        mime = ' Audio/${ext.toUpperCase()} ; codecs=test';
        var p = await restore();
        await p.fetchVideoMetadata('https://example.com/clip.$ext');
        expect(p.selectedFormat!.isAudioOnly, isTrue);
        expect(await p.startDownload(rightsConfirmed: true), isTrue);
        p.dispose();
        providers.remove(p);
        complete = true;
        p = await restore();
        expect(p.completedTasks.single.format.isAudioOnly, isTrue);
        for (final share in [false, true]) {
          await p.openFile(p.completedTasks.single, share: share);
          expect(calls.last.method, share ? 'share' : 'open');
          expect(calls.last.arguments, {
            'id': 7,
            'uri': 'content://downloads/7',
            'mimeType': 'audio/$ext',
          });
        }
      },
    );
  }

  for (final ext in ['mp4', 'mp3']) {
    test(
      'a legacy native inspection without MIME keeps $ext inference',
      () async {
        final p = await restore();
        await p.fetchVideoMetadata('https://example.com/clip.$ext');
        expect(p.selectedFormat!.isAudioOnly, ext == 'mp3');
      },
    );
  }

  for (final contentType in ['Audio/MP4; codecs=mp4a', 'video/mp4']) {
    test('HEAD inspection respects $contentType for a direct MP4', () async {
      final client = MockClient((request) async {
        expect(request.method, 'HEAD');
        return http.Response('', 200, headers: {'content-type': contentType});
      });
      try {
        final video = await VideoParserService.extractVideoInfo(
          'https://example.com/clip.mp4',
          client: client,
        );
        expect(
          video.formats.single.isAudioOnly,
          contentType.startsWith('Audio/'),
        );
      } finally {
        client.close();
      }
    });
  }
}
