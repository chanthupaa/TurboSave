import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videodownloader/providers/download_provider.dart';
import 'package:videodownloader/screens/downloads_screen.dart';
import 'package:videodownloader/screens/main_navigation_screen.dart';
import 'package:videodownloader/services/android_download_service.dart';
import 'package:videodownloader/services/shared_link_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const page = 'https://www.tiktok.com/@creator/video/123';
  const stale = 'https://cdn.example.com/stale.mp4';
  const fresh = 'https://cdn.example.com/fresh.mp4';
  late Future<Object?> Function(MethodCall call) native;
  late List<Map<String, String>> pendingShares;

  void androidTest(
    String name,
    Future<void> Function(WidgetTester tester) body,
  ) {
    testWidgets(name, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  String extraction(
    String url, {
    int width = 1280,
    int height = 720,
    Map<String, String> headers = const {},
  }) => jsonEncode({
    'title': 'TikTok sample',
    'formats': [
      {
        'id': 'complete',
        'url': url,
        'ext': 'mp4',
        'width': width,
        'height': height,
        'size': 4900000,
        'headers': headers,
        if (headers['Cookie'] case final cookie?) 'sessionCookie': cookie,
      },
    ],
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    pendingShares = [];
    native = (call) async => switch (call.method) {
      'extract' => extraction(stale),
      'enqueue' => 41,
      'query' => <Map<String, Object?>>[],
      _ => null,
    };
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      AndroidDownloadService.channel,
      (call) => native(call),
    );
    messenger.setMockMethodCallHandler(SharedLinkService.channel, (call) async {
      if (call.method == 'getPendingShares') return pendingShares;
      return null;
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(AndroidDownloadService.channel, null);
    messenger.setMockMethodCallHandler(SharedLinkService.channel, null);
  });

  test('launcher and shared links reuse one Android task', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android:launchMode="singleTask"'));
    expect(manifest, contains('android:documentLaunchMode="never"'));
  });

  test('TikTok share ignores a promotional link and keeps the video link', () {
    const video = 'https://vt.tiktok.com/ZSvideo123/';
    expect(
      SharedLinkService.parseText(
        'Watch this $video Get TikTok: https://www.tiktok.com/download',
      ),
      video,
    );
    expect(
      () => SharedLinkService.parseText(
        'https://example.com/one https://example.com/two',
      ),
      throwsFormatException,
    );
  });

  androidTest(
    'source-page download refreshes its temporary URL before enqueue',
    (tester) async {
      var extracts = 0;
      String? enqueued;
      native = (call) async {
        if (call.method == 'extract') {
          extracts++;
          return extraction(extracts == 1 ? stale : fresh);
        }
        if (call.method == 'enqueue') {
          enqueued = call.arguments['url'] as String;
          return 42;
        }
        if (call.method == 'query') return <Map<String, Object?>>[];
        return null;
      };
      final provider = DownloadProvider();
      try {
        await provider.ready;
        await provider.fetchVideoMetadata(page);
        expect(await provider.startDownload(rightsConfirmed: true), isTrue);
        expect(extracts, 2);
        expect(enqueued, fresh);
      } finally {
        provider.dispose();
      }
    },
  );

  androidTest(
    'download failure shows a clean message without PlatformException',
    (tester) async {
      native = (call) async {
        if (call.method == 'extract') return extraction(stale);
        if (call.method == 'enqueue') {
          throw PlatformException(
            code: 'MEDIA_ERROR',
            message: 'This file is unavailable or needs sign-in.',
          );
        }
        return null;
      };
      final provider = DownloadProvider();
      addTearDown(provider.dispose);
      await provider.ready;
      await provider.fetchVideoMetadata(page);
      expect(await provider.startDownload(rightsConfirmed: true), isFalse);
      expect(
        provider.activeTasks.single.error,
        'This file is unavailable or needs sign-in.',
      );
    },
  );

  androidTest('TikTok challenge cookie reaches only the native transfer', (
    tester,
  ) async {
    Map<Object?, Object?>? enqueueArguments;
    native = (call) async {
      if (call.method == 'extract') {
        return extraction(
          fresh,
          headers: const {'Cookie': 'challenge=temporary'},
        );
      }
      if (call.method == 'enqueue') {
        enqueueArguments = Map<Object?, Object?>.from(call.arguments as Map);
        return 43;
      }
      if (call.method == 'query') return <Map<String, Object?>>[];
      return null;
    };
    final provider = DownloadProvider();
    try {
      await provider.ready;
      await provider.fetchVideoMetadata(page);
      expect(await provider.startDownload(rightsConfirmed: true), isTrue);
      expect(
        (enqueueArguments!['headers'] as Map)['Cookie'],
        'challenge=temporary',
      );
      final saved = await SharedPreferences.getInstance();
      expect(
        saved.getString('queue_v2'),
        isNot(contains('challenge=temporary')),
      );
    } finally {
      provider.dispose();
    }
  });

  androidTest('the same failed file and quality cannot be queued twice', (
    tester,
  ) async {
    var enqueues = 0;
    native = (call) async {
      if (call.method == 'extract') return extraction(fresh);
      if (call.method == 'enqueue') {
        enqueues++;
        throw PlatformException(code: 'MEDIA_ERROR', message: 'Rejected');
      }
      return null;
    };
    final provider = DownloadProvider();
    try {
      await provider.ready;
      await provider.fetchVideoMetadata(page);
      expect(await provider.startDownload(rightsConfirmed: true), isFalse);
      expect(await provider.startDownload(rightsConfirmed: true), isFalse);
      expect(enqueues, 1);
      expect(provider.activeTasks, hasLength(1));
      expect(provider.errorMessage, contains('already in Activity'));
    } finally {
      provider.dispose();
    }
  });

  androidTest('portrait formats use the short edge for their quality label', (
    tester,
  ) async {
    native = (call) async => call.method == 'extract'
        ? extraction(stale, width: 720, height: 1280)
        : null;
    final provider = DownloadProvider();
    addTearDown(provider.dispose);
    await provider.ready;
    await provider.fetchVideoMetadata(page);
    final format = provider.currentVideo!.formats.single;
    expect(format.resolution, '720p');
    expect(format.label, contains('720×1280'));
  });

  androidTest('failed Activity items are not described as in progress', (
    tester,
  ) async {
    native = (call) async {
      if (call.method == 'extract') return extraction(stale);
      if (call.method == 'enqueue') {
        throw PlatformException(code: 'MEDIA_ERROR', message: 'Unavailable');
      }
      return null;
    };
    final provider = DownloadProvider();
    addTearDown(provider.dispose);
    await provider.ready;
    await provider.fetchVideoMetadata(page);
    await provider.startDownload(rightsConfirmed: true);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(home: DownloadsScreen(onNavigateToHome: () {})),
      ),
    );
    await tester.pump();
    expect(find.text('1 download needs attention'), findsOneWidget);
    expect(find.textContaining('in progress'), findsNothing);
    expect(find.byTooltip('Remove failed download'), findsOneWidget);
    expect(find.byTooltip('Cancel download'), findsNothing);
  });

  androidTest('share errors stay above the phone navigation bar', (
    tester,
  ) async {
    pendingShares = [
      {
        'id': 'bad-tiktok-share',
        'text': 'https://example.com/one https://example.com/two',
      },
    ];
    final provider = DownloadProvider();
    addTearDown(provider.dispose);
    await provider.ready;
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: MainNavigationScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final snack = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snack.behavior, SnackBarBehavior.floating);
    expect(
      tester.getRect(find.byType(SnackBar)).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(NavigationBar)).top),
    );
  });
}
