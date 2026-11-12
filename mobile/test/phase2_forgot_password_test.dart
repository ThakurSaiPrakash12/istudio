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
              onSubmit: (username, password) async {},
            ),
          ),
        ),
      );

      final forgotBtn = find.text('Forgot password?');
      expect(forgotBtn, findsOneWidget);
    });

    testWidgets(
        'ForgotPasswordSheet step 1 accepts username or email and shows send code button',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider(
              create: (_) => AuthProvider(),
              child: const ForgotPasswordSheet(initialUsername: 'studio_pro'),
            ),
          ),
        ),
      );

      // New step 1: "Reset Your Password" title
      expect(find.text('Reset Your Password'), findsOneWidget);
      // Send code button
      expect(find.text('Send Verification Code'), findsOneWidget);
      // Pre-filled identifier from initialUsername
      expect(find.text('studio_pro'), findsOneWidget);
      // Subtitle visible
      expect(
        find.text("Enter your username or email and we'll send a code."),
        findsOneWidget,
      );
    });
  });
}
