import 'package:kfusion/ui/table_layout.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

const _columns = [
  TableColumn('time', 'Time', width: 80),
  TableColumn('target', 'Target', flex: 2),
  TableColumn('rule', 'Rule', flex: 1),
  TableColumn('exit', 'Exit', width: 120),
];

double _sum(List<double> widths) => widths.fold(0, (sum, w) => sum + w);

void main() {
  test('flexible columns share what the fixed ones leave', () {
    expect(tableColumnWidths(_columns, 500), [80, 200, 100, 120]);
  });

  test('a dragged column keeps its width and the other flexible ones '
      'take up the rest', () {
    final widths = tableColumnWidths(_columns, 500, {'target': 150});

    expect(widths, [80, 150, 150, 120]);
  });

  test('dragged widths scale to fit once the table is narrower than them', () {
    final widths = tableColumnWidths(_columns, 400, {
      'target': 300,
      'rule': 200,
    });

    expect(_sum(widths), closeTo(400, 0.001));
    expect(widths[1] / widths[2], closeTo(1.5, 0.001));
  });

  test('dragged widths scale to fill when no flexible column is left', () {
    final widths = tableColumnWidths(_columns, 700, {
      'target': 150,
      'rule': 150,
    });

    expect(_sum(widths), closeTo(700, 0.001));
    expect(widths[0] / widths[3], closeTo(80 / 120, 0.001));
  });

  test('a drag moves one edge and leaves the other columns in place', () {
    final widths = tableColumnWidths(_columns, 500);
    final overrides = resizedTableColumns(_columns, widths, const {}, 1, 30);
    final resized = tableColumnWidths(_columns, 500, overrides);

    expect(overrides, {'target': 230, 'rule': 70});
    expect(resized, [80, 230, 70, 120]);
  });

  test('widening a column squeezes the ones after it in turn', () {
    final widths = tableColumnWidths(_columns, 500);

    expect(resizedTableColumns(_columns, widths, const {}, 1, 80), {
      'target': 280,
      'rule': tableColumnMinWidth,
      'exit': 120 - (80 - (100 - tableColumnMinWidth)),
    });
    expect(resizedTableColumns(_columns, widths, const {}, 1, 500), {
      'target': 200 + (100 - tableColumnMinWidth) + (120 - tableColumnMinWidth),
      'rule': tableColumnMinWidth,
      'exit': tableColumnMinWidth,
    });
  });

  test('narrowing a column gives its space to the next one only', () {
    final widths = tableColumnWidths(_columns, 500);

    expect(resizedTableColumns(_columns, widths, const {}, 0, -500), {
      'time': tableColumnMinWidth,
      'target': 200 + 80 - tableColumnMinWidth,
    });
  });

  test('a column that cannot be resized is never squeezed', () {
    const columns = [
      TableColumn('target', 'Target', flex: 1),
      TableColumn('action', '', width: 44, resizable: false),
      TableColumn('exit', 'Exit', width: 120),
    ];
    final widths = tableColumnWidths(columns, 400);

    expect(resizedTableColumns(columns, widths, const {}, 0, 50), {
      'target': 286,
      'exit': 70,
    });
  });

  test('flex shares clamp at zero when fixed widths exceed the table', () {
    const columns = [
      TableColumn('a', 'A', width: 100),
      TableColumn('f', 'F', flex: 1),
    ];

    expect(tableColumnWidths(columns, 60), [100, 0]);
  });

  test('existing overrides survive a resize untouched', () {
    final widths = tableColumnWidths(_columns, 500);

    expect(resizedTableColumns(_columns, widths, const {'exit': 90}, 1, 10), {
      'exit': 90,
      'target': 210,
      'rule': 90,
    });
  });

  group('TableCells', () {
    testWidgets('cells take their column widths and end columns align to '
        'the end', (tester) async {
      await tester.pumpWidget(
        const TestApp(
          child: Align(
            alignment: Alignment.topLeft,
            child: TableCells(
              columns: [
                TableColumn('a', 'A', width: 120),
                TableColumn('b', 'B', width: 80, end: true),
              ],
              widths: [120, 80],
              height: 40,
              inset: 8,
              cells: [Text('left'), Text('right')],
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(TableCells)).height, 40);
      expect(tester.getRect(find.text('left')).left, 8);
      // The end cell's text ends 8 dp before the row's 200 dp mark.
      expect(tester.getRect(find.text('right')).right, 120 + 80 - 8);
    });
  });

  group('TableColumnResizer', () {
    Future<void> pumpResizer(
      WidgetTester tester, {
      required List<TableColumn> columns,
      required List<double> widths,
      required void Function(int, double) onResize,
      required VoidCallback onResizeEnd,
      required VoidCallback onReset,
      TextDirection direction = TextDirection.ltr,
    }) {
      return tester.pumpWidget(
        TestApp(
          child: Directionality(
            textDirection: direction,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                height: 50,
                child: TableColumnResizer(
                  columns: columns,
                  widths: widths,
                  onResize: onResize,
                  onResizeEnd: onResizeEnd,
                  onReset: onReset,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Finder handles() => find.descendant(
      of: find.byType(TableColumnResizer),
      matching: find.byType(GestureDetector),
    );

    const twoFixed = [
      TableColumn('a', 'A', width: 100),
      TableColumn('b', 'B', width: 100),
    ];

    testWidgets('a handle stands only where both neighbours resize', (
      tester,
    ) async {
      await pumpResizer(
        tester,
        columns: const [
          TableColumn('a', 'A', width: 100),
          TableColumn('b', 'B', width: 100, resizable: false),
          TableColumn('c', 'C', width: 100),
        ],
        widths: const [100, 100, 100],
        onResize: (_, _) {},
        onResizeEnd: () {},
        onReset: () {},
      );
      expect(handles(), findsNothing);
      await pumpResizer(
        tester,
        columns: const [
          TableColumn('a', 'A', width: 100),
          TableColumn('b', 'B', width: 100),
          TableColumn('c', 'C', width: 100),
        ],
        widths: const [100, 100, 100],
        onResize: (_, _) {},
        onResizeEnd: () {},
        onReset: () {},
      );
      expect(handles(), findsNWidgets(2));
    });

    testWidgets('dragging a handle reports its deltas and the drag end', (
      tester,
    ) async {
      final deltas = <(int, double)>[];
      var ends = 0;
      await pumpResizer(
        tester,
        columns: twoFixed,
        widths: const [100, 100],
        onResize: (boundary, delta) => deltas.add((boundary, delta)),
        onResizeEnd: () => ends++,
        onReset: () {},
      );
      await tester.drag(handles(), const Offset(24, 0));
      // Flush the double-tap recogniser's pending timeout.
      await tester.pump(const Duration(milliseconds: 400));
      expect(deltas, isNotEmpty);
      expect(deltas.every((call) => call.$1 == 0), isTrue);
      // The gesture arena keeps the touch slop for itself, so the reported
      // deltas total less than the pointer travel; their sign and their
      // sum staying within it is the contract.
      final total = deltas.fold<double>(0, (sum, call) => sum + call.$2);
      expect(total, greaterThan(0));
      expect(total, lessThanOrEqualTo(24));
      expect(deltas.every((call) => call.$2 > 0), isTrue);
      expect(ends, 1);
    });

    testWidgets('in rtl the same drag reports the mirrored delta', (
      tester,
    ) async {
      final deltas = <(int, double)>[];
      await pumpResizer(
        tester,
        columns: twoFixed,
        widths: const [100, 100],
        onResize: (boundary, delta) => deltas.add((boundary, delta)),
        onResizeEnd: () {},
        onReset: () {},
        direction: TextDirection.rtl,
      );
      await tester.drag(handles(), const Offset(24, 0));
      await tester.pump(const Duration(milliseconds: 400));
      final total = deltas.fold<double>(0, (sum, call) => sum + call.$2);
      expect(total, lessThan(0));
      expect(total, greaterThanOrEqualTo(-24));
      expect(deltas.every((call) => call.$2 < 0), isTrue);
    });

    testWidgets('double tapping a handle resets and hovering reveals it', (
      tester,
    ) async {
      var resets = 0;
      await pumpResizer(
        tester,
        columns: twoFixed,
        widths: const [100, 100],
        onResize: (_, _) {},
        onResizeEnd: () {},
        onReset: () => resets++,
      );
      Visibility visibility() => tester.widget<Visibility>(
        find.descendant(
          of: find.byType(TableColumnResizer),
          matching: find.byType(Visibility),
        ),
      );
      expect(visibility().visible, isFalse);
      final center = tester.getCenter(handles());
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: center);
      await gesture.moveTo(center);
      await tester.pump();
      expect(visibility().visible, isTrue);
      await gesture.removePointer();
      final first = await tester.startGesture(center);
      await first.up();
      await tester.pump(const Duration(milliseconds: 50));
      final second = await tester.startGesture(center);
      await second.up();
      await tester.pump(const Duration(milliseconds: 400));
      expect(resets, 1);
    });
  });
}
