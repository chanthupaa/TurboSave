import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:videodownloader/providers/download_provider.dart';
import 'package:videodownloader/screens/library_screen.dart';

class LibraryStore extends InMemorySharedPreferencesStore {
  LibraryStore() : super.withData({});
  bool reject = false;
  bool throwOnWrite = false;
  Completer<void>? hold;
  final writeAttempted = Completer<void>();
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    await hold?.future;
    if (!writeAttempted.isCompleted) writeAttempted.complete();
    if (throwOnWrite) throw StateError('Storage unavailable');
    if (reject) return false;
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Library shows a save failure and retains the card', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    SharedPreferences.setMockInitialValues({
      'library_v2': jsonEncode([
        {
          'id': 'saved',
          'nativeId': 7,
          'title': 'Saved clip',
          'sourceUrl': 'https://example.com/clip.mp4',
          'ext': 'mp4',
          'size': '1 MB',
          'status': 'completed',
          'createdAt': '2026-11-01T00:00:00Z',
          'filePath': 'content://downloads/7',
        },
      ]),
    });
    final provider = DownloadProvider();
    await provider.ready;
    final previous = SharedPreferencesStorePlatform.instance;
    final store = LibraryStore()..reject = true;
    SharedPreferencesStorePlatform.instance = store;
    try {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: Scaffold(body: LibraryScreen(onNavigateToHome: () {})),
          ),
        ),
      );
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove library record'));
      await tester.pump();
      await tester.runAsync(() async {
        await store.writeAttempted.future;
        await pumpEventQueue(times: 20);
      });
      await tester.pump();
      expect(find.text('Saved clip'), findsOneWidget);
      expect(
        find.text(
          'Could not remove this Library entry. Check device storage and try again.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
      SharedPreferencesStorePlatform.instance = previous;
      debugDefaultTargetPlatformOverride = null;
    }
  });
  for (final failure in ['none', 'false', 'exception']) {
    test(
      'Library removal handles $failure storage result and permits retry',
      () async {
        SharedPreferences.setMockInitialValues({
          'library_v2': jsonEncode([
            {
              'id': 'saved',
              'nativeId': 7,
              'title': 'Clip',
              'sourceUrl': 'https://example.com/clip.mp4',
              'ext': 'mp4',
              'size': '1 MB',
              'status': 'completed',
              'createdAt': '2026-11-01T00:00:00Z',
              'filePath': 'content://downloads/7',
            },
          ]),
        });
        final provider = DownloadProvider();
        await provider.ready;
        final previous = SharedPreferencesStorePlatform.instance;
        final store = LibraryStore()
          ..reject = failure == 'false'
          ..throwOnWrite = failure == 'exception'
          ..hold = Completer<void>();
        SharedPreferencesStorePlatform.instance = store;
        try {
          final removal = provider.deleteCompletedTask('saved');
          await pumpEventQueue();
          expect(
            provider.completedTasks,
            hasLength(1),
            reason: 'Keep entry until saving succeeds',
          );
          store.hold!.complete();
          expect(await removal, failure == 'none');
          if (failure != 'none') {
            expect(provider.completedTasks.single.id, 'saved');
            expect(provider.errorMessage, contains('Check device storage'));
            store.reject = false;
            store.throwOnWrite = false;
            expect(await provider.deleteCompletedTask('saved'), isTrue);
          }
          expect(provider.completedTasks, isEmpty);
          expect(
            jsonDecode((await store.getAll())['flutter.library_v2'] as String),
            isEmpty,
          );
          // A later queued save must not resurrect the removed record.
          await provider.clearPrivateRecords();
          expect(
            jsonDecode((await store.getAll())['flutter.library_v2'] as String),
            isEmpty,
          );
        } finally {
          provider.dispose();
          SharedPreferencesStorePlatform.instance = previous;
        }
      },
    );
  }
}
