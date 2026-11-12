// Audit reproductions only. No production fixes are included.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videodownloader/providers/download_provider.dart';
import 'package:videodownloader/screens/downloader_screen.dart';
import 'package:videodownloader/screens/main_navigation_screen.dart';
import 'package:videodownloader/services/android_download_service.dart';
import 'package:videodownloader/services/shared_link_service.dart';
import 'package:videodownloader/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const source = 'https://example.com/clip.mp4';
  const page = 'https://vimeo.com/123456';
  late DownloadProvider provider;
  var disposed = false;
  late Future<Object?> Function(MethodCall) native;
  var inbox = <Map<String, String>>[];
  var nextId = 100;
  final calls = <MethodCall>[];

  setUpAll(() async {
    final font = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    await font.load();
  });

  void audit(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      SharedPreferences.setMockInitialValues({});
      calls.clear();
      inbox = [];
      nextId = 100;
      disposed = false;
      native = (call) async => switch (call.method) {
        'inspect' => {'bytes': 1048576},
        'enqueue' => ++nextId,
        'query' => [],
        'extract' => jsonEncode({
          'title': 'A public sample',
          'thumbnail': 'https://example.com/thumbnail.jpg',
          'formats': [
            {'id': '720', 'url': source, 'ext': 'mp4', 'height': 720},
          ],
        }),
        _ => null,
      };
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(AndroidDownloadService.channel, (
        call,
      ) {
        calls.add(call);
        return native(call);
      });
      messenger.setMockMethodCallHandler(SharedLinkService.channel, (
        call,
      ) async {
        if (call.method == 'getPendingShares') return inbox;
        return null;
      });
      provider = DownloadProvider();
      try {
        await provider.ready;
        await body(tester);
      } finally {
        if (!disposed) provider.dispose();
        messenger.setMockMethodCallHandler(
          AndroidDownloadService.channel,
          null,
        );
        messenger.setMockMethodCallHandler(SharedLinkService.channel, null);
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    double width = 600,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(theme: AppTheme.lightTheme, home: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  audit('enqueue finishing after provider disposal must remain recoverable', (
    tester,
  ) async {
    final enqueue = Completer<Object?>();
    final normal = native;
    native = (call) => call.method == 'enqueue' ? enqueue.future : normal(call);
    await provider.fetchVideoMetadata(source);
    final starting = provider.startDownload(rightsConfirmed: true);
    await tester.pump();
    provider.dispose();
    disposed = true;
    enqueue.complete(101);
    await starting;
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('queue_v2'),
      contains('101'),
      reason: 'Android accepted the transfer, but a restart has no persisted job to track.',
    );
  });

  audit(
    'returning Home must not reopen an already dismissed shared-link sheet',
    (tester) async {
      inbox = [
        {'id': 'shared', 'text': source},
      ];
      await mount(tester, const MainNavigationScreen());
      expect(find.byType(BottomSheet), findsOneWidget);
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Activity').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
    },
  );

  audit('a saved page thumbnail should appear in its media details', (
    tester,
  ) async {
    await provider.fetchVideoMetadata(page);
    await mount(
      tester,
      Scaffold(body: DownloaderScreen(onNavigateToDownloads: () {})),
      width: 800,
    );
    expect(provider.currentVideo!.thumbnailUrl, isNotEmpty);
    expect(
      find.byType(Image),
      findsWidgets,
      reason:
          'Metadata has a thumbnail, but all artwork is a generic local icon.',
    );
  });

  audit('different audio bitrates should have distinguishable quality labels', (
    tester,
  ) async {
    final normal = native;
    native = (call) async {
      if (call.method != 'extract') return normal(call);
      return jsonEncode({
        'formats': [
          for (final abr in [64, 128])
            {
              'id': '$abr',
              'url': 'https://example.com/audio.m4a',
              'ext': 'm4a',
              'audioOnly': true,
              'abr': abr,
            },
        ],
      });
    };
    await provider.fetchVideoMetadata(page);
    final formats = provider.currentVideo!.formats;
    expect(
      formats.map((f) => '${f.label} ${f.estimatedSize}').toSet(),
      hasLength(2),
    );
  });

  audit('a failed Retry should display the latest error on Activity', (
    tester,
  ) async {
    await provider.fetchVideoMetadata(source);
    await provider.startDownload(rightsConfirmed: true);
    final normal = native;
    native = (call) async {
      if (call.method == 'query') {
        return [
          {'id': 101, 'status': 'failed', 'error': 'Old expired link'},
        ];
      }
      if (call.method == 'enqueue') {
        throw PlatformException(
          code: 'MEDIA_ERROR',
          message: 'New error: storage full',
        );
      }
      return normal(call);
    };
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    final task = provider.activeTasks.single;
    await provider.retryTask(task.id);
    expect(provider.errorMessage, contains('storage full'));
    expect(
      task.error,
      contains('storage full'),
      reason: 'Activity renders task.error, not the provider error.',
    );
  });

  audit(
    'leaving Home while clipboard access is pending must not touch a disposed controller',
    (tester) async {
      final clipboard = Completer<Object?>();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') return clipboard.future;
        return null;
      });
      try {
        await mount(tester, const MainNavigationScreen());
        await tester.tap(find.text('Paste'));
        await tester.pump();
        await tester.tap(find.text('Activity').last);
        await tester.pumpAndSettle();
        clipboard.complete({'text': source});
        await tester.pump();
        expect(tester.takeException(), isNull);
      } finally {
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      }
    },
  );

  audit(
    'one stale native ID must not stop other downloads from reaching Library',
    (tester) async {
      await provider.fetchVideoMetadata(source);
      await provider.startDownload(rightsConfirmed: true);
      await provider.startDownload(rightsConfirmed: true);
      final normal = native;
      native = (call) async {
        if (call.method == 'query') {
          if ((call.arguments['ids'] as List).contains(101)) {
            throw PlatformException(
              code: 'MEDIA_ERROR',
              message: 'This download does not belong to this app.',
            );
          }
          return [
            {
              'id': 102,
              'status': 'completed',
              'uri': 'content://downloads/102',
            },
          ];
        }
        return normal(call);
      };
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(
        provider.completedTasks.map((task) => task.nativeDownloadId),
        contains(102),
        reason: 'The native batch fails on ID 101; every poll repeats the same failing batch.',
      );
    },
  );

  audit(
    'Home header fits a 360-pixel phone with an active download and the real font',
    (tester) async {
      await provider.fetchVideoMetadata(source);
      await provider.startDownload(rightsConfirmed: true);
      await mount(tester, const MainNavigationScreen(), width: 360);
      expect(tester.takeException(), isNull);
    },
  );
}
