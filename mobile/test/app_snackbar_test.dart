import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_studio/app/utils/app_snackbar.dart';

void main() {
  Future<void> showSnackBar(
    WidgetTester tester, {
    required SnackType type,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                if (type == SnackType.success) {
                  AppSnackBar.success(context, 'Done');
                } else {
                  AppSnackBar.error(context, 'Failed');
                }
              },
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
  }

  testWidgets('success snackbar stays for 10 seconds then dismisses', (
    tester,
  ) async {
    await showSnackBar(tester, type: SnackType.success);

    expect(find.text('Done'), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
    expect(find.text('Done'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsNothing);
  });

  testWidgets('error snackbar remains until dismissed', (tester) async {
    await showSnackBar(tester, type: SnackType.error);

    expect(find.text('Failed'), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
    expect(find.text('Failed'), findsOneWidget);

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('Failed'), findsNothing);
  });
}
