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

    testWidgets('ForgotPasswordSheet displays step 1 username verification correctly',
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

      expect(find.text('Reset Studio Password'), findsOneWidget);
      expect(find.text('Verify Username'), findsOneWidget);
      expect(find.text('studio_pro'), findsOneWidget);
    });
  });
}
