import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleAuthResult {
  const AppleAuthResult({
    required this.identityToken,
    required this.userIdentifier,
    this.email,
    this.givenName,
    this.familyName,
    this.authorizationCode,
  });

  final String identityToken;
  final String userIdentifier;
  final String? email;
  final String? givenName;
  final String? familyName;
  final String? authorizationCode;

  String? get fullName {
    final parts = [givenName, familyName]
        .where((s) => s != null && s.trim().isNotEmpty)
        .map((s) => s!.trim());
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }
}

class AppleAuthException implements Exception {
  const AppleAuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AppleAuthService {
  Future<bool> isAvailable() async {
    try {
      return await SignInWithApple.isAvailable();
    } catch (_) {
      return false;
    }
  }

  Future<AppleAuthResult?> signIn() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final userIdentifier = credential.userIdentifier;
      if (userIdentifier == null || userIdentifier.isEmpty) {
        throw const AppleAuthException(
          'Apple sign-in completed, but no user identifier was received.',
        );
      }

      return AppleAuthResult(
        identityToken: credential.identityToken ?? '',
        userIdentifier: userIdentifier,
        email: credential.email,
        givenName: credential.givenName,
        familyName: credential.familyName,
        authorizationCode: credential.authorizationCode,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return null;
      }
      throw AppleAuthException(e.message);
    } catch (e) {
      throw AppleAuthException('Apple sign-in failed: $e');
    }
  }
}

