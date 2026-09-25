import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/secure_vault_service.dart';
import '../utils/validators.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService, SecureVaultService? vault})
      : _authService = authService ?? AuthService(),
        _vault = vault ?? SecureVaultService.instance {
    ApiService.onUnauthorized = handleUnauthorized;
  }

  final AuthService _authService;
  final SecureVaultService _vault;

  User? _user;
  String? _token;
  String? _errorMessage;
  bool _isLoading = false;
  bool _isBootstrapping = true;

  User? get user => _user;
  String? get token => _token;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isBootstrapping => _isBootstrapping;
  bool get isLoggedIn => _user != null && _token != null;

  Future<void> bootstrap() async {
    try {
      // 1. One-time seamless migration of any existing unencrypted SharedPreferences data
      final prefs = await SharedPreferences.getInstance();
      await _vault.migrateLegacyStorage(prefs);

      // 2. Read from hardware-encrypted secure vault
      final storedToken = await _vault.readToken();
      final storedUser = await _vault.readUser();
      final tokenIsUsable = storedToken != null &&
          storedToken.isNotEmpty &&
          !_isTokenExpired(storedToken);

      // 3. Immediately restore cached session so UI doesn't flicker or wait
      if (tokenIsUsable) {
        _token = storedToken;
        _user = storedUser;

        if (_user != null && _user!.logoUrl.isEmpty) {
          final storedLogo = await _vault.readStudioLogo(_user!.id);
          if (storedLogo != null && storedLogo.isNotEmpty) {
            _user = _user!.copyWith(logoUrl: storedLogo);
          }
        }
      }

      _isBootstrapping = false;
      notifyListeners();

      // 4. Fetch fresh profile in background without logging user out if server is sleeping
      if (tokenIsUsable) {
        try {
          final freshUser = await _authService.me(storedToken);
          _user = freshUser;
          await _vault.writeUser(freshUser);
          if (freshUser.logoUrl.isNotEmpty) {
            await _vault.writeStudioLogo(freshUser.id, freshUser.logoUrl);
          }
          notifyListeners();
        } on ApiException catch (error) {
          if (error.statusCode == 401) {
            await _clearSession();
            notifyListeners();
          }
        } catch (_) {
          // Retain cached user session if offline or cold starting
        }
      }

      if (!tokenIsUsable && storedToken != null && storedToken.isNotEmpty) {
        await _clearSession();
        notifyListeners();
      }
    } catch (_) {
      _isBootstrapping = false;
      notifyListeners();
    }
  }

  Future<bool> login({required String phone, required String password}) async {
    return _runAuth(() async {
      final result = await _authService.login(
        phone: Validators.normalizePhone(phone),
        password: password,
      );
      await _persistSession(result);
    });
  }

  Future<bool> signup({
    required String username,
    required String phone,
    required String password,
  }) async {
    return _runAuth(() async {
      final result = await _authService.signup(
        username: username.trim(),
        phone: Validators.normalizePhone(phone),
        password: password,
      );
      await _persistSession(result);
    });
  }

  Future<Map<String, dynamic>> sendSignupOtp({
    required String username,
    required String phone,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final normalized = Validators.normalizePhone(phone);
      final res = await _authService.sendSignupOtp(
        username: username.trim(),
        phone: normalized,
      );
      return res;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      rethrow;
    } catch (_) {
      _errorMessage =
          'Unable to send signup verification code. Please try again.';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifySignupAndLogin({
    required String username,
    required String phone,
    required String password,
    required String otp,
  }) async {
    return _runAuth(() async {
      final result = await _authService.verifySignupAndLogin(
        username: username.trim(),
        phone: Validators.normalizePhone(phone),
        password: password,
        otp: otp.trim(),
      );
      await _persistSession(result);
    });
  }

  Future<bool> updateProfile(Map<String, dynamic> fields) async {
    if (_token == null) {
      _errorMessage = 'Please sign in before updating your profile.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _user = await _authService.updateProfile(token: _token!, fields: fields);
      if (_user != null) {
        await _vault.writeUser(_user!);
        if (fields.containsKey('logoUrl')) {
          final newLogo = fields['logoUrl'] as String? ?? '';
          await _vault.writeStudioLogo(_user!.id, newLogo);
        }
      }
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'Unable to save your profile.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setTemporaryLogoUrl(String logoUrl) {
    if (_user != null) {
      _user = _user!.copyWith(logoUrl: logoUrl);
      notifyListeners();
      final user = _user!;
      _vault.writeStudioLogo(user.id, logoUrl);
      _vault.writeUser(user);
    }
  }

  Future<bool> uploadLogo(List<int> bytes, String filename) async {
    if (_token == null) {
      _errorMessage = 'Please sign in before uploading a profile image.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final updatedUser = await _authService.uploadLogo(
        token: _token!,
        bytes: bytes,
        filename: filename,
      );
      _user = updatedUser;
      await _vault.writeUser(updatedUser);
      if (updatedUser.logoUrl.isNotEmpty) {
        await _vault.writeStudioLogo(updatedUser.id, updatedUser.logoUrl);
      }
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'Unable to upload your logo to server.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _clearSession();
    notifyListeners();
  }

  Future<void> handleUnauthorized() async {
    if (_token == null && _user == null) return;
    await _clearSession();
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>> verifyForgotPasswordUsername(String username) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final res =
          await _authService.verifyForgotPasswordUsername(username.trim());
      return res;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      rethrow;
    } catch (_) {
      _errorMessage =
          'Unable to verify username. Please check your connection.';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> sendForgotPasswordOtp(String phone) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final normalized = Validators.normalizePhone(phone);
      final res = await _authService.sendForgotPasswordOtp(normalized);
      return res;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      rethrow;
    } catch (_) {
      _errorMessage =
          'Unable to send verification code. Please check your connection.';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> verifyForgotPasswordOtp({
    required String phone,
    required String otp,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final normalized = Validators.normalizePhone(phone);
      final token = await _authService.verifyForgotPasswordOtp(
        phone: normalized,
        otp: otp.trim(),
      );
      return token;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      rethrow;
    } catch (_) {
      _errorMessage = 'Invalid or expired code. Please try again.';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resetPassword({
    String? resetToken,
    String? username,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authService.resetPassword(
        resetToken: resetToken,
        username: username,
        newPassword: newPassword,
      );
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'Unable to reset password. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyCurrentPassword(String currentPassword) async {
    if (_token == null) {
      _errorMessage = 'Please sign in to verify your password.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final ok = await _authService.verifyCurrentPassword(
        token: _token!,
        currentPassword: currentPassword,
      );
      return ok;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'Unable to verify password right now.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_token == null) {
      _errorMessage = 'Please sign in to change your password.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authService.changePassword(
        token: _token!,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'Unable to change password right now.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> _runAuth(Future<void> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _persistSession(AuthResult result) async {
    await _vault.writeToken(result.token);
    await _vault.writeUser(result.user);
    if (result.user.logoUrl.isNotEmpty) {
      await _vault.writeStudioLogo(result.user.id, result.user.logoUrl);
    }
    _token = result.token;
    _user = result.user;
  }

  Future<void> _clearSession() async {
    await _vault.clearAllSessionData();
    _token = null;
    _user = null;
  }

  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final normalized = base64Url.normalize(parts[1]);
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(normalized)))
              as Map<String, dynamic>;
      final expiresAt = (payload['exp'] as num?)?.toInt();
      return expiresAt == null ||
          expiresAt <= DateTime.now().millisecondsSinceEpoch ~/ 1000;
    } catch (_) {
      return true;
    }
  }
}
