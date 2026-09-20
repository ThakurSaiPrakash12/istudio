import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lumen_studio/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> pumpAuth(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const IStudioApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
  }

  testWidgets('shows the login screen', (WidgetTester tester) async {
    await pumpAuth(tester);

    expect(find.textContaining('iSTUDIO'), findsWidgets);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Username'), findsNothing);
  });

  testWidgets('reveals signup fields for new users', (WidgetTester tester) async {
    await pumpAuth(tester);

    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();

    expect(find.text('Join the studio'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('Create password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('validates empty login fields', (WidgetTester tester) async {
    await pumpAuth(tester);

    final signInButton = find.text('Sign in').last;
    await tester.ensureVisible(signInButton);
    await tester.tap(signInButton);
    await tester.pumpAndSettle();

    expect(find.text('Enter your phone number'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });
}
