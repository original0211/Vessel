import 'package:kfusion/ui/chip.dart';
import 'package:kfusion/widgets/chip_title.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

void main() {
  final future = DateTime.now().add(const Duration(days: 30));
  final past = DateTime.now().subtract(const Duration(days: 30));

  Future<void> pumpTitle(
    WidgetTester tester,
    ChipTitle title, {
    double width = 800,
  }) async {
    await tester.pumpWidget(
      TestApp(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: title),
        ),
      ),
    );
  }

  group('ChipTitle', () {
    testWidgets('a bare title is plain ellipsized text, no chips', (
      tester,
    ) async {
      await pumpTitle(tester, const ChipTitle(title: 'Alpha'));
      final text = tester.widget<Text>(find.text('Alpha'));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(find.byType(TonalChip), findsNothing);
      expect(find.byType(ExpireChip), findsNothing);
    });

    testWidgets('a count chip stands beside the title when there is no '
        'expiry', (tester) async {
      await pumpTitle(tester, const ChipTitle(title: 'Alpha', chip: '6'));
      expect(
        find.descendant(of: find.byType(TonalChip), matching: find.text('6')),
        findsOneWidget,
      );
      expect(find.byType(ExpireChip), findsNothing);
    });

    testWidgets('an expiry chip stands beside the title when the row is '
        'wide', (tester) async {
      await pumpTitle(tester, ChipTitle(title: 'Alpha', expire: future));
      expect(find.byType(ExpireChip), findsOneWidget);
      expect(find.byType(TonalChip), findsNothing);
    });

    testWidgets('the expiry chip gives way before it squeezes the title '
        'below half the row', (tester) async {
      await pumpTitle(
        tester,
        ChipTitle(title: 'A very long subscription title', expire: future),
        width: 200,
      );
      expect(find.byType(ExpireChip), findsNothing);
      expect(find.text('A very long subscription title'), findsOneWidget);
    });

    testWidgets('with both chips and room to spare, both stand', (
      tester,
    ) async {
      await pumpTitle(
        tester,
        ChipTitle(title: 'Alpha', chip: '6', expire: future),
      );
      expect(find.byType(TonalChip), findsOneWidget);
      expect(find.byType(ExpireChip), findsOneWidget);
    });

    testWidgets('in a narrow row the count chip stays and the expiry chip '
        'gives way', (tester) async {
      await pumpTitle(
        tester,
        ChipTitle(
          title: 'A very long subscription title',
          chip: '6',
          expire: future,
        ),
        width: 200,
      );
      expect(find.byType(TonalChip), findsOneWidget);
      expect(find.byType(ExpireChip), findsNothing);
    });
  });

  group('ExpireChip', () {
    testWidgets('an unexpired date reads in the variant foreground', (
      tester,
    ) async {
      await pumpTitle(tester, ChipTitle(title: 'Alpha', expire: future));
      final context = tester.element(find.byType(ExpireChip));
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(ExpireChip),
          matching: find.byType(Text),
        ),
      );
      expect(text.style?.color, Theme.of(context).colorScheme.onSurfaceVariant);
    });

    testWidgets('an expired date reads in the error foreground', (
      tester,
    ) async {
      await pumpTitle(tester, ChipTitle(title: 'Alpha', expire: past));
      final context = tester.element(find.byType(ExpireChip));
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(ExpireChip),
          matching: find.byType(Text),
        ),
      );
      expect(text.style?.color, Theme.of(context).colorScheme.error);
    });

    testWidgets('widthOf matches the rendered chip width', (tester) async {
      await pumpTitle(tester, ChipTitle(title: 'Alpha', expire: future));
      final context = tester.element(find.byType(ExpireChip));
      final rendered = tester.getSize(find.byType(ExpireChip)).width;
      expect(ExpireChip.widthOf(context, future), closeTo(rendered, 1.0));
    });
  });
}
