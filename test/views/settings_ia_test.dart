import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfusion/common/common.dart';
import 'package:kfusion/enum/enum.dart';
import 'package:kfusion/models/models.dart';
import 'package:kfusion/providers/app.dart';
import 'package:kfusion/providers/config.dart';
import 'package:kfusion/providers/database.dart';
import 'package:kfusion/state.dart';
import 'package:kfusion/views/access.dart';
import 'package:kfusion/views/config/dns.dart';
import 'package:kfusion/views/config/general.dart';
import 'package:kfusion/views/config/network.dart';
import 'package:kfusion/views/developer.dart';
import 'package:kfusion/views/proxies/setting.dart';
import 'package:kfusion/views/theme.dart';
import 'package:kfusion/views/tools.dart';

import '../helpers/app_paths.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

// Pins for the settings re-integration, first pass (SETTINGS-IA): every
// move, rename and convergence of the redesign's first chapter, each
// asserted at its new place, absent at its old place, and reachable
// through the settings search index.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory home;

  setUpAll(() async {
    home = Directory.systemTemp.createTempSync('flclash-settings-ia-');
    await useAppPaths(home);
  });

  tearDownAll(() {
    if (home.existsSync()) home.deleteSync(recursive: true);
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    globalState.container = container;
    return container;
  }

  Future<void> pumpIndex(WidgetTester tester) async {
    const size = Size(1400, 2400);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = createContainer();
    container.read(viewSizeProvider.notifier).update((_) => size);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: ToolsView()),
      ),
    );
    await tester.pumpAndSettle();
  }

  double dyOf(WidgetTester tester, String label) =>
      tester.getTopLeft(find.text(label)).dy;

  group('settings index regrouping', () {
    test('the destination lists carry the moves in source', () {
      // The access control entry is Android-only, so no widget pump on
      // this platform can see it; its list membership is pinned here.
      final source = File('lib/views/tools.dart').readAsStringSync();
      String region(String from, String to) {
        final start = source.indexOf(from);
        final end = source.indexOf(to, start);
        expect(start, greaterThanOrEqualTo(0));
        expect(end, greaterThan(start));
        return source.substring(start, end);
      }

      final daily = region('final daily', 'final configuration');
      final configuration = region('final configuration', 'final maintenance');
      final maintenance = region('final maintenance', 'final legal');

      expect(daily.contains('appLocalizations.accessControl'), isFalse);
      expect(daily.contains('appLocalizations.backupAndRestore'), isFalse);
      expect(configuration.contains('appLocalizations.accessControl'), isTrue);
      expect(
        configuration.indexOf('appLocalizations.onDemand'),
        lessThan(configuration.indexOf('appLocalizations.accessControl')),
      );
      expect(maintenance.contains('appLocalizations.backupAndRestore'), isTrue);
      expect(
        maintenance.indexOf('appLocalizations.backupAndRestore'),
        lessThan(maintenance.indexOf('appLocalizations.logs')),
      );
    });

    testWidgets('the moved entries stand in their new groups', (tester) async {
      await pumpIndex(tester);
      final l10n = currentAppLocalizations;
      expect(find.text(l10n.proxySettings), findsOneWidget);
      expect(
        dyOf(tester, l10n.backupAndRestore),
        lessThan(dyOf(tester, l10n.logs)),
      );
      expect(
        dyOf(tester, l10n.onDemand),
        lessThan(dyOf(tester, l10n.backupAndRestore)),
      );
      expect(find.text(l10n.developerMode), findsOneWidget);
    });

    testWidgets('the search reaches the renamed and moved entries', (
      tester,
    ) async {
      await pumpIndex(tester);
      final l10n = currentAppLocalizations;

      await tester.enterText(find.byType(TextField), 'speed');
      await tester.pumpAndSettle();
      expect(find.text(l10n.proxySettings), findsOneWidget);
      expect(find.text(l10n.general), findsNothing);

      await tester.enterText(find.byType(TextField), 'maintenance');
      await tester.pumpAndSettle();
      expect(find.text(l10n.developerMode), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'backup');
      await tester.pumpAndSettle();
      expect(find.text(l10n.backupAndRestore), findsOneWidget);
      expect(tester.takeException(), null);
    });

    testWidgets('the desktop index carries the shared system proxy note', (
      tester,
    ) async {
      await pumpIndex(tester);
      expect(
        find.textContaining(currentAppLocalizations.systemProxySharedNote),
        findsOneWidget,
      );
    });

    testWidgets('the index TUN switch drives the shared config state', (
      tester,
    ) async {
      await pumpIndex(tester);
      final container = globalState.container;
      bool tunOn() => container.read(patchClashConfigProvider).tun.enable;

      expect(tunOn(), isFalse);
      await tester.tap(find.text('TUN'));
      await tester.pumpAndSettle();
      expect(tunOn(), isTrue);
      expect(tester.takeException(), null);
    });

    testWidgets('the developer page answers to its new name', (tester) async {
      const size = Size(1000, 1000);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = createContainer();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(child: DeveloperView()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(currentAppLocalizations.developerMode), findsOneWidget);
      expect(tester.takeException(), null);
    });
  });

  group('network convergence', () {
    testWidgets('the network page drops its master switches', (tester) async {
      const size = Size(1000, 1400);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = createContainer();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(child: NetworkListView()),
        ),
      );
      await tester.pumpAndSettle();

      // The TUN master row is gone: the name survives only as the
      // detail section's title. The desktop system proxy row stands.
      expect(find.text('TUN'), findsOneWidget);
      expect(find.text(currentAppLocalizations.systemProxy), findsOneWidget);
      expect(
        find.textContaining(currentAppLocalizations.systemProxySharedNote),
        findsOneWidget,
      );
      expect(tester.takeException(), null);
    });

    testWidgets('the vpn block is one section of detail rows', (tester) async {
      final container = createContainer();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(
            child: Scaffold(
              body: Material(
                child: SingleChildScrollView(child: VpnSections()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VPNItem), findsNothing);
      expect(find.byType(VpnSystemProxyItem), findsNothing);
      expect(find.byType(BypassDomainItem), findsOneWidget);
      expect(find.byType(AllowBypassItem), findsOneWidget);
      expect(find.byType(Ipv6Item), findsOneWidget);
      expect(find.byType(DNSHijackingItem), findsOneWidget);
      expect(
        find.textContaining(currentAppLocalizations.vpnEnableDesc),
        findsOneWidget,
      );
      expect(tester.takeException(), null);
    });
  });

  group('general page shedding', () {
    Future<void> pumpGeneral(WidgetTester tester) async {
      const size = Size(1000, 3000);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = createContainer();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(child: GeneralView()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the startup section and its rows are gone', (tester) async {
      await pumpGeneral(tester);
      final l10n = currentAppLocalizations;
      expect(find.text('Startup and background'), findsNothing);
      expect(find.text(l10n.onDemand), findsNothing);
      expect(find.text(l10n.testUrl), findsNothing);
      expect(find.text('Hosts'), findsNothing);
      expect(find.text(l10n.appendSystemDns), findsNothing);
      expect(tester.takeException(), null);
    });

    testWidgets('the sections stand in the new order under the kernel name', (
      tester,
    ) async {
      await pumpGeneral(tester);
      final l10n = currentAppLocalizations;
      final requests = dyOf(tester, l10n.requestsAndUpdates);
      final connection = dyOf(tester, l10n.connection);
      final kernel = dyOf(tester, l10n.kernel);
      final inbound = dyOf(tester, l10n.inbound);
      final logs = dyOf(tester, l10n.logsAndDiagnostics);
      expect(requests, lessThan(connection));
      expect(connection, lessThan(kernel));
      expect(kernel, lessThan(inbound));
      expect(inbound, lessThan(logs));
      expect(find.text(l10n.coreIpv6), findsOneWidget);
      expect(tester.takeException(), null);
    });
  });

  group('dns resolution section', () {
    late ProviderContainer dnsContainer;

    Future<void> pumpDns(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      dnsContainer = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(
            () => TestProfiles([
              const Profile(
                id: 1,
                type: ProfileType.custom,
                autoUpdateDuration: Duration.zero,
              ),
            ]),
          ),
        ],
      );
      addTearDown(dnsContainer.dispose);
      globalState.container = dnsContainer;
      dnsContainer
          .read(viewSizeProvider.notifier)
          .update((_) => const Size(1200, 1200));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: dnsContainer,
          child: const TestApp(child: DnsView()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the resolution rows stand over the empty state', (
      tester,
    ) async {
      await pumpDns(tester);
      final l10n = currentAppLocalizations;

      expect(find.text(l10n.nameResolution), findsOneWidget);
      expect(find.text('Hosts'), findsOneWidget);
      expect(find.text(l10n.appendSystemDns), findsOneWidget);
      expect(
        dyOf(tester, l10n.nameResolution),
        lessThan(dyOf(tester, l10n.nullTip(l10n.overrideEntries))),
      );
      // The family tag rides along: once inside the hosts subtitle,
      // once as the append-system-dns row's own tag.
      expect(find.text(l10n.mihomoOnly), findsOneWidget);
      expect(find.textContaining(l10n.mihomoOnly), findsNWidgets(2));

      bool append() =>
          dnsContainer.read(networkSettingProvider).appendSystemDns;
      final before = append();
      await tester.tap(find.text(l10n.appendSystemDns));
      await tester.pumpAndSettle();
      expect(append(), isNot(before));
      expect(tester.takeException(), null);
    });

    testWidgets('the resolution rows stand over the filled state too', (
      tester,
    ) async {
      await pumpDns(tester);
      dnsContainer
          .read(patchClashConfigProvider.notifier)
          .update(
            (state) => state.copyWith(dnsOverrideKeys: {DnsOverrideKey.ipv6}),
          );
      await tester.pumpAndSettle();
      final l10n = currentAppLocalizations;
      expect(find.text(l10n.nameResolution), findsOneWidget);
      expect(find.text('Hosts'), findsOneWidget);
      expect(find.text('IPv6'), findsOneWidget);
      expect(tester.takeException(), null);
    });
  });

  group('proxy page takes the test url', () {
    testWidgets('the test url row leads the first section with its note', (
      tester,
    ) async {
      const size = Size(1000, 1400);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = createContainer();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(child: Scaffold(body: ProxiesSetting())),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = currentAppLocalizations;
      expect(find.text(l10n.testUrl), findsOneWidget);
      expect(find.text(l10n.testUrlApplyNote), findsOneWidget);
      expect(dyOf(tester, l10n.testUrl), lessThan(dyOf(tester, l10n.sort)));
      expect(tester.takeException(), null);
    });
  });

  group('access panel list display section', () {
    testWidgets('the three list rows stand under the new section', (
      tester,
    ) async {
      const size = Size(1000, 1400);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = createContainer();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(
            child: Scaffold(
              body: SingleChildScrollView(child: AccessControlPanel()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = currentAppLocalizations;
      expect(find.text(l10n.listDisplay), findsOneWidget);
      expect(find.text(l10n.source), findsNothing);
      expect(dyOf(tester, l10n.mode), lessThan(dyOf(tester, l10n.listDisplay)));
      expect(dyOf(tester, l10n.listDisplay), lessThan(dyOf(tester, l10n.sort)));
      expect(dyOf(tester, l10n.sort), lessThan(dyOf(tester, l10n.systemApp)));
      expect(
        dyOf(tester, l10n.systemApp),
        lessThan(dyOf(tester, l10n.noNetworkApp)),
      );
      expect(tester.takeException(), null);
    });
  });

  group('theme page order', () {
    testWidgets('text scaling stands over liquid glass', (tester) async {
      const size = Size(1000, 2400);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = createContainer();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(child: ThemeView()),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = currentAppLocalizations;
      expect(find.text(l10n.textScale), findsOneWidget);
      expect(find.text(l10n.liquidGlass), findsOneWidget);
      expect(
        dyOf(tester, l10n.textScale),
        lessThan(dyOf(tester, l10n.liquidGlass)),
      );
      expect(tester.takeException(), null);
    });
  });
}
