import 'package:kfusion/common/constant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Tripwires over the shipped sources: that endpoint 403s at 100,000,000 bytes and up, and the Hetzner family refuses this app's TLS stack.
  group('speedTestDownloadUrls', () {
    test('the primary request stays under the Cloudflare bytes ceiling', () {
      final primary = Uri.parse(speedTestDownloadUrls.first);
      expect(primary.host, 'speed.cloudflare.com');
      final bytes = int.parse(primary.queryParameters['bytes']!);
      expect(bytes, greaterThan(0));
      expect(bytes, lessThan(100000000));
    });

    test('no retired source is listed', () {
      for (final url in speedTestDownloadUrls) {
        expect(Uri.parse(url).scheme, 'https');
        expect(url, isNot(contains('hetzner')));
      }
    });
  });
}
