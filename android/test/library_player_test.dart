import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videodownloader/providers/download_provider.dart';
import 'package:videodownloader/screens/library_screen.dart';
import 'package:videodownloader/services/android_download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'library_v2': jsonEncode([
        {
          'id': 'saved_41',
          'nativeId': 41,
          'title': 'Saved clip',
          'sourceUrl': 'https://example.com/saved.mp4',
          'ext': 'mp4',
          'formatId': '1080',
          'formatLabel': '1080p MP4',
          'resolution': '1080x1080',
          'audioOnly': false,
          'size': '2 MB',
          'progress': 1.0,
          'status': 'completed',
          'createdAt': '2026-11-04T00:00:00Z',
          'completedAt': '2026-11-04T00:01:00Z',
          'filePath': 'content://downloads/41',
        },
      ]),
    });
    calls.clear();
    messenger.setMockMethodCallHandler(AndroidDownloadService.channel, (
      call,
    ) async {
      if (call.method == 'reconcile') return null;
      if (call.method == 'open' || call.method == 'openGallery') {
        calls.add(call);
        return null;
      }
      fail('Unexpected native call: ${call.method}');
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(AndroidDownloadService.channel, null);
  });

  testWidgets('tapping a saved Library card opens the in-app player', (
    tester,
  ) async {
    final provider = DownloadProvider();
    await provider.ready;
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(body: LibraryScreen(onNavigateToHome: () {})),
        ),
      ),
    );

    await tester.tap(find.text('Saved clip'));
    await tester.pump();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'open');
    expect(calls.single.arguments, {
      'id': 41,
      'uri': 'content://downloads/41',
      'mimeType': 'video/mp4',
    });
  });

  testWidgets('slideshow images are grouped and open as one gallery', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'library_v2': jsonEncode([
        for (var index = 1; index <= 2; index++)
          {
            'id': 'image_$index',
            'nativeId': 50 + index,
            'title': 'Photo post',
            'sourceUrl': 'https://www.tiktok.com/@creator/photo/1',
            'ext': 'jpg',
            'formatId': 'image-$index',
            'formatLabel': 'Image $index · JPG',
            'resolution': '1080×1920',
            'audioOnly': false,
            'imageOnly': true,
            'collectionId': 'album_1',
            'collectionIndex': index,
            'collectionCount': 2,
            'size': '1 MB',
            'progress': 1.0,
            'status': 'completed',
            'createdAt': '2026-11-05T00:00:00Z',
            'completedAt': '2026-11-05T00:01:00Z',
            'filePath': 'content://downloads/${50 + index}',
          },
      ]),
    });
    final provider = DownloadProvider();
    await provider.ready;
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(body: LibraryScreen(onNavigateToHome: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Photo post'), findsOneWidget);
    expect(find.text('2 images'), findsOneWidget);
    await tester.tap(find.text('Photo post'));
    await tester.pump();

    final call = calls.singleWhere((item) => item.method == 'openGallery');
    expect(call.arguments, {
      'items': [
        {'id': 51, 'uri': 'content://downloads/51', 'mimeType': 'image/jpeg'},
        {'id': 52, 'uri': 'content://downloads/52', 'mimeType': 'image/jpeg'},
      ],
    });
  });
}
