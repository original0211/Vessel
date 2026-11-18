import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfusion/common/common.dart';
import 'package:kfusion/enum/enum.dart';
import 'package:kfusion/models/models.dart';
import 'package:kfusion/providers/providers.dart';
import 'package:kfusion/state.dart';
import 'package:kfusion/ui/ui.dart';
import 'package:kfusion/views/proxies/hara_proxies.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_profiles.dart';

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

  Future<void> pumpPage(
    WidgetTester tester, {
    List<int?> jp03Samples = const [],
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
    for (final value in jp03Samples) {
      samples.record(Delay(name: 'JP-03', url: defaultTestUrl, value: value));
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(locale: const Locale('zh', 'CN'), child: sectionsHost()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder stabilityLines() {
    return find.byWidgetPredicate(
      (widget) => widget is Text && (widget.data?.startsWith('近') ?? false),
    );
  }

  testWidgets('no samples: rows state no stability line', (tester) async {
    await pumpPage(tester);
    expect(stabilityLines(), findsNothing);
  });

  testWidgets('two samples are not enough for a stability line', (
    tester,
  ) async {
    await pumpPage(tester, jp03Samples: const [96, 210]);
    expect(stabilityLines(), findsNothing);
  });

  testWidgets('the line states count, span and failures under the delay', (
    tester,
  ) async {
    await pumpPage(tester, jp03Samples: const [96, 210, null, -1]);
    final lines = find.text('近4次 96–210 · 失败2');
    // One per JP-03 delay slot: the GLOBAL, Home and Auto member rows.
    expect(lines, findsNWidgets(3));
    final rows = find.ancestor(of: lines, matching: find.byType(Row));
    expect(
      find.descendant(of: rows, matching: find.text('JP-03')),
      findsWidgets,
    );
  });

  testWidgets('a failure-free history omits the failure segment', (
    tester,
  ) async {
    await pumpPage(tester, jp03Samples: const [90, 120, 110]);
    expect(find.text('近3次 90–120'), findsNWidgets(3));
    expect(find.textContaining('失败'), findsNothing);
  });
}
