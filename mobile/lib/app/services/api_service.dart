import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode = 0});

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  static Future<void> Function()? onUnauthorized;

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 20);

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
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
      );
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(
        http.MultipartFile.fromBytes(fieldName, bytes, filename: filename),
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
