import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfusion/core/controller.dart';
import 'package:kfusion/core/interface.dart';
import 'package:kfusion/core/singbox/singbox_runner.dart';
import 'package:kfusion/enum/enum.dart';
import 'package:kfusion/features/config_hub/singbox_action.dart';
import 'package:kfusion/features/proxies/speed_test.dart';
import 'package:kfusion/models/models.dart';
import 'package:kfusion/providers/providers.dart';
import 'package:kfusion/state.dart';
import 'package:kfusion/ui/ui.dart';
import 'package:kfusion/views/proxies/hara_proxies.dart';
import 'package:mocktail/mocktail.dart';

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

  Future<ProviderContainer> pumpPage(
    WidgetTester tester, {
    SpeedTestState? jp03State,
    _MockCoreHandlerInterface? core,
    bool singBoxBearing = false,
    bool noticeAccepted = false,
  }) async {
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
        if (core != null)
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        if (singBoxBearing) ...[
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
        ],
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
    if (noticeAccepted) {
      container
          .read(appSettingProvider.notifier)
          .update((state) => state.copyWith(speedTestNoticeAccepted: true));
    }
    if (jp03State != null) {
      container.read(speedTestResultsProvider.notifier).set('JP-03', jp03State);
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(locale: const Locale('zh', 'CN'), child: sectionsHost()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('leaf rows offer a speed test beside the delay reading', (
    tester,
  ) async {
    await pumpPage(tester);
    // JP-03, HK-01 and DIRECT leaf rows; group rows carry none.
    expect(find.text('测速'), findsNWidgets(6));
  });

  testWidgets('a measured reading states its single-connection basis', (
    tester,
  ) async {
    await pumpPage(
      tester,
      jp03State: const SpeedTestState.succeeded(
        mbps: 86.4,
        totalBytes: 1234567,
      ),
    );
    // One per JP-03 row: the GLOBAL, Home and Auto member rows.
    expect(find.text('↓ 86.4 Mbps · 单连接'), findsNWidgets(3));
  });

  testWidgets('a running test says so in place of the invitation', (
    tester,
  ) async {
    await pumpPage(tester, jp03State: const SpeedTestState.running());
    expect(find.text('测速中…'), findsNWidgets(3));
  });

  testWidgets('a failed test reads as unmeasurable, never as a number', (
    tester,
  ) async {
    await pumpPage(tester, jp03State: const SpeedTestState.failed());
    expect(find.text('不可测'), findsNWidgets(3));
    expect(find.textContaining('Mbps'), findsNothing);
  });

  testWidgets('the first tap asks about traffic before any download', (
    tester,
  ) async {
    final core = _MockCoreHandlerInterface();
    when(() => core.asyncTestSpeed(any())).thenAnswer(
      (_) async =>
          const SpeedTestResult(name: 'JP-03', mbps: 342, totalBytes: 4096),
    );
    await pumpPage(tester, core: core);

    await tester.tap(find.text('测速').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('约 20–100 MB'), findsOneWidget);
    verifyNever(() => core.asyncTestSpeed(any()));

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    verify(() => core.asyncTestSpeed('JP-03')).called(1);
    expect(find.text('↓ 342 Mbps · 单连接'), findsNWidgets(3));
  });

  testWidgets('an accepted notice is not asked twice', (tester) async {
    final core = _MockCoreHandlerInterface();
    when(() => core.asyncTestSpeed(any())).thenAnswer(
      (_) async =>
          const SpeedTestResult(name: 'JP-03', mbps: 342, totalBytes: 4096),
    );
    await pumpPage(tester, core: core, noticeAccepted: true);

    await tester.tap(find.text('测速').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('约 20–100 MB'), findsNothing);
    verify(() => core.asyncTestSpeed('JP-03')).called(1);
  });

  testWidgets('under sing-box the entry stays inert and starts nothing', (
    tester,
  ) async {
    final core = _MockCoreHandlerInterface();
    final container = await pumpPage(
      tester,
      core: core,
      singBoxBearing: true,
      noticeAccepted: true,
    );

    await tester.tap(find.text('测速').first);
    await tester.pumpAndSettle();
    verifyNever(() => core.asyncTestSpeed(any()));
    expect(container.read(speedTestResultsProvider), isEmpty);
  });
}
