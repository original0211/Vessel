import 'package:kfusion/widgets/active_polling.dart';
import 'package:kfusion/widgets/last_update_time_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('a missing date renders as an empty text in the given style', (
    tester,
  ) async {
    const style = TextStyle(fontSize: 13);
    await tester.pumpWidget(
      const TestApp(
        child: LastUpdateTimeText(lastUpdateDate: null, style: style),
      ),
    );
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.data, '');
    expect(text.style, style);
    expect(find.byType(TickBuilder), findsNothing);
  });

  testWidgets('a date renders its age through the tick builder', (
    tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        child: LastUpdateTimeText(
          lastUpdateDate: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      ),
    );
    expect(find.byType(TickBuilder), findsOneWidget);
    expect(find.text('5 minutes ago'), findsOneWidget);
  });

  testWidgets('the compact form shortens the age', (tester) async {
    await tester.pumpWidget(
      TestApp(
        child: LastUpdateTimeText(
          lastUpdateDate: DateTime.now().subtract(const Duration(minutes: 5)),
          compact: true,
        ),
      ),
    );
    expect(find.text('5m ago'), findsOneWidget);
  });
}
