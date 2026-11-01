import 'dart:math' as math;

import 'package:kfusion/providers/config.dart';
import 'package:kfusion/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class PreviewChoice<T> {
  const PreviewChoice({
    required this.value,
    required this.label,
    this.pictogram,
  });

  final T value;
  final String label;
  final Widget? pictogram;
}

class PreviewChoiceGroup<T> extends StatelessWidget {
  const PreviewChoiceGroup({
    super.key,
    required this.info,
    required this.choices,
    required this.value,
    required this.onChanged,
    this.actions = const [],
  });

  final Info info;
  final List<PreviewChoice<T>> choices;
  final T value;
  final ValueChanged<T> onChanged;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final palette = context.haraPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                info.label,
                style: HaraText.sectionTitle(context, palette.sub),
              ),
            ),
            ...actions,
          ],
        ),
        const SizedBox(height: HaraSpace.sectionTitleGap),
        HaraHairline(color: palette.line),
        for (final choice in choices)
          _PreviewChoiceRow<T>(
            choice: choice,
            selected: choice.value == value,
            onPressed: () => onChanged(choice.value),
          ),
      ],
    );
  }
}

class _PreviewChoiceRow<T> extends StatelessWidget {
  const _PreviewChoiceRow({
    required this.choice,
    required this.selected,
    required this.onPressed,
  });

  final PreviewChoice<T> choice;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.haraPalette;
    return InkWell(
      customBorder: AppShape.hara,
      onTap: onPressed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: HaraSpace.nodeRowVertical,
            ),
            child: Row(
              children: [
                if (choice.pictogram != null) ...[
                  ExcludeSemantics(child: choice.pictogram!),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Text(
                    choice.label,
                    style: HaraText.nodeName(
                      context,
                      palette.ink,
                      current: selected,
                    ),
                  ),
                ),
                if (selected) SelectionCheck(color: palette.ink),
              ],
            ),
          ),
          HaraHairline(color: palette.line),
        ],
      ),
    );
  }
}

/// A choice row's thumbnail: the home sketch in the option's own field —
/// split vertically when [splitPalette] is set, double-framed for glass,
/// with [frameColor] where the field is too dark for a hairline to read.
class HomeSketchThumb extends StatelessWidget {
  const HomeSketchThumb({
    super.key,
    required this.palette,
    this.splitPalette,
    this.glass = false,
    this.frameColor,
  });

  static const double height = 30;
  static const double width = height * 96 / 66;
  static const Size size = Size(width, height);

  final HaraPalette palette;
  final HaraPalette? splitPalette;
  final bool glass;
  final Color? frameColor;

  @override
  Widget build(BuildContext context) {
    final frame = frameColor ?? context.haraPalette.line;
    Widget sketch(HaraPalette sketchPalette) =>
        CustomPaint(painter: _HomeSketchPainter(sketchPalette), size: size);
    final split = splitPalette;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          if (split == null)
            sketch(palette)
          else ...[
            ClipRect(
              clipper: const _HalfClipper(right: false),
              child: sketch(palette),
            ),
            ClipRect(
              clipper: const _HalfClipper(right: true),
              child: sketch(split),
            ),
          ],
          if (glass)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(left: 3, top: 3),
                child: CustomPaint(painter: _PreviewFramePainter(frame)),
              ),
            ),
          Positioned.fill(
            child: CustomPaint(painter: _PreviewFramePainter(frame)),
          ),
        ],
      ),
    );
  }
}

class _HalfClipper extends CustomClipper<Rect> {
  const _HalfClipper({required this.right});

  final bool right;

  @override
  Rect getClip(Size size) => right
      ? Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height)
      : Rect.fromLTWH(0, 0, size.width / 2, size.height);

  @override
  bool shouldReclip(_HalfClipper oldClipper) => oldClipper.right != right;
}

/// The home screen as Vessel draws it, shown in both fields at once: the
/// disc, the add-profile row, and the three destinations along the foot.
class ThemeLivePreview extends ConsumerWidget {
  const ThemeLivePreview({super.key});

  static const double _phoneWidth = 168;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pureBlack = ref.watch(
      themeSettingProvider.select((state) => state.pureBlack),
    );
    final line = context.haraPalette.line;
    Widget phone(HaraPalette palette, double width) => SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: 9 / 17,
        child: CustomPaint(
          foregroundPainter: _PreviewFramePainter(line),
          child: CustomPaint(painter: _HomeSketchPainter(palette)),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: HaraSpace.groupGap),
      child: LayoutBuilder(
        builder: (_, constraints) {
          final width = math.min(_phoneWidth, (constraints.maxWidth - 12) / 2);
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              phone(HaraPalette.light, width),
              phone(
                HaraPalette.of(Brightness.dark, pureBlack: pureBlack),
                width,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A hairline sketch of the home screen in one field: wordmark, disc with
/// its point in ink, the add-profile row, and the foot's three destinations,
/// the first of them current.
class _HomeSketchPainter extends CustomPainter {
  const _HomeSketchPainter(this.palette);

  final HaraPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final inset = width * 0.09;
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.bg);
    canvas.drawRect(
      Rect.fromLTWH(inset, height * 0.045, width * 0.16, height * 0.008),
      Paint()..color = palette.ink,
    );
    final center = Offset(width / 2, height * 0.36);
    final stroke = math.max(1.0, width * 0.008);
    final ringRadius = math.min(width * 0.30, height * 0.335) - stroke;
    canvas.drawCircle(
      center,
      ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = palette.sub,
    );
    canvas.drawCircle(
      DiscGeometry.dotCenter(center, ringRadius),
      DiscGeometry.dotRadius(ringRadius + stroke / 2),
      Paint()..color = palette.ink,
    );
    final hairline = Paint()
      ..strokeWidth = HaraSpace.hairline
      ..color = palette.line;
    canvas.drawLine(
      Offset(inset, height * 0.80),
      Offset(width - inset, height * 0.80),
      hairline,
    );
    canvas.drawRect(
      Rect.fromLTWH(inset, height * 0.825, width * 0.22, height * 0.007),
      Paint()..color = palette.ink,
    );
    final arrowY = height * 0.8285;
    canvas.drawPath(
      Path()
        ..moveTo(width * 0.862, arrowY - height * 0.006)
        ..lineTo(width * 0.888, arrowY)
        ..lineTo(width * 0.862, arrowY + height * 0.006),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, width * 0.007)
        ..color = palette.sub,
    );
    canvas.drawLine(
      Offset(0, height * 0.905),
      Offset(width, height * 0.905),
      hairline,
    );
    for (var i = 0; i < 3; i++) {
      final cellCenter = width * (i * 2 + 1) / 6;
      canvas.drawRect(
        Rect.fromLTWH(
          cellCenter - width * 0.065,
          height * 0.945,
          width * 0.13,
          height * 0.007,
        ),
        Paint()..color = i == 0 ? palette.ink : palette.dim,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(
        width / 6 - width * 0.05,
        height * 0.962,
        width * 0.10,
        1.6,
      ),
      Paint()..color = palette.ink,
    );
  }

  @override
  bool shouldRepaint(_HomeSketchPainter oldDelegate) =>
      oldDelegate.palette != palette;
}

/// The hairline frame of a live preview phone, painted over the sketch so
/// the phones read as framed schematics on the page field.
class _PreviewFramePainter extends CustomPainter {
  const _PreviewFramePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      (Offset.zero & size).deflate(HaraSpace.hairline / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = HaraSpace.hairline
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_PreviewFramePainter oldDelegate) =>
      oldDelegate.color != color;
}
