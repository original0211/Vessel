import 'dart:math' show max;

import 'package:kfusion/enum/enum.dart';
import 'package:kfusion/models/models.dart';
import 'package:kfusion/providers/app.dart';
import 'package:kfusion/providers/config.dart';
import 'package:kfusion/providers/database.dart';
import 'package:kfusion/state.dart';

import 'package:kfusion/views/theme.dart';
import 'package:kfusion/views/theme_preview.dart';
import 'package:kfusion/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [profilesProvider.overrideWith(TestProfiles.new)],
    );
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(1400, 2400);
  });

  tearDown(() => container.dispose());

  Future<void> pumpThemeView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: ThemeView()),
      ),
    );
    await tester.pumpAndSettle();
  }

  ThemeProps readTheme() => container.read(themeSettingProvider);

  group('theme mode', () {
    testWidgets('defaults to following the system', (tester) async {
      await pumpThemeView(tester);

      expect(readTheme().themeMode, ThemeMode.system);
    });

    testWidgets('switches to light and back to dark', (tester) async {
      await pumpThemeView(tester);

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(readTheme().themeMode, ThemeMode.light);

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(readTheme().themeMode, ThemeMode.dark);

      await tester.tap(find.text('Auto'));
      await tester.pumpAndSettle();
      expect(readTheme().themeMode, ThemeMode.system);
    });
  });

  group('sidebar blur', () {
    testWidgets('the retired toggle never renders', (tester) async {
      await pumpThemeView(tester);

      expect(find.text('Sidebar blur'), findsNothing);
    });
  });

  group('liquid glass', () {
    testWidgets('is off until a tier is chosen, and switches back', (
      tester,
    ) async {
      await pumpThemeView(tester);
      final group = find.ancestor(
        of: find.text('Liquid Glass').first,
        matching: find.byType(PreviewChoiceGroup<LiquidGlassMode>),
      );
      Finder choice(String label) =>
          find.descendant(of: group, matching: find.text(label)).last;

      expect(readTheme().liquidGlass, LiquidGlassMode.none);

      await tester.tap(choice('Standard'));
      await tester.pumpAndSettle();
      expect(readTheme().liquidGlass, LiquidGlassMode.standard);

      await tester.tap(choice('None'));
      await tester.pumpAndSettle();
      expect(readTheme().liquidGlass, LiquidGlassMode.none);
    });

    testWidgets('offers no ultra tier', (tester) async {
      await pumpThemeView(tester);

      expect(find.text('Ultra'), findsNothing);
    });
  });

  group('pure black', () {
    testWidgets('switches both ways', (tester) async {
      await pumpThemeView(tester);

      expect(readTheme().pureBlack, isFalse);

      await tester.tap(find.text('Pure black'));
      await tester.pumpAndSettle();
      expect(readTheme().pureBlack, isTrue);

      await tester.tap(find.text('Standard').first);
      await tester.pumpAndSettle();
      expect(readTheme().pureBlack, isFalse);
    });
  });

  group('home navigation', () {
    testWidgets('offers no bottom bar style or cabin core rows', (
      tester,
    ) async {
      await pumpThemeView(tester);

      expect(find.text('Bottom bar'), findsNothing);
      expect(find.text('Floating'), findsNothing);
      expect(find.text('Docked'), findsNothing);
      expect(find.text('Compact cabin core'), findsNothing);
    });

    testWidgets('offers no tab animation group', (tester) async {
      await pumpThemeView(tester);

      expect(find.text('Tab animation'), findsNothing);
      expect(find.text('Slide'), findsNothing);
      expect(find.text('Fade'), findsNothing);
    });
  });

  group('choice thumbnails', () {
    // In page order: auto, light, dark, the pure black pair, the glass pair.
    Finder thumbs() => find.byType(HomeSketchThumb);

    Finder paintsOf(Finder thumb) =>
        find.descendant(of: thumb, matching: find.byType(CustomPaint));

    void expectField(Finder thumb, Color color) {
      expect(
        paintsOf(thumb).first,
        paints..rect(
          color: color,
          rect: const Rect.fromLTWH(
            0,
            0,
            HomeSketchThumb.width,
            HomeSketchThumb.height,
          ),
        ),
      );
    }

    testWidgets('every choice row carries one, all the same size', (
      tester,
    ) async {
      await pumpThemeView(tester);

      expect(thumbs(), findsNWidgets(7));
      for (final thumb in tester.elementList(thumbs())) {
        expect(
          tester.getSize(find.byWidget(thumb.widget)),
          HomeSketchThumb.size,
        );
      }
    });

    testWidgets('each thumbnail sketches on the field of its option', (
      tester,
    ) async {
      await pumpThemeView(tester);

      expectField(thumbs().at(1), const Color(0xFFFFFFFF));
      expectField(thumbs().at(2), const Color(0xFF101010));

      final auto = paintsOf(thumbs().at(0));
      expect(auto, findsNWidgets(3));
      expect(auto.at(0), paints..rect(color: const Color(0xFFFFFFFF)));
      expect(auto.at(1), paints..rect(color: const Color(0xFF101010)));
    });

    testWidgets('the pure black thumbnail reads apart from the standard one', (
      tester,
    ) async {
      await pumpThemeView(tester);
      final pageLine = tester.element(find.byType(ThemeView)).haraPalette.line;

      expectField(thumbs().at(3), const Color(0xFF101010));
      expectField(thumbs().at(4), const Color(0xFF000000));
      expect(
        paintsOf(thumbs().at(3)).last,
        paints..rect(color: pageLine, style: PaintingStyle.stroke),
      );
      expect(
        paintsOf(thumbs().at(4)).last,
        paints..rect(
          color: HaraPalette.of(Brightness.dark, pureBlack: true).ink,
          style: PaintingStyle.stroke,
        ),
      );
    });

    testWidgets('the standard glass thumbnail carries a second frame', (
      tester,
    ) async {
      await pumpThemeView(tester);

      expect(paintsOf(thumbs().at(5)), findsNWidgets(2));
      expect(paintsOf(thumbs().at(6)), findsNWidgets(3));
    });
  });

  group('preview form', () {
    testWidgets('the option thumbs carry no rounded clip', (tester) async {
      await pumpThemeView(tester);

      expect(
        find.descendant(
          of: find.byType(HomeSketchThumb),
          matching: find.byType(ClipRSuperellipse),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(HomeSketchThumb),
          matching: find.byType(ClipRRect),
        ),
        findsNothing,
      );
    });

    testWidgets('the live preview phones carry no rounded clip', (
      tester,
    ) async {
      await pumpThemeView(tester);

      expect(
        find.descendant(
          of: find.byType(ThemeLivePreview),
          matching: find.byType(ClipRSuperellipse),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(ThemeLivePreview),
          matching: find.byType(ClipRRect),
        ),
        findsNothing,
      );
    });

    testWidgets('the choice rows mark the current value in ink', (
      tester,
    ) async {
      await pumpThemeView(tester);
      final palette = tester.element(find.byType(ThemeView)).haraPalette;

      final checks = find.byType(SelectionCheck);
      expect(checks, findsWidgets);
      for (final check in tester.widgetList<SelectionCheck>(checks)) {
        expect(check.color, palette.ink);
        expect(check.color, isNot(palette.vermilion));
      }
    });
  });

  group('retired theme color controls', () {
    testWidgets('the color controls are gone, the kept groups remain', (
      tester,
    ) async {
      await pumpThemeView(tester);

      expect(find.text('Theme color'), findsNothing);
      expect(find.text('Color style'), findsNothing);
      expect(find.text('Custom color'), findsNothing);
      expect(find.text('Theme mode'), findsOneWidget);
      expect(find.text('Pure black mode'), findsOneWidget);
    });
  });

  group('live preview sketch', () {
    Finder phones() => find.descendant(
      of: find.byType(ThemeLivePreview),
      matching: find.byType(AspectRatio),
    );

    Finder sketches() => find.descendant(
      of: find.byType(ThemeLivePreview),
      matching: find.byType(CustomPaint),
    );

    testWidgets('the two phones share a size and a top edge', (tester) async {
      await pumpThemeView(tester);

      final found = phones();
      expect(found, findsNWidgets(2));
      final first = tester.getRect(found.at(0));
      final second = tester.getRect(found.at(1));
      expect(first.size, second.size);
      expect(first.top, second.top);
      final previewTop = tester.getTopLeft(find.byType(ThemeLivePreview)).dy;
      expect(first.top - previewTop, HaraSpace.groupGap);
    });

    testWidgets(
      'each phone sketches the disc, its point in ink, and its field',
      (tester) async {
        await pumpThemeView(tester);

        void expectSketch(int index, HaraPalette palette) {
          final sketch = sketches().at(index * 2 + 1);
          final size = tester.getSize(sketch);
          final center = Offset(size.width / 2, size.height * 0.36);
          final stroke = max(1.0, size.width * 0.008);
          final ringRadius = size.width * 0.30 - stroke;
          final dotCenter = DiscGeometry.dotCenter(center, ringRadius);
          final dotRadius = DiscGeometry.dotRadius(ringRadius + stroke / 2);
          expect(
            sketch,
            paints
              ..rect(color: palette.bg)
              ..circle(
                x: center.dx,
                y: center.dy,
                radius: ringRadius,
                style: PaintingStyle.stroke,
                color: palette.sub,
              )
              ..circle(
                x: dotCenter.dx,
                y: dotCenter.dy,
                radius: dotRadius,
                color: palette.ink,
              ),
          );
        }

        expectSketch(0, HaraPalette.light);
        expectSketch(1, HaraPalette.dark);
      },
    );
  });

  group('text scale', () {
    testWidgets('follows the system until custom is picked', (tester) async {
      await pumpThemeView(tester);

      expect(readTheme().textScale.enable, isFalse);
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);

      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      expect(readTheme().textScale.enable, isTrue);
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNotNull);

      await tester.tap(find.text('Follow system'));
      await tester.pumpAndSettle();

      expect(readTheme().textScale.enable, isFalse);
    });

    testWidgets('writes the scale only when the drag ends', (tester) async {
      await pumpThemeView(tester);
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();
      final before = readTheme().textScale.scale;

      final slider = find.byType(Slider);
      final gesture = await tester.startGesture(tester.getCenter(slider));
      await gesture.moveBy(const Offset(120, 0));
      await tester.pump();
      expect(readTheme().textScale.scale, before);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(readTheme().textScale.scale, isNot(before));
    });

    testWidgets('resets a custom scale to 100%', (tester) async {
      container
          .read(themeSettingProvider.notifier)
          .update(
            (state) => state.copyWith.textScale(enable: true, scale: 1.2),
          );

      await pumpThemeView(tester);

      expect(find.text('120%'), findsOneWidget);

      await tester.tap(find.byTooltip('Reset').last);
      await tester.pumpAndSettle();

      expect(readTheme().textScale.scale, 1);
      expect(find.text('100%'), findsOneWidget);
    });
  });
}
