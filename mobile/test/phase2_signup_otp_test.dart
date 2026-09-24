import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_studio/app/providers/auth_provider.dart';
import 'package:lumen_studio/app/screens/auth/signup_form.dart';
import 'package:lumen_studio/app/screens/auth/signup_otp_sheet.dart';
import 'package:provider/provider.dart';

void main() {
  group('Phase 2: Signup Phone OTP Verification Tests', () {
    testWidgets('SignupForm renders all registration fields', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider(
              create: (_) => AuthProvider(),
              child: SignupForm(
                isLoading: false,
                onSubmit: ({
                  required String username,
                  required String phone,
                  required String password,
                }) async {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Phone number'), findsOneWidget);
      expect(find.text('Create password'), findsOneWidget);
      expect(find.text('Confirm password'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
    });

    testWidgets('SignupOtpSheet renders phone number and verification controls',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider(
              create: (_) => AuthProvider(),
              child: const SignupOtpSheet(
                username: 'alice_studio',
                phone: '9876543210',
                password: 'SecretPassword123',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Verify Your Number'), findsOneWidget);
      expect(find.text('Code sent to +91 9876543210'), findsOneWidget);
      expect(find.text('Confirm & Register Studio'), findsOneWidget);
    });
  });
}
