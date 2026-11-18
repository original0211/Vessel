import 'dart:async';

import 'package:kfusion/core/controller.dart';
import 'package:kfusion/core/interface.dart';
import 'package:kfusion/core/singbox/singbox_runner.dart';
import 'package:kfusion/enum/enum.dart';
import 'package:kfusion/features/config_hub/singbox_action.dart';
import 'package:kfusion/features/proxies/speed_test.dart';
import 'package:kfusion/models/models.dart';
import 'package:kfusion/providers/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

import '../helpers/test_profiles.dart';

class _MockCoreHandlerInterface extends Mock implements CoreHandlerInterface {}

class _IdleSingBoxAction extends SingBoxAction {
  @override
  Future<SingBoxStatus> build() async =>
      const SingBoxStatus(state: SingBoxState.idle);

  @override
  SingBoxClashApi? get api => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const profile = Profile(
    id: 1,
    label: 'Test',
    type: ProfileType.url,
    url: 'https://example.com/sub',
    selectedMap: {'GLOBAL': 'JP-03'},
    autoUpdateDuration: Duration.zero,
  );
  const groups = [
    Group(
      name: 'GLOBAL',
      type: GroupType.Selector,
      all: [
        Proxy(name: 'JP-03', type: 'Shadowsocks'),
        Proxy(name: 'HK-01', type: 'Shadowsocks'),
      ],
    ),
  ];
  const node = Proxy(name: 'JP-03', type: 'Shadowsocks');

  late _MockCoreHandlerInterface core;
  late ProviderContainer container;

  setUp(() {
    core = _MockCoreHandlerInterface();
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles(const [profile])),
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
        groupsProvider.overrideWithValue(groups),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        singBoxActionProvider.overrideWith(() => _IdleSingBoxAction()),
      ],
    );
    addTearDown(container.dispose);
  });

  SpeedTestState? stateOf(String name) =>
      container.read(speedTestResultsProvider)[name];

  ProxiesAction action() => container.read(proxiesActionProvider.notifier);

  group('SpeedTestResults store', () {
    test('starts empty, sets and clears per node', () {
      final store = container.read(speedTestResultsProvider.notifier);
      expect(container.read(speedTestResultsProvider), isEmpty);

      store.set('JP-03', const SpeedTestState.running());
      store.set(
        'HK-01',
        const SpeedTestState.succeeded(mbps: 42, totalBytes: 10),
      );
      expect(stateOf('JP-03')?.phase, SpeedTestPhase.running);
      expect(stateOf('HK-01')?.mbps, 42);

      store.clear('JP-03');
      expect(stateOf('JP-03'), isNull);
      expect(stateOf('HK-01'), isNotNull);
    });
  });

  group('proxySpeedTest', () {
    test('publishes running, then the measured reading', () async {
      final completer = Completer<SpeedTestResult?>();
      when(
        () => core.asyncTestSpeed('JP-03'),
      ).thenAnswer((_) => completer.future);

      final running = action().proxySpeedTest(node);
      expect(stateOf('JP-03')?.phase, SpeedTestPhase.running);
      expect(container.read(speedTestActiveNameProvider), 'JP-03');

      completer.complete(
        const SpeedTestResult(name: 'JP-03', mbps: 86.4, totalBytes: 4096),
      );
      await running;

      final state = stateOf('JP-03');
      expect(state?.phase, SpeedTestPhase.succeeded);
      expect(state?.mbps, 86.4);
      expect(state?.totalBytes, 4096);
      expect(container.read(speedTestActiveNameProvider), isNull);
    });

    test('an error result and a missing result both land as failed', () async {
      when(() => core.asyncTestSpeed('JP-03')).thenAnswer(
        (_) async => const SpeedTestResult(name: 'JP-03', error: 'refused'),
      );
      await action().proxySpeedTest(node);
      expect(stateOf('JP-03')?.phase, SpeedTestPhase.failed);
      expect(stateOf('JP-03')?.mbps, isNull);

      when(() => core.asyncTestSpeed('JP-03')).thenAnswer((_) async => null);
      await action().proxySpeedTest(node);
      expect(stateOf('JP-03')?.phase, SpeedTestPhase.failed);
    });

    test('a thrown core error lands as failed, never as a reading', () async {
      when(() => core.asyncTestSpeed('JP-03')).thenThrow(Exception('down'));
      await action().proxySpeedTest(node);
      expect(stateOf('JP-03')?.phase, SpeedTestPhase.failed);
      expect(stateOf('JP-03')?.mbps, isNull);
    });

    test('a second test never starts while one is running', () async {
      final completer = Completer<SpeedTestResult?>();
      when(
        () => core.asyncTestSpeed(any()),
      ).thenAnswer((_) => completer.future);

      final running = action().proxySpeedTest(node);
      await action().proxySpeedTest(
        const Proxy(name: 'HK-01', type: 'Shadowsocks'),
      );

      verify(() => core.asyncTestSpeed(any())).called(1);
      expect(stateOf('HK-01'), isNull);

      completer.complete(
        const SpeedTestResult(name: 'JP-03', mbps: 10, totalBytes: 1),
      );
      await running;
    });

    test('cancelling restores the reading the test replaced', () async {
      container
          .read(speedTestResultsProvider.notifier)
          .set(
            'JP-03',
            const SpeedTestState.succeeded(mbps: 55, totalBytes: 99),
          );
      final completer = Completer<SpeedTestResult?>();
      when(
        () => core.asyncTestSpeed('JP-03'),
      ).thenAnswer((_) => completer.future);

      final running = action().proxySpeedTest(node);
      expect(stateOf('JP-03')?.phase, SpeedTestPhase.running);

      action().cancelSpeedTest();
      expect(stateOf('JP-03')?.mbps, 55);

      completer.complete(
        const SpeedTestResult(name: 'JP-03', mbps: 999, totalBytes: 1),
      );
      await running;
      expect(stateOf('JP-03')?.mbps, 55);
    });

    test('cancelling a first test leaves no state behind', () async {
      final completer = Completer<SpeedTestResult?>();
      when(
        () => core.asyncTestSpeed('JP-03'),
      ).thenAnswer((_) => completer.future);

      final running = action().proxySpeedTest(node);
      action().cancelSpeedTest();
      expect(stateOf('JP-03'), isNull);

      completer.complete(
        const SpeedTestResult(name: 'JP-03', mbps: 999, totalBytes: 1),
      );
      await running;
      expect(stateOf('JP-03'), isNull);
    });
  });
}
