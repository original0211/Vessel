import 'dart:io';
import 'dart:math' show max;

import 'package:kfusion/common/feature.dart';

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
    testWidgets('stays hidden while the feature is off', (tester) async {
      await pumpThemeView(tester);

      expect(find.text('Sidebar blur'), findsNothing);
    });

    testWidgets('shows a working toggle only on supported platforms', (
      tester,
    ) async {
      feature = const Feature(sidebarBlur: true);
      addTearDown(() => feature = const Feature());
      await pumpThemeView(tester);
      final toggle = find.text('Sidebar blur');

      expect(readTheme().sidebarBlur, isTrue);
      if (!Platform.isMacOS && !Platform.isWindows) {
        expect(toggle, findsNothing);
        return;
      }

      expect(toggle, findsOneWidget);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(readTheme().sidebarBlur, isFalse);
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
    AppSettingProps readSetting() => container.read(appSettingProvider);

    testWidgets('picks a floating or docked bottom bar', (tester) async {
      await pumpThemeView(tester);

      expect(readSetting().floatingNavigationBar, isTrue);

      await tester.tap(find.text('Docked'));
      await tester.pumpAndSettle();
      expect(readSetting().floatingNavigationBar, isFalse);

      await tester.tap(find.text('Floating'));
      await tester.pumpAndSettle();
      expect(readSetting().floatingNavigationBar, isTrue);
    });

    testWidgets('picks a sliding or fading tab switch', (tester) async {
      await pumpThemeView(tester);

      expect(readSetting().tabAnimation, TabAnimation.slide);

      await tester.tap(find.text('Fade'));
      await tester.pumpAndSettle();
      expect(readSetting().tabAnimation, TabAnimation.fade);

      await tester.tap(find.text('Slide'));
      await tester.pumpAndSettle();
      expect(readSetting().tabAnimation, TabAnimation.slide);
    });
  });

  group('preview ground', () {
    testWidgets('the mini screen ground is the field, not the page step', (
      tester,
    ) async {
      Future<void> pumpScheme(ColorScheme scheme) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 200,
                height: 400,
                child: MiniScreen(colorScheme: scheme, floatingBar: false),
              ),
            ),
          ),
        );
      }

      final light = ColorScheme.fromSeed(seedColor: Colors.blue);
      await pumpScheme(light);
      expect(
        find.descendant(
          of: find.byType(MiniScreen),
          matching: find.byType(CustomPaint),
        ),
        paints..rect(
          color: const Color(0xFFFFFFFF),
          rect: const Rect.fromLTWH(0, 0, 200, 400),
        ),
      );

      final dark = ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      );
      await pumpScheme(dark);
      expect(
        find.descendant(
          of: find.byType(MiniScreen),
          matching: find.byType(CustomPaint),
        ),
        paints..rect(
          color: const Color(0xFF101010),
          rect: const Rect.fromLTWH(0, 0, 200, 400),
        ),
      );
    });
  });

  group('preview form', () {
    testWidgets('the option thumbs are square and hairline-framed', (
      tester,
    ) async {
      await pumpThemeView(tester);
      final palette = tester.element(find.byType(ThemeView)).haraPalette;

      final thumbs = find.byType(MiniScreenThumb);
      expect(thumbs, findsWidgets);
      for (final thumb in tester.elementList(thumbs)) {
        final scope = find.byWidget(thumb.widget);
        final clip = find.descendant(
          of: scope,
          matching: find.byType(ClipRSuperellipse),
        );
        expect(
          tester.widget<ClipRSuperellipse>(clip).borderRadius,
          BorderRadius.zero,
        );
        final frame = find.descendant(
          of: scope,
          matching: find.byType(DecoratedBox),
        );
        final decoration =
            tester.widget<DecoratedBox>(frame).decoration as ShapeDecoration;
        final side = (decoration.shape as OutlinedBorder).side;
        expect(side.color, palette.line);
        expect(side.width, HaraSpace.hairline);
      }
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
