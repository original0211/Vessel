import 'package:kfusion/common/common.dart';
import 'package:kfusion/l10n/l10n.dart';
import 'package:kfusion/providers/app.dart';
import 'package:kfusion/ui/popup.dart';
import 'package:kfusion/widgets/config_item.dart';
import 'package:kfusion/widgets/input.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

final _viewSizeOverride = viewSizeProvider.overrideWithBuild(
  (_, _) => const Size(1200, 1000),
);

final _modeProvider = Provider<String>((_) => 'a');
final _nameProvider = Provider<String>((_) => 'old');
final _entriesProvider = Provider<List<String>>((_) => const []);

Future<void> pumpItem(WidgetTester tester, Widget item) async {
  await tester.pumpWidget(
    TestApp(
      overrides: [_viewSizeOverride],
      wrapInProviderScope: true,
      child: Scaffold(body: item),
    ),
  );
  await tester.pump();
}

void main() {
  test('validateCidr accepts a CIDR and refuses anything else', () async {
    final l = await AppLocalizations.load(const Locale('en'));
    expect(validateCidr('10.0.0.0/8', l), isNull);
    expect(validateCidr('2001:db8::/32', l), isNull);
    expect(validateCidr('10.0.0.0/33', l), l.invalidCidrContent);
    expect(validateCidr('not-a-cidr', l), l.invalidCidrContent);
    expect(validateCidr(null, l), l.invalidCidrContent);
  });

  group('ConfigOptionsItem', () {
    testWidgets('shows its subtitle and current value, and writes the '
        'picked option', (tester) async {
      final written = <String>[];
      await pumpItem(
        tester,
        ConfigOptionsItem<String>(
          selector: _modeProvider,
          title: (_) => 'Mode',
          subtitle: (_) => 'Pick one',
          options: const ['a', 'b'],
          textBuilder: (value) => value,
          onChanged: (_, value) => written.add(value),
        ),
      );
      expect(find.text('Pick one'), findsOneWidget);
      await tester.tap(find.text('Mode'));
      await tester.pumpAndSettle();
      expect(find.byType(CommonPopupMenu), findsOneWidget);
      await tester.tap(find.text('b'));
      await tester.pumpAndSettle();
      expect(written, ['b']);
    });
  });

  group('ConfigTextItem', () {
    ConfigTextItem item({
      List<String> written = const [],
      String Function(String value)? normalize,
      ConfigValidator? validator,
      bool allowEmpty = false,
    }) {
      return ConfigTextItem(
        selector: _nameProvider,
        title: (_) => 'Name',
        normalize: normalize,
        validator: validator,
        allowEmpty: allowEmpty,
        onChanged: (_, value) => written.add(value),
      );
    }

    testWidgets('shows the value under the title and writes an edit', (
      tester,
    ) async {
      final written = <String>[];
      await pumpItem(tester, item(written: written));
      expect(find.text('old'), findsOneWidget);
      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'new');
      await tester.tap(find.text(currentAppLocalizations.submit));
      await tester.pumpAndSettle();
      expect(written, ['new']);
    });

    testWidgets('an unchanged edit writes nothing', (tester) async {
      final written = <String>[];
      await pumpItem(tester, item(written: written));
      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'old');
      await tester.tap(find.text(currentAppLocalizations.submit));
      await tester.pumpAndSettle();
      expect(written, isEmpty);
    });

    testWidgets('an empty edit is refused with the empty tip', (tester) async {
      final written = <String>[];
      await pumpItem(tester, item(written: written));
      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text(currentAppLocalizations.submit));
      await tester.pumpAndSettle();
      expect(
        find.text(currentAppLocalizations.emptyTip('Name')),
        findsOneWidget,
      );
      expect(written, isEmpty);
    });

    testWidgets('normalization runs before the validator and the writer', (
      tester,
    ) async {
      final written = <String>[];
      await pumpItem(
        tester,
        item(
          written: written,
          normalize: (value) => value.trim(),
          validator: (value, _) => value == 'bad' ? 'No bad' : null,
        ),
      );
      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), ' bad ');
      await tester.tap(find.text(currentAppLocalizations.submit));
      await tester.pumpAndSettle();
      expect(find.text('No bad'), findsOneWidget);
      expect(written, isEmpty);
      await tester.enterText(find.byType(TextField), ' good ');
      await tester.tap(find.text(currentAppLocalizations.submit));
      await tester.pumpAndSettle();
      expect(written, ['good']);
    });
  });

  group('ConfigListEditItem', () {
    testWidgets('an empty list reads as none, opens its editor, and '
        'leaving it unchanged writes nothing', (tester) async {
      final written = <List<String>>[];
      await pumpItem(
        tester,
        ConfigListEditItem(
          selector: _entriesProvider,
          title: (_) => 'Entries',
          onChanged: (_, value) => written.add(value),
        ),
      );
      expect(find.text(currentAppLocalizations.none), findsOneWidget);
      await tester.tap(find.text('Entries'));
      await tester.pumpAndSettle();
      expect(find.byType(ListEditView), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ListEditView), findsNothing);
      expect(written, isEmpty);
    });

    testWidgets('a filled list counts its entries', (tester) async {
      await tester.pumpWidget(
        TestApp(
          overrides: [
            _viewSizeOverride,
            _entriesProvider.overrideWithValue(const ['a', 'b']),
          ],
          wrapInProviderScope: true,
          child: Scaffold(
            body: ConfigListEditItem(
              selector: _entriesProvider,
              title: (_) => 'Entries',
              onChanged: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(currentAppLocalizations.itemsCount(2)), findsOneWidget);
    });
  });
}
