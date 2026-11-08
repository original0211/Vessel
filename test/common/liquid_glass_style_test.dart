import 'package:kfusion/ui/liquid_glass.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final light = ColorScheme.fromSeed(seedColor: const Color(0xFF445566));
  final dark = ColorScheme.fromSeed(
    seedColor: const Color(0xFF445566),
    brightness: Brightness.dark,
  );

  group('LiquidGlassStyle defaults', () {
    test('the bare style carries the documented defaults', () {
      const style = LiquidGlassStyle(tint: Color(0xFF112233));
      expect(style.contrast, 0);
      expect(style.blur, 2.5);
      expect(style.haze, 0);
      expect(style.hazeBlur, 0);
      expect(style.refraction, 60);
      expect(style.bevel, 20);
      expect(style.saturation, 1.5);
      expect(style.brightness, 1);
      expect(style.rim, 0.6);
      expect(style.rimWidth, 1.3);
      expect(style.rimTail, 0);
      expect(style.rimFocus, 0);
      expect(style.rimAdded, 0);
      expect(style.endShade, 0);
      expect(style.dispersion, 0);
      expect(style.rimBlur, 0);
      expect(style.hairline, 0);
      expect(style.hairlineSide, isNull);
    });
  });

  group('LiquidGlassStyle.scale', () {
    const base = LiquidGlassStyle(
      tint: Color(0xCC112233),
      contrast: 0.4,
      blur: 10,
      haze: 0.5,
      hazeBlur: 7,
      refraction: 60,
      bevel: 9,
      saturation: 2,
      brightness: 1.4,
      rim: 0.6,
      rimWidth: 1.1,
      rimTail: 0.2,
      rimFocus: 0.7,
      rimAdded: 0.3,
      endShade: 0.2,
      dispersion: 4,
      rimBlur: 2,
      hairline: 0.4,
      hairlineSide: 0.8,
    );

    test('scale of zero removes every scaled field and keeps the rest', () {
      final scaled = base.scale(0);
      expect(scaled.tint.a, 0);
      expect(scaled.contrast, 0);
      expect(scaled.blur, 0);
      expect(scaled.haze, 0);
      expect(scaled.refraction, 0);
      expect(scaled.saturation, 1);
      expect(scaled.brightness, 1);
      expect(scaled.rim, 0);
      expect(scaled.endShade, 0);
      expect(scaled.dispersion, 0);
      expect(scaled.rimBlur, 0);
      expect(scaled.hairline, 0);
      expect(scaled.hairlineSide, 0);
      expect(scaled.hazeBlur, 7);
      expect(scaled.bevel, 9);
      expect(scaled.rimWidth, 1.1);
      expect(scaled.rimTail, 0.2);
      expect(scaled.rimFocus, 0.7);
      expect(scaled.rimAdded, 0.3);
    });

    test('scale of one is the identity and a half scale halves', () {
      expect(base.scale(1), base);
      final half = base.scale(0.5);
      expect(half.blur, 5);
      expect(half.saturation, 1.5);
      expect(half.brightness, closeTo(1.2, 1e-9));
      expect(half.tint.a, closeTo(0.4, 1e-3));
      expect(half.hairlineSide, 0.4);
    });

    test('scale clamps its input to the unit interval', () {
      expect(base.scale(2), base);
      expect(base.scale(-1), base.scale(0));
    });

    test('a null hairline side stays null under scaling', () {
      const style = LiquidGlassStyle(tint: Color(0xFF112233), hairline: 0.5);
      expect(style.scale(0.5).hairlineSide, isNull);
      expect(style.scale(0.5).hairline, 0.25);
    });
  });

  group('LiquidGlassStyle copyWith and equality', () {
    test('copyWith replaces only the blur', () {
      const base = LiquidGlassStyle(tint: Color(0xFF112233), blur: 3);
      final copied = base.copyWith(blur: 16);
      expect(copied.blur, 16);
      expect(copied.tint, base.tint);
      expect(copied.refraction, base.refraction);
      expect(base.copyWith(), base);
    });

    test('equal styles share a hash code and any field breaks equality', () {
      const a = LiquidGlassStyle(tint: Color(0xFF112233), dispersion: 2);
      const b = LiquidGlassStyle(tint: Color(0xFF112233), dispersion: 2);
      const c = LiquidGlassStyle(tint: Color(0xFF112233), dispersion: 3);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('LiquidGlassStyle factories', () {
    test('regular takes its light tint literally and its dark tint from '
        'the scheme', () {
      final lightStyle = LiquidGlassStyle.regular(light);
      expect(lightStyle.tint, const Color(0x8AFDFDFD));
      expect(lightStyle.contrast, 0.4);
      expect(lightStyle.saturation, 2.08);
      final darkStyle = LiquidGlassStyle.regular(dark);
      expect(
        darkStyle.tint,
        dark.surfaceContainerHighest.withValues(alpha: 0.62),
      );
      expect(darkStyle.contrast, -0.4);
      expect(darkStyle.saturation, 2.84);
      expect(darkStyle.hairlineSide, 0.75);
    });

    test('pill flips contrast and saturation with brightness', () {
      final lightStyle = LiquidGlassStyle.pill(light);
      expect(lightStyle.tint, const Color(0x93F4F4F4));
      expect(lightStyle.saturation, 2.1);
      expect(lightStyle.hairline, 0.35);
      final darkStyle = LiquidGlassStyle.pill(dark);
      expect(darkStyle.contrast, -0.4);
      expect(darkStyle.saturation, 1.925);
      expect(darkStyle.rim, 0.35);
      expect(
        darkStyle.tint,
        dark.surfaceContainerHighest.withValues(alpha: 0.48),
      );
    });

    test('menu is the thick blurred style and alert only deepens its blur', () {
      final lightMenu = LiquidGlassStyle.menu(light);
      expect(lightMenu.blur, 12);
      expect(lightMenu.brightness, 1.1);
      expect(lightMenu.tint, light.surfaceBright.withValues(alpha: 0.55));
      final darkMenu = LiquidGlassStyle.menu(dark);
      expect(darkMenu.brightness, 1.8);
      expect(darkMenu.contrast, -0.53);
      final alert = LiquidGlassStyle.alert(dark);
      expect(alert.blur, 16);
      expect(alert.tint, darkMenu.tint);
      expect(alert.saturation, darkMenu.saturation);
    });

    test('tinted dyes the glass with the given color', () {
      const color = Color(0xFF2266AA);
      final lightStyle = LiquidGlassStyle.tinted(light, color);
      expect(lightStyle.tint, color.withValues(alpha: 0.82));
      expect(lightStyle.saturation, 1.2);
      expect(lightStyle.rim, 0.2);
      expect(lightStyle.hairline, 0.34);
      expect(lightStyle.hairlineSide, 0.5);
      final darkStyle = LiquidGlassStyle.tinted(dark, color);
      expect(darkStyle.rim, 0.14);
      expect(darkStyle.hairline, 0);
      expect(darkStyle.hairlineSide, 0.73);
    });

    test('lens bends outward and lensContent further, with dark panes '
        'brightened', () {
      final lightLens = LiquidGlassStyle.lens(light);
      expect(lightLens.refraction, -4.3);
      expect(lightLens.bevel, 5.5);
      expect(lightLens.dispersion, 6.5);
      expect(lightLens.rim, 0.6);
      expect(lightLens.brightness, 1);
      final darkLens = LiquidGlassStyle.lens(dark);
      expect(darkLens.brightness, 1.33);
      expect(darkLens.rim, 0.3);
      final content = LiquidGlassStyle.lensContent(light);
      expect(content.refraction, 14);
      expect(content.bevel, 11.2);
      expect(content.rim, 0);
      expect(content.dispersion, 3.6);
      expect(content.rimBlur, 2.5);
    });
  });

  group('LiquidGlassGlow', () {
    test('equality and hash code follow all four fields', () {
      const a = LiquidGlassGlow(
        center: Offset(4, 5),
        reach: 30,
        strength: 0.5,
        wash: 0.1,
      );
      const b = LiquidGlassGlow(
        center: Offset(4, 5),
        reach: 30,
        strength: 0.5,
        wash: 0.1,
      );
      const c = LiquidGlassGlow(center: Offset(9, 5), reach: 30, strength: 0.5);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(LiquidGlassGlow.none.strength, 0);
      expect(LiquidGlassGlow.none.wash, 0);
    });
  });

  group('LiquidGlassScope', () {
    testWidgets('without a scope the glass reads disabled at ultra quality', (
      tester,
    ) async {
      late bool enabled;
      late LiquidGlassQuality quality;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              enabled = LiquidGlassScope.of(context);
              quality = LiquidGlassScope.qualityOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(enabled, isFalse);
      expect(quality, LiquidGlassQuality.ultra);
    });

    testWidgets('a scope publishes its enabled flag and quality', (
      tester,
    ) async {
      late bool enabled;
      late LiquidGlassQuality quality;
      await tester.pumpWidget(
        MaterialApp(
          home: LiquidGlassScope(
            enabled: true,
            quality: LiquidGlassQuality.standard,
            child: Builder(
              builder: (context) {
                enabled = LiquidGlassScope.of(context);
                quality = LiquidGlassScope.qualityOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(enabled, isTrue);
      expect(quality, LiquidGlassQuality.standard);
    });
  });
}
