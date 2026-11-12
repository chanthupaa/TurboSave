// Audit-only reproductions. Production code is intentionally unchanged.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videodownloader/providers/download_provider.dart';
import 'package:videodownloader/screens/main_navigation_screen.dart';
import 'package:videodownloader/services/android_download_service.dart';
import 'package:videodownloader/services/shared_link_service.dart';
import 'package:videodownloader/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const source = 'https://example.com/a.mp4';
  late DownloadProvider provider;
  late Future<Object?> Function(MethodCall) native;
  late Future<Object?> Function(MethodCall) shares;
  var nextId = 100;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void audit(
    String name,
    Future<void> Function(WidgetTester) body, {
    Map<String, Object> initial = const {},
  }) {
    testWidgets(name, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      SharedPreferences.setMockInitialValues(initial);
      nextId = 100;
      native = (call) async => switch (call.method) {
        'inspect' => {'bytes': 1024},
        'enqueue' => ++nextId,
        'query' => [],
        _ => null,
      };
      shares = (call) async => call.method == 'getPendingShares' ? [] : null;
      messenger.setMockMethodCallHandler(
        AndroidDownloadService.channel,
        (call) => native(call),
      );
      messenger.setMockMethodCallHandler(
        SharedLinkService.channel,
        (call) => shares(call),
      );
      provider = DownloadProvider();
      try {
        await body(tester);
      } finally {
        provider.dispose();
        messenger.setMockMethodCallHandler(
          AndroidDownloadService.channel,
          null,
        );
        messenger.setMockMethodCallHandler(SharedLinkService.channel, null);
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  Future<void> mount(WidgetTester tester) async {
    await provider.ready;
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MainNavigationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  audit(
    'cancelling during a completion query must not leave the deleted file in Library',
    (tester) async {
      await provider.fetchVideoMetadata(source);
      await provider.startDownload(rightsConfirmed: true);
      final query = Completer<Object?>();
      final cancel = Completer<Object?>();
      final normal = native;
      native = (call) => switch (call.method) {
        'query' => query.future,
        'cancel' => cancel.future,
        _ => normal(call),
      };
      await tester.pump(const Duration(seconds: 2));
      final cancelling = provider.cancelTask(provider.activeTasks.single.id);
      await tester.pump();
      query.complete([
        {'id': 101, 'status': 'completed', 'uri': 'content://downloads/101'},
      ]);
      await tester.pump();
      cancel.complete(null);
      await cancelling;
      expect(
        provider.completedTasks,
        isEmpty,
        reason:
            'Native cancel removed the file; it must not remain marked Saved.',
      );
    },
  );

  audit(
    'a second fast share should present the latest details after closing the first sheet',
    (tester) async {
      shares = (call) async => call.method == 'getPendingShares'
          ? [
              {'id': 'first', 'text': source},
            ]
          : null;
      await mount(tester);
      expect(find.byType(BottomSheet), findsOneWidget);
      final done = Completer<void>();
      messenger.handlePlatformMessage(
        'turbosave/share',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('sharedLink', {
            'id': 'second',
            'text': 'https://example.com/b.mp4',
          }),
        ),
        (_) => done.complete(),
      );
      await done.future;
      await tester.pump();
      await tester.pumpAndSettle();
      expect(provider.currentVideo!.sourceUrl, 'https://example.com/b.mp4');
      expect(find.byType(BottomSheet), findsOneWidget);
    },
  );

  audit('Home should preserve the typed link across tab changes', (
    tester,
  ) async {
    await mount(tester);
    await tester.enterText(find.byType(TextField).first, source);
    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      source,
    );
  });

  audit('failed native share acknowledgement must be retried on resume', (
    tester,
  ) async {
    var acks = 0;
    final handled = <String>[];
    shares = (call) async {
      if (call.method == 'getPendingShares')
        return [
          {'id': 'one', 'text': source},
        ];
      if (call.method == 'acknowledgeShare' && ++acks == 1)
        throw PlatformException(code: 'TEMPORARY');
      return null;
    };
    final inbox = SharedLinkService(
      onLink: (link) async {
        handled.add(link);
      },
      onError: (_) {},
    );
    try {
      await inbox.start();
      await tester.pump();
      await inbox.resume();
      await tester.pump();
      expect(handled, [source]);
      expect(acks, 2);
    } finally {
      inbox.dispose();
    }
  });

  audit(
    'one malformed saved setting should not prevent download initialization',
    (tester) async {
      await expectLater(provider.ready, completes);
    },
    initial: {'wifi_only': 'invalid'},
  );

  audit('audio-only MP4 should open with an audio MIME type', (tester) async {
    final calls = <MethodCall>[];
    final normal = native;
    native = (call) async {
      calls.add(call);
      if (call.method == 'extract')
        return jsonEncode({
          'formats': [
            {
              'id': 'audio',
              'ext': 'mp4',
              'url': source,
              'audioOnly': true,
              'abr': 128,
            },
          ],
        });
      if (call.method == 'query')
        return [
          {'id': 101, 'status': 'completed', 'uri': 'content://downloads/101'},
        ];
      return normal(call);
    };
    await provider.fetchVideoMetadata('https://vimeo.com/123456');
    await provider.startDownload(rightsConfirmed: true);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await provider.openFile(provider.completedTasks.single);
    expect(calls.last.arguments['mimeType'], 'audio/mp4');
  });

  audit('primary fetch button should have a screen-reader label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await mount(tester);
      expect(
        tester
            .getSemantics(find.byType(FilledButton).first)
            .getSemanticsData()
            .label,
        isNotEmpty,
      );
    } finally {
      semantics.dispose();
    }
  });

  test(
    'sharing a literal URL must preserve its trailing query punctuation',
    () {
      const link = 'https://example.com/watch?id=hello!';
      expect(SharedLinkService.parseText(link), link);
    },
  );

  audit(
    'theme toggle should switch from system-light to dark on the first tap',
    (tester) async {
      await provider.ready;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      provider.setThemeMode(ThemeMode.system);
      await mount(tester);
      await tester.tap(find.byTooltip('Toggle theme'));
      await tester.pump();
      expect(provider.themeMode, ThemeMode.dark);
    },
  );
}
