import 'dart:async';
import 'dart:io';

import 'package:kfusion/core/controller.dart';
import 'package:kfusion/core/interface.dart';
import 'package:kfusion/core/singbox/singbox_runner.dart';
import 'package:kfusion/enum/enum.dart';
import 'package:kfusion/features/config_hub/singbox_action.dart';
import 'package:kfusion/features/config_hub/singbox_speedtest.dart';
import 'package:kfusion/features/proxies/speed_test.dart';
import 'package:kfusion/models/models.dart';
import 'package:kfusion/providers/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod/riverpod.dart';

import '../helpers/app_paths.dart';
import '../helpers/test_profiles.dart';

class _MockCoreHandlerInterface extends Mock implements CoreHandlerInterface {}

class _BearerSingBoxAction extends SingBoxAction {
  @override
  Future<SingBoxStatus> build() async =>
      const SingBoxStatus(state: SingBoxState.running);

  @override
  SingBoxClashApi? get api => SingBoxClashApi(port: 0, secret: '');
}

class _FakeTester extends SingBoxSpeedTester {
  _FakeTester({this.reading = 42});

  final double? reading;
  final Completer<void> gate = Completer<void>();
  bool gated = false;
  bool cancelCalled = false;
  String? measuredTarget;
  String? measuredProfileText;
  String? measuredHomeDir;

  @override
  Future<SpeedTestResult> measure({
    required String targetName,
    required String profileText,
    required String homeDir,
    required bool Function() cancelled,
  }) async {
    measuredTarget = targetName;
    measuredProfileText = profileText;
    measuredHomeDir = homeDir;
    if (gated) {
      await gate.future;
    }
    final mbps = reading;
    if (mbps == null) {
      return SpeedTestResult(name: targetName, error: 'source down');
    }
    return SpeedTestResult(name: targetName, mbps: mbps, totalBytes: 4096);
  }

  @override
  void cancel() {
    cancelCalled = true;
    if (!gate.isCompleted) {
      gate.complete();
    }
  }
}

const _profileYaml = '''
proxies:
  - name: JP-03
    type: ss
    server: 203.0.113.1
    port: 8388
    cipher: aes-128-gcm
    password: pw1
''';

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

  late Directory root;
  late _MockCoreHandlerInterface core;
  late _FakeTester tester;
  late ProviderContainer container;

  Future<void> setUpContainer({
    required bool supported,
    double? reading = 42,
  }) async {
    root = await Directory.systemTemp.createTemp('speed_test_singbox_');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    await useAppPaths(root);
    final profileFile = File(p.join(root.path, 'profiles', '1.yaml'));
    await profileFile.create(recursive: true);
    await profileFile.writeAsString(_profileYaml);
    core = _MockCoreHandlerInterface();
    tester = _FakeTester(reading: reading);
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles(const [profile])),
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
        groupsProvider.overrideWithValue(groups),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        singBoxActionProvider.overrideWith(() => _BearerSingBoxAction()),
        speedTestSingBoxSupportedProvider.overrideWithValue(supported),
        singBoxSpeedTesterProvider.overrideWithValue(tester),
      ],
    );
    addTearDown(container.dispose);
    // The action reads the bearing synchronously, as the UI keeps it
    // warm in production; build it before acting.
    await container.read(singBoxActionProvider.future);
  }

  SpeedTestState? stateOf(String name) =>
      container.read(speedTestResultsProvider)[name];

  ProxiesAction action() => container.read(proxiesActionProvider.notifier);

  test('under Windows sing-box the second instance takes the test', () async {
    await setUpContainer(supported: true);

    await action().proxySpeedTest(node);

    expect(tester.measuredTarget, 'JP-03');
    expect(tester.measuredProfileText, contains('JP-03'));
    expect(tester.measuredHomeDir, root.path);
    final state = stateOf('JP-03');
    expect(state?.phase, SpeedTestPhase.succeeded);
    expect(state?.mbps, 42);
    verifyNever(() => core.asyncTestSpeed(any()));
  });

  test('where the platform has no second instance nothing starts', () async {
    await setUpContainer(supported: false);

    await action().proxySpeedTest(node);

    expect(tester.measuredTarget, isNull);
    expect(stateOf('JP-03'), isNull);
    verifyNever(() => core.asyncTestSpeed(any()));
  });

  test('a failed instance test lands as failed, never as a reading', () async {
    await setUpContainer(supported: true, reading: null);

    await action().proxySpeedTest(node);

    expect(stateOf('JP-03')?.phase, SpeedTestPhase.failed);
    expect(stateOf('JP-03')?.mbps, isNull);
  });

  test('cancelling aborts the instance and restores the old reading', () async {
    await setUpContainer(supported: true);
    tester.gated = true;
    container
        .read(speedTestResultsProvider.notifier)
        .set('JP-03', const SpeedTestState.succeeded(mbps: 55, totalBytes: 99));

    final running = action().proxySpeedTest(node);
    while (tester.measuredTarget == null) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(stateOf('JP-03')?.phase, SpeedTestPhase.running);

    action().cancelSpeedTest();
    expect(tester.cancelCalled, isTrue);
    await running;
    expect(stateOf('JP-03')?.mbps, 55);
  });
}
