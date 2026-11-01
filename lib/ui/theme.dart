import 'package:kfusion/ui/color.dart';
import 'package:kfusion/ui/hara.dart';
import 'package:kfusion/ui/metrics.dart';
import 'package:kfusion/ui/typography.dart';
import 'package:material_ui/material_ui.dart';

class CommonMinFilledButtonTheme extends StatelessWidget {
  final Widget child;

  const CommonMinFilledButtonTheme({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return FilledButtonTheme(
      data: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ).merge(FilledButtonTheme.of(context).style),
      ),
      child: child,
    );
  }
}

class CommonMinIconButtonTheme extends StatelessWidget {
  final Widget child;

  const CommonMinIconButtonTheme({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return IconButtonTheme(
      data: IconButtonThemeData(
        style: IconButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          iconSize: 20.ap(context),
        ).merge(IconButtonTheme.of(context).style),
      ),
      child: child,
    );
  }
}

class SliderDefaultsM3 extends SliderThemeData {
  SliderDefaultsM3(this.context) : super(trackHeight: 16.0);

  final BuildContext context;
  late final HaraPalette _palette = context.haraPalette;

  @override
  Color? get activeTrackColor => _palette.ink;

  @override
  Color? get inactiveTrackColor => _palette.line;

  @override
  Color? get secondaryActiveTrackColor => _palette.ink.withValues(alpha: 0.54);

  @override
  Color? get disabledActiveTrackColor => _palette.dim;

  @override
  Color? get disabledInactiveTrackColor => _palette.line;

  @override
  Color? get disabledSecondaryActiveTrackColor => _palette.dim;

  @override
  Color? get activeTickMarkColor => _palette.bg;

  @override
  Color? get inactiveTickMarkColor => _palette.sub;

  @override
  Color? get disabledActiveTickMarkColor => _palette.bg;

  @override
  Color? get disabledInactiveTickMarkColor => _palette.dim;

  @override
  Color? get thumbColor => _palette.ink;

  @override
  Color? get disabledThumbColor => _palette.dim;

  @override
  Color? get overlayColor =>
      WidgetStateColor.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.dragged)) {
          return _palette.ink.opacity10;
        }
        if (states.contains(WidgetState.hovered)) {
          return _palette.ink.withValues(alpha: 0.08);
        }
        if (states.contains(WidgetState.focused)) {
          return _palette.ink.opacity10;
        }

        return Colors.transparent;
      });

  @override
  TextStyle? get valueIndicatorTextStyle => AppTextStyle.subheadline
      .of(context, emphasized: true)
      .copyWith(color: _palette.bg);

  @override
  Color? get valueIndicatorColor => _palette.ink;

  @override
  SliderComponentShape? get valueIndicatorShape =>
      const RoundedRectSliderValueIndicatorShape();

  @override
  SliderComponentShape? get thumbShape => const HandleThumbShape();

  @override
  SliderTrackShape? get trackShape => const GappedSliderTrackShape();

  @override
  SliderComponentShape? get overlayShape => const RoundSliderOverlayShape();

  @override
  SliderTickMarkShape? get tickMarkShape =>
      const RoundSliderTickMarkShape(tickMarkRadius: 4.0 / 2);

  @override
  WidgetStateProperty<Size?>? get thumbSize {
    return WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) {
        return const Size(4.0, 44.0);
      }
      if (states.contains(WidgetState.hovered)) {
        return const Size(4.0, 44.0);
      }
      if (states.contains(WidgetState.focused)) {
        return const Size(2.0, 44.0);
      }
      if (states.contains(WidgetState.pressed)) {
        return const Size(2.0, 44.0);
      }
      return const Size(4.0, 44.0);
    });
  }

  @override
  double? get trackGap => 6.0;
}
