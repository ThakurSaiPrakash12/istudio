class ApiConfig {
  const ApiConfig._();

  /// Backend URL injected at build time via --dart-define-from-file=.env
  /// Run with: flutter run --dart-define-from-file=.env
  /// Never hardcode this value — keep it in mobile/.env (git-ignored).
  static const String _backendUrl = String.fromEnvironment('API_BASE_URL');

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

  static String get origin {
    assert(
      _backendUrl.isNotEmpty,
      'API_BASE_URL is not set. Run with: flutter run --dart-define-from-file=.env',
    );
    return _strip(_backendUrl);
  }

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
