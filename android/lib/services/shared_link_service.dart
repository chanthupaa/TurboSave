import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';

import 'media_policy.dart';
import 'video_parser_service.dart';

/// Receives text links only. Receiving a share never enqueues a download.
class SharedLinkService {
  static const channel = MethodChannel('turbosave/share');
  final Future<void> Function(String) onLink;
  final void Function(String) onError;
  final Set<String> _seen = {};
  final Set<String> _pendingAcknowledgements = {};
  Future<void> _work = Future.value();
  bool _disposed = false;
  SharedLinkService({required this.onLink, required this.onError});

  static String parseText(String text) {
    if (text.length > 8192)
      throw const FormatException(
        'The shared text is too long. Share one link.',
      );
    final literal = text.trim();
    if (RegExp(
      r'''^https://[^\s<>"']+$''',
      caseSensitive: false,
    ).hasMatch(literal)) {
      MediaPolicy.validate(literal);
      return literal;
    }
    final links = RegExp(r'''https://[^\s<>"']+''', caseSensitive: false)
        .allMatches(text)
        .map((match) {
          var url = match.group(0)!;
          url = url.replaceFirst(RegExp(r'[.,;!?]+$'), '');
          for (final pair in const [('(', ')'), ('[', ']'), ('{', '}')]) {
            while (url.endsWith(pair.$2) &&
                pair.$2.allMatches(url).length >
                    pair.$1.allMatches(url).length) {
              url = url.substring(0, url.length - 1);
            }
          }
          return url;
        })
        .toSet();
    final tiktokLinks = links.where((link) {
      final uri = Uri.tryParse(link);
      if (uri == null) return false;
      final host = uri.host.toLowerCase();
      if (host == 'vm.tiktok.com' || host == 'vt.tiktok.com') return true;
      return (host == 'tiktok.com' || host.endsWith('.tiktok.com')) &&
          (uri.path.startsWith('/t/') ||
              uri.path.contains('/video/') ||
              uri.path.contains('/photo/'));
    }).toList();
    if (links.length != 1 && tiktokLinks.length != 1)
      throw const FormatException(
        'Share one public HTTPS video, audio or slideshow link at a time.',
      );
    return MediaPolicy.validate(
      links.length == 1 ? links.single : tiktokLinks.single,
    ).toString();
  }

  Future<void> start() async {
    if (!VideoParserService.isAndroid) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedLink') _accept(call.arguments);
    });
    await resume();
  }

  Future<void> resume() async {
    if (_disposed || !VideoParserService.isAndroid) return;
    try {
      final pending =
          await channel.invokeListMethod<dynamic>('getPendingShares') ?? [];
      for (final item in pending.take(4)) {
        _accept(item);
      }
    } on MissingPluginException {
      /* Preview and older native hosts have no inbox. */
    } on PlatformException {
      onError('Shared links could not be read. You can still paste a link.');
    }
  }

  void _accept(dynamic value) {
    if (_disposed ||
        value is! Map ||
        value['id'] is! String ||
        value['text'] is! String)
      return;
    final id = value['id'] as String;
    if (id.length > 100) return;
    if (!_seen.add(id)) {
      if (_pendingAcknowledgements.contains(id)) {
        _work = _work.then((_) async {
          if (_pendingAcknowledgements.contains(id)) await _acknowledge(id);
        });
      }
      return;
    }
    if (_seen.length > 32) {
      final oldest = _seen.first;
      _seen.remove(oldest);
      _pendingAcknowledgements.remove(oldest);
    }
    _work = _work.then((_) async {
      if (_disposed) return;
      try {
        await onLink(parseText(value['text'] as String));
      } on FormatException catch (error) {
        onError(error.message);
      } catch (_) {
        onError(
          'Could not check the shared link. Paste it on Home to try again.',
        );
      }
      if (!_disposed) {
        if (_seen.contains(id)) _pendingAcknowledgements.add(id);
        await _acknowledge(id);
      }
    });
  }

  Future<void> _acknowledge(String id) async {
    if (_disposed) return;
    try {
      await channel.invokeMethod<void>('acknowledgeShare', {'id': id});
      _pendingAcknowledgements.remove(id);
    } catch (error, stack) {
      developer.log(
        'Could not acknowledge a handled share; retrying on the next delivery or resume.',
        name: 'TurboSave.sharing',
        error: error,
        stackTrace: stack,
      );
    }
  }

  void dispose() {
    _disposed = true;
    if (VideoParserService.isAndroid) channel.setMethodCallHandler(null);
  }
}
