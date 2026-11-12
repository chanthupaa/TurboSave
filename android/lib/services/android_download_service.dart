import 'package:flutter/services.dart';

/// Android owns transfers and notifications, including while Flutter is closed.
class AndroidDownloadService {
  static const channel = MethodChannel('turbosave/downloads');

  static Future<String> extract(String url) async =>
      (await channel.invokeMethod<String>('extract', {'url': url})) ??
      '{"error":"The local extractor returned no result."}';

  static Future<bool> supportsAdaptive() async {
    try {
      return await channel.invokeMethod<bool>('supportsAdaptive') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<Map<String, dynamic>> inspect(String url) async =>
      Map<String, dynamic>.from(
        await channel.invokeMethod<Map>('inspect', {'url': url}) ?? {},
      );

  static Future<int> enqueue(
    String url,
    String name,
    bool wifiOnly, {
    String? ext,
    bool extracted = false,
    Map<String, String> headers = const {},
    String? audioUrl,
    Map<String, String> audioHeaders = const {},
  }) async => (await channel.invokeMethod<int>('enqueue', {
    'url': url,
    'name': name,
    'wifiOnly': wifiOnly,
    'ext': ext,
    'extracted': extracted,
    'headers': headers,
    'audioUrl': audioUrl,
    'audioHeaders': audioHeaders,
  }))!;

  static Future<List<Map<String, dynamic>>> query(List<int> ids) async =>
      (await channel.invokeMethod<List>('query', {'ids': ids}) ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  static Future<void> cancel(int id) =>
      channel.invokeMethod('cancel', {'id': id});

  static Future<void> reconcile(List<int> retainedIds) =>
      channel.invokeMethod('reconcile', {'ids': retainedIds});

  static Future<void> open(
    int id,
    String uri,
    String mimeType, {
    bool share = false,
  }) => channel.invokeMethod(share ? 'share' : 'open', {
    'id': id,
    'uri': uri,
    'mimeType': mimeType,
  });

  static Future<void> openGallery(List<Map<String, Object>> items) =>
      channel.invokeMethod('openGallery', {'items': items});
}
