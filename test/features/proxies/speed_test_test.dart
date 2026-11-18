import 'package:kfusion/features/proxies/speed_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatSpeedMbps', () {
    test('keeps one decimal below a hundred', () {
      expect(formatSpeedMbps(86.44), '86.4');
      expect(formatSpeedMbps(9.96), '10.0');
      expect(formatSpeedMbps(0.42), '0.4');
    });

    test('rounds to whole numbers at a hundred and above', () {
      expect(formatSpeedMbps(100), '100');
      expect(formatSpeedMbps(342.4), '342');
      expect(formatSpeedMbps(1553.8), '1554');
    });
  });

  group('SpeedTestState', () {
    test('a running test carries no reading', () {
      const state = SpeedTestState.running();
      expect(state.phase, SpeedTestPhase.running);
      expect(state.mbps, isNull);
    });

    test('a succeeded test carries its reading and its traffic', () {
      const state = SpeedTestState.succeeded(mbps: 86.4, totalBytes: 2048);
      expect(state.phase, SpeedTestPhase.succeeded);
      expect(state.mbps, 86.4);
      expect(state.totalBytes, 2048);
    });

    test('a failed test carries no reading to mistake for a measurement', () {
      const state = SpeedTestState.failed();
      expect(state.phase, SpeedTestPhase.failed);
      expect(state.mbps, isNull);
      expect(state.totalBytes, 0);
    });
  });
}
