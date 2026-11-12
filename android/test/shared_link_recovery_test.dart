import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:videodownloader/services/media_policy.dart';
import 'package:videodownloader/services/shared_link_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const source = 'https://example.com/clip.mp4';
  final handled = <String>[];
  final errors = <String>[];
  final acknowledgements = <String>[];
  var pending = <Map<String, String>>[];
  var failures = 0;
  var missingPlugin = false;
  Completer<void>? handling;
  Completer<void>? acknowledging;
  late SharedLinkService inbox;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    handled.clear();
    errors.clear();
    acknowledgements.clear();
    failures = 0;
    missingPlugin = false;
    handling = null;
    acknowledging = null;
    pending = [
      {'id': 'one', 'text': source},
    ];
    messenger.setMockMethodCallHandler(SharedLinkService.channel, (call) async {
      if (call.method == 'getPendingShares') return List.of(pending);
      if (call.method == 'acknowledgeShare') {
        final id = call.arguments['id'] as String;
        acknowledgements.add(id);
        await acknowledging?.future;
        if (failures > 0) {
          failures--;
          if (missingPlugin) throw MissingPluginException('Unavailable');
          throw PlatformException(code: 'TEMPORARY');
        }
        pending.removeWhere((item) => item['id'] == id);
        return null;
      }
      throw StateError('Unexpected native call: ${call.method}');
    });
    inbox = SharedLinkService(
      onLink: (link) async {
        handled.add(link);
        await handling?.future;
      },
      onError: errors.add,
    );
  });

  tearDown(() {
    inbox.dispose();
    messenger.setMockMethodCallHandler(SharedLinkService.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> resume() async {
    await inbox.resume();
    await pumpEventQueue();
  }

  test(
    'repeated failed acknowledgements retry without rehandling the link',
    () async {
      failures = 2;
      await inbox.start();
      await pumpEventQueue();
      await resume();
      await resume();
      await resume();
      expect(handled, [source]);
      expect(acknowledgements, ['one', 'one', 'one']);
      expect(pending, isEmpty);
      expect(errors, isEmpty);
    },
  );

  test(
    'a failed acknowledgement does not block the next shared link',
    () async {
      failures = 1;
      pending.add({'id': 'two', 'text': 'https://example.com/next.mp4'});
      await inbox.start();
      await pumpEventQueue();
      expect(handled, [source, 'https://example.com/next.mp4']);
      await resume();
      expect(handled, hasLength(2));
      expect(acknowledgements, ['one', 'two', 'one']);
      expect(pending, isEmpty);
    },
  );

  test('duplicate delivery while handling never acknowledges early', () async {
    handling = Completer<void>();
    await inbox.start();
    await pumpEventQueue();
    await resume();
    expect(handled, [source]);
    expect(acknowledgements, isEmpty);
    handling!.complete();
    await pumpEventQueue();
    expect(acknowledgements, ['one']);
    expect(pending, isEmpty);
  });

  test(
    'queued resume retries serialize and stop after acknowledgement succeeds',
    () async {
      failures = 1;
      acknowledging = Completer<void>();
      await inbox.start();
      await pumpEventQueue();
      await resume();
      await resume();
      await resume();
      expect(acknowledgements, ['one']);
      acknowledging!.complete();
      await pumpEventQueue();
      expect(handled, [source]);
      expect(acknowledgements, ['one', 'one']);
      expect(pending, isEmpty);
    },
  );

  test(
    'a missing acknowledgement method cannot poison later processing',
    () async {
      failures = 1;
      missingPlugin = true;
      await inbox.start();
      await pumpEventQueue();
      await resume();
      expect(handled, [source]);
      expect(acknowledgements, ['one', 'one']);
      expect(pending, isEmpty);
    },
  );

  test('disposing after an acknowledgement failure stops retries', () async {
    failures = 1;
    await inbox.start();
    await pumpEventQueue();
    inbox.dispose();
    await resume();
    expect(handled, [source]);
    expect(acknowledgements, ['one']);
    expect(pending, hasLength(1));
  });

  test(
    'disposing during handling leaves the native item unacknowledged',
    () async {
      handling = Completer<void>();
      await inbox.start();
      await pumpEventQueue();
      inbox.dispose();
      handling!.complete();
      await pumpEventQueue();
      expect(handled, [source]);
      expect(acknowledgements, isEmpty);
      expect(pending, hasLength(1));
    },
  );

  test(
    'invalid shared text reports its error once while acknowledgement retries',
    () async {
      pending = [
        {'id': 'one', 'text': 'http://example.com/clip.mp4'},
      ];
      failures = 1;
      await inbox.start();
      await pumpEventQueue();
      await resume();
      expect(handled, isEmpty);
      expect(errors, hasLength(1));
      expect(acknowledgements, ['one', 'one']);
      expect(pending, isEmpty);
    },
  );

  for (final suffix in ['!', '?', ',', '.', ';', '?!', '(part)', ')', ']']) {
    for (final location in [
      'https://example.com/watch/',
      'https://example.com/watch?id=',
    ]) {
      final link = '${location}hello$suffix';
      test('literal URL preserves $link', () {
        expect(SharedLinkService.parseText('  $link\n'), link);
      });
    }
  }

  test('encoded delimiters and balanced parentheses are unchanged', () {
    const link = 'https://example.com/clip(part)?id=hello%21%3F#part(1)';
    expect(SharedLinkService.parseText(link), link);
  });

  test('prose and wrappers still resolve one link', () {
    for (final text in [
      'Watch this: ($source).',
      '<$source>',
      '[$source]',
      'Watch $source!',
    ]) {
      expect(SharedLinkService.parseText(text), source);
    }
  });

  test('wrapped meaningful punctuation inside parentheses is retained', () {
    const link = 'https://example.com/watch?id=hello!';
    expect(SharedLinkService.parseText('Watch ($link).'), link);
  });

  test(
    'literal handling retains length source and destination restrictions',
    () {
      for (final link in [
        'https://example.com/a https://example.com/b',
        'http://example.com/a!',
        'https://localhost/a!',
        'https://127.0.0.1/a!',
        'https://user:password@example.com/a!',
        'https://example.com:444/a!',
        if (MediaPolicy.restricted) 'https://music.youtube.com/watch?id=hello!',
        'https://example.com/${'x' * 8192}',
      ]) {
        expect(() => SharedLinkService.parseText(link), throwsFormatException);
      }
    },
  );
}
