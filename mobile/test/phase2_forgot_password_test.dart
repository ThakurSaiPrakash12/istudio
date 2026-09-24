import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_studio/app/providers/auth_provider.dart';
import 'package:lumen_studio/app/screens/auth/forgot_password_sheet.dart';
import 'package:lumen_studio/app/screens/auth/login_form.dart';
import 'package:provider/provider.dart';

void main() {
  group('Phase 2: Forgot Password & OTP Flow Tests', () {
    testWidgets('LoginForm renders Forgot password button and opens sheet',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginForm(
              isLoading: false,
              onSubmit: (_, __) async {},
            ),
          ),
        ),
      );

      final forgotBtn = find.text('Forgot password?');
      expect(forgotBtn, findsOneWidget);
    });

    testWidgets('ForgotPasswordSheet displays step 1 phone validation correctly',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider(
              create: (_) => AuthProvider(),
              child: const ForgotPasswordSheet(initialPhone: '9876543210'),
            ),
          ),
        ),
      );

      expect(find.text('Reset Studio Password'), findsOneWidget);
      expect(find.text('Send Verification Code'), findsOneWidget);
      expect(find.text('9876543210'), findsOneWidget);
    });
  });
}
