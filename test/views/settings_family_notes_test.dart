import 'dart:io';

import 'package:kfusion/providers/providers.dart';
import 'package:kfusion/state.dart';
import 'package:kfusion/views/config/general.dart';
import 'package:kfusion/views/config/network.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_paths.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

const _tag = 'mihomo only';
const _note = 'Applies only while the core is mihomo.';

ProviderContainer _container(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [profilesProvider.overrideWith(() => TestProfiles(const []))],
  );
  addTearDown(container.dispose);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
  globalState.container = container;
  container.read(viewSizeProvider.notifier).update((_) => size);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final home = Directory.systemTemp.createTempSync('setfix-notes-');
    await useAppPaths(home);
  });

  group('general page family notes', () {
    Future<void> pumpGeneral(WidgetTester tester) async {
      final container = _container(tester, const Size(1000, 3000));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(child: GeneralView()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the inbound section footer carries the note', (tester) async {
      await pumpGeneral(tester);
      expect(find.textContaining(_note), findsOneWidget);
    });

    testWidgets('family rows carry the tag', (tester) async {
      await pumpGeneral(tester);
      expect(find.text(_tag), findsNWidgets(6));
      expect(find.textContaining(_tag), findsNWidgets(6));
    });

    testWidgets('the clash ipv6 row reads as the core one', (tester) async {
      await pumpGeneral(tester);
      expect(find.text('Core IPv6'), findsOneWidget);
      expect(find.text('IPv6'), findsNothing);
      expect(find.text('VPN IPv6'), findsNothing);
    });
  });

  group('network page family notes', () {
    Future<void> pumpNetwork(WidgetTester tester) async {
      final container = _container(tester, const Size(400, 1760));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(child: Scaffold(body: NetworkListView())),
        ),
      );
      await tester.pump();
    }

    testWidgets('the network page never shows the core ipv6 label', (
      tester,
    ) async {
      await pumpNetwork(tester);
      expect(find.text('Core IPv6'), findsNothing);
    });

    testWidgets('the vpn ipv6 row reads as the vpn one', (tester) async {
      final container = _container(tester, const Size(400, 844));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(child: Scaffold(body: Ipv6Item())),
        ),
      );
      await tester.pump();
      expect(find.text('VPN IPv6'), findsOneWidget);
      expect(find.text('IPv6'), findsNothing);
      expect(find.text('Core IPv6'), findsNothing);
    });

    testWidgets('the interface rows carry the tag', (tester) async {
      final container = _container(tester, const Size(400, 844));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(
            child: Scaffold(
              body: Column(
                children: [InterfaceNameModeItem(), InterfaceNameItem()],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(_tag), findsNWidgets(2));
    });

    testWidgets('the tun and outbound sections carry the note', (tester) async {
      await pumpNetwork(tester);
      await tester.scrollUntilVisible(
        find.text(_note),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(find.text(_note), findsOneWidget);
      expect(find.textContaining(_note), findsNWidgets(2));
    });
  });
}
