class ApiConfig {
  const ApiConfig._();

  /// Deployed backend origin. Edit this when the host changes.
  /// Trailing slashes and `/api` are stripped automatically.
  static const String backendUrl = 'https://istudio-1-txuo.onrender.com';

  /// Optional local override:
  /// `flutter run --dart-define=API_BASE_URL=http://192.168.1.9:5000/api`
  static const String _override = String.fromEnvironment('API_BASE_URL');

  static String _strip(String value) {
    var url = value.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.endsWith('/api')) {
      url = url.substring(0, url.length - 4);
      while (url.endsWith('/')) {
        url = url.substring(0, url.length - 1);
      }
    }
    return url;
  }

  static String get origin =>
      _strip(_override.isNotEmpty ? _override : backendUrl);

  static String get baseUrl => '$origin/api';

  static String resolveMedia(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    var p = path.trim();

    // Convert HTTP to HTTPS for remote URLs to avoid cleartext HTTP blocks on Android/iOS
    if (p.startsWith('http://') && !p.contains('localhost') && !p.contains('127.0.0.1') && !p.contains('192.168.')) {
      p = 'https://${p.substring(7)}';
    }

    if (p.startsWith('http://') ||
        p.startsWith('https://') ||
        p.startsWith('data:image/') ||
        p.startsWith('file://') ||
        p.startsWith('content://')) {
      return p;
    }
    if (!p.startsWith('/')) {
      return '$origin/$p';
    }
    return '$origin$p';
  }
}
