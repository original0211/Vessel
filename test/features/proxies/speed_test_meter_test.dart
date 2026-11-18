import 'package:kfusion/features/proxies/speed_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('speedMbpsForWindow', () {
    // The same table the Go meter is pinned against in
    // core/speedtest_test.go.
    test('converts window bytes and duration to Mbps', () {
      expect(speedMbpsForWindow(12500000, const Duration(seconds: 1)), 100);
      expect(
        speedMbpsForWindow(1250000, const Duration(milliseconds: 500)),
        20,
      );
      expect(speedMbpsForWindow(0, const Duration(seconds: 1)), 0);
      expect(speedMbpsForWindow(100, Duration.zero), 0);
    });
  });

  group('SpeedTestMeter', () {
    final base = DateTime.fromMillisecondsSinceEpoch(1000000);

    test('the warmup ends on the time bound', () {
      final meter = SpeedTestMeter(startedAt: base);
      meter.add(100, base.add(const Duration(milliseconds: 500)));
      expect(meter.warmupDone, isFalse);
      meter.add(100, base.add(const Duration(seconds: 1)));
      expect(meter.warmupDone, isTrue);
      meter.add(700, base.add(const Duration(seconds: 2)));
      final window = meter.window(base.add(const Duration(seconds: 2)));
      expect(window.bytes, 700);
      expect(window.duration, const Duration(seconds: 1));
    });

    test('the warmup ends on the byte bound', () {
      final meter = SpeedTestMeter(startedAt: base);
      meter.add(512 << 10, base.add(const Duration(milliseconds: 100)));
      expect(meter.warmupDone, isTrue);
      final window = meter.window(base.add(const Duration(milliseconds: 600)));
      expect(window.bytes, 0);
      expect(window.duration, const Duration(milliseconds: 500));
    });

    test('there is no window before the warmup ends', () {
      final meter = SpeedTestMeter(startedAt: base);
      meter.add(10, base);
      final window = meter.window(base.add(const Duration(seconds: 1)));
      expect(window.bytes, 0);
      expect(window.duration, Duration.zero);
    });

    test('a window is measurable only with bytes over the floor', () {
      expect(
        speedWindowMeasurable(const SpeedTestWindow(0, Duration(seconds: 1))),
        isFalse,
      );
      expect(
        speedWindowMeasurable(
          const SpeedTestWindow(100, Duration(milliseconds: 199)),
        ),
        isFalse,
      );
      expect(
        speedWindowMeasurable(
          const SpeedTestWindow(100, Duration(milliseconds: 200)),
        ),
        isTrue,
      );
    });
  });

  group('speedTestEntryEnabled', () {
    test('the mihomo core measures on every platform', () {
      expect(
        speedTestEntryEnabled(singBoxBearing: false, windowsPlatform: false),
        isTrue,
      );
      expect(
        speedTestEntryEnabled(singBoxBearing: false, windowsPlatform: true),
        isTrue,
      );
    });

    test('the sing-box core measures only on Windows', () {
      expect(
        speedTestEntryEnabled(singBoxBearing: true, windowsPlatform: false),
        isFalse,
      );
      expect(
        speedTestEntryEnabled(singBoxBearing: true, windowsPlatform: true),
        isTrue,
      );
    });
  });
}
