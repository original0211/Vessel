import 'dart:math';

import 'package:kfusion/common/common.dart';
import 'package:kfusion/enum/enum.dart';
import 'package:kfusion/models/models.dart';
import 'package:kfusion/providers/config.dart';
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
                _LiquidGlassItem(),
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
    return PreviewChoiceGroup<ThemeMode>(
      info: Info(label: appLocalizations.themeMode, glyph: AppGlyphs.sun),
      value: themeMode,
      choices: [
        PreviewChoice(
          value: ThemeMode.system,
          label: appLocalizations.auto,
          pictogram: const HomeSketchThumb(
            palette: HaraPalette.light,
            splitPalette: HaraPalette.dark,
          ),
        ),
        PreviewChoice(
          value: ThemeMode.light,
          label: appLocalizations.light,
          pictogram: const HomeSketchThumb(palette: HaraPalette.light),
        ),
        PreviewChoice(
          value: ThemeMode.dark,
          label: appLocalizations.dark,
          pictogram: const HomeSketchThumb(palette: HaraPalette.dark),
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

class _PureBlackItem extends ConsumerWidget {
  const _PureBlackItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final pureBlack = ref.watch(
      themeSettingProvider.select((state) => state.pureBlack),
    );
    final pureBlackPalette = HaraPalette.of(Brightness.dark, pureBlack: true);
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
          pictogram: const HomeSketchThumb(palette: HaraPalette.dark),
        ),
        PreviewChoice(
          value: true,
          label: appLocalizations.pureBlack,
          pictogram: HomeSketchThumb(
            palette: pureBlackPalette,
            frameColor: pureBlackPalette.ink,
          ),
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

class _LiquidGlassItem extends ConsumerWidget {
  const _LiquidGlassItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final mode = ref.watch(
      themeSettingProvider.select((state) => state.liquidGlass),
    );
    final palette = context.haraPalette;
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
          pictogram: HomeSketchThumb(palette: palette),
        ),
        PreviewChoice(
          value: LiquidGlassMode.standard,
          label: appLocalizations.standard,
          pictogram: HomeSketchThumb(palette: palette, glass: true),
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
