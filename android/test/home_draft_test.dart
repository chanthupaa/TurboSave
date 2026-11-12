import 'dart:async';

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
import 'package:videodownloader/services/media_policy.dart';
import 'package:videodownloader/services/shared_link_service.dart';
import 'package:videodownloader/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const first = 'https://example.com/first.mp4';
  const second = 'https://example.com/second.mp4';
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  Finder field() => find.descendant(
    of: find.byType(DownloaderScreen),
    matching: find.byType(TextField),
  );

  String text(WidgetTester tester) =>
      tester.widget<TextField>(field()).controller!.text;

  Future<void> select(WidgetTester tester, String tab) async {
    final navigation = find.byWidgetPredicate(
      (widget) => widget is NavigationBar || widget is NavigationRail,
    );
    await tester.tap(
      find.descendant(of: navigation, matching: find.text(tab)).last,
    );
    await tester.pumpAndSettle();
  }

  Future<void> roundTrips(WidgetTester tester, String expected) async {
    for (final tab in ['Activity', 'Library', 'Settings', 'Activity']) {
      await select(tester, tab);
      expect(
        find.byType(DownloaderScreen, skipOffstage: false),
        findsNothing,
        reason: 'Preserving a draft must not keep hidden Home mounted.',
      );
      await select(tester, 'Home');
      expect(text(tester), expected);
      expect(find.byType(BottomSheet), findsNothing);
    }
  }

  Future<void> dismissDetails(WidgetTester tester) async {
    final sheet = find.byType(BottomSheet);
    if (sheet.evaluate().isNotEmpty) {
      Navigator.of(tester.element(sheet)).pop();
      await tester.pumpAndSettle();
    }
  }

  Future<void> share(WidgetTester tester, String id, String url) async {
    final delivered = Completer<void>();
    messenger.handlePlatformMessage(
      'turbosave/share',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('sharedLink', {'id': id, 'text': url}),
      ),
      (_) => delivered.complete(),
    );
    await delivered.future;
    await tester.pumpAndSettle();
  }

  void draftCase(
    String name,
    Future<void> Function(WidgetTester) body, {
    double width = 390,
  }) {
    testWidgets(name, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      SharedPreferences.setMockInitialValues({});
      calls.clear();
      messenger.setMockMethodCallHandler(AndroidDownloadService.channel, (
        call,
      ) async {
        calls.add(call);
        return switch (call.method) {
          'inspect' => {'bytes': 1024},
          'reconcile' => null,
          _ => throw StateError('Unexpected native call: ${call.method}'),
        };
      });
      messenger.setMockMethodCallHandler(
        SharedLinkService.channel,
        (call) async => call.method == 'getPendingShares' ? [] : null,
      );
      final provider = DownloadProvider();
      try {
        await provider.ready;
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
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
        await body(tester);
        expect(calls.where((call) => call.method == 'enqueue'), isEmpty);
        expect(tester.takeException(), isNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getStringList('recent_links_v2'), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        provider.dispose();
        messenger.setMockMethodCallHandler(
          AndroidDownloadService.channel,
          null,
        );
        messenger.setMockMethodCallHandler(SharedLinkService.channel, null);
        debugDefaultTargetPlatformOverride = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    });
  }

  for (final width in [390.0, 1100.0]) {
    draftCase('draft survives every tab at width $width', (tester) async {
      const draft = '  https://example.com/watch?id=unfinished&  ';
      await tester.enterText(field(), draft);
      await roundTrips(tester, draft);
      expect(calls.where((call) => call.method == 'inspect'), isEmpty);
    }, width: width);
  }

  draftCase('an edited shared link replaces the old share on return Home', (
    tester,
  ) async {
    await share(tester, 'first', first);
    await dismissDetails(tester);
    await tester.enterText(field(), second);
    await roundTrips(tester, second);
  });

  draftCase('clearing a shared link stays empty after switching tabs', (
    tester,
  ) async {
    await share(tester, 'first', first);
    await dismissDetails(tester);
    await tester.enterText(field(), '');
    await roundTrips(tester, '');
  });

  draftCase('a new share while Home is hidden replaces the older draft', (
    tester,
  ) async {
    await tester.enterText(field(), first);
    await select(tester, 'Library');
    await share(tester, 'new', second);
    expect(text(tester), second);
    expect(find.byType(BottomSheet), findsOneWidget);
    await dismissDetails(tester);
    await roundTrips(tester, second);
  });

  draftCase('sharing the same URL again replaces a subsequent manual edit', (
    tester,
  ) async {
    await share(tester, 'first', first);
    await dismissDetails(tester);
    await tester.enterText(field(), second);
    await share(tester, 'second-delivery', first);
    expect(text(tester), first);
    await dismissDetails(tester);
    await roundTrips(tester, first);
  });

  draftCase('pasted links remain after leaving Home', (tester) async {
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      return call.method == 'Clipboard.getData' ? {'text': first} : null;
    });
    try {
      await tester.tap(find.text('Paste'));
      await tester.pumpAndSettle();
      expect(text(tester), first);
      await dismissDetails(tester);
      await roundTrips(tester, first);
    } finally {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    }
  });

  draftCase('the sample shortcut updates the draft too', (tester) async {
    await tester.tap(find.text('Try an open movie trailer'));
    await tester.pumpAndSettle();
    expect(text(tester), MediaPolicy.sampleUrl);
    await dismissDetails(tester);
    await roundTrips(tester, MediaPolicy.sampleUrl);
  });
}
