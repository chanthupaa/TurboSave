import 'package:flutter_test/flutter_test.dart';
import 'package:videodownloader/services/media_policy.dart';

void main() {
  test('selected release edition matches the expected source policy', () {
    const open = bool.fromEnvironment('EXPECT_OPEN');
    expect(MediaPolicy.restricted, !open);
    for (final source in [
      'https://youtube.com/watch?v=example',
      'https://www.pornhub.com/',
    ]) {
      if (open) {
        expect(MediaPolicy.validate(source).scheme, 'https');
      } else {
        expect(() => MediaPolicy.validate(source), throwsFormatException);
      }
    }
    expect(
      () => MediaPolicy.validate('https://localhost/private.mp4'),
      throwsFormatException,
    );
  });
}
