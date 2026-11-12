import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videodownloader/providers/download_provider.dart';
import 'package:videodownloader/screens/downloader_screen.dart';
import 'package:videodownloader/screens/downloads_screen.dart';
import 'package:videodownloader/services/android_download_service.dart';
import 'package:videodownloader/widgets/media_artwork.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const page = 'https://vimeo.com/123456';
  var failExtraction = false;
  var extractCalls = 0;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    failExtraction = false;
    extractCalls = 0;
    messenger.setMockMethodCallHandler(AndroidDownloadService.channel, (
      call,
    ) async {
      if (call.method == 'extract') {
        extractCalls++;
        if (failExtraction) {
          throw PlatformException(
            code: 'MEDIA_ERROR',
            message: 'This post is unavailable.',
          );
        }
        return jsonEncode({
          'title': 'Open movie trailer',
          'author': 'Blender Foundation',
          'duration': 42,
          'thumbnail': 'https://example.com/poster.jpg',
          'formats': [
            for (final quality in [2160, 1440, 1080, 720, 480, 360])
              {
                'id': 'video-$quality',
                'url': 'https://example.com/video-$quality.mp4',
                'ext': 'mp4',
                'width': quality * 16 ~/ 9,
                'height': quality,
                'size': quality * 10000,
              },
            for (final bitrate in [192, 128])
              {
                'id': 'audio-$bitrate',
                'url': 'https://example.com/audio-$bitrate.m4a',
                'ext': 'm4a',
                'audioOnly': true,
                'abr': bitrate,
                'size': bitrate * 10000,
              },
          ],
        });
      }
      if (call.method == 'enqueue') return 41;
      if (call.method == 'query') return [];
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(AndroidDownloadService.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  Future<DownloadProvider> provider() async {
    final value = DownloadProvider();
    await value.ready;
    return value;
  }

  testWidgets('important format choices are visible with an honest default', (
    tester,
  ) async {
    final value = await provider();
    addTearDown(value.dispose);
    await value.fetchVideoMetadata(page);
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: value,
        child: MaterialApp(
          home: Scaffold(body: DownloaderScreen(onNavigateToDownloads: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ChoiceChip), findsNWidgets(4));
    expect(find.textContaining('Best available'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.textContaining('By starting the download'), findsOneWidget);
    expect(find.text('Show 2 more'), findsOneWidget);
    await tester.tap(find.text('Show 2 more'));
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNWidgets(6));

    await tester.tap(find.text('Audio'));
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNWidgets(2));
    expect(find.textContaining('192 kbps'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('starting a download clears only the matching source clipboard', (
    tester,
  ) async {
    final value = await provider();
    addTearDown(value.dispose);
    await value.fetchVideoMetadata(page);
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var clipboard = page;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': clipboard};
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map<Object?, Object?>)['text'] as String;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    var started = false;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: value,
        child: MaterialApp(
          home: Scaffold(
            body: DownloaderScreen(onNavigateToDownloads: () => started = true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start download'));
    for (var i = 0; i < 20 && !started; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(started, isTrue);
    expect(clipboard, isEmpty);
    value.didChangeAppLifecycleState(AppLifecycleState.paused);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('fetch errors stay beside the link and offer recovery', (
    tester,
  ) async {
    final value = await provider();
    addTearDown(value.dispose);
    failExtraction = true;
    await value.fetchVideoMetadata(page);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: value,
        child: MaterialApp(
          home: Scaffold(
            body: DownloaderScreen(
              onNavigateToDownloads: () {},
              draftLink: page,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This post is unavailable.'), findsOneWidget);
    expect(find.text('Edit link'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(extractCalls, 2);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('format choices remain usable on a small dark-mode phone', (
    tester,
  ) async {
    final value = await provider();
    addTearDown(value.dispose);
    await value.fetchVideoMetadata(page);
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: value,
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(375, 667),
              textScaler: TextScaler.linear(1.5),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: DownloaderScreen(onNavigateToDownloads: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Review formats'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review formats'));
    await tester.pumpAndSettle();

    expect(find.text('Available complete files'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(4));
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Activity gives downloaded media enough visual priority', (
    tester,
  ) async {
    final value = await provider();
    addTearDown(value.dispose);
    await value.fetchVideoMetadata(page);
    await value.startDownload(rightsConfirmed: true);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: value,
        child: MaterialApp(
          home: Scaffold(body: DownloadsScreen(onNavigateToHome: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final artwork = tester.widget<MediaArtwork>(find.byType(MediaArtwork));
    expect(artwork.width, greaterThanOrEqualTo(88));
    expect(artwork.height, greaterThanOrEqualTo(56));
    value.didChangeAppLifecycleState(AppLifecycleState.paused);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('format choices reflow in phone landscape', (tester) async {
    final value = await provider();
    addTearDown(value.dispose);
    await value.fetchVideoMetadata(page);
    tester.view.physicalSize = const Size(667, 375);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: value,
        child: MaterialApp(
          home: Scaffold(body: DownloaderScreen(onNavigateToDownloads: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ChoiceChip), findsNWidgets(4));
    expect(find.text('Show 2 more'), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });
}
