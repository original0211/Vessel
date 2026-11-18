import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfusion/common/common.dart';
import 'package:kfusion/core/controller.dart';
import 'package:kfusion/core/interface.dart';
import 'package:kfusion/core/singbox/singbox_runner.dart';
import 'package:kfusion/enum/enum.dart';
import 'package:kfusion/features/config_hub/singbox_action.dart';
import 'package:kfusion/models/models.dart';
import 'package:kfusion/providers/providers.dart';
import 'package:kfusion/state.dart';
import 'package:kfusion/ui/ui.dart';
import 'package:kfusion/views/proxies/hara_proxies.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_profiles.dart';

class _MockCoreHandlerInterface extends Mock implements CoreHandlerInterface {}

class _RecordingSingBoxApi extends SingBoxClashApi {
  _RecordingSingBoxApi() : super(port: 0, secret: '');

  @override
  Future<void> changeProxy(String groupName, String proxyName) async {}

  @override
  Future<void> closeConnections() async {}
}

class _BearerSingBoxAction extends SingBoxAction {
  _BearerSingBoxAction(this._api);

  final SingBoxClashApi _api;

  @override
  Future<SingBoxStatus> build() async =>
      const SingBoxStatus(state: SingBoxState.running);

  @override
  SingBoxClashApi? get api => _api;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(
      const ChangeProxyParams(groupName: '', proxyName: ''),
    );
  });

  const parent = '⚡ CF前置';
  const child = '⚡ CF前置 · auto';

  const profile = Profile(
    id: 1,
    label: 'Test',
    type: ProfileType.url,
    url: 'https://example.com/sub',
    selectedMap: {parent: 'CF-02'},
    autoUpdateDuration: Duration.zero,
  );
  const groups = [
    Group(
      name: parent,
      type: GroupType.URLTest,
      now: 'CF-01',
      all: [
        Proxy(name: 'CF-01', type: 'Http'),
        Proxy(name: 'CF-02', type: 'Shadowsocks'),
      ],
    ),
  ];
  const panel = <String, SingBoxPanelGroup>{
    parent: (type: 'Selector', now: 'CF-02', all: [child, 'CF-01', 'CF-02']),
    child: (type: 'URLTest', now: 'CF-01', all: ['CF-01', 'CF-02']),
  };

  testWidgets('the auto row and the member row state the same stability line', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final core = _MockCoreHandlerInterface();
    when(
      () => core.changeProxy(any()),
    ).thenAnswer((_) async => const ChangeProxyResult(changed: true));
    when(
      () => core.getProxies(),
    ).thenAnswer((_) async => const ProxiesData(proxies: {}, all: []));
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles([profile])),
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        groupsProvider.overrideWithValue(groups),
        currentGroupsStateProvider.overrideWithValue(
          GroupsState(value: groups),
        ),
        singBoxPanelGroupsProvider.overrideWithValue(const AsyncData(panel)),
        singBoxActionProvider.overrideWith(
          () => _BearerSingBoxAction(_RecordingSingBoxApi()),
        ),
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
    final samples = container.read(delaySamplesProvider.notifier);
    for (final value in <int?>[96, 210, null, -1]) {
      samples.record(Delay(name: 'CF-01', url: defaultTestUrl, value: value));
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          locale: const Locale('en'),
          child: Builder(
            builder: (context) => Material(
              color: context.haraPalette.bg,
              child: CustomScrollView(
                slivers: [
                  HaraProxyGroupSection(
                    group: groups.single,
                    exitName: 'CF-01',
                    first: true,
                    exitMarker: HaraExitMarker.dot,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The auto row's delay slot speaks for the panel child's current pick
    // (CF-01); the CF-01 member row speaks for itself. Both state the same
    // line, and CF-02, with no history, states none.
    final lines = find.text('last 4 96–210 · 2 failed');
    expect(lines, findsNWidgets(2));
    final rows = find.ancestor(of: lines, matching: find.byType(Row));
    expect(
      find.descendant(of: rows, matching: find.text('Auto')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: rows, matching: find.text('CF-01')),
      findsOneWidget,
    );
  });
}
