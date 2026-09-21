import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService() {
    ApiService.onUnauthorized = handleUnauthorized;
  }

  static const _tokenKey = 'lumen_auth_token';
  static const _userKey = 'lumen_cached_user';
  static const _logoKeyPrefix = 'lumen_cached_studio_logo_';

  final AuthService _authService;
  static const _secureStorage = FlutterSecureStorage();

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
      final prefs = await SharedPreferences.getInstance();
      final storedToken = await _readToken(prefs);
      final storedUserJson = prefs.getString(_userKey);
      final tokenIsUsable =
          storedToken != null &&
          storedToken.isNotEmpty &&
          !_isTokenExpired(storedToken);

      // 1. Immediately restore cached session and logo so UI doesn't flicker or wait for cold start
      if (tokenIsUsable) {
        _token = storedToken;
        if (storedUserJson != null && storedUserJson.isNotEmpty) {
          try {
            _user = User.fromJson(
              jsonDecode(storedUserJson) as Map<String, dynamic>,
            );
          } catch (_) {}
        }
        final storedLogo = _user == null
            ? null
            : prefs.getString('$_logoKeyPrefix${_user!.id}');
        if (_user != null &&
            _user!.logoUrl.isEmpty &&
            storedLogo != null &&
            storedLogo.isNotEmpty) {
          _user = _user!.copyWith(logoUrl: storedLogo);
        }
      }

      _isBootstrapping = false;
      notifyListeners();

      // 2. Fetch fresh profile in background without logging user out if server is sleeping
      if (tokenIsUsable) {
        try {
          final user = await _authService.me(storedToken);
          _user = user;
          await prefs.setString(_userKey, jsonEncode(user.toJson()));
          await _persistLogo(prefs, user);
          notifyListeners();
        } on ApiException catch (error) {
          if (error.statusCode == 401) {
            await _clearSession();
            notifyListeners();
          }
          // If server is sleeping or network error, retain cached user session!
        } catch (_) {
          // Server sleeping / cold start - retain cached user session
        }
      }
      if (!tokenIsUsable && storedToken != null && storedToken.isNotEmpty) {
        await _clearSession();
        notifyListeners();
      }
    } catch (_) {
      // SharedPreferences error fallback
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
      final prefs = await SharedPreferences.getInstance();
      if (_user != null) {
        await prefs.setString(_userKey, jsonEncode(_user!.toJson()));
        if (fields.containsKey('logoUrl')) {
          final newLogo = fields['logoUrl'] as String? ?? '';
          if (newLogo.isEmpty) {
            await prefs.remove('$_logoKeyPrefix${_user!.id}');
          } else {
            await prefs.setString('$_logoKeyPrefix${_user!.id}', newLogo);
          }
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
      SharedPreferences.getInstance().then((prefs) async {
        await _persistLogo(prefs, user);
        await prefs.setString(_userKey, jsonEncode(user.toJson()));
      });
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(updatedUser.toJson()));
      await _persistLogo(prefs, updatedUser);
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
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.write(key: _tokenKey, value: result.token);
    await prefs.remove(_tokenKey);
    await prefs.setString(_userKey, jsonEncode(result.user.toJson()));
    await _persistLogo(prefs, result.user);
    _token = result.token;
    _user = result.user;
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.delete(key: _tokenKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    _token = null;
    _user = null;
  }

  Future<String?> _readToken(SharedPreferences prefs) async {
    try {
      final token = await _secureStorage
          .read(key: _tokenKey)
          .timeout(const Duration(milliseconds: 250));
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {
      // Platform secure storage may be unavailable in desktop/test environments.
    }
    final legacyToken = prefs.getString(_tokenKey);
    if (legacyToken != null && legacyToken.isNotEmpty) {
      try {
        await _secureStorage.write(key: _tokenKey, value: legacyToken);
        await prefs.remove(_tokenKey);
      } catch (_) {}
    }
    return legacyToken;
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

  Future<void> _persistLogo(SharedPreferences prefs, User user) async {
    final key = '$_logoKeyPrefix${user.id}';
    if (user.logoUrl.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, user.logoUrl);
    }
  }
}
