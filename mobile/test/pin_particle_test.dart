import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_studio/app/widgets/pin_particle_field.dart';

void main() {
  testWidgets('PinParticleField renders 6 PIN boxes and triggers particle on digit input',
      (WidgetTester tester) async {
    final controllers = List.generate(6, (_) => TextEditingController());
    final focusNodes = List.generate(6, (_) => FocusNode());
    String completedCode = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PinParticleField(
            controllers: controllers,
            focusNodes: focusNodes,
            onCompleted: (code) => completedCode = code,
          ),
        ),
      ),
    );

    // Verify 6 PinParticleBox widgets exist
    expect(find.byType(PinParticleBox), findsNWidgets(6));

    // Type '1' in first box
    await tester.enterText(find.byType(TextField).first, '1');
    await tester.pump();

    // Verify text updated
    expect(controllers[0].text, '1');

    // Pump frames to let particle burst animate and finish
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 300));

    // Enter remaining digits
    for (int i = 1; i < 5; i++) {
      controllers[i].text = '$i';
    }
    await tester.enterText(find.byType(TextField).last, '9');
    await tester.pumpAndSettle();

    expect(completedCode, '112349');

    for (final c in controllers) {
      c.dispose();
    }
    for (final f in focusNodes) {
      f.dispose();
    }
  });

  testWidgets('PinParticleField setDigitsWithCascade auto-fills with staggered particles',
      (WidgetTester tester) async {
    final controllers = List.generate(6, (_) => TextEditingController());
    final focusNodes = List.generate(6, (_) => FocusNode());
    final key = GlobalKey<PinParticleFieldState>();
    String completedCode = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PinParticleField(
            key: key,
            controllers: controllers,
            focusNodes: focusNodes,
            onCompleted: (code) => completedCode = code,
          ),
        ),
      ),
    );

    key.currentState?.setDigitsWithCascade('123456');
    await tester.pump();

    // Advance timers for cascade
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(completedCode, '123456');
    expect(controllers.map((c) => c.text).join(), '123456');

    for (final c in controllers) {
      c.dispose();
    }
    for (final f in focusNodes) {
      f.dispose();
    }
  });
}
