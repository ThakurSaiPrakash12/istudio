import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:http_parser/http_parser.dart';

import 'api_config.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode = 0});

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

MediaType _resolveImageMediaType(String filename, List<int> bytes) {
  // Check magic bytes first
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return MediaType('image', 'jpeg');
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return MediaType('image', 'png');
  }
  if (bytes.length >= 6 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x38) {
    return MediaType('image', 'gif');
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return MediaType('image', 'webp');
  }

  // Fall back to filename extension
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) {
    return MediaType('image', 'png');
  }
  if (lower.endsWith('.webp')) {
    return MediaType('image', 'webp');
  }
  if (lower.endsWith('.gif')) {
    return MediaType('image', 'gif');
  }
  return MediaType('image', 'jpeg');
}

String _sanitizeFilename(String filename, MediaType mediaType) {
  final cleanName = filename.trim().isEmpty ? 'proof' : filename.trim();
  final lower = cleanName.toLowerCase();
  if (lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.gif')) {
    return cleanName;
  }
  final ext = mediaType.subtype == 'jpeg' ? 'jpg' : mediaType.subtype;
  return '$cleanName.$ext';
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  static Future<void> Function()? onUnauthorized;

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 45);

  Map<String, String> _headers({String? token}) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    String? token,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}$endpoint'),
            headers: {
              ..._headers(token: token),
              if (idempotencyKey != null && idempotencyKey.isNotEmpty)
                'Idempotency-Key': idempotencyKey,
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      return _decode(response, token: token);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('The studio is taking too long to respond.');
    } catch (_) {
      throw const ApiException(
        'Unable to reach the studio. Check your connection.',
      );
    }
  }

  Future<Map<String, dynamic>> patch(
    String endpoint,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    try {
      final response = await _client
          .patch(
            Uri.parse('${ApiConfig.baseUrl}$endpoint'),
            headers: _headers(token: token),
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      return _decode(response, token: token);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('The studio is taking too long to respond.');
    } catch (_) {
      throw const ApiException(
        'Unable to reach the studio. Check your connection.',
      );
    }
  }

  Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    try {
      final response = await _client
          .put(
            Uri.parse('${ApiConfig.baseUrl}$endpoint'),
            headers: _headers(token: token),
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      return _decode(response, token: token);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('The studio is taking too long to respond.');
    } catch (_) {
      throw const ApiException(
        'Unable to reach the studio. Check your connection.',
      );
    }
  }

  Future<Map<String, dynamic>> postMultipart(
    String endpoint, {
    required String fieldName,
    required List<int> bytes,
    required String filename,
    String? token,
    MediaType? contentType,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
      );
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      final resolvedContentType =
          contentType ?? _resolveImageMediaType(filename, bytes);
      final resolvedFilename =
          _sanitizeFilename(filename, resolvedContentType);

      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          bytes,
          filename: resolvedFilename,
          contentType: resolvedContentType,
        ),
      );
      final streamed = await _client.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      return _decode(response, token: token);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('The studio is taking too long to respond.');
    } catch (_) {
      throw const ApiException(
        'Unable to reach the studio. Check your connection.',
      );
    }
  }

  Future<Map<String, dynamic>> get(String endpoint, {String? token}) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}$endpoint'),
            headers: _headers(token: token),
          )
          .timeout(_timeout);
      return _decode(response, token: token);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('The studio is taking too long to respond.');
    } catch (_) {
      throw const ApiException(
        'Unable to reach the studio. Check your connection.',
      );
    }
  }

  Future<Map<String, dynamic>> delete(String endpoint, {String? token}) async {
    try {
      final response = await _client
          .delete(
            Uri.parse('${ApiConfig.baseUrl}$endpoint'),
            headers: _headers(token: token),
          )
          .timeout(_timeout);
      return _decode(response, token: token);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('The studio is taking too long to respond.');
    } catch (_) {
      throw const ApiException(
        'Unable to reach the studio. Check your connection.',
      );
    }
  }

  Map<String, dynamic> _decode(http.Response response, {String? token}) {
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        'Unexpected response from the studio.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode == 401 && token != null && token.isNotEmpty) {
      onUnauthorized?.call();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return payload;
    }

    throw ApiException(
      payload['message'] as String? ?? 'Something went wrong.',
      statusCode: response.statusCode,
    );
  }
}
