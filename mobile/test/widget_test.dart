import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lumen_studio/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> pumpAuth(WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const IStudioApp());
    await tester.pumpAndSettle();
  }

  testWidgets('shows the login screen', (WidgetTester tester) async {
    await pumpAuth(tester);

    // Brand name is present in auth screen
    expect(find.textContaining('Clients Hub'), findsWidgets);
    // Login form fields
    expect(find.text('Email or username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    // Sign-up fields must NOT appear yet
    expect(find.text('Username'), findsNothing);
    expect(find.text('Email address'), findsNothing);
  });

  testWidgets('reveals signup fields for new users', (WidgetTester tester) async {
    await pumpAuth(tester);

    // Switch to signup
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();

    // Signup-specific fields
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Create password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    // No phone field
    expect(find.text('Phone number'), findsNothing);
    // Submit button label exists somewhere in the tree
    expect(find.textContaining('Verify Email'), findsWidgets);
  });

  testWidgets('validates empty login fields', (WidgetTester tester) async {
    await pumpAuth(tester);

    final signInButton = find.text('Sign in').last;
    await tester.ensureVisible(signInButton);
    await tester.tap(signInButton);
    await tester.pumpAndSettle();

    expect(find.text('Please enter your email or username.'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });
}
