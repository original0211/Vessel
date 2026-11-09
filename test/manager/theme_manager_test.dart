import 'package:kfusion/enum/enum.dart';
import 'package:kfusion/manager/theme_manager.dart';
import 'package:kfusion/ui/hara.dart';
import 'package:kfusion/ui/theme.dart';
import 'package:kfusion/models/models.dart';
import 'package:kfusion/providers/config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('following the system picks up a font scale changed while the '
      'app runs', (tester) async {
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    double? scaled;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ThemeManager(
            child: Builder(
              builder: (context) {
                scaled = MediaQuery.textScalerOf(context).scale(10);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );

    expect(scaled, 10);

    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    await tester.pump();

    expect(scaled, closeTo(13, 1e-9));
  });

  testWidgets('a theme setting the theme does not read keeps the same theme', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final themes = <ThemeData>[];
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (_, ref, _) {
            ref.watch(themeSettingProvider);
            themes.add(watchAppTheme(ref, Brightness.dark));
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    void update(ThemeProps Function(ThemeProps props) change) {
      final notifier = container.read(themeSettingProvider.notifier);
      notifier.value = change(notifier.value);
    }

    update((props) => props.copyWith(liquidGlass: LiquidGlassMode.standard));
    await tester.pump();
    update((props) => props.copyWith(pureBlack: !props.pureBlack));
    await tester.pump();

    expect(themes, hasLength(3));
    expect(themes[1], same(themes[0]));
    expect(themes[2], isNot(same(themes[1])));
  });

  group('control themes read the field, not the accent', () {
    Future<ThemeData> appTheme(
      WidgetTester tester,
      Brightness brightness,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      late ThemeData theme;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (_, ref, _) {
              theme = watchAppTheme(ref, brightness);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return theme;
    }

    testWidgets('a switch is ink when on and a hairline outline when off', (
      tester,
    ) async {
      for (final (brightness, palette) in [
        (Brightness.light, HaraPalette.light),
        (Brightness.dark, HaraPalette.dark),
      ]) {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        late ThemeData theme;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: Consumer(
              builder: (_, ref, _) {
                theme = watchAppTheme(ref, brightness);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        final switchTheme = theme.switchTheme;
        expect(
          switchTheme.trackColor!.resolve({WidgetState.selected}),
          palette.ink,
          reason: '$brightness on track',
        );
        expect(
          switchTheme.trackColor!.resolve({}),
          palette.bg,
          reason: '$brightness off track',
        );
        expect(
          switchTheme.trackOutlineColor!.resolve({}),
          palette.line,
          reason: '$brightness off outline',
        );
        expect(
          switchTheme.thumbColor!.resolve({WidgetState.selected}),
          palette.bg,
          reason: '$brightness on thumb',
        );
        expect(
          switchTheme.thumbColor!.resolve({}),
          palette.sub,
          reason: '$brightness off thumb',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('a checkbox fills ink and checks in the field color', (
      tester,
    ) async {
      final theme = await appTheme(tester, Brightness.light);
      final checkboxTheme = theme.checkboxTheme;
      expect(
        checkboxTheme.fillColor!.resolve({WidgetState.selected}),
        HaraPalette.light.ink,
      );
      expect(checkboxTheme.fillColor!.resolve({}), Colors.transparent);
      expect(checkboxTheme.checkColor!.resolve({}), HaraPalette.light.bg);
    });

    testWidgets('a filled button fills the field behind a hairline', (
      tester,
    ) async {
      final theme = await appTheme(tester, Brightness.light);
      final style = theme.filledButtonTheme.style!;
      expect(style.backgroundColor!.resolve({}), HaraPalette.light.bg);
      expect(style.foregroundColor!.resolve({}), HaraPalette.light.ink);
      expect(
        style.backgroundColor!.resolve({WidgetState.disabled}),
        HaraPalette.light.line,
      );
    });

    testWidgets('the slider defaults run on ink over the hairline', (
      tester,
    ) async {
      late SliderDefaultsM3 defaults;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [HaraTheme(HaraPalette.light)]),
          home: Builder(
            builder: (context) {
              defaults = SliderDefaultsM3(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(defaults.activeTrackColor, HaraPalette.light.ink);
      expect(defaults.inactiveTrackColor, HaraPalette.light.line);
      expect(defaults.thumbColor, HaraPalette.light.ink);
    });

    testWidgets('the slider defaults follow the dark field', (tester) async {
      late SliderDefaultsM3 defaults;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [HaraTheme(HaraPalette.dark)]),
          home: Builder(
            builder: (context) {
              defaults = SliderDefaultsM3(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(defaults.activeTrackColor, HaraPalette.dark.ink);
      expect(defaults.inactiveTrackColor, HaraPalette.dark.line);
      expect(defaults.thumbColor, HaraPalette.dark.ink);
    });
  });
}
