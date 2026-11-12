import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videodownloader/providers/download_provider.dart';
import 'package:videodownloader/screens/downloader_screen.dart';
import 'package:videodownloader/services/android_download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  const payload = {
    'title': 'Photo post',
    'author': 'creator',
    'thumbnail': 'https://cdn.example.com/cover.jpg',
    'formats': [
      {
        'id': 'image-1',
        'url': 'https://cdn.example.com/one.jpg',
        'ext': 'jpg',
        'width': 1080,
        'height': 1920,
        'imageOnly': true,
        'imageIndex': 1,
      },
      {
        'id': 'image-2',
        'url': 'https://cdn.example.com/two.webp',
        'ext': 'webp',
        'width': 1080,
        'height': 1920,
        'imageOnly': true,
        'imageIndex': 2,
      },
    ],
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    var id = 70;
    messenger.setMockMethodCallHandler(AndroidDownloadService.channel, (
      call,
    ) async {
      calls.add(call);
      switch (call.method) {
        case 'extract':
          return jsonEncode(payload);
        case 'enqueue':
          return id++;
        case 'query':
          return <Map<String, Object?>>[];
        case 'reconcile':
          return null;
      }
      fail('Unexpected native call: ${call.method}');
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(AndroidDownloadService.channel, null);
  });

  test('selected slideshow images are one durable collection', () async {
    final provider = DownloadProvider();
    await provider.ready;
    addTearDown(provider.dispose);
    await provider.fetchVideoMetadata(
      'https://www.tiktok.com/@creator/photo/123',
    );

    expect(provider.currentVideo!.formats, hasLength(2));
    expect(
      provider.currentVideo!.formats.every((item) => item.isImage),
      isTrue,
    );
    expect(
      provider.currentVideo!.formats.first.label,
      'Image 1 · JPG · 1080×1920',
    );

    expect(
      await provider.startDownloads(
        provider.currentVideo!.formats,
        rightsConfirmed: true,
      ),
      isTrue,
    );
    expect(provider.activeTasks, hasLength(2));
    expect(
      provider.activeTasks.map((task) => task.collectionId).toSet(),
      hasLength(1),
    );
    expect(provider.activeTasks.map((task) => task.collectionIndex), [2, 1]);
    expect(
      provider.activeTasks.every((task) => task.collectionCount == 2),
      isTrue,
    );

    final queue = jsonDecode(
      (await SharedPreferences.getInstance()).getString('queue_v2')!,
    ) as List;
    expect(queue, hasLength(2));
    expect(queue.every((item) => item['imageOnly'] == true), isTrue);
    expect(queue.every((item) => item['collectionCount'] == 2), isTrue);
    expect(calls.where((call) => call.method == 'enqueue'), hasLength(2));
  });

  testWidgets('image review supports select all and individual selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = DownloadProvider();
    await provider.ready;
    addTearDown(provider.dispose);
    await provider.fetchVideoMetadata('https://www.instagram.com/p/example/');
    debugDefaultTargetPlatformOverride = null;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(body: DownloaderScreen(onNavigateToDownloads: _noop)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review formats'));
    await tester.pumpAndSettle();

    expect(find.text('Images'), findsOneWidget);
    expect(find.text('2 selected'), findsOneWidget);
    expect(find.text('Clear all'), findsOneWidget);
    expect(find.text('Download selected'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('slideshow-image-1')));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('Select all'), findsOneWidget);

    await tester.tap(find.text('Select all'));
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.text('Clear all'));
    await tester.pump();
    expect(find.text('0 selected'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Download selected'),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('Select all'));
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);
  });
}

void _noop() {}
