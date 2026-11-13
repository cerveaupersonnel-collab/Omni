import 'package:flutter_test/flutter_test.dart';
import 'package:omni/core/utils/format.dart';

void main() {
  group('formatBytes', () {
    test('small values stay in bytes', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(500), '500 B');
    });
    test('scales to KB, MB and GB', () {
      expect(formatBytes(1536), '1.5 KB');
      expect(formatBytes(1048576), '1.0 MB');
      expect(formatBytes(5 * 1024 * 1024 * 1024), '5.0 GB');
    });
  });

  group('formatDuration', () {
    test('minutes and seconds', () => expect(formatDuration(const Duration(seconds: 65)), '01:05'));
    test('hours', () => expect(formatDuration(const Duration(seconds: 3661)), '1:01:01'));
  });
}
