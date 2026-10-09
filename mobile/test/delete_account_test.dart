import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_studio/app/models/user.dart';
import 'package:lumen_studio/app/providers/auth_provider.dart';
import 'package:lumen_studio/app/screens/profile/profile_screen.dart';
import 'package:provider/provider.dart';

void main() {
  group('Delete Account Verification Flow Tests', () {
    testWidgets('Delete account button in profile shows delete sheet', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authProvider = AuthProvider();
      authProvider.setUserForTesting(
        const User(
          id: 'user123',
          username: 'studiopro',
          email: 'studio@example.com',
          phone: '9876543210',
          studioName: 'Studio Pro',
          ownerName: 'Alex',
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: const MaterialApp(
            home: Scaffold(
              body: ProfileScreen(),
            ),
          ),
        ),
      );

      // Scroll down until Delete Account is visible
      await tester.scrollUntilVisible(
        find.text('Delete Account'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      // Drag a bit further to fully center it in view
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -150));
      await tester.pumpAndSettle();

      expect(find.text('Delete Account'), findsOneWidget);

      // Tap Delete Account to open bottom sheet
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();

      // Step 1: Initial verification sheet renders email and Send Verification Code
      expect(find.text('Permanently Delete Account'), findsOneWidget);
      expect(find.text('This action cannot be undone.'), findsOneWidget);
      expect(find.text('studio@example.com'), findsNWidgets(2));
      expect(find.text('Send Verification Code'), findsOneWidget);
      expect(find.text('Already have a code?'), findsOneWidget);

      // Tap 'Already have a code?' to enter OTP directly (using PinParticleField)
      await tester.tap(find.text('Already have a code?'));
      await tester.pumpAndSettle();

      // Verify OTP step (like signup OTP code)
      expect(find.text('Verify Email Code'), findsOneWidget);
      expect(find.text('Step 1 of 2'), findsOneWidget);
      expect(find.text('Verify Code'), findsOneWidget);
      expect(find.text('Resend Code'), findsOneWidget);

      // Password field should NOT be shown yet on Step 1
      expect(find.text('Confirm Password'), findsNothing);
      expect(find.text('Enter your account password'), findsNothing);
    });
  });
}
