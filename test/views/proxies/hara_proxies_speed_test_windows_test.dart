import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfusion/core/controller.dart';
import 'package:kfusion/core/interface.dart';
import 'package:kfusion/core/singbox/singbox_runner.dart';
import 'package:kfusion/enum/enum.dart';
import 'package:kfusion/features/config_hub/singbox_action.dart';
import 'package:kfusion/features/config_hub/singbox_speedtest.dart';
import 'package:kfusion/models/models.dart';
import 'package:kfusion/providers/providers.dart';
import 'package:kfusion/state.dart';
import 'package:kfusion/ui/ui.dart';
import 'package:kfusion/views/proxies/hara_proxies.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../../helpers/app_paths.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_profiles.dart';

class _MockCoreHandlerInterface extends Mock implements CoreHandlerInterface {}

class _BearerSingBoxAction extends SingBoxAction {
  _BearerSingBoxAction(this._api);

  final SingBoxClashApi _api;

  @override
  Future<SingBoxStatus> build() async =>
      const SingBoxStatus(state: SingBoxState.running);

  @override
  SingBoxClashApi? get api => _api;
}

class _RecordingSingBoxApi extends SingBoxClashApi {
  _RecordingSingBoxApi() : super(port: 0, secret: '');

  @override
  Future<void> changeProxy(String groupName, String proxyName) async {}

  @override
  Future<void> closeConnections() async {}
}

class _FakeTester extends SingBoxSpeedTester {
  String? measuredTarget;

  @override
  Future<SpeedTestResult> measure({
    required String targetName,
    required String profileText,
    required String homeDir,
    required bool Function() cancelled,
  }) async {
    measuredTarget = targetName;
    return SpeedTestResult(name: targetName, mbps: 342, totalBytes: 4096);
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
    selectedMap: {'GLOBAL': 'Home', 'Home': 'JP-03', 'Auto': 'JP-03'},
    autoUpdateDuration: Duration.zero,
  );

  final groups = [
    const Group(
      name: 'GLOBAL',
      type: GroupType.Selector,
      all: [
        Proxy(name: 'Home', type: 'Selector'),
        Proxy(name: 'JP-03', type: 'Shadowsocks'),
        Proxy(name: 'DIRECT', type: 'Direct'),
      ],
    ),
    const Group(
      name: 'Home',
      type: GroupType.Selector,
      all: [
        Proxy(name: 'JP-03', type: 'Shadowsocks'),
        Proxy(name: 'HK-01', type: 'Shadowsocks'),
      ],
    ),
    const Group(
      name: 'Auto',
      type: GroupType.URLTest,
      all: [
        Proxy(name: 'JP-03', type: 'Shadowsocks'),
        Proxy(name: 'HK-01', type: 'Shadowsocks'),
      ],
    ),
  ];

  late Directory root;
  late _FakeTester fakeTester;
  late _MockCoreHandlerInterface core;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('speed_test_windows_');
    await useAppPaths(root);
    final profileFile = File(p.join(root.path, 'profiles', '1.yaml'));
    await profileFile.create(recursive: true);
    await profileFile.writeAsString(_profileYaml);
  });

  tearDownAll(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  Widget sectionsHost() {
    return Builder(
      builder: (context) => Material(
        color: context.haraPalette.bg,
        child: CustomScrollView(
          slivers: [
            for (final (index, group) in groups.indexed)
              HaraProxyGroupSection(
                group: group,
                exitName: null,
                first: index == 0,
                exitMarker: HaraExitMarker.dot,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> pumpPage(WidgetTester tester, {required bool supported}) async {
    tester.view.physicalSize = const Size(412, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles(const [profile])),
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
        groupsProvider.overrideWithValue(groups),
        currentGroupsStateProvider.overrideWithValue(
          GroupsState(value: groups),
        ),
        delayProvider(proxyName: 'JP-03', testUrl: null).overrideWithValue(58),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        singBoxPanelGroupsProvider.overrideWithValue(
          const AsyncData({
            'GLOBAL': (
              type: 'Selector',
              now: 'JP-03',
              all: ['Home', 'JP-03', 'DIRECT'],
            ),
            'Home': (type: 'Selector', now: 'JP-03', all: ['JP-03', 'HK-01']),
            'Auto': (type: 'Selector', now: 'JP-03', all: ['JP-03', 'HK-01']),
          }),
        ),
        singBoxActionProvider.overrideWith(
          () => _BearerSingBoxAction(_RecordingSingBoxApi()),
        ),
        speedTestSingBoxSupportedProvider.overrideWithValue(supported),
        singBoxSpeedTesterProvider.overrideWithValue(fakeTester),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
    });
    globalState.container = container;
    container
        .read(viewSizeProvider.notifier)
        .update((_) => const Size(412, 800));
    container
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(speedTestNoticeAccepted: true));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(locale: const Locale('zh', 'CN'), child: sectionsHost()),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    fakeTester = _FakeTester();
    core = _MockCoreHandlerInterface();
  });

  testWidgets('on Windows the sing-box entry runs the second instance', (
    tester,
  ) async {
    await pumpPage(tester, supported: true);

    await tester.tap(find.text('测速').first);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    expect(fakeTester.measuredTarget, 'JP-03');
    expect(find.text('↓ 342 Mbps · 单连接'), findsNWidgets(3));
    verifyNever(() => core.asyncTestSpeed(any()));
  });

  testWidgets('off Windows the sing-box entry stays inert', (tester) async {
    await pumpPage(tester, supported: false);

    await tester.tap(find.text('测速').first);
    await tester.pumpAndSettle();

    expect(fakeTester.measuredTarget, isNull);
    verifyNever(() => core.asyncTestSpeed(any()));
  });
}
