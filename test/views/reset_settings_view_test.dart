import 'dart:io';

import 'package:kfusion/common/common.dart';
import 'package:kfusion/models/models.dart';
import 'package:kfusion/providers/app.dart';
import 'package:kfusion/providers/config.dart';
import 'package:kfusion/state.dart';
import 'package:kfusion/views/config/general.dart';
import 'package:kfusion/views/tools.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/app_paths.dart';
import '../helpers/test_app.dart';

// Pins for the settings reset (SETTINGS-RESET): the entry row at the foot
// of the general page, the confirmation and its three named points, the
// vermilion confirm word, both exits of the dialog, and reachability of
// the row through the settings search index.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory home;

  setUpAll(() async {
    home = Directory.systemTemp.createTempSync('flclash-settings-reset-');
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

  Future<ProviderContainer> pumpGeneral(WidgetTester tester) async {
    const size = Size(1000, 3200);
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

  void dirtyAppSettings(ProviderContainer container) {
    container
        .read(appSettingProvider.notifier)
        .update((_) => const AppSettingProps(autoLaunch: true));
  }

  testWidgets('the reset section closes the page with its row', (tester) async {
    await pumpGeneral(tester);
    final l10n = currentAppLocalizations;
    expect(find.text(l10n.resetSettings), findsOneWidget);
    final logsDy = tester.getTopLeft(find.text(l10n.logsAndDiagnostics)).dy;
    final resetDy = tester.getTopLeft(find.text(l10n.reset)).dy;
    expect(resetDy, greaterThan(logsDy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the confirmation names its three points; cancel keeps '
      'the settings untouched', (tester) async {
    final container = await pumpGeneral(tester);
    dirtyAppSettings(container);
    final l10n = currentAppLocalizations;
    await tester.ensureVisible(find.text(l10n.resetSettings));
    await tester.tap(find.text(l10n.resetSettings));
    await tester.pumpAndSettle();
    expect(find.text(l10n.resetSettingsDesc), findsOneWidget);
    expect(find.text(l10n.resetSettingsDataDesc), findsOneWidget);
    expect(find.text(l10n.resetSettingsReconnectDesc), findsOneWidget);
    final cancel = tester.widget<TextButton>(
      find.widgetWithText(TextButton, l10n.cancel),
    );
    expect(cancel.autofocus, isTrue);
    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();
    expect(find.text(l10n.resetSettingsDesc), findsNothing);
    expect(container.read(appSettingProvider).autoLaunch, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the confirm word is vermilion and confirming restores '
      'the defaults', (tester) async {
    final container = await pumpGeneral(tester);
    dirtyAppSettings(container);
    final l10n = currentAppLocalizations;
    await tester.ensureVisible(find.text(l10n.resetSettings));
    await tester.tap(find.text(l10n.resetSettings));
    await tester.pumpAndSettle();
    final confirm = tester.widget<TextButton>(
      find.widgetWithText(TextButton, l10n.restoreDefaults),
    );
    expect(
      confirm.style?.foregroundColor?.resolve(const {}),
      const Color(0xFF7F0019),
    );
    await tester.tap(find.text(l10n.restoreDefaults));
    await tester.pumpAndSettle();
    expect(find.text(l10n.resetSettingsDesc), findsNothing);
    expect(container.read(appSettingProvider), defaultAppSettingProps);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the settings search reaches the reset row by name', (
    tester,
  ) async {
    await pumpIndex(tester);
    final l10n = currentAppLocalizations;
    await tester.enterText(find.byType(TextField), 'reset');
    await tester.pumpAndSettle();
    expect(find.text(l10n.general), findsOneWidget);
    await tester.enterText(find.byType(TextField), l10n.resetSettings);
    await tester.pumpAndSettle();
    expect(find.text(l10n.general), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
