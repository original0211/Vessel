import 'dart:math';

import 'package:kfusion/common/common.dart';
import 'package:kfusion/enum/enum.dart';
import 'package:kfusion/models/models.dart';
import 'package:kfusion/providers/config.dart';
import 'package:kfusion/providers/state.dart';
import 'package:kfusion/ui/icons/icons.dart';
import 'package:kfusion/views/theme_preview.dart';
import 'package:kfusion/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemeView extends StatelessWidget {
  const ThemeView({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final palette = context.haraPalette;
    return BaseScaffold(
      title: appLocalizations.theme,
      body: Material(
        color: palette.bg,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = max(
              HaraSpace.pageInset,
              (constraints.maxWidth - HaraSpace.contentMaxWidth) / 2,
            );
            return ListView(
              padding: EdgeInsets.fromLTRB(side, context.appBarInset, side, 48),
              children: const [
                ThemeLivePreview(),
                SizedBox(height: HaraSpace.groupGap),
                _ThemeModeItem(),
                SizedBox(height: HaraSpace.groupGap),
                _PureBlackItem(),
                SizedBox(height: HaraSpace.groupGap),
                _NavigationBarItem(),
                SizedBox(height: HaraSpace.groupGap),
                _CabinCoreCompactItem(),
                SizedBox(height: HaraSpace.groupGap),
                _TabAnimationItem(),
                SizedBox(height: HaraSpace.groupGap),
                _LiquidGlassItem(),
                SizedBox(height: HaraSpace.groupGap),
                _SidebarBlurItem(),
                SizedBox(height: HaraSpace.groupGap),
                _TextScaleFactorItem(),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A lone toggle between two groups: a top hairline, the label (and its
/// description), and the A switch mark; the row tap flips the value.
class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({
    required this.label,
    this.desc,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? desc;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.haraPalette;
    final appLocalizations = context.appLocalizations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HaraHairline(color: palette.line),
        Semantics(
          toggled: value,
          child: HaraRow(
            onTap: () => onChanged(!value),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: HaraText.nodeName(
                          context,
                          palette.ink,
                          current: false,
                        ),
                      ),
                      if (desc != null) ...[
                        const SizedBox(height: HaraSpace.profileMetaGap),
                        Text(
                          desc!,
                          style: HaraText.profileMeta(context, palette.sub),
                        ),
                      ],
                    ],
                  ),
                ),
                HaraToggleMark(
                  value: value,
                  word: value
                      ? appLocalizations.enabled
                      : appLocalizations.disabled,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The reset affordance of a group header, as an ink text action.
class _ResetAction extends StatelessWidget {
  const _ResetAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.haraPalette;
    return Semantics(
      button: true,
      child: Tooltip(
        message: context.appLocalizations.reset,
        child: InkWell(
          customBorder: AppShape.hara,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              context.appLocalizations.reset,
              style: HaraText.action(context, palette.ink),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeModeItem extends ConsumerWidget {
  const _ThemeModeItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final themeMode = ref.watch(
      themeSettingProvider.select((state) => state.themeMode),
    );
    final floatingBar = ref.watch(_floatingBarProvider);
    final liquidGlass = ref.watch(_liquidGlassProvider);
    final light = MiniScreen(
      colorScheme: ref.watch(genColorSchemeProvider(Brightness.light)),
      floatingBar: floatingBar,
      liquidGlass: liquidGlass,
    );
    final dark = MiniScreen(
      colorScheme: ref.watch(genColorSchemeProvider(Brightness.dark)),
      floatingBar: floatingBar,
      liquidGlass: liquidGlass,
    );
    return PreviewChoiceGroup<ThemeMode>(
      info: Info(label: appLocalizations.themeMode, glyph: AppGlyphs.sun),
      value: themeMode,
      choices: [
        PreviewChoice(
          value: ThemeMode.system,
          label: appLocalizations.auto,
          pictogram: MiniScreenThumb(
            screen: MiniSplitScreen(light: light, dark: dark),
          ),
        ),
        PreviewChoice(
          value: ThemeMode.light,
          label: appLocalizations.light,
          pictogram: MiniScreenThumb(screen: light),
        ),
        PreviewChoice(
          value: ThemeMode.dark,
          label: appLocalizations.dark,
          pictogram: MiniScreenThumb(screen: dark),
        ),
      ],
      onChanged: (value) {
        ref
            .read(themeSettingProvider.notifier)
            .update((state) => state.copyWith(themeMode: value));
      },
    );
  }
}

final _floatingBarProvider = appSettingProvider.select(
  (state) => state.floatingNavigationBar,
);

final _liquidGlassProvider = themeSettingProvider.select(
  (state) => state.liquidGlass != LiquidGlassMode.none,
);

class _PureBlackItem extends ConsumerWidget {
  const _PureBlackItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final pureBlack = ref.watch(
      themeSettingProvider.select((state) => state.pureBlack),
    );
    final floatingBar = ref.watch(_floatingBarProvider);
    final liquidGlass = ref.watch(_liquidGlassProvider);
    Widget preview(bool pureBlack) => MiniScreenThumb(
      screen: MiniScreen(
        colorScheme: ref.watch(
          genColorSchemeProvider(Brightness.dark, pureBlack: pureBlack),
        ),
        floatingBar: floatingBar,
        liquidGlass: liquidGlass,
      ),
    );
    return PreviewChoiceGroup<bool>(
      info: Info(
        label: appLocalizations.pureBlackMode,
        glyph: AppGlyphs.pureBlack,
      ),
      value: pureBlack,
      choices: [
        PreviewChoice(
          value: false,
          label: appLocalizations.standard,
          pictogram: preview(false),
        ),
        PreviewChoice(
          value: true,
          label: appLocalizations.pureBlack,
          pictogram: preview(true),
        ),
      ],
      onChanged: (value) {
        ref
            .read(themeSettingProvider.notifier)
            .update((state) => state.copyWith(pureBlack: value));
      },
    );
  }
}

class _NavigationBarItem extends ConsumerWidget {
  const _NavigationBarItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final floatingBar = ref.watch(_floatingBarProvider);
    final liquidGlass = ref.watch(_liquidGlassProvider);
    final colorScheme = context.colorScheme;
    return PreviewChoiceGroup<bool>(
      info: Info(
        label: appLocalizations.navigationBarStyle,
        glyph: AppGlyphs.layers,
      ),
      value: floatingBar,
      choices: [
        PreviewChoice(
          value: true,
          label: appLocalizations.floating,
          pictogram: MiniScreenThumb(
            screen: MiniScreen(
              colorScheme: colorScheme,
              floatingBar: true,
              liquidGlass: liquidGlass,
            ),
          ),
        ),
        PreviewChoice(
          value: false,
          label: appLocalizations.docked,
          pictogram: MiniScreenThumb(
            screen: MiniScreen(colorScheme: colorScheme, floatingBar: false),
          ),
        ),
      ],
      onChanged: (value) {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(floatingNavigationBar: value));
      },
    );
  }
}

class _CabinCoreCompactItem extends ConsumerWidget {
  const _CabinCoreCompactItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final compact = ref.watch(
      appSettingProvider.select((state) => state.cabinCoreCompact),
    );
    return _ThemeToggle(
      label: appLocalizations.cabinCoreCompact,
      value: compact,
      onChanged: (value) {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(cabinCoreCompact: value));
      },
    );
  }
}

class _TabAnimationItem extends ConsumerWidget {
  const _TabAnimationItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final tabAnimation = ref.watch(
      appSettingProvider.select((state) => state.tabAnimation),
    );
    final floatingBar = ref.watch(_floatingBarProvider);
    final liquidGlass = ref.watch(_liquidGlassProvider);
    final colorScheme = context.colorScheme;
    Widget switching(TabAnimation tabAnimation) => MiniScreenThumb(
      screen: MiniScreen(
        colorScheme: colorScheme,
        floatingBar: floatingBar,
        liquidGlass: liquidGlass,
        selected: 1,
        previous: 0,
        progress: 0.55,
        tabAnimation: tabAnimation,
      ),
    );
    return PreviewChoiceGroup<TabAnimation>(
      info: Info(label: appLocalizations.tabAnimation, glyph: AppGlyphs.motion),
      value: tabAnimation,
      choices: [
        PreviewChoice(
          value: TabAnimation.slide,
          label: appLocalizations.slide,
          pictogram: switching(TabAnimation.slide),
        ),
        PreviewChoice(
          value: TabAnimation.fade,
          label: appLocalizations.fade,
          pictogram: switching(TabAnimation.fade),
        ),
      ],
      onChanged: (value) {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(tabAnimation: value));
      },
    );
  }
}

class _LiquidGlassItem extends ConsumerWidget {
  const _LiquidGlassItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final mode = ref.watch(
      themeSettingProvider.select((state) => state.liquidGlass),
    );
    final colorScheme = context.colorScheme;
    // Floating either way, as a docked bar stays a fill, over the list page,
    // whose rows run on under the bar where glass shows them.
    Widget preview(bool liquidGlass) => MiniScreenThumb(
      screen: MiniScreen(
        colorScheme: colorScheme,
        floatingBar: true,
        liquidGlass: liquidGlass,
        selected: 1,
      ),
    );
    return PreviewChoiceGroup<LiquidGlassMode>(
      info: Info(
        label: appLocalizations.liquidGlass,
        glyph: AppGlyphs.liquidGlass,
      ),
      value: mode,
      choices: [
        PreviewChoice(
          value: LiquidGlassMode.none,
          label: appLocalizations.none,
          pictogram: preview(false),
        ),
        PreviewChoice(
          value: LiquidGlassMode.standard,
          label: appLocalizations.standard,
          pictogram: preview(true),
        ),
        PreviewChoice(
          value: LiquidGlassMode.ultra,
          label: appLocalizations.ultra,
          pictogram: preview(true),
        ),
      ],
      onChanged: (value) {
        ref
            .read(themeSettingProvider.notifier)
            .update((state) => state.copyWith(liquidGlass: value));
      },
    );
  }
}

class _SidebarBlurItem extends ConsumerWidget {
  const _SidebarBlurItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!feature.sidebarBlur || (!system.isMacOS && !system.isWindows)) {
      return const SizedBox.shrink();
    }
    final appLocalizations = context.appLocalizations;
    final sidebarBlur = ref.watch(
      themeSettingProvider.select((state) => state.sidebarBlur),
    );
    return _ThemeToggle(
      label: appLocalizations.sidebarBlur,
      desc: appLocalizations.sidebarBlurDesc,
      value: sidebarBlur,
      onChanged: (value) {
        ref
            .read(themeSettingProvider.notifier)
            .update((state) => state.copyWith(sidebarBlur: value));
      },
    );
  }
}

class _TextScaleFactorItem extends ConsumerStatefulWidget {
  const _TextScaleFactorItem();

  static const _step = 0.05;

  @override
  ConsumerState<_TextScaleFactorItem> createState() =>
      _TextScaleFactorItemState();
}

class _TextScaleFactorItemState extends ConsumerState<_TextScaleFactorItem> {
  double? _draft;

  void _update(TextScale Function(TextScale textScale) update) {
    setState(() => _draft = null);
    ref
        .read(themeSettingProvider.notifier)
        .update((state) => state.copyWith(textScale: update(state.textScale)));
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final palette = context.haraPalette;
    final textScale = ref.watch(
      themeSettingProvider.select((state) => state.textScale),
    );
    final systemScale = systemTextScaleOf(
      context,
    ).clamp(minTextScale, maxTextScale).toDouble();
    final scale = _draft ?? (textScale.enable ? textScale.scale : systemScale);
    final percent = '${(scale * 100).round()}%';
    final divisions =
        ((maxTextScale - minTextScale) / _TextScaleFactorItem._step).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PreviewChoiceGroup<bool>(
          info: Info(label: appLocalizations.textScale),
          value: textScale.enable,
          choices: [
            PreviewChoice(value: false, label: appLocalizations.followSystem),
            PreviewChoice(value: true, label: appLocalizations.custom),
          ],
          actions: [
            if (textScale.enable && textScale.scale != 1)
              _ResetAction(
                onPressed: () => _update((state) => state.copyWith(scale: 1)),
              ),
          ],
          onChanged: (value) =>
              _update((state) => state.copyWith(enable: value)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: HaraSpace.nodeRowVertical,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  Expanded(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topLeft,
                      child: MediaQuery(
                        data: MediaQuery.of(
                          context,
                        ).copyWith(textScaler: TextScaler.linear(scale)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 4,
                          children: [
                            Text(
                              'Aa',
                              style: HaraText.pageTitle(context, palette.ink),
                            ),
                            Text(
                              appLocalizations.textScalePreview,
                              style: HaraText.profileMeta(context, palette.sub),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Text(
                    percent,
                    style: HaraText.dataValue(context, palette.ink),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              MediaQuery.withNoTextScaling(
                child: Row(
                  spacing: 12,
                  children: [
                    ExcludeSemantics(
                      child: Text(
                        'A',
                        style: HaraText.profileMeta(context, palette.sub),
                      ),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderDefaultsM3(context).copyWith(
                          activeTrackColor: palette.ink,
                          inactiveTrackColor: palette.line,
                          thumbColor: palette.ink,
                          overlayColor: palette.ink.withValues(alpha: 0.08),
                          valueIndicatorColor: palette.ink,
                          valueIndicatorTextStyle: TextStyle(color: palette.bg),
                        ),
                        child: Slider(
                          padding: EdgeInsets.zero,
                          min: minTextScale,
                          max: maxTextScale,
                          divisions: divisions,
                          value: scale,
                          label: percent,
                          onChanged: textScale.enable
                              ? (value) => setState(() => _draft = value)
                              : null,
                          onChangeEnd: (value) =>
                              _update((state) => state.copyWith(scale: value)),
                        ),
                      ),
                    ),
                    ExcludeSemantics(
                      child: Text(
                        'A',
                        style: HaraText.pageTitle(context, palette.sub),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        HaraHairline(color: palette.line),
      ],
    );
  }
}
