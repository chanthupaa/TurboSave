// Audit only: native methods are simulated. These tests do not certify Android.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:videodownloader/models/download_task.dart';
import 'package:videodownloader/providers/download_provider.dart';
import 'package:videodownloader/screens/downloader_screen.dart';
import 'package:videodownloader/services/android_download_service.dart';
import 'package:videodownloader/services/media_policy.dart';
import 'package:videodownloader/services/video_parser_service.dart';

const page = 'https://vimeo.com/123456';
const media = 'https://media.example.com/test.mp4';
Map<String, dynamic> format([String url = media]) => {
  'id': '720',
  'url': url,
  'ext': 'mp4',
  'height': 720,
  'size': 1048576,
};
Map<String, dynamic> record(int id) => {
  'id': 'android_$id',
  'nativeId': id,
  'title': 'Audit sample',
  'sourceUrl': media,
  'ext': 'mp4',
  'formatId': 'original',
  'size': '1 MB',
  'progress': 0.0,
  'status': 'failed',
  'createdAt': '2026-10-25T00:00:00.000Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  final providers = <DownloadProvider>[];
  late Future<Object?> Function(MethodCall) handler;
  var nativeId = 100;
  List<Map<String, dynamic>> snapshots = [];
  Future<DownloadProvider> provider() async {
    final value = DownloadProvider();
    providers.add(value);
    await value.ready;
    return value;
  }

  void auditTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        for (final value in providers) {
          value.dispose();
        }
        providers.clear();
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    snapshots = [];
    nativeId = 100;
    handler = (call) async => switch (call.method) {
      'extract' => jsonEncode({
        'title': 'Audit sample',
        'formats': [format()],
      }),
      'inspect' => {'bytes': 1048576},
      'enqueue' => ++nativeId,
      'query' => snapshots,
      _ => null,
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidDownloadService.channel, (call) {
          calls.add(call);
          return handler(call);
        });
  });
  tearDown(() {
    for (final value in providers) {
      value.dispose();
    }
    providers.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidDownloadService.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('policy blocks YouTube aliases, CDN hosts and known adult domains', () {
    for (final url in [
      'https://youtube.com/watch?v=test',
      'https://music.youtube.com/watch?v=test',
      'https://youtu.be/test',
      'https://www.youtube.com./shorts/test',
      'https://rr1.googlevideo.com/test.mp4',
      'https://i.ytimg.com/test.mp4',
      'https://www.pornhub.com/test',
      'https://onlyfans.com/test',
      'https://cdn.xxx.example/test.mp4',
    ]) {
      expect(
        () => MediaPolicy.validate(url),
        throwsFormatException,
        reason: url,
      );
    }
  });
  test(
    'policy rejects private, credentialed, non-HTTPS and playlist inputs',
    () {
      for (final url in [
        'http://example.com/test.mp4',
        'https://localhost/test.mp4',
        'https://192.168.1.2/test.mp4',
        'https://[::1]/test.mp4',
        'https://user:password@example.com/test.mp4',
        'https://example.com:8443/test.mp4',
        'https://example.com/test.m3u8',
        'https://example.com/test.apk',
      ]) {
        expect(
          () => MediaPolicy.validate(url),
          throwsFormatException,
          reason: url,
        );
      }
    },
  );
  test('policy distinguishes direct audio/video from source pages', () {
    expect(MediaPolicy.classify(media).$2, MediaLinkKind.directFile);
    expect(
      MediaPolicy.classify('https://example.com/audio.M4A?key=sample').$2,
      MediaLinkKind.directFile,
    );
    expect(MediaPolicy.classify(page).$2, MediaLinkKind.sourcePage);
  });
  test('blocked links never reach the native extractor', () async {
    await expectLater(
      VideoParserService.extractVideoInfo('https://youtu.be/test'),
      throwsFormatException,
    );
    expect(calls, isEmpty);
  });
  test(
    'direct-file inspection validates MIME and obtains actual size',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'HEAD');
        expect(request.followRedirects, isFalse);
        return http.Response(
          '',
          200,
          headers: {'content-type': 'video/mp4', 'content-length': '1048576'},
        );
      });
      final video = await VideoParserService.extractVideoInfo(
        media,
        client: client,
      );
      expect(video.formats.single.estimatedSize, '1.0 MB');
      client.close();
    },
  );
  test(
    'direct-file inspection rejects JSON, error pages and redirects',
    () async {
      for (final response in [
        http.Response('{}', 200, headers: {'content-type': 'application/json'}),
        http.Response('', 404, headers: {'content-type': 'video/mp4'}),
        http.Response(
          '',
          302,
          headers: {'location': 'https://localhost/test.mp4'},
        ),
      ]) {
        final client = MockClient((_) async => response);
        await expectLater(
          VideoParserService.extractVideoInfo(media, client: client),
          throwsFormatException,
        );
        client.close();
      }
    },
  );
  test(
    'page extraction drops unsafe media and disallowed request headers',
    () async {
      handler = (_) async => jsonEncode({
        'formats': [
          format('http://media.example.com/test.mp4'),
          format('https://localhost/test.mp4'),
          format('https://googlevideo.com/test.mp4'),
          {
            ...format(),
            'headers': {
              'User-Agent': 'Audit',
              'Cookie': 'private',
              'Referer': 'bad\r\nvalue',
              'Authorization': 'private',
            },
          },
        ],
      });
      final video = await VideoParserService.extractVideoInfo(page);
      expect(video.formats, hasLength(1));
      expect(video.formats.single.httpHeaders, {'User-Agent': 'Audit'});
      expect(video.formats.single.extracted, isTrue);
    },
  );
  test(
    'page extraction errors, invalid payloads and empty formats fail safely',
    () async {
      for (final payload in [
        '[]',
        '{"error":"Post unavailable"}',
        '{}',
        '{"formats":[]}',
      ]) {
        handler = (_) async => payload;
        await expectLater(
          VideoParserService.extractVideoInfo(page),
          throwsFormatException,
        );
      }
    },
  );
  auditTest('rights confirmation is enforced before enqueue', (tester) async {
    final p = await provider();
    await p.fetchVideoMetadata(page);
    expect(await p.startDownload(rightsConfirmed: false), isFalse);
    expect(calls.where((call) => call.method == 'enqueue'), isEmpty);
  });
  auditTest('Android queue polls real states and persists a completed URI', (
    tester,
  ) async {
    final p = await provider();
    await p.fetchVideoMetadata(page);
    expect(await p.startDownload(rightsConfirmed: true), isTrue);
    expect(p.activeTasks.single.nativeDownloadId, 101);
    snapshots = [
      {'id': 101, 'status': 'downloading', 'bytes': 500, 'total': 1000},
    ];
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(p.activeTasks.single.progress, 0.5);
    snapshots = [
      {'id': 101, 'status': 'completed', 'uri': 'content://downloads/101'},
    ];
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(p.activeTasks, isEmpty);
    expect(p.completedTasks.single.progress, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('library_v2'), contains('content://downloads/101'));
    expect(prefs.getString('queue_v2'), '[]');
  });
  auditTest(
    'missing saved URI and native errors never become completed files',
    (tester) async {
      final p = await provider();
      await p.fetchVideoMetadata(page);
      await p.startDownload(rightsConfirmed: true);
      snapshots = [
        {'id': 101, 'status': 'completed'},
      ];
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(p.activeTasks.single.status, TaskStatus.failed);
      expect(p.completedTasks, isEmpty);
    },
  );
  auditTest('cancel removes the Android job and persisted queue record', (
    tester,
  ) async {
    final p = await provider();
    await p.fetchVideoMetadata(page);
    await p.startDownload(rightsConfirmed: true);
    await p.cancelTask(p.activeTasks.single.id);
    expect(p.activeTasks, isEmpty);
    expect(calls.lastWhere((c) => c.method == 'cancel').arguments, {'id': 101});
    expect((await SharedPreferences.getInstance()).getString('queue_v2'), '[]');
  });
  auditTest(
    'history defaults off and query-bearing source links are not remembered',
    (tester) async {
      final p = await provider();
      await p.fetchVideoMetadata(page);
      expect(p.recentLinks, isEmpty);
      p.toggleHistory(true);
      await p.fetchVideoMetadata('$page?token=sample');
      expect(p.recentLinks, isEmpty);
      await p.fetchVideoMetadata(page);
      expect(p.recentLinks, [page]);
      p.toggleHistory(false);
      expect(p.recentLinks, isEmpty);
    },
  );
  auditTest(
    'latest request wins when extraction responses arrive out of order',
    (tester) async {
      final first = Completer<Object?>();
      handler = (call) async => call.arguments['url'] == page
          ? first.future
          : jsonEncode({
              'title': 'Second post',
              'formats': [format()],
            });
      final p = await provider();
      final pending = p.fetchVideoMetadata(page);
      await tester.pump();
      await p.fetchVideoMetadata('https://vimeo.com/654321');
      first.complete(
        jsonEncode({
          'title': 'Old post',
          'formats': [format()],
        }),
      );
      await pending;
      expect(p.currentVideo!.title, 'Second post');
      expect(p.isExtracting, isFalse);
    },
  );
  auditTest(
    'clearing a pending inspection prevents stale results from reopening it',
    (tester) async {
      final pending = Completer<Object?>();
      handler = (_) => pending.future;
      final p = await provider();
      final fetch = p.fetchVideoMetadata(page);
      await tester.pump();
      p.clearCurrentVideo();
      pending.complete(
        jsonEncode({
          'formats': [format()],
        }),
      );
      await fetch;
      expect(p.currentVideo, isNull);
      expect(p.isExtracting, isFalse);
    },
  );
  auditTest(
    'native extraction error is visible and does not leave loading stuck',
    (tester) async {
      handler = (_) async =>
          throw PlatformException(code: 'extract_failed', message: 'Offline');
      final p = await provider();
      await p.fetchVideoMetadata(page);
      expect(p.errorMessage, 'Offline');
      expect(p.isExtracting, isFalse);
      expect(p.currentVideo, isNull);
    },
  );
  test('non-Android preview refuses social-post extraction', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await expectLater(
      VideoParserService.extractVideoInfo(page),
      throwsFormatException,
    );
    expect(calls, isEmpty);
  });

  // These checks deliberately assert desired behavior. Keep failures visible:
  // they are findings to repair later, not changes to the recovered app.
  group('REGRESSION: known pipeline defects', () {
    auditTest(
      'media details must render without Material/ListTile assertions',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final p = await provider();
        await p.fetchVideoMetadata(page);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: p,
            child: MaterialApp(
              home: Scaffold(
                body: DownloaderScreen(onNavigateToDownloads: () {}),
              ),
            ),
          ),
        );
        await tester.pump();
        final error = tester.takeException();
        await tester.pumpWidget(const SizedBox());
        expect(
          error,
          isNull,
          reason:
              'Opening valid media details must not emit framework assertions',
        );
      },
    );
    auditTest('one corrupt restored record must not hide later valid records', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'queue_v2': jsonEncode([
          record(1),
          {'broken': true},
          record(2),
        ]),
      });
      final p = await provider();
      expect(p.activeTasks, hasLength(2));
    });
    auditTest(
      'opening saved MP4 must use video/mp4 for compatible player matching',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'library_v2': jsonEncode([
            {
              ...record(1),
              'status': 'completed',
              'filePath': 'content://downloads/1',
            },
          ]),
        });
        final p = await provider();
        await p.openFile(p.completedTasks.single);
        expect(calls.last.arguments['mimeType'], 'video/mp4');
      },
    );
    auditTest(
      'retry must retain control of replacement if old-job cleanup fails',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'queue_v2': jsonEncode([record(1)]),
        });
        final normal = handler;
        handler = (call) async {
          if (call.method == 'cancel') {
            throw PlatformException(code: 'cleanup_failed');
          }
          return normal(call);
        };
        final p = await provider();
        await p.retryTask(p.activeTasks.single.id);
        expect(calls.where((c) => c.method == 'enqueue'), hasLength(1));
        expect(p.activeTasks.single.nativeDownloadId, 101);
      },
    );
    auditTest('repeated Retry taps should enqueue only one replacement', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'queue_v2': jsonEncode([record(1)]),
      });
      final p = await provider();
      final id = p.activeTasks.single.id;
      await Future.wait([p.retryTask(id), p.retryTask(id)]);
      expect(calls.where((c) => c.method == 'enqueue'), hasLength(1));
    });
  });
}
