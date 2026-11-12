// Reconstructed for the web preview. This browser-only source was absent from
// the Android APK; the original recovered Dart files remain unchanged.
import 'package:web/web.dart' as web;

void downloadOnWeb(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    throw const FormatException('A public HTTPS media link is required.');
  }
  final link = web.HTMLAnchorElement()
    ..href = uri.toString()
    ..target = '_blank'
    ..rel = 'noopener noreferrer'
    ..download = '';
  link.click();
}
