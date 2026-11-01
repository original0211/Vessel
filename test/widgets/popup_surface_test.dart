import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfusion/providers/providers.dart';
import 'package:kfusion/state.dart';
import 'package:kfusion/ui/icons/icons.dart';
import 'package:kfusion/ui/ui.dart';
import 'package:kfusion/views/profiles/universal_import.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

/// The production theme assembly from `watchAppTheme`, minus the providers.
ThemeData _appTheme(Brightness brightness, {bool pureBlack = false}) {
  final scheme = seededColorScheme(
    seedColor: const Color(0xFF3B82C4),
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    extensions: [HaraTheme(HaraPalette.of(brightness, pureBlack: pureBlack))],
  ).withAppShapes.withAppSurfaces.withAppTypography;
}

void main() {
  group('popup surfaces at the theme base', () {
    for (final brightness in Brightness.values) {
      test('menus and the canvas stand on the field, square and '
          'unshadowed ($brightness)', () {
        final theme = _appTheme(brightness);
        final palette = HaraPalette.of(brightness);
        final rim = BorderSide(color: palette.line, width: HaraSpace.hairline);
        final menuShape = AppShape.hara.copyWith(side: rim);

        expect(theme.canvasColor, palette.bg);
        expect(theme.popupMenuTheme.color, palette.bg);
        expect(theme.popupMenuTheme.elevation, 0);
        expect(theme.popupMenuTheme.shape, menuShape);
        final style = theme.menuTheme.style!;
        expect(style.backgroundColor!.resolve(<WidgetState>{}), palette.bg);
        expect(style.elevation!.resolve(<WidgetState>{}), 0);
        expect(style.shape!.resolve(<WidgetState>{}), menuShape);

        // The cabin paper a page surface still reads is never a menu colour.
        expect(theme.popupMenuTheme.color, isNot(theme.colorScheme.surface));
        expect(theme.canvasColor, isNot(theme.colorScheme.surface));
      });
    }

    test('dialogs keep the floating ladder colour', () {
      final theme = _appTheme(Brightness.light);
      expect(
        theme.dialogTheme.backgroundColor,
        SurfaceLevel.floatingOf(theme.colorScheme).colorOf(theme.colorScheme),
      );
    });

    test('a pure black theme puts its menus on pure black', () {
      final theme = _appTheme(Brightness.dark, pureBlack: true);
      final palette = HaraPalette.of(Brightness.dark, pureBlack: true);
      expect(theme.popupMenuTheme.color, palette.bg);
      expect(theme.canvasColor, palette.bg);
    });
  });

  group('the universal import routing template picker', () {
    Future<void> pumpView(WidgetTester tester, Brightness brightness) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
      });
      globalState.container = container;
      container
          .read(viewSizeProvider.notifier)
          .update((_) => const Size(800, 1000));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TestApp(
            theme: _appTheme(Brightness.light),
            darkTheme: _appTheme(Brightness.dark),
            themeMode: brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            child: const UniversalImportView(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder checkGlyph() => find.descendant(
      of: find.byType(CommonPopupMenu),
      matching: find.byWidgetPredicate(
        (widget) => widget is GlyphIcon && widget.glyph == AppGlyphs.check,
      ),
    );

    for (final brightness in Brightness.values) {
      testWidgets('the open menu stands on the field with the current '
          'template checked ($brightness)', (tester) async {
        await pumpView(tester, brightness);
        final palette = HaraPalette.of(brightness);
        expect(find.byType(DropdownButton<String>), findsNothing);

        await tester.tap(find.text('Vessel 默认'));
        await tester.pumpAndSettle();

        final card = tester.widget<PopupMenuCard>(find.byType(PopupMenuCard));
        expect(card.fill, palette.bg);
        expect(card.shadows, isEmpty);
        expect(card.rimColor, palette.line);
        final context = tester.element(find.byType(UniversalImportView));
        expect(card.fill, isNot(Theme.of(context).colorScheme.surface));
        expect(checkGlyph(), findsOneWidget);
      });
    }

    testWidgets('picking a template moves the check and the trigger label', (
      tester,
    ) async {
      await pumpView(tester, Brightness.light);
      await tester.tap(find.text('Vessel 默认'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保留原配置'));
      await tester.pumpAndSettle();

      expect(find.byType(PopupMenuCard), findsNothing);
      expect(find.text('保留原配置'), findsOneWidget);

      await tester.tap(find.text('保留原配置'));
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuCard), findsOneWidget);
      expect(checkGlyph(), findsOneWidget);
    });
  });
}
