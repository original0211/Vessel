import 'package:kfusion/common/common.dart';
import 'package:kfusion/common/service_probe.dart' show routedOutbound;
import 'package:kfusion/enum/enum.dart';
import 'package:kfusion/l10n/l10n.dart';
import 'package:kfusion/models/models.dart';
import 'package:kfusion/providers/ip_quality.dart';
import 'package:kfusion/providers/outbound_ip.dart';
import 'package:kfusion/providers/providers.dart';
import 'package:kfusion/providers/routed_probe.dart';
import 'package:kfusion/ui/ui.dart';
import 'package:kfusion/views/dashboard/hara_dashboard.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../helpers/preferences.dart';
import '../../helpers/test_app.dart';

const _ip = '203.0.113.9';
const _node = 'Tokyo 01';

const _profile = Profile(
  id: 1,
  label: 'Home',
  autoUpdateDuration: Duration.zero,
);

const _residential = IpQuality(
  ip: _ip,
  source: IpQualitySource.ipLocate,
  type: IpType.residential,
  organization: 'Example Broadband',
  asn: 64500,
);

const _stamp = RouteStamp(
  coreEpoch: 1,
  picksVersion: 1,
  hostEpoch: 1,
  proxied: true,
  chains: [_node],
);

const _freshEntry = ProbeEntry<IpInfo>(
  phase: ProbePhase.fresh,
  value: IpInfo(ip: _ip, countryCode: 'GB'),
  stamp: _stamp,
);

class _RecordingSetupAction extends SetupAction {
  @override
  Future<bool> setRunning(bool running, {bool initialize = false}) {
    ref.read(runTimeProvider.notifier).value = running ? 1 : null;
    return Future.value(true);
  }
}

class _QualityStub {
  _QualityStub(this.answer);

  final Future<IpQuality> Function(String ip) answer;
  final calls = <String>[];

  Future<IpQuality> call(Ref ref, String ip) {
    calls.add(ip);
    return answer(ip);
  }
}

List<Override> _overrides({
  required ProbeEntry<IpInfo> entry,
  required _QualityStub quality,
}) {
  return [
    profilesProvider.overrideWithValue(const [_profile]),
    currentProfileIdProvider.overrideWithBuild((_, _) => 1),
    suspendProvider.overrideWithValue(false),
    setupActionProvider.overrideWith(_RecordingSetupAction.new),
    outboundIpProbeProvider.overrideWithBuild(
      (_, _) => RoutedProbeState({routedOutbound: entry}),
    ),
    ipQualityProvider.overrideWith(quality.call),
  ];
}

Widget _app({
  required ProbeEntry<IpInfo> entry,
  required _QualityStub quality,
}) {
  return TestApp(
    locale: const Locale('en'),
    overrides: _overrides(entry: entry, quality: quality),
    child: const HaraDashboard(),
  );
}

Future<void> _pumpConnected(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(app);
  await tester.pump();
  await tester.tap(find.byType(DiscRingMotif));
  await tester.pump();
  await tester.pump();
}

Future<void> _openFromRow(WidgetTester tester, Finder rowAnchor) async {
  await tester.tap(rowAnchor);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

AppLocalizations _localizations(WidgetTester tester) {
  return tester.element(find.byType(HaraDashboard)).appLocalizations;
}

void main() {
  setUp(() async {
    await mockPreferences();
  });

  testWidgets('tapping the exit row opens the ip quality sheet', (
    tester,
  ) async {
    final quality = _QualityStub((_) async => _residential);
    await _pumpConnected(tester, _app(entry: _freshEntry, quality: quality));
    final localizations = _localizations(tester);

    await _openFromRow(tester, find.text('United Kingdom · Residential'));

    expect(find.text(localizations.outboundIp), findsOneWidget);
    expect(find.text(localizations.ipAddress), findsOneWidget);
    expect(find.text(_ip), findsWidgets);
    expect(find.text('Example Broadband'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the exit row stays shut while no address is known', (
    tester,
  ) async {
    final quality = _QualityStub((_) async => _residential);
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _app(
        entry: const ProbeEntry(phase: ProbePhase.empty),
        quality: quality,
      ),
    );
    await tester.pump();
    final localizations = _localizations(tester);

    await _openFromRow(tester, find.text(localizations.ipExit));

    expect(find.text(localizations.outboundIp), findsNothing);
    expect(find.text(localizations.ipAddress), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hide ip still opens the sheet, masked inside', (tester) async {
    final quality = _QualityStub((_) async => _residential);
    final container = ProviderContainer(
      overrides: _overrides(entry: _freshEntry, quality: quality),
    );
    addTearDown(container.dispose);
    container
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(hideIp: true));
    await _pumpConnected(
      tester,
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(locale: Locale('en'), child: HaraDashboard()),
      ),
    );
    final localizations = _localizations(tester);
    expect(find.text('*****'), findsOneWidget);

    await _openFromRow(tester, find.text('*****'));

    expect(find.text(localizations.outboundIp), findsOneWidget);
    expect(find.text(localizations.ipAddress), findsOneWidget);
    expect(find.text(_ip), findsNothing);
    expect(find.text('*****'), findsWidgets);
    expect(tester.takeException(), isNull);
    // Flush the debounced sync the settings write schedules.
    await tester.pump(const Duration(seconds: 15));
  });
}
