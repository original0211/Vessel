import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:kfusion/enum/enum.dart';
import 'package:kfusion/models/models.dart';
import 'package:kfusion/providers/outbound_ip.dart';
import 'package:kfusion/providers/providers.dart';
import 'package:kfusion/providers/routed_probe.dart';
import 'package:kfusion/state.dart';
import 'package:kfusion/ui/icons/icons.dart';
import 'package:kfusion/ui/ui.dart';
import 'package:kfusion/views/dashboard/hara_dashboard.dart';
import 'package:kfusion/views/proxies/hara_proxies.dart';

import '../../helpers/preferences.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_profiles.dart';

class _RecordingProxiesAction extends ProxiesAction {
  final unfoldWrites = <Set<String>>[];

  @override
  void updateCurrentUnfoldSet(Set<String> value) {
    unfoldWrites.add(Set.of(value));
  }
}

const _profile = Profile(
  id: 1,
  label: 'Test',
  type: ProfileType.url,
  url: 'https://example.com/sub',
  selectedMap: {
    'GLOBAL': 'Home',
    'Home': 'JP-03',
    'North': 'US-02',
    'Wide': 'W-02',
  },
  autoUpdateDuration: Duration.zero,
);

const _groups = [
  Group(
    name: 'GLOBAL',
    type: GroupType.Selector,
    all: [
      Proxy(name: 'Home', type: 'Selector'),
      Proxy(name: 'JP-03', type: 'Shadowsocks'),
      Proxy(name: 'DIRECT', type: 'Direct'),
    ],
  ),
  Group(
    name: 'Home',
    type: GroupType.Selector,
    all: [
      Proxy(name: 'HK-01', type: 'Shadowsocks'),
      Proxy(name: 'JP-03', type: 'Shadowsocks'),
      Proxy(name: 'SG-01', type: 'Shadowsocks'),
    ],
  ),
  Group(
    name: 'North',
    type: GroupType.Selector,
    all: [
      Proxy(name: 'US-01', type: 'Shadowsocks'),
      Proxy(name: 'US-02', type: 'Shadowsocks'),
    ],
  ),
  Group(
    name: 'Wide',
    type: GroupType.Selector,
    all: [
      Proxy(name: 'W-01', type: 'Shadowsocks'),
      Proxy(name: 'W-02', type: 'Shadowsocks'),
      Proxy(name: 'JP-99', type: 'Shadowsocks'),
    ],
  ),
];

List<Group> _tallGroups() {
  return [
    const Group(
      name: 'GLOBAL',
      type: GroupType.Selector,
      all: [
        Proxy(name: 'Main', type: 'Selector'),
        Proxy(name: 'DIRECT', type: 'Direct'),
      ],
    ),
    const Group(
      name: 'Main',
      type: GroupType.Selector,
      all: [
        Proxy(name: 'M-01', type: 'Shadowsocks'),
        Proxy(name: 'M-02', type: 'Shadowsocks'),
      ],
    ),
    for (var g = 1; g <= 10; g++)
      Group(
        name: 'G$g',
        type: GroupType.Selector,
        all: [
          for (var i = 1; i <= 8; i++)
            Proxy(name: 'G$g-N$i', type: 'Shadowsocks'),
        ],
      ),
  ];
}

const _tallProfile = Profile(
  id: 1,
  label: 'Test',
  type: ProfileType.url,
  url: 'https://example.com/sub',
  selectedMap: {'GLOBAL': 'Main', 'Main': 'M-01'},
  autoUpdateDuration: Duration.zero,
);

// The same profile with every group unfolded, the pre-fold presentation.
const _tallProfileOpen = Profile(
  id: 1,
  label: 'Test',
  type: ProfileType.url,
  url: 'https://example.com/sub',
  selectedMap: {'GLOBAL': 'Main', 'Main': 'M-01'},
  unfoldSet: {
    'GLOBAL',
    'Main',
    'G1',
    'G2',
    'G3',
    'G4',
    'G5',
    'G6',
    'G7',
    'G8',
    'G9',
    'G10',
  },
  autoUpdateDuration: Duration.zero,
);

Finder _section(String name) => find.byWidgetPredicate(
  (widget) => widget is HaraProxyGroupSection && widget.group.name == name,
);

Finder _richText(String needle) => find.byWidgetPredicate(
  (widget) =>
      widget is Text && (widget.textSpan?.toPlainText() ?? '') == needle,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await mockPreferences();
  });

  Future<ProviderContainer> pumpSections(
    WidgetTester tester, {
    required HaraProxyGroupSection section,
    List<Override> extra = const [],
  }) async {
    tester.view.physicalSize = const Size(412, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles(const [_profile])),
        currentProfileIdProvider.overrideWithBuild((_, _) => _profile.id),
        groupsProvider.overrideWithValue(_groups),
        currentGroupsStateProvider.overrideWithValue(
          const GroupsState(value: _groups),
        ),
        ...extra,
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
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: Builder(
            builder: (context) => Material(
              color: context.haraPalette.bg,
              child: CustomScrollView(slivers: [section]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('a folded header carries pick, count and best delay', (
    tester,
  ) async {
    var toggles = 0;
    await pumpSections(
      tester,
      section: HaraProxyGroupSection(
        group: _groups[3],
        exitName: null,
        first: true,
        exitMarker: HaraExitMarker.dot,
        expanded: false,
        onToggleFold: () => toggles++,
      ),
      extra: [
        delayProvider(proxyName: 'W-01', testUrl: null).overrideWithValue(120),
        delayProvider(proxyName: 'JP-99', testUrl: null).overrideWithValue(42),
      ],
    );
    // No member rows while folded.
    expect(find.text('W-01'), findsNothing);
    expect(find.text('JP-99'), findsNothing);
    // The header still reads the group: pick, member count, best delay.
    expect(find.text('→ W-02'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(_richText('42 ms'), findsOneWidget);

    await tester.tap(find.text('Wide'));
    await tester.pump();
    expect(toggles, 1);
  });

  testWidgets('pinExit lifts the exit row above the configured order', (
    tester,
  ) async {
    await pumpSections(
      tester,
      section: const HaraProxyGroupSection(
        group: Group(
          name: 'Home',
          type: GroupType.Selector,
          all: [
            Proxy(name: 'HK-01', type: 'Shadowsocks'),
            Proxy(name: 'JP-03', type: 'Shadowsocks'),
            Proxy(name: 'SG-01', type: 'Shadowsocks'),
          ],
        ),
        exitName: 'JP-03',
        first: true,
        exitMarker: HaraExitMarker.dot,
        pinExit: true,
      ),
    );
    expect(
      tester.getTopLeft(find.text('JP-03')).dy,
      lessThan(tester.getTopLeft(find.text('HK-01')).dy),
    );
  });

  testWidgets('without pinExit the configured order stands', (tester) async {
    await pumpSections(
      tester,
      section: const HaraProxyGroupSection(
        group: Group(
          name: 'Home',
          type: GroupType.Selector,
          all: [
            Proxy(name: 'HK-01', type: 'Shadowsocks'),
            Proxy(name: 'JP-03', type: 'Shadowsocks'),
            Proxy(name: 'SG-01', type: 'Shadowsocks'),
          ],
        ),
        exitName: 'JP-03',
        first: true,
        exitMarker: HaraExitMarker.dot,
      ),
    );
    expect(
      tester.getTopLeft(find.text('HK-01')).dy,
      lessThan(tester.getTopLeft(find.text('JP-03')).dy),
    );
  });

  Future<ProviderContainer> pumpDashboard(
    WidgetTester tester, {
    Profile profile = _profile,
    List<Group> groups = _groups,
    Size size = const Size(412, 1400),
    List<Override> extra = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      TestApp(
        locale: const Locale('en'),
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([profile])),
          currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
          groupsProvider.overrideWithValue(groups),
          currentGroupsStateProvider.overrideWithValue(
            GroupsState(value: groups),
          ),
          suspendProvider.overrideWithValue(false),
          outboundIpProbeProvider.overrideWithBuild(
            (_, _) => const RoutedProbeState({}),
          ),
          ...extra,
        ],
        child: const HaraDashboard(),
      ),
    );
    await tester.pump();
    return ProviderScope.containerOf(
      tester.element(find.byType(HaraDashboard)),
    );
  }

  testWidgets('only the exit group starts expanded on the main screen', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      extra: [
        delayProvider(proxyName: 'W-01', testUrl: null).overrideWithValue(120),
        delayProvider(proxyName: 'JP-99', testUrl: null).overrideWithValue(42),
      ],
    );
    // The exit group is open, its exit row pinned and dotted.
    expect(find.text('HK-01'), findsOneWidget);
    expect(find.byType(HaraDot), findsOneWidget);
    final home = _section('Home');
    expect(
      tester
          .getTopLeft(find.descendant(of: home, matching: find.text('JP-03')))
          .dy,
      lessThan(
        tester
            .getTopLeft(find.descendant(of: home, matching: find.text('HK-01')))
            .dy,
      ),
    );
    // The other groups are folded; their headers carry the reading.
    expect(find.text('DIRECT'), findsNothing);
    expect(find.text('US-01'), findsNothing);
    expect(find.text('W-01'), findsNothing);
    expect(find.text('→ JP-03'), findsOneWidget);
    expect(find.text('→ US-02'), findsOneWidget);
    final wide = _section('Wide');
    expect(find.descendant(of: wide, matching: find.text('3')), findsOneWidget);
    expect(
      find.descendant(of: wide, matching: _richText('42 ms')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a folded header toggles it and persists the set', (
    tester,
  ) async {
    final container = await pumpDashboard(
      tester,
      extra: [proxiesActionProvider.overrideWith(_RecordingProxiesAction.new)],
    );
    final action =
        container.read(proxiesActionProvider.notifier)
            as _RecordingProxiesAction;
    final northHeader = find.descendant(
      of: _section('North'),
      matching: find.text('North'),
    );

    await tester.tap(northHeader);
    await tester.pump();
    expect(find.text('US-01'), findsOneWidget);
    expect(action.unfoldWrites.last, {'Home', 'North'});

    await tester.tap(northHeader);
    await tester.pump();
    expect(find.text('US-01'), findsNothing);
    expect(action.unfoldWrites.last, {'Home'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('a chip tap scrolls to its group and expands it', (tester) async {
    final groups = _tallGroups();
    await pumpDashboard(
      tester,
      profile: _tallProfile,
      groups: groups,
      size: const Size(412, 800),
    );
    expect(find.text('G3-N1'), findsNothing);

    // Bring the rail into reach first, as a thumb would.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
    await tester.pump();
    await tester.tap(find.text('G3').first);
    await tester.pumpAndSettle();

    final row = find.text('G3-N1');
    expect(row, findsOneWidget);
    final dy = tester.getTopLeft(row).dy;
    expect(dy, greaterThan(60));
    expect(dy, lessThan(800));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the chip rail sticks once the node zone reaches the top', (
    tester,
  ) async {
    final groups = _tallGroups();
    await pumpDashboard(
      tester,
      profile: _tallProfile,
      groups: groups,
      size: const Size(412, 800),
    );
    expect(find.byKey(const ValueKey('stickyNodeChips')), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('stickyNodeChips')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search filters across groups and clearing restores the fold', (
    tester,
  ) async {
    await pumpDashboard(tester);
    await tester.enterText(find.byType(TextField), 'JP');
    await tester.pump();
    await tester.pump();

    // Hits surface across groups, each result group open with its count.
    expect(find.text('JP-03'), findsWidgets);
    expect(find.text('JP-99'), findsOneWidget);
    expect(
      find.descendant(of: _section('Home'), matching: find.text('1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _section('Wide'), matching: find.text('1')),
      findsOneWidget,
    );
    // A group without a hit drops out of the results entirely.
    expect(find.text('North'), findsNothing);
    expect(find.text('US-01'), findsNothing);
    expect(find.text('HK-01'), findsNothing);

    final clear = find.byWidgetPredicate(
      (widget) =>
          widget is GlyphIcon && identical(widget.glyph, AppGlyphs.close),
    );
    await tester.tap(clear);
    await tester.pump();
    await tester.pump();

    // The fold defaults are back: North folded again, its rows hidden.
    expect(
      find.descendant(of: _section('North'), matching: find.text('North')),
      findsOneWidget,
    );
    expect(find.text('US-01'), findsNothing);
    expect(find.text('HK-01'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the fold defaults cut the scroll depth of a long list', (
    tester,
  ) async {
    final groups = _tallGroups();
    await pumpDashboard(
      tester,
      profile: _tallProfile,
      groups: groups,
      size: const Size(412, 800),
    );
    await tester.pumpAndSettle();
    final controller = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    final foldedDepth = controller.position.maxScrollExtent;

    await tester.pumpWidget(const SizedBox());
    await pumpDashboard(
      tester,
      profile: _tallProfileOpen,
      groups: groups,
      size: const Size(412, 800),
    );
    await tester.pumpAndSettle();
    final openController = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    final openDepth = openController.position.maxScrollExtent;
    expect(openDepth - foldedDepth, greaterThan(1000));
    expect(tester.takeException(), isNull);
  });
}
