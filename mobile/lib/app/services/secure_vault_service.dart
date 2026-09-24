import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';

/// Production-grade hardware-backed encrypted storage vault.
/// Uses Android Keystore (EncryptedSharedPreferences) and iOS Keychain.
class SecureVaultService {
  SecureVaultService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                resetOnError: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  static final SecureVaultService instance = SecureVaultService();

  final FlutterSecureStorage _storage;

  // Keys
  static const String _keyToken = 'sec_lumen_auth_token';
  static const String _keyUser = 'sec_lumen_user_profile';
  static const String _keyLogoPrefix = 'sec_lumen_logo_';

  // Legacy plaintext SharedPreferences keys for one-time seamless migration
  static const String _legacyKeyToken = 'lumen_auth_token';
  static const String _legacyKeyUser = 'lumen_cached_user';
  static const String _legacyKeyLogoPrefix = 'lumen_cached_studio_logo_';

  /// Performs a transparent one-time migration from legacy unencrypted
  /// SharedPreferences into the hardware-encrypted vault.
  Future<void> migrateLegacyStorage(SharedPreferences prefs) async {
    try {
      // 1. Migrate token
      final legacyToken = prefs.getString(_legacyKeyToken);
      if (legacyToken != null && legacyToken.isNotEmpty) {
        final existingSecToken = await readToken();
        if (existingSecToken == null || existingSecToken.isEmpty) {
          await writeToken(legacyToken);
        }
        await prefs.remove(_legacyKeyToken);
      }

      // 2. Migrate cached user
      final legacyUserJson = prefs.getString(_legacyKeyUser);
      if (legacyUserJson != null && legacyUserJson.isNotEmpty) {
        final existingSecUser = await readUser();
        if (existingSecUser == null) {
          try {
            final parsed = jsonDecode(legacyUserJson) as Map<String, dynamic>;
            await writeUser(User.fromJson(parsed));
          } catch (_) {}
        }
        await prefs.remove(_legacyKeyUser);
      }

      // 3. Migrate cached studio logos
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_legacyKeyLogoPrefix)) {
          final logoVal = prefs.getString(key);
          final idStr = key.replaceFirst(_legacyKeyLogoPrefix, '');
          if (idStr.isNotEmpty && logoVal != null && logoVal.isNotEmpty) {
            await writeStudioLogo(idStr, logoVal);
          }
          await prefs.remove(key);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SecureVault] Legacy migration notice: $e');
      }
    }
  }

  // --- Auth Token ---

  Future<void> writeToken(String token) async {
    try {
      await _storage.write(key: _keyToken, value: token);
    } catch (e) {
      if (kDebugMode) debugPrint('[SecureVault] Failed to write token: $e');
    }
  }

  Future<String?> readToken() async {
    try {
      return await _storage.read(key: _keyToken);
    } catch (e) {
      if (kDebugMode) debugPrint('[SecureVault] Failed to read token: $e');
      return null;
    }
  }

  Future<void> deleteToken() async {
    try {
      await _storage.delete(key: _keyToken);
    } catch (_) {}
  }

  // --- User Profile ---

  Future<void> writeUser(User user) async {
    try {
      final jsonStr = jsonEncode(user.toJson());
      await _storage.write(key: _keyUser, value: jsonStr);
    } catch (e) {
      if (kDebugMode) debugPrint('[SecureVault] Failed to write user: $e');
    }
  }

  Future<User?> readUser() async {
    try {
      final raw = await _storage.read(key: _keyUser);
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return User.fromJson(map);
    } catch (e) {
      if (kDebugMode) debugPrint('[SecureVault] Failed to read user: $e');
      return null;
    }
  }

  Future<void> deleteUser() async {
    try {
      await _storage.delete(key: _keyUser);
    } catch (_) {}
  }

  // --- Studio Logo ---

  Future<void> writeStudioLogo(String userId, String logoUrl) async {
    try {
      if (logoUrl.isEmpty) {
        await _storage.delete(key: '$_keyLogoPrefix$userId');
      } else {
        await _storage.write(key: '$_keyLogoPrefix$userId', value: logoUrl);
      }
    } catch (_) {}
  }

  Future<String?> readStudioLogo(String userId) async {
    try {
      return await _storage.read(key: '$_keyLogoPrefix$userId');
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteStudioLogo(String userId) async {
    try {
      await _storage.delete(key: '$_keyLogoPrefix$userId');
    } catch (_) {}
  }

  // --- Wipe Session ---

  Future<void> clearAllSessionData() async {
    try {
      await _storage.deleteAll();
    } catch (_) {
      await deleteToken();
      await deleteUser();
    }
  }
}
