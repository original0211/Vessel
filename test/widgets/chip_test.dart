import 'package:kfusion/ui/chip.dart';
import 'package:kfusion/ui/icons/icons.dart';
import 'package:kfusion/ui/shape.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

void main() {
  group('CommonChip', () {
    testWidgets('shows its label on the raised surface without a delete '
        'action', (tester) async {
      await tester.pumpWidget(
        const TestApp(child: CommonChip(label: 'stable')),
      );
      expect(find.text('stable'), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(CommonChip),
          matching: find.byType(Material),
        ),
      );
      expect(material.shape, AppShape.sm);
      final text = tester.widget<Text>(find.text('stable'));
      final scheme = Theme.of(
        tester.element(find.byType(CommonChip)),
      ).colorScheme;
      expect(text.style?.color, scheme.onSurfaceVariant);
      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(CommonChip),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(padding.padding, const EdgeInsets.fromLTRB(8, 3, 8, 3));
    });

    testWidgets('with onDeleted it grows a close glyph that fires the '
        'callback and narrows the trailing padding', (tester) async {
      var deleted = 0;
      await tester.pumpWidget(
        TestApp(
          child: CommonChip(label: 'draft', onDeleted: () => deleted++),
        ),
      );
      final icon = tester.widget<GlyphIcon>(find.byType(GlyphIcon));
      expect(icon.glyph, AppGlyphs.close);
      expect(icon.size, 14);
      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(CommonChip),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(padding.padding, const EdgeInsets.fromLTRB(8, 3, 6, 3));
      await tester.tap(find.byType(InkWell));
      expect(deleted, 1);
    });
  });

  group('TonalChip', () {
    const chipColor = Color(0xFFDDEEFF);
    const chipForeground = Color(0xFF113355);

    testWidgets('renders its label in the given tones without an ink '
        'response', (tester) async {
      await tester.pumpWidget(
        const TestApp(
          child: TonalChip(
            label: 'tonal',
            color: chipColor,
            foregroundColor: chipForeground,
          ),
        ),
      );
      expect(find.byType(InkWell), findsNothing);
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(TonalChip),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, chipColor);
      final text = tester.widget<Text>(find.text('tonal'));
      expect(text.style?.color, chipForeground);
    });

    testWidgets('with onPressed the chip answers taps', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        TestApp(
          child: TonalChip(
            label: 'tap',
            color: chipColor,
            foregroundColor: chipForeground,
            onPressed: () => pressed++,
          ),
        ),
      );
      expect(find.byType(InkWell), findsOneWidget);
      await tester.tap(find.byType(TonalChip));
      expect(pressed, 1);
    });

    testWidgets('lays out beside a baseline-aligned sibling', (tester) async {
      await tester.pumpWidget(
        const TestApp(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              TonalChip(
                label: 'base',
                color: chipColor,
                foregroundColor: chipForeground,
              ),
              Text('sibling'),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('base'), findsOneWidget);
      expect(tester.getSize(find.byType(TonalChip)).height, greaterThan(0));
    });

    testWidgets('widthOf adds the horizontal padding to the measured label '
        'and grows with the label', (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        TestApp(
          child: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final short = TonalChip.widthOf(captured, 'ab');
      final long = TonalChip.widthOf(captured, 'abcdefgh');
      expect(long, greaterThan(short));
      expect(short, chipLabelWidth(captured, 'ab') + 12);
    });
  });

  group('MetaChip', () {
    testWidgets('defaults its label to the variant foreground', (tester) async {
      await tester.pumpWidget(const TestApp(child: MetaChip(label: 'meta')));
      final scheme = Theme.of(
        tester.element(find.byType(MetaChip)),
      ).colorScheme;
      final text = tester.widget<Text>(find.text('meta'));
      expect(text.style?.color, scheme.onSurfaceVariant);
    });

    testWidgets('an explicit color wins over the default', (tester) async {
      const own = Color(0xFFAA5500);
      await tester.pumpWidget(
        const TestApp(
          child: MetaChip(label: 'meta', color: own),
        ),
      );
      final text = tester.widget<Text>(find.text('meta'));
      expect(text.style?.color, own);
    });
  });
}
