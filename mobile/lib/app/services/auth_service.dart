import '../models/user.dart';
import 'api_service.dart';

class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final User user;
}

class AuthService {
  AuthService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  Future<AuthResult> signup({
    required String username,
    required String phone,
    required String password,
  }) async {
    final payload = await _api.post('/auth/signup', {
      'username': username.trim(),
      'phone': phone,
      'password': password,
    });
    return _parseAuth(payload);
  }

  Future<Map<String, dynamic>> sendSignupOtp({
    required String username,
    required String phone,
  }) async {
    final payload = await _api.post('/auth/signup/send-otp', {
      'username': username.trim(),
      'phone': phone,
    });
    return payload;
  }

  Future<AuthResult> verifySignupAndLogin({
    required String username,
    required String phone,
    required String password,
    required String otp,
  }) async {
    final payload = await _api.post('/auth/signup/verify', {
      'username': username.trim(),
      'phone': phone,
      'password': password,
      'otp': otp.trim(),
    });
    return _parseAuth(payload);
  }

  Future<AuthResult> login({
    required String phone,
    required String password,
  }) async {
    final payload = await _api.post('/auth/login', {
      'phone': phone,
      'password': password,
    });
    return _parseAuth(payload);
  }

  Future<User> me(String token) async {
    final payload = await _api.get('/auth/me', token: token);
    return _parseUser(payload);
  }

  Future<User> updateProfile({
    required String token,
    required Map<String, dynamic> fields,
  }) async {
    final payload = await _api.patch('/auth/profile', fields, token: token);
    return _parseUser(payload);
  }

  Future<User> uploadLogo({
    required String token,
    required List<int> bytes,
    required String filename,
  }) async {
    final payload = await _api.postMultipart(
      '/auth/logo',
      fieldName: 'logo',
      bytes: bytes,
      filename: filename,
      token: token,
    );
    return _parseUser(payload);
  }

  Future<Map<String, dynamic>> sendForgotPasswordOtp(String phone) async {
    final payload = await _api.post('/auth/forgot-password/send-otp', {
      'phone': phone,
    });
    return payload;
  }

  Future<String> verifyForgotPasswordOtp({
    required String phone,
    required String otp,
  }) async {
    final payload = await _api.post('/auth/forgot-password/verify-otp', {
      'phone': phone,
      'otp': otp,
    });
    final resetToken = payload['resetToken'] as String?;
    if (resetToken == null || resetToken.isEmpty) {
      throw const ApiException('Invalid reset verification response.');
    }
    return resetToken;
  }

  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    await _api.post('/auth/forgot-password/reset', {
      'resetToken': resetToken,
      'newPassword': newPassword,
    });
  }

  User _parseUser(Map<String, dynamic> payload) {
    final userJson = payload['user'] as Map<String, dynamic>?;
    if (userJson == null) {
      throw const ApiException('Profile could not be loaded.');
    }
    return User.fromJson(userJson);
  }

  AuthResult _parseAuth(Map<String, dynamic> payload) {
    final token = payload['token'] as String?;
    final userJson = payload['user'] as Map<String, dynamic>?;
    if (token == null || userJson == null) {
      throw const ApiException('Invalid authentication response.');
    }
    return AuthResult(token: token, user: User.fromJson(userJson));
  }
}
