import 'package:kfusion/common/common.dart';
import 'package:kfusion/providers/app.dart';
import 'package:kfusion/state.dart';
import 'package:kfusion/views/developer.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

ProviderContainer _containerFor(WidgetTester tester) {
  const size = Size(1400, 1000);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer();
  addTearDown(container.dispose);
  globalState.container = container;
  container.read(viewSizeProvider.notifier).update((_) => size);
  return container;
}

Future<void> _pumpDeveloperView(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const TestApp(child: DeveloperView()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    globalState.appEnv = 'dev';
  });

  testWidgets('shows no developer mode switch, only the actions', (
    tester,
  ) async {
    final container = _containerFor(tester);
    await _pumpDeveloperView(tester, container);

    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.text(currentAppLocalizations.developerMode),
      ),
      findsNothing,
    );
    expect(find.text(currentAppLocalizations.clearData), findsOneWidget);
    expect(find.text(currentAppLocalizations.pruneCache), findsOneWidget);
    expect(tester.takeException(), null);
  });

  testWidgets('clear data asks for confirmation and aborts on cancel', (
    tester,
  ) async {
    final container = _containerFor(tester);
    await _pumpDeveloperView(tester, container);

    await tester.tap(find.text(currentAppLocalizations.clearData));
    await tester.pumpAndSettle();

    expect(find.text(currentAppLocalizations.confirmClearAllData), findsOne);

    await tester.tap(find.text(currentAppLocalizations.cancel));
    await tester.pumpAndSettle();

    expect(
      find.text(currentAppLocalizations.confirmClearAllData),
      findsNothing,
    );
    expect(tester.takeException(), null);
  });
}
