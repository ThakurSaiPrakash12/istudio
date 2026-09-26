import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_studio/app/models/user.dart';
import 'package:lumen_studio/app/providers/auth_provider.dart';
import 'package:lumen_studio/app/services/auth_service.dart';
import 'package:lumen_studio/app/services/google_auth_service.dart';
import 'package:lumen_studio/app/widgets/google_sign_in_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeGoogleAuthService extends Fake implements GoogleAuthService {
  GoogleAuthResult? mockResult;
  bool shouldThrow = false;

  @override
  Future<GoogleAuthResult?> signIn() async {
    if (shouldThrow) throw Exception('Google Sign-In failed');
    return mockResult;
  }
}

class _FakeAuthService extends Fake implements AuthService {
  AuthResult? mockAuthResult;

  @override
  Future<AuthResult> loginWithGoogle({
    required String idToken,
    String? accessToken,
  }) async {
    if (mockAuthResult != null) return mockAuthResult!;
    throw Exception('Login failed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('Google Auth User Model Tests', () {
    test('User serializes and deserializes googleId correctly', () {
      const user = User(
        id: 'usr_123',
        username: 'john_doe',
        phone: '9876543210',
        email: 'john@example.com',
        googleId: 'google_sub_9999',
      );

      final json = user.toJson();
      expect(json['googleId'], 'google_sub_9999');

      final deserialized = User.fromJson(json);
      expect(deserialized.id, 'usr_123');
      expect(deserialized.email, 'john@example.com');
      expect(deserialized.googleId, 'google_sub_9999');

      final copied = deserialized.copyWith(googleId: 'new_google_id');
      expect(copied.googleId, 'new_google_id');
      expect(copied.username, 'john_doe');
    });
  });

  group('GoogleSignInButton Widget Tests', () {
    testWidgets('Renders GoogleSignInButton with vector logo and label', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GoogleSignInButton(
                label: 'Sign in with Google',
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.byType(GoogleLogo), findsOneWidget);

      await tester.tap(find.byType(GoogleSignInButton));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('Shows loading indicator when isLoading is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GoogleSignInButton(
                isLoading: true,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing);
    });
  });

  group('AuthProvider Google Auth Integration Tests', () {
    late _FakeGoogleAuthService fakeGoogleAuth;
    late _FakeAuthService fakeAuthService;
    late AuthProvider authProvider;

    setUp(() {
      fakeGoogleAuth = _FakeGoogleAuthService();
      fakeAuthService = _FakeAuthService();
      authProvider = AuthProvider(
        authService: fakeAuthService,
        googleAuthService: fakeGoogleAuth,
      );
    });

    test('Gracefully handles user cancellation without error message', () async {
      fakeGoogleAuth.mockResult = null; // User cancelled prompt

      final success = await authProvider.signInWithGoogle();
      expect(success, isFalse);
      expect(authProvider.errorMessage, isNull);
      expect(authProvider.isLoggedIn, isFalse);
    });

    test('Completes login and saves JWT when Google authentication succeeds', () async {
      fakeGoogleAuth.mockResult = const GoogleAuthResult(
        idToken: 'mock_valid_id_token',
        accessToken: 'mock_access_token',
        email: 'photographer@studio.com',
        displayName: 'Studio Photographer',
      );

      const expectedUser = User(
        id: 'usr_g_456',
        username: 'Studio Photographer',
        phone: '',
        email: 'photographer@studio.com',
        googleId: 'google_sub_123',
      );

      fakeAuthService.mockAuthResult = const AuthResult(
        token: 'jwt_mock_token_abc123',
        user: expectedUser,
      );

      final success = await authProvider.signInWithGoogle();
      expect(success, isTrue);
      expect(authProvider.isLoggedIn, isTrue);
      expect(authProvider.user?.email, 'photographer@studio.com');
      expect(authProvider.token, 'jwt_mock_token_abc123');
      expect(authProvider.errorMessage, isNull);
    });
  });
}
