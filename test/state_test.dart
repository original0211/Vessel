import 'package:kfusion/common/constant.dart';
import 'package:kfusion/providers/providers.dart';
import 'package:kfusion/ui/color.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_color_utilities/hct/hct.dart';

void main() {
  test('genColorScheme is fixed to the default seed for both fields', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    for (final brightness in Brightness.values) {
      expect(
        container.read(genColorSchemeProvider(brightness)),
        seededColorScheme(
          seedColor: const Color(defaultPrimaryColor),
          brightness: brightness,
        ),
        reason: '$brightness',
      );
    }
  });

  test('pure black darkens only the dark scheme and keeps surface order', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final light = container.read(genColorSchemeProvider(Brightness.light));
    container
        .read(themeSettingProvider.notifier)
        .update((state) => state.copyWith(pureBlack: true));

    expect(container.read(genColorSchemeProvider(Brightness.light)), light);

    final dark = container.read(genColorSchemeProvider(Brightness.dark));
    final tones = [
      dark.surfaceContainerLowest,
      dark.surface,
      dark.surfaceDim,
      dark.surfaceContainerLow,
      dark.surfaceContainer,
      dark.surfaceContainerHigh,
      dark.surfaceContainerHighest,
    ].map((color) => Hct.fromInt(color.toARGB32()).tone).toList();

    expect(dark.surface, Colors.black);
    expect(tones, orderedEquals([...tones]..sort()));
    expect(tones[3], greaterThan(tones[1]));
  });
}
