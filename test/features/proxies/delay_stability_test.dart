import 'package:flutter_test/flutter_test.dart';
import 'package:kfusion/features/proxies/delay_stability.dart';

void main() {
  group('summarizeDelayStability', () {
    test('an empty history states nothing', () {
      expect(summarizeDelayStability(const []), isNull);
    });

    test('fewer than three samples state nothing', () {
      expect(summarizeDelayStability(const [120]), isNull);
      expect(summarizeDelayStability(const [120, null]), isNull);
    });

    test('three successes give their count and span', () {
      final stability = summarizeDelayStability(const [210, 96, 150]);
      expect(stability, isNotNull);
      expect(stability!.sampleCount, 3);
      expect(stability.failureCount, 0);
      expect(stability.minDelay, 96);
      expect(stability.maxDelay, 210);
    });

    test('null and non-positive samples count as failures, not delays', () {
      final stability = summarizeDelayStability(const [100, null, -1, 300, 0]);
      expect(stability, isNotNull);
      expect(stability!.sampleCount, 5);
      expect(stability.failureCount, 3);
      expect(stability.minDelay, 100);
      expect(stability.maxDelay, 300);
    });

    test('an all-failure history has no span', () {
      final stability = summarizeDelayStability(const [null, -1, 0]);
      expect(stability, isNotNull);
      expect(stability!.sampleCount, 3);
      expect(stability.failureCount, 3);
      expect(stability.minDelay, isNull);
      expect(stability.maxDelay, isNull);
    });

    test('a single repeated value spans itself', () {
      final stability = summarizeDelayStability(const [50, 50, 50, 50]);
      expect(stability, isNotNull);
      expect(stability!.minDelay, 50);
      expect(stability.maxDelay, 50);
    });
  });
}
