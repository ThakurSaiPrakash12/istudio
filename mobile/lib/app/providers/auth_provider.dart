import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService();

  static const _tokenKey = 'lumen_auth_token';

  final AuthService _authService;

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
      final storedToken = prefs.getString(_tokenKey);
      if (storedToken == null || storedToken.isEmpty) {
        return;
      }
      final user = await _authService.me(storedToken);
      _token = storedToken;
      _user = user;
    } catch (_) {
      await _clearSession();
    } finally {
      _isBootstrapping = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String phone,
    required String password,
  }) async {
    return _runAuth(() async {
      final result = await _authService.login(
        phone: Validators.normalizePhone(phone),
        password: password,
      );
      await _persistSession(result);
    });
  }

  void loginDemo() {
    _token = 'lumen-studio-demo-token';
    _user = const User(
      id: 'usr-demo-01',
      username: 'alex',
      phone: '+91 98765 43210',
      ownerName: 'Alex Mercer',
      studioName: 'Lumen Art Studio',
      email: 'alex@lumenstudio.art',
      city: 'Indiranagar, Bengaluru',
      address: 'Studio Loft 4B, 100ft Road',
      about: 'Editorial, Fashion & Fine Art Wedding Photography.',
      specialties: 'Weddings · Maternity · Commercial',
      instagram: '@lumenstudio.art',
      website: 'lumenstudio.art',
    );
    notifyListeners();
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
    if (_token == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _user = await _authService.updateProfile(token: _token!, fields: fields);
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
    }
  }

  Future<bool> uploadLogo(List<int> bytes, String filename) async {
    if (_token == null) {
      notifyListeners();
      return true;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _user = await _authService.uploadLogo(
        token: _token!,
        bytes: bytes,
        filename: filename,
      );
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
    await prefs.setString(_tokenKey, result.token);
    _token = result.token;
    _user = result.user;
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    _token = null;
    _user = null;
  }
}
