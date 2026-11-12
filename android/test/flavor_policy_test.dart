import 'package:flutter_test/flutter_test.dart';
import 'package:videodownloader/services/media_policy.dart';

void main() {
  test('flavor policy controls source restrictions without removing network safety', () {
    const open = String.fromEnvironment('FLUTTER_APP_FLAVOR') == 'unrestricted';
    expect(MediaPolicy.restricted, !open);
    for (final link in [
      'https://youtube.com/watch?v=example',
      'https://www.pornhub.com/',
    ]) {
      if (open) {
        expect(MediaPolicy.validate(link).scheme, 'https');
      } else {
        expect(() => MediaPolicy.validate(link), throwsFormatException);
      }
    }
    for (final link in [
      'http://example.com/video.mp4',
      'https://user:pass@example.com/video.mp4',
      'https://localhost/video.mp4',
      'https://127.0.0.1/a',
    ]) {
      expect(() => MediaPolicy.validate(link), throwsFormatException);
    }
  });
}
