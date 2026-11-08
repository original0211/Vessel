import 'package:kfusion/ui/icons/icons.dart';
import 'package:kfusion/ui/selection_mark.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('SelectionCheck', () {
    testWidgets('paints the check glyph at 24 dp in the scheme primary', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SelectionCheck()));
      final icon = tester.widget<GlyphIcon>(find.byType(GlyphIcon));
      expect(icon.glyph, AppGlyphs.check);
      expect(icon.size, SelectionCheck.size);
      expect(icon.fill, 1);
      final scheme = Theme.of(
        tester.element(find.byType(SelectionCheck)),
      ).colorScheme;
      expect(icon.color, scheme.primary);
    });

    testWidgets('an explicit color overrides the scheme primary', (
      tester,
    ) async {
      const own = Color(0xFF336699);
      await tester.pumpWidget(
        const MaterialApp(home: SelectionCheck(color: own)),
      );
      final icon = tester.widget<GlyphIcon>(find.byType(GlyphIcon));
      expect(icon.color, own);
    });
  });

  group('SelectionBadge', () {
    Future<void> pumpBadge(WidgetTester tester, SelectionBadge badge) {
      return tester.pumpWidget(MaterialApp(home: badge));
    }

    ShapeDecoration badgeDecoration(WidgetTester tester) {
      final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
      return box.decoration as ShapeDecoration;
    }

    testWidgets('default badge is a filled check disc on the primary', (
      tester,
    ) async {
      await pumpBadge(tester, const SelectionBadge());
      final scheme = Theme.of(
        tester.element(find.byType(SelectionBadge)),
      ).colorScheme;
      expect(badgeDecoration(tester).color, scheme.primary);
      final icon = tester.widget<GlyphIcon>(find.byType(GlyphIcon));
      expect(icon.glyph, AppGlyphs.check);
      expect(icon.size, 22 - 6);
      expect(icon.color, scheme.onPrimary);
      final sized = tester.widget<SizedBox>(
        find
            .descendant(
              of: find.byType(SelectionBadge),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(sized.width, 22);
      expect(sized.height, 22);
    });

    testWidgets('preferred badge out of use is a tonal pin', (tester) async {
      await pumpBadge(tester, const SelectionBadge.preferred());
      final scheme = Theme.of(
        tester.element(find.byType(SelectionBadge)),
      ).colorScheme;
      expect(
        badgeDecoration(tester).color,
        scheme.primary.withValues(alpha: 0.14),
      );
      final icon = tester.widget<GlyphIcon>(find.byType(GlyphIcon));
      expect(icon.glyph, AppGlyphs.pin);
      expect(icon.color, scheme.primary);
    });

    testWidgets('preferred badge in use drops the tonal treatment', (
      tester,
    ) async {
      await pumpBadge(tester, const SelectionBadge.preferred(inUse: true));
      final scheme = Theme.of(
        tester.element(find.byType(SelectionBadge)),
      ).colorScheme;
      expect(badgeDecoration(tester).color, scheme.primary);
      final icon = tester.widget<GlyphIcon>(find.byType(GlyphIcon));
      expect(icon.glyph, AppGlyphs.pin);
      expect(icon.color, scheme.onPrimary);
    });

    testWidgets('a custom size shrinks the glyph by the 6 dp inset', (
      tester,
    ) async {
      await pumpBadge(tester, const SelectionBadge(size: 30));
      final icon = tester.widget<GlyphIcon>(find.byType(GlyphIcon));
      expect(icon.size, 24);
    });
  });
}
