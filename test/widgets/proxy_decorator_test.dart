import 'package:kfusion/ui/effect.dart';
import 'package:kfusion/ui/inherited.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('commonProxyDecorator', () {
    Future<AnimationController> pumpDecorator(
      WidgetTester tester, {
      required double value,
    }) async {
      final controller = AnimationController(
        vsync: tester,
        duration: const Duration(seconds: 1),
      );
      addTearDown(controller.dispose);
      controller.value = value;
      ProxyDecoratorProvider? seen;
      await tester.pumpWidget(
        MaterialApp(
          home: commonProxyDecorator(
            Builder(
              builder: (context) {
                seen = ProxyDecoratorProvider.of(context);
                return const SizedBox.square(dimension: 40);
              },
            ),
            0,
            controller,
          ),
        ),
      );
      expect(seen, isNotNull);
      return controller;
    }

    testWidgets('at rest the child is unscaled and the lift reads zero', (
      tester,
    ) async {
      await pumpDecorator(tester, value: 0);
      final transform = tester.widget<Transform>(find.byType(Transform));
      expect(transform.transform.storage[0], 1.0);
      final provider = tester.widget<ProxyDecoratorProvider>(
        find.byType(ProxyDecoratorProvider),
      );
      expect(provider.isProxyDecorator, isTrue);
      expect(provider.lift, 0.0);
    });

    testWidgets(
      'fully lifted the child scales by 1.02 and the lift reads one',
      (tester) async {
        await pumpDecorator(tester, value: 1);
        final transform = tester.widget<Transform>(find.byType(Transform));
        expect(transform.transform.storage[0], closeTo(1.02, 1e-9));
        final provider = tester.widget<ProxyDecoratorProvider>(
          find.byType(ProxyDecoratorProvider),
        );
        expect(provider.lift, 1.0);
      },
    );

    testWidgets('midway the lift follows the eased animation value', (
      tester,
    ) async {
      final controller = await pumpDecorator(tester, value: 0);
      controller.value = 0.5;
      await tester.pump();
      final provider = tester.widget<ProxyDecoratorProvider>(
        find.byType(ProxyDecoratorProvider),
      );
      // Curves.easeInOut passes through 0.5 exactly at the midpoint.
      expect(provider.lift, closeTo(0.5, 1e-9));
      final transform = tester.widget<Transform>(find.byType(Transform));
      expect(transform.transform.storage[0], closeTo(1.01, 1e-9));
    });
  });
}
