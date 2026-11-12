import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videodownloader/providers/download_provider.dart';
import 'package:videodownloader/services/android_download_service.dart';

const source = 'https://example.com/clip.mp4';
Map<String, Object?> savedTask(int id, {bool completed = true}) => {
  'id': 'android_$id',
  'nativeId': id,
  'title': 'Clip $id',
  'sourceUrl': source,
  'ext': 'mp4',
  'formatId': 'original',
  'size': '1 MB',
  'status': completed ? 'completed' : 'failed',
  'createdAt': '2026-10-30T00:00:00Z',
  if (completed) 'filePath': 'content://downloads/$id',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final providers = <DownloadProvider>[];
  final calls = <MethodCall>[];
  final retained = <Set<int>>[];
  var snapshots = <Map<String, Object?>>[];
  var syncFails = false;
  Completer<int>? enqueue;

  Future<DownloadProvider> restore({
    List<Map<String, Object?>> library = const [],
    List<Map<String, Object?>> queue = const [],
  }) async {
    SharedPreferences.setMockInitialValues({
      'library_v2': jsonEncode(library),
      'queue_v2': jsonEncode(queue),
    });
    final provider = DownloadProvider();
    providers.add(provider);
    await provider.ready;
    await pumpEventQueue();
    return provider;
  }

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    retained.clear();
    snapshots = [];
    syncFails = false;
    enqueue = null;
    messenger.setMockMethodCallHandler(AndroidDownloadService.channel, (
      call,
    ) async {
      calls.add(call);
      switch (call.method) {
        case 'reconcile':
          if (syncFails) throw PlatformException(code: 'BUSY');
          final ids = (call.arguments['ids'] as List).cast<int>().toSet();
          final prefs = await SharedPreferences.getInstance();
          final savedIds = <int>{};
          for (final key in ['library_v2', 'queue_v2']) {
            final entries = jsonDecode(prefs.getString(key) ?? '[]') as List;
            // Startup may reconcile the bounded in-memory Library from a larger old list.
            for (final entry in entries.take(key == 'library_v2' ? 100 : 20)) {
              if (entry['nativeId'] is int)
                savedIds.add(entry['nativeId'] as int);
            }
          }
          expect(
            ids,
            savedIds,
            reason: 'Native pruning must follow the durable task write.',
          );
          retained.add(ids);
          return null;
        case 'inspect':
          return {'bytes': 1048576};
        case 'query':
          return snapshots;
        case 'enqueue':
          return enqueue == null ? 500 : await enqueue!.future;
        case 'cancel':
          fail('Record cleanup must not cancel or delete files.');
        default:
          return null;
      }
    });
  });

  tearDown(() {
    for (final provider in providers) {
      provider.dispose();
    }
    providers.clear();
    messenger.setMockMethodCallHandler(AndroidDownloadService.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('startup reconciles only the retained 100 Library and recoverable queue IDs', () async {
    final p = await restore(
      library: List.generate(125, (i) => savedTask(i + 1)),
      queue: [savedTask(200, completed: false)],
    );
    expect(p.completedTasks, hasLength(100));
    expect(retained.single, {...List.generate(100, (i) => i + 1), 200});
    expect(p.activeTasks.single.nativeDownloadId, 200);
  });

  test(
    'deleting a Library record prunes metadata after saving without cancelling',
    () async {
      final p = await restore(library: [savedTask(1), savedTask(2)]);
      p.deleteCompletedTask('android_1');
      await pumpEventQueue();
      expect(retained.last, {2});
      expect(calls.where((call) => call.method == 'cancel'), isEmpty);
    },
  );

  test('clear private records keeps failed and live queue ownership', () async {
    final p = await restore(
      library: [savedTask(1)],
      queue: [
        savedTask(2, completed: false),
        {...savedTask(3, completed: false), 'status': 'queued'},
      ],
    );
    await p.clearPrivateRecords();
    expect(retained.last, {2, 3});
    expect(p.activeTasks, hasLength(2));
    expect(p.completedTasks, isEmpty);
  });

  test(
    'completion evicts the oldest native record when Library reaches its limit',
    () async {
      snapshots = [
        {
          'id': 200,
          'status': 'completed',
          'uri': 'content://downloads/200',
          'bytes': 100,
          'total': 100,
        },
      ];
      final p = await restore(
        library: List.generate(100, (i) => savedTask(i + 1)),
        queue: [
          {...savedTask(200, completed: false), 'status': 'queued'},
        ],
      );
      expect(p.completedTasks, hasLength(100));
      expect(retained.last, {...List.generate(99, (i) => i + 1), 200});
      expect(retained.last, isNot(contains(100)));
    },
  );

  test(
    'open and share pass the selected native ID with its exact URI',
    () async {
      final p = await restore(library: [savedTask(7)]);
      for (final share in [false, true]) {
        await p.openFile(p.completedTasks.single, share: share);
        expect(calls.last.method, share ? 'share' : 'open');
        expect(calls.last.arguments['id'], 7);
        expect(calls.last.arguments['uri'], 'content://downloads/7');
      }
    },
  );

  test(
    'enqueue completing after disposal is saved before native reconciliation',
    () async {
      final p = await restore();
      await p.fetchVideoMetadata(source);
      enqueue = Completer<int>();
      final starting = p.startDownload(rightsConfirmed: true);
      await pumpEventQueue();
      p.dispose();
      providers.remove(p);
      enqueue!.complete(500);
      expect(await starting, isTrue);
      expect(retained.last, {500});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('queue_v2'), contains('500'));
    },
  );

  test('failed native reconciliation preserves saved records and retries on next save', () async {
    final p = await restore(library: [savedTask(1)]);
    syncFails = true;
    await p.fetchVideoMetadata(source);
    expect(await p.startDownload(rightsConfirmed: true), isTrue);
    expect(p.activeTasks.single.nativeDownloadId, 500);
    syncFails = false;
    await p.clearPrivateRecords();
    expect(retained.last, {500});
  });

  test('non-Android preview never calls native reconciliation', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await restore(library: [savedTask(1)]);
    expect(calls, isEmpty);
  });

  test('startup readiness does not wait for native metadata cleanup', () async {
    SharedPreferences.setMockInitialValues({});
    final cleanup = Completer<void>();
    messenger.setMockMethodCallHandler(AndroidDownloadService.channel, (
      call,
    ) async {
      expect(call.method, 'reconcile');
      await cleanup.future;
      return null;
    });
    final p = DownloadProvider();
    providers.add(p);
    try {
      await p.ready.timeout(const Duration(seconds: 2));
      expect(cleanup.isCompleted, isFalse);
    } finally {
      cleanup.complete();
      await pumpEventQueue();
    }
  });

  test(
    'unchanged retained IDs do not repeat native bookkeeping work',
    () async {
      final p = await restore(queue: [savedTask(2, completed: false)]);
      final syncs = retained.length;
      await p.clearPrivateRecords();
      expect(retained, hasLength(syncs));
      expect(retained.single, {2});
    },
  );

  test(
    'cleanup failure with empty retention retries on the next save',
    () async {
      syncFails = true;
      final p = await restore();
      expect(retained, isEmpty);
      syncFails = false;
      await p.clearPrivateRecords();
      expect(retained.single, isEmpty);
    },
  );

  test(
    'restart after deletion does not restore forgotten Library ownership',
    () async {
      final p = await restore(library: [savedTask(1), savedTask(2)]);
      p.deleteCompletedTask('android_1');
      await pumpEventQueue();
      p.dispose();
      providers.remove(p);
      retained.clear();
      final restarted = DownloadProvider();
      providers.add(restarted);
      await restarted.ready;
      await pumpEventQueue();
      expect(restarted.completedTasks.single.nativeDownloadId, 2);
      expect(retained.single, {2});
    },
  );
}
