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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const source =
      'https://download.blender.org/durian/trailer/sintel_trailer-480p.mp4';
  final calls = <MethodCall>[];
  final acknowledged = <String>[];
  var pending = <Map<String, String>>[];
  var nextId = 10;
  late DownloadProvider provider;
  var providerCreated = false;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    acknowledged.clear();
    pending = [];
    nextId = 10;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidDownloadService.channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'inspect' => {'bytes': 4000000},
            'enqueue' => ++nextId,
            'query' =>
              (call.arguments['ids'] as List)
                  .map(
                    (id) => {
                      'id': id,
                      'status': 'downloading',
                      'bytes': 100000,
                      'total': 4000000,
                    },
                  )
                  .toList(),
            _ => null,
          };
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SharedLinkService.channel, (call) async {
          if (call.method == 'getPendingShares') return pending;
          if (call.method == 'acknowledgeShare')
            acknowledged.add(call.arguments['id'] as String);
          return null;
        });
    providerCreated = false;
  });
  tearDown(() {
    if (providerCreated) provider.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidDownloadService.channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SharedLinkService.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  void widgetCase(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      provider = DownloadProvider();
      providerCreated = true;
      try {
        await body(tester);
      } finally {
        provider.dispose();
        providerCreated = false;
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  test(
    'shared text extracts one HTTPS link and removes wrapper punctuation',
    () {
      expect(SharedLinkService.parseText('A trailer ($source).'), source);
      expect(
        () => SharedLinkService.parseText('$source https://example.com/a'),
        throwsFormatException,
      );
      expect(
        () => SharedLinkService.parseText('http://example.com/a'),
        throwsFormatException,
      );
      expect(
        () => SharedLinkService.parseText('https://localhost/private'),
        throwsFormatException,
      );
      expect(
        () => SharedLinkService.parseText('x' * 8193),
        throwsFormatException,
      );
      expect(
        () => SharedLinkService.parseText(
          'https://music.youtube.com/watch?v=example',
        ),
        throwsFormatException,
      );
    },
  );

  widgetCase('cold share opens details for review without enqueueing a file', (
    tester,
  ) async {
    pending = [
      {'id': 'cold-share', 'text': 'Watch this: $source'},
    ];
    await provider.ready;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: MainNavigationScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Available complete files'), findsOneWidget);
    expect(
      find.text('I own this file or have permission to download it.'),
      findsOneWidget,
    );
    expect(calls.where((call) => call.method == 'enqueue'), isEmpty);
    expect(acknowledged, ['cold-share']);
    expect(tester.takeException(), isNull);
  });

  widgetCase(
    'duplicate native delivery is processed once and warm shares are received',
    (tester) async {
      final handled = <String>[];
      final inbox = SharedLinkService(
        onLink: (link) async {
          handled.add(link);
        },
        onError: (message) => fail(message),
      );
      pending = [
        {'id': 'same', 'text': source},
      ];
      await inbox.start();
      await tester.pump();
      await inbox.resume();
      await tester.pump();
      expect(handled, [source]);
      final codec = const StandardMethodCodec();
      final completed = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'turbosave/share',
            codec.encodeMethodCall(
              const MethodCall('sharedLink', {
                'id': 'warm',
                'text': 'https://example.com/clip.mp4',
              }),
            ),
            (_) => completed.complete(),
          );
      await completed.future;
      await tester.pump();
      expect(handled, [source, 'https://example.com/clip.mp4']);
      expect(calls.where((call) => call.method == 'enqueue'), isEmpty);
      inbox.dispose();
    },
  );

  widgetCase(
    'progress polling stops while idle, backgrounded, and after cancellation',
    (tester) async {
      await provider.ready;
      await tester.pump(const Duration(seconds: 10));
      expect(provider.isPolling, isFalse);
      expect(calls.where((call) => call.method == 'query'), isEmpty);
      await provider.fetchVideoMetadata(source);
      await provider.startDownload(rightsConfirmed: true);
      expect(provider.isPolling, isTrue);
      await tester.pump(const Duration(seconds: 2));
      final foregroundQueries = calls
          .where((call) => call.method == 'query')
          .length;
      expect(foregroundQueries, greaterThan(0));
      provider.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 20));
      expect(provider.isPolling, isFalse);
      expect(
        calls.where((call) => call.method == 'query').length,
        foregroundQueries,
      );
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(
        calls.where((call) => call.method == 'query').length,
        greaterThan(foregroundQueries),
      );
      await provider.cancelTask(provider.activeTasks.single.id);
      expect(provider.isPolling, isFalse);
    },
  );

  widgetCase('large saved histories restore only the bounded local library', (
    tester,
  ) async {
    provider.dispose();
    SharedPreferences.setMockInitialValues({
      'library_v2': jsonEncode(
        List.generate(
          125,
          (id) => {
            'id': 'android_$id',
            'nativeId': id,
            'title': 'Saved clip $id',
            'sourceUrl': source,
            'ext': 'mp4',
            'formatId': 'original',
            'size': '1 MB',
            'status': 'completed',
            'createdAt': '2026-10-28T00:00:00Z',
          },
        ),
      ),
    });
    provider = DownloadProvider();
    await provider.ready;
    expect(provider.completedTasks.length, 100);
    expect(provider.isPolling, isFalse);
  });
}
