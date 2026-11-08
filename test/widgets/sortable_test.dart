import 'package:kfusion/ui/icons/icons.dart';
import 'package:kfusion/ui/sortable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

void main() {
  group('SortableItem scope', () {
    Future<SortableItemData?> pumpProbe(
      WidgetTester tester, {
      bool? sorting,
    }) async {
      SortableItemData? seen;
      final probe = SortableItem(
        index: 3,
        child: Builder(
          builder: (context) {
            seen = SortableItem.maybeOf(context);
            return const SizedBox.shrink();
          },
        ),
      );
      await tester.pumpWidget(
        TestApp(
          child: sorting == null
              ? probe
              : SortModeScope(sorting: sorting, child: probe),
        ),
      );
      return seen;
    }

    testWidgets('without a sort mode scope the item reads as not sorting', (
      tester,
    ) async {
      final data = await pumpProbe(tester);
      expect(data, (index: 3, sorting: false));
    });

    testWidgets('the scope sorting flag reaches the item data', (tester) async {
      expect(await pumpProbe(tester, sorting: true), (index: 3, sorting: true));
      expect(await pumpProbe(tester, sorting: false), (
        index: 3,
        sorting: false,
      ));
    });

    testWidgets('isSorting answers from the nearest item scope', (
      tester,
    ) async {
      bool? seen;
      await tester.pumpWidget(
        TestApp(
          child: SortModeScope(
            sorting: true,
            child: SortableItem(
              index: 0,
              child: Builder(
                builder: (context) {
                  seen = SortableItem.isSorting(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      expect(seen, isTrue);
    });
  });

  group('DisclosureIndicator', () {
    testWidgets('is a 48 dp box holding the forward chevron', (tester) async {
      await tester.pumpWidget(
        const TestApp(child: Center(child: DisclosureIndicator())),
      );
      expect(
        tester.getSize(find.byType(DisclosureIndicator)),
        const Size.square(kMinInteractiveDimension),
      );
      final icon = tester.widget<GlyphIcon>(find.byType(GlyphIcon));
      expect(icon.glyph, AppGlyphs.chevronForward);
    });
  });

  group('SortHandle keyboard sorting', () {
    Future<List<(int, int)>> pumpList(
      WidgetTester tester, {
      int count = 3,
    }) async {
      final calls = <(int, int)>[];
      await tester.pumpWidget(
        TestApp(
          child: ReorderableListView.builder(
            itemCount: count,
            onReorderItem: (from, to) => calls.add((from, to)),
            itemBuilder: (context, index) => SizedBox(
              key: ValueKey(index),
              height: 56,
              child: Row(
                children: [
                  Expanded(child: Text('row $index')),
                  SortHandle(index: index),
                ],
              ),
            ),
          ),
        ),
      );
      return calls;
    }

    Future<void> focusHandle(WidgetTester tester, int index) async {
      final inside = find.descendant(
        of: find.byType(SortHandle).at(index),
        matching: find.byType(GlyphIcon),
      );
      Focus.of(tester.element(inside)).requestFocus();
      await tester.pump();
    }

    AnimatedContainer handleDisc(WidgetTester tester, int index) {
      return tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(SortHandle).at(index),
          matching: find.byType(AnimatedContainer),
        ),
      );
    }

    Color discColor(WidgetTester tester, int index) {
      final decoration =
          handleDisc(tester, index).decoration! as ShapeDecoration;
      return decoration.color!;
    }

    testWidgets('space lifts the row, arrows reorder, escape sets it down', (
      tester,
    ) async {
      final calls = await pumpList(tester);
      final scheme = Theme.of(
        tester.element(find.byType(SortHandle).first),
      ).colorScheme;
      await focusHandle(tester, 1);
      expect(discColor(tester, 1), scheme.onSurface.withValues(alpha: 0.12));

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(discColor(tester, 1), scheme.onSurface.withValues(alpha: 0.16));
      final glyph = tester.widget<GlyphIcon>(
        find.descendant(
          of: find.byType(SortHandle).at(1),
          matching: find.byType(GlyphIcon),
        ),
      );
      expect(glyph.glyph, AppGlyphs.dragHandle);
      expect(glyph.color, scheme.primary);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(calls, [(1, 2)]);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      expect(calls, [(1, 2), (1, 0)]);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(discColor(tester, 1), scheme.onSurface.withValues(alpha: 0.12));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(calls, hasLength(2));
    });

    testWidgets('arrows at the list edges stay put', (tester) async {
      final calls = await pumpList(tester);
      await focusHandle(tester, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      expect(calls, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(calls, isEmpty);
    });

    testWidgets('an unrelated key is ignored while lifted', (tester) async {
      final calls = await pumpList(tester);
      await focusHandle(tester, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      expect(calls, isEmpty);
    });

    testWidgets('losing focus sets a lifted row back down', (tester) async {
      await pumpList(tester);
      final scheme = Theme.of(
        tester.element(find.byType(SortHandle).first),
      ).colorScheme;
      await focusHandle(tester, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(discColor(tester, 1), scheme.onSurface.withValues(alpha: 0.16));
      await focusHandle(tester, 2);
      expect(discColor(tester, 1), scheme.onSurface.withValues(alpha: 0));
    });
  });

  group('SortableTrailing', () {
    Future<void> pumpTrailing(
      WidgetTester tester, {
      required bool sorting,
    }) async {
      await tester.pumpWidget(
        TestApp(
          child: Align(
            alignment: Alignment.topLeft,
            child: SortableTrailing(
              item: (index: 0, sorting: sorting),
              child: const SizedBox(width: 80, height: 48),
            ),
          ),
        ),
      );
    }

    testWidgets('idle shows the trailing and no handle', (tester) async {
      await pumpTrailing(tester, sorting: false);
      expect(find.byType(SortHandle), findsNothing);
      expect(tester.getSize(find.byType(SortableTrailing)).width, 80);
    });

    testWidgets('sorting swaps the trailing for the handle', (tester) async {
      await pumpTrailing(tester, sorting: true);
      await tester.pumpAndSettle();
      expect(find.byType(SortHandle), findsOneWidget);
      expect(
        tester.getSize(find.byType(SortableTrailing)).width,
        kMinInteractiveDimension,
      );
    });

    testWidgets('toggling sorting animates between the two widths', (
      tester,
    ) async {
      await pumpTrailing(tester, sorting: false);
      await pumpTrailing(tester, sorting: true);
      await tester.pump(const Duration(milliseconds: 100));
      final midWidth = tester.getSize(find.byType(SortableTrailing)).width;
      expect(midWidth, lessThan(80));
      expect(midWidth, greaterThan(kMinInteractiveDimension));
      await tester.pumpAndSettle();
      expect(find.byType(SortHandle), findsOneWidget);
      await pumpTrailing(tester, sorting: false);
      await tester.pumpAndSettle();
      expect(find.byType(SortHandle), findsNothing);
      expect(tester.getSize(find.byType(SortableTrailing)).width, 80);
    });
  });

  group('sortModeAction', () {
    testWidgets('carries the sort glyph, tooltip and selection state', (
      tester,
    ) async {
      late BuildContext captured;
      var pressed = 0;
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
      final idle = sortModeAction(captured, sorting: false, onPressed: null);
      expect(idle.glyph, AppGlyphs.sort);
      expect(idle.isSelected, isFalse);
      expect(idle.onPressed, isNull);
      expect(idle.tooltip, isNotEmpty);
      final active = sortModeAction(
        captured,
        sorting: true,
        onPressed: () => pressed++,
      );
      expect(active.isSelected, isTrue);
      active.onPressed?.call();
      expect(pressed, 1);
    });
  });
}
