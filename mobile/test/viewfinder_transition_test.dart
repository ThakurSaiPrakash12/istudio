import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_studio/app/routes/smooth_page_route.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Viewfinder Lens Zoom Route Transition Tests', () {
    testWidgets('Builds smooth page transition without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            return SmoothPageRoute(
              builder: (context) => const Scaffold(
                body: Text('Second Screen'),
              ),
            );
          },
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/second');
                },
                child: const Text('Go to Second'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Go to Second'), findsOneWidget);

      await tester.tap(find.text('Go to Second'));
      await tester.pump(); // Start transition
      await tester.pump(const Duration(milliseconds: 150)); // Mid transition
      await tester.pumpAndSettle(); // End transition

      expect(find.text('Second Screen'), findsOneWidget);
    });
  });
}
