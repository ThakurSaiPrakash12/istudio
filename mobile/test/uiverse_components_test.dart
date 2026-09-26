import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_studio/app/widgets/uiverse_loader.dart';
import 'package:lumen_studio/app/widgets/uiverse_search_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UiverseLoader Widget Tests', () {
    testWidgets('Renders UiverseLoader with loading text and animated bars', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: UiverseLoader(),
            ),
          ),
        ),
      );

      expect(find.byType(UiverseLoader), findsOneWidget);
      expect(find.text('loading'), findsOneWidget);

      // Advance animation timer
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byType(UiverseLoader), findsOneWidget);
    });

    testWidgets('Renders UiverseLoader with custom text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: UiverseLoader(text: 'fetching clients'),
            ),
          ),
        ),
      );

      expect(find.text('fetching clients'), findsOneWidget);
    });
  });

  group('UiverseSearchBar Widget Tests', () {
    testWidgets('Renders search input and handles text entry and clear', (tester) async {
      final controller = TextEditingController();
      String changedValue = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: UiverseSearchBar(
                controller: controller,
                hintText: 'Search clients...',
                onChanged: (val) => changedValue = val,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Search clients...'), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);

      // Type text into search bar
      await tester.enterText(find.byType(TextField), 'John Doe');
      await tester.pumpAndSettle();

      expect(changedValue, 'John Doe');
      expect(controller.text, 'John Doe');
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Tap clear button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(controller.text, '');
      expect(changedValue, '');
    });
  });
}
