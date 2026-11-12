import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videodownloader/models/download_task.dart';
import 'package:videodownloader/providers/download_provider.dart';
import 'package:videodownloader/services/android_download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const source = 'https://example.com/clip.mp4';
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late DownloadProvider provider;
  late Future<Object?> Function(MethodCall) native;
  late List<MethodCall> calls;
  var nextId = 100;

  Future<void> start() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    calls = [];
    nextId = 100;
    native = (call) async => switch (call.method) {
      'inspect' => {'bytes': 1024},
      'enqueue' => ++nextId,
      'query' => [],
      _ => null,
    };
    messenger.setMockMethodCallHandler(AndroidDownloadService.channel, (call) {
      calls.add(call);
      return native(call);
    });
    provider = DownloadProvider();
    await provider.ready;
    await provider.fetchVideoMetadata(source);
    expect(await provider.startDownload(rightsConfirmed: true), isTrue);
  }

  void cancellationTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      await start();
      try {
        await body(tester);
      } finally {
        provider.dispose();
        messenger.setMockMethodCallHandler(
          AndroidDownloadService.channel,
          null,
        );
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  Map<String, Object> completed(int id) => {
    'id': id,
    'status': 'completed',
    'uri': 'content://downloads/$id',
  };

  Future<void> expectEmptySavedState() async {
    final prefs = await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString('queue_v2')!), isEmpty);
    expect(jsonDecode(prefs.getString('library_v2')!), isEmpty);
  }

  cancellationTest('cancel finishing before a stale completion stays removed', (
    tester,
  ) async {
    final query = Completer<Object?>();
    final cancel = Completer<Object?>();
    native = (call) async => switch (call.method) {
      'query' => query.future,
      'cancel' => cancel.future,
      _ => null,
    };
    await tester.pump(const Duration(seconds: 2));
    final cancelling = provider.cancelTask(provider.activeTasks.single.id);
    await tester.pump();
    cancel.complete(null);
    await cancelling;
    query.complete([completed(101)]);
    await tester.pump();
    expect(provider.activeTasks, isEmpty);
    expect(provider.completedTasks, isEmpty);
    expect(provider.isPolling, isFalse);
    await expectEmptySavedState();
  });

  cancellationTest(
    'pending cancellation cannot complete or survive restoration',
    (tester) async {
      final query = Completer<Object?>();
      final cancel = Completer<Object?>();
      native = (call) async => switch (call.method) {
        'query' => query.future,
        'cancel' => cancel.future,
        _ => null,
      };
      await tester.pump(const Duration(seconds: 2));
      final cancelling = provider.cancelTask(provider.activeTasks.single.id);
      await tester.pump();
      query.complete([completed(101)]);
      await tester.pump();
      expect(provider.completedTasks, isEmpty);
      cancel.complete(null);
      await cancelling;
      await expectEmptySavedState();
      provider.dispose();
      provider = DownloadProvider();
      await provider.ready;
      expect(provider.activeTasks, isEmpty);
      expect(provider.completedTasks, isEmpty);
    },
  );

  cancellationTest(
    'failed cancel keeps the job and later completion is recovered',
    (tester) async {
      final query = Completer<Object?>();
      final cancel = Completer<Object?>();
      native = (call) async => switch (call.method) {
        'query' => query.future,
        'cancel' => cancel.future,
        _ => null,
      };
      await tester.pump(const Duration(seconds: 2));
      final cancelling = provider.cancelTask(provider.activeTasks.single.id);
      await tester.pump();
      query.complete([completed(101)]);
      await tester.pump();
      cancel.completeError(
        PlatformException(code: 'TEMPORARY', message: 'Busy'),
      );
      await cancelling;
      expect(provider.activeTasks.single.nativeDownloadId, 101);
      expect(provider.completedTasks, isEmpty);
      expect(provider.errorMessage, contains('Busy'));
      native = (call) async => call.method == 'query' ? [completed(101)] : null;
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(provider.activeTasks, isEmpty);
      expect(provider.completedTasks.single.nativeDownloadId, 101);
      expect(provider.isPolling, isFalse);
    },
  );

  cancellationTest('duplicate cancel sends only one native request', (
    tester,
  ) async {
    final cancel = Completer<Object?>();
    native = (call) async =>
        call.method == 'cancel' ? await cancel.future : null;
    final id = provider.activeTasks.single.id;
    final first = provider.cancelTask(id);
    await tester.pump();
    expect(provider.errorMessage, isNull);
    final second = provider.cancelTask(id);
    await tester.pump();
    expect(calls.where((call) => call.method == 'cancel'), hasLength(1));
    cancel.complete(null);
    await Future.wait([first, second]);
    expect(provider.activeTasks, isEmpty);
    await expectEmptySavedState();
  });

  cancellationTest(
    'cancelling one task does not delay another task reaching Library',
    (tester) async {
      final cancelledTask = provider.activeTasks.single;
      expect(await provider.startDownload(rightsConfirmed: true), isTrue);
      final query = Completer<Object?>();
      final cancel = Completer<Object?>();
      native = (call) async => switch (call.method) {
        'query' => query.future,
        'cancel' => cancel.future,
        _ => null,
      };
      await tester.pump(const Duration(seconds: 2));
      final cancelling = provider.cancelTask(cancelledTask.id);
      await tester.pump();
      query.complete([completed(101), completed(102)]);
      await tester.pump();
      expect(provider.completedTasks.single.nativeDownloadId, 102);
      cancel.complete(null);
      await cancelling;
      expect(provider.activeTasks, isEmpty);
      expect(provider.completedTasks.single.nativeDownloadId, 102);
      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString('queue_v2')!), isEmpty);
      expect(
        (jsonDecode(prefs.getString('library_v2')!) as List).single['nativeId'],
        102,
      );
    },
  );

  cancellationTest(
    'completion winning before Cancel never deletes the saved file',
    (tester) async {
      final id = provider.activeTasks.single.id;
      native = (call) async => call.method == 'query' ? [completed(101)] : null;
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      await provider.cancelTask(id);
      expect(provider.completedTasks.single.nativeDownloadId, 101);
      expect(calls.where((call) => call.method == 'cancel'), isEmpty);
    },
  );

  cancellationTest(
    'retry cannot enqueue a replacement while cancellation is pending',
    (tester) async {
      native = (call) async => call.method == 'query'
          ? [
              {'id': 101, 'status': 'failed', 'error': 'Network failure'},
            ]
          : null;
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      final task = provider.activeTasks.single;
      expect(task.status, TaskStatus.failed);
      final cancel = Completer<Object?>();
      native = (call) async => switch (call.method) {
        'cancel' => await cancel.future,
        'enqueue' => ++nextId,
        _ => [],
      };
      final cancelling = provider.cancelTask(task.id);
      await tester.pump();
      expect(provider.errorMessage, isNull);
      await provider.retryTask(task.id);
      expect(calls.where((call) => call.method == 'enqueue'), hasLength(1));
      cancel.complete(null);
      await cancelling;
      expect(provider.activeTasks, isEmpty);
    },
  );

  cancellationTest('Cancel still works while Retry is checking the source', (
    tester,
  ) async {
    final sourceReply = jsonEncode({
      'formats': [
        {'id': 'video', 'ext': 'mp4', 'url': source},
      ],
    });
    native = (call) async => switch (call.method) {
      'extract' => sourceReply,
      'enqueue' => ++nextId,
      'query' => [
        {'id': 102, 'status': 'failed', 'error': 'Network failure'},
      ],
      _ => null,
    };
    await provider.fetchVideoMetadata('https://vimeo.com/123456');
    expect(await provider.startDownload(rightsConfirmed: true), isTrue);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    final task = provider.activeTasks.singleWhere(
      (task) => task.nativeDownloadId == 102,
    );
    final lookup = Completer<Object?>();
    final cancel = Completer<Object?>();
    native = (call) async => switch (call.method) {
      'extract' => await lookup.future,
      'cancel' => await cancel.future,
      'enqueue' => ++nextId,
      _ => [],
    };
    final retrying = provider.retryTask(task.id);
    await tester.pump();
    final cancelling = provider.cancelTask(task.id);
    await tester.pump();
    expect(calls.where((call) => call.method == 'cancel'), hasLength(1));
    lookup.complete(sourceReply);
    await retrying;
    expect(calls.where((call) => call.method == 'enqueue'), hasLength(2));
    cancel.complete(null);
    await cancelling;
    expect(provider.activeTasks.any((item) => item.id == task.id), isFalse);
  });
}
