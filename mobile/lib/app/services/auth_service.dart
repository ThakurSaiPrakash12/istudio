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

  Future<Map<String, dynamic>> checkUsername(String username) async {
    final payload = await _api.get('/auth/check-username?username=${Uri.encodeComponent(username.trim())}');
    return payload;
  }

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

  Future<Map<String, dynamic>> sendSignupEmailOtp({
    required String username,
    required String email,
  }) async {
    final payload = await _api.post('/auth/signup/send-email-otp', {
      'username': username.trim(),
      'email': email.trim().toLowerCase(),
    });
    return payload;
  }

  Future<AuthResult> verifySignupEmailAndLogin({
    required String username,
    required String email,
    required String password,
    required String otp,
    String? phone,
  }) async {
    final body = <String, dynamic>{
      'username': username.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
      'otp': otp.trim(),
    };
    if (phone != null && phone.trim().isNotEmpty) {
      body['phone'] = phone.trim();
    }
    final payload = await _api.post('/auth/signup/verify-email', body);
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
    required String identifier,
    required String password,
  }) async {
    final payload = await _api.post('/auth/login', {
      'identifier': identifier.trim(),
      'password': password,
    });
    return _parseAuth(payload);
  }

  Future<User> setPassword({
    required String token,
    required String newPassword,
  }) async {
    final payload = await _api.post(
      '/auth/set-password',
      {'newPassword': newPassword},
      token: token,
    );
    return _parseUser(payload);
  }

  Future<AuthResult> loginWithGoogle({
    required String idToken,
    String? accessToken,
  }) async {
    final body = <String, dynamic>{
      'idToken': idToken,
    };
    if (accessToken != null) {
      body['accessToken'] = accessToken;
    }
    final payload = await _api.post('/auth/google', body);
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

  Future<User> uploadPaymentQr({
    required String token,
    required List<int> bytes,
    required String filename,
  }) async {
    final payload = await _api.postMultipart(
      '/auth/payment-qr',
      fieldName: 'logo',
      bytes: bytes,
      filename: filename,
      token: token,
    );
    return _parseUser(payload);
  }

  Future<Map<String, dynamic>> verifyForgotPasswordUsername(String username) async {
    final payload = await _api.post('/auth/forgot-password/verify-username', {
      'username': username.trim(),
    });
    return payload;
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
    String? resetToken,
    String? username,
    required String newPassword,
  }) async {
    final body = <String, dynamic>{
      'newPassword': newPassword,
    };
    if (resetToken != null && resetToken.isNotEmpty) {
      body['resetToken'] = resetToken;
    }
    if (username != null && username.isNotEmpty) {
      body['username'] = username.trim();
    }
    await _api.post('/auth/forgot-password/reset', body);
  }

  Future<bool> verifyCurrentPassword({
    required String token,
    required String currentPassword,
  }) async {
    final payload = await _api.post(
      '/auth/verify-password',
      {'currentPassword': currentPassword},
      token: token,
    );
    return payload['success'] == true;
  }

  Future<void> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.post(
      '/auth/change-password',
      {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
      token: token,
    );
  }

  Future<Map<String, dynamic>> sendDeleteAccountOtp({required String token}) async {
    return _api.post('/auth/delete-account/send-otp', {}, token: token);
  }

  Future<Map<String, dynamic>> verifyDeleteAccountOtp({
    required String token,
    required String otp,
  }) async {
    return _api.post(
      '/auth/delete-account/verify-otp',
      {'otp': otp},
      token: token,
    );
  }

  Future<void> deleteAccount({
    required String token,
    String? otp,
    String? deleteToken,
    required String password,
  }) async {
    await _api.post(
      '/auth/delete-account/confirm',
      {
        if (otp != null && otp.isNotEmpty) 'otp': otp,
        if (deleteToken != null && deleteToken.isNotEmpty) 'deleteToken': deleteToken,
        'password': password,
      },
      token: token,
    );
  }

  Future<Map<String, dynamic>> sendEmailChangeOtp({
    required String token,
    required String newEmail,
  }) async {
    return _api.post(
      '/auth/send-email-change-otp',
      {'newEmail': newEmail.trim().toLowerCase()},
      token: token,
    );
  }

  Future<User> verifyEmailChange({
    required String token,
    required String newEmail,
    required String otp,
  }) async {
    final payload = await _api.post(
      '/auth/verify-email-change',
      {
        'newEmail': newEmail.trim().toLowerCase(),
        'otp': otp.trim(),
      },
      token: token,
    );
    return _parseUser(payload);
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
