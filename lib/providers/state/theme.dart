part of '../state.dart';

@riverpod
ColorScheme genColorScheme(Ref ref, Brightness brightness, {bool? pureBlack}) {
  final pureBlackSetting = ref.watch(
    themeSettingProvider.select((state) => state.pureBlack),
  );
  return _cachedColorScheme(
    const Color(defaultPrimaryColor),
    brightness,
    pureBlack ?? pureBlackSetting,
  );
}

const _maxCachedColorSchemes = 64;

final _colorSchemes = <(Color, Brightness, bool), ColorScheme>{};

ColorScheme _cachedColorScheme(
  Color seedColor,
  Brightness brightness,
  bool pureBlack,
) {
  final key = (seedColor, brightness, pureBlack);
  final colorScheme =
      _colorSchemes.remove(key) ??
      seededColorScheme(
        seedColor: seedColor,
        brightness: brightness,
      ).toPureBlack(pureBlack);
  _colorSchemes[key] = colorScheme;
  if (_colorSchemes.length > _maxCachedColorSchemes) {
    _colorSchemes.remove(_colorSchemes.keys.first);
  }
  return colorScheme;
}

typedef WindowBlurRequest = ({bool enabled, Brightness brightness, Color tint});

@riverpod
WindowBlurRequest windowBlurRequest(Ref ref) {
  // Sidebar blur is retired; the request stays because the startup
  // no-effect call is what parks the macOS effect view.
  final brightness = ref.watch(currentBrightnessProvider);
  final colorScheme = ref.watch(genColorSchemeProvider(brightness));
  return (
    enabled: false,
    brightness: brightness,
    tint: colorScheme.surfaceContainer,
  );
}

@riverpod
Brightness currentBrightness(Ref ref) {
  final themeMode = ref.watch(
    themeSettingProvider.select((state) => state.themeMode),
  );
  final systemBrightness = ref.watch(systemBrightnessProvider);
  return switch (themeMode) {
    ThemeMode.system => systemBrightness,
    ThemeMode.light => Brightness.light,
    ThemeMode.dark => Brightness.dark,
  };
}
