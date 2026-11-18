import 'package:kfusion/common/common.dart';
import 'package:kfusion/models/models.dart';
import 'package:kfusion/providers/action.dart';
import 'package:kfusion/providers/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const url = 'https://test.example';
  final key = delayTestKey(url, 'Proxy');

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  DelaySamples samplesNotifier() =>
      container.read(delaySamplesProvider.notifier);

  group('DelaySamples provider', () {
    test('starts empty', () {
      expect(container.read(delaySamplesProvider), isEmpty);
    });

    test('records results under the delay-test key of url and name', () {
      samplesNotifier().record(
        const Delay(name: 'Proxy', url: url, value: 120),
      );
      samplesNotifier().record(
        const Delay(name: 'Proxy', url: url, value: null),
      );

      expect(container.read(delaySamplesProvider), {
        key: [120, null],
      });
    });

    test('keeps nodes and test urls in separate histories', () {
      samplesNotifier().record(const Delay(name: 'Proxy', url: url, value: 10));
      samplesNotifier().record(const Delay(name: 'Other', url: url, value: 20));
      samplesNotifier().record(
        const Delay(name: 'Proxy', url: 'https://elsewhere.example', value: 30),
      );

      final samples = container.read(delaySamplesProvider);
      expect(samples[key], [10]);
      expect(samples[delayTestKey(url, 'Other')], [20]);
      expect(samples[delayTestKey('https://elsewhere.example', 'Proxy')], [30]);
    });

    test('counts a repeated value once per test, not once per change', () {
      for (var i = 0; i < 3; i++) {
        samplesNotifier().record(
          const Delay(name: 'Proxy', url: url, value: 88),
        );
      }

      expect(container.read(delaySamplesProvider)[key], [88, 88, 88]);
    });

    test('keeps only the latest ten results, oldest first', () {
      for (var value = 1; value <= 12; value++) {
        samplesNotifier().record(Delay(name: 'Proxy', url: url, value: value));
      }

      expect(container.read(delaySamplesProvider)[key], [
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
      ]);
    });
  });

  group('delay result recording', () {
    test('every result the proxies action publishes is also sampled', () async {
      final action = container.read(proxiesActionProvider.notifier);
      action.setDelay(const Delay(name: 'Proxy', url: url, value: 42));
      action.setDelay(const Delay(name: 'Proxy', url: url, value: -1));

      expect(container.read(delaySamplesProvider)[key], [42, -1]);

      // Let the buffered publish land before the container goes away.
      await Future<void>.delayed(renderThrottleDuration * 2);
      expect(container.read(delayDataSourceProvider)[url]?['Proxy'], -1);
    });
  });
}
