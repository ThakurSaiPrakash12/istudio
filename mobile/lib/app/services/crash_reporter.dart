import 'dart:collection';
import 'package:flutter/foundation.dart';

class Breadcrumb {
  Breadcrumb({
    required this.message,
    this.category,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final String message;
  final String? category;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  Map<String, dynamic> toMap() => {
        'timestamp': timestamp.toIso8601String(),
        'message': message,
        if (category != null) 'category': category,
        if (data != null) 'data': data,
      };

  @override
  String toString() => '[${timestamp.toIso8601String()}][$category] $message';
}

class CrashReport {
  CrashReport({
    required this.error,
    required this.stackTrace,
    this.reason,
    this.fatal = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final String error;
  final String stackTrace;
  final String? reason;
  final bool fatal;
  final DateTime timestamp;
}

/// Central crash resilience, breadcrumb tracking, and error telemetry service.
class CrashReporter {
  CrashReporter._();
  static final CrashReporter instance = CrashReporter._();

  static const int _maxBreadcrumbs = 60;
  static const int _maxReports = 20;

  final Queue<Breadcrumb> _breadcrumbs = Queue<Breadcrumb>();
  final List<CrashReport> _reports = <CrashReport>[];

  List<Breadcrumb> get breadcrumbs => List.unmodifiable(_breadcrumbs);
  List<CrashReport> get reports => List.unmodifiable(_reports);

  /// Records a chronological user or system action (navigation, clicks, network status)
  void addBreadcrumb(
    String message, {
    String? category,
    Map<String, dynamic>? data,
  }) {
    final sanitizedMessage = _sanitize(message);
    final sanitizedData = data?.map((k, v) => MapEntry(k, _sanitize(v.toString())));

    final crumb = Breadcrumb(
      message: sanitizedMessage,
      category: category ?? 'app',
      data: sanitizedData,
    );

    if (_breadcrumbs.length >= _maxBreadcrumbs) {
      _breadcrumbs.removeFirst();
    }
    _breadcrumbs.add(crumb);

    if (kDebugMode) {
      debugPrint('[Breadcrumb] ${crumb.toString()}');
    }
  }

  /// Handles UI framework layout & build errors from FlutterError.onError
  void recordFlutterError(FlutterErrorDetails details) {
    final errorStr = details.exceptionAsString();
    final stackStr = details.stack?.toString() ?? '';

    _storeReport(
      error: errorStr,
      stack: stackStr,
      reason: details.context?.toString() ?? 'Flutter framework error',
      fatal: false,
    );

    if (kDebugMode) {
      FlutterError.presentError(details);
    } else {
      debugPrint('[CrashReporter] FlutterError: $errorStr');
    }
  }

  /// Handles asynchronous Dart runtime errors (futures, streams, microtasks)
  void recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) {
    final errorStr = error.toString();
    final stackStr = stack?.toString() ?? '';

    _storeReport(
      error: errorStr,
      stack: stackStr,
      reason: reason ?? 'Uncaught asynchronous exception',
      fatal: fatal,
    );

    if (kDebugMode) {
      debugPrint('[CrashReporter] AsyncError caught: $errorStr\n$stackStr');
    }
  }

  void _storeReport({
    required String error,
    required String stack,
    String? reason,
    bool fatal = false,
  }) {
    final report = CrashReport(
      error: _sanitize(error),
      stackTrace: stack,
      reason: reason,
      fatal: fatal,
    );

    if (_reports.length >= _maxReports) {
      _reports.removeAt(0);
    }
    _reports.add(report);
  }

  /// Removes any potential tokens, passwords, or PII before saving or transmitting
  String _sanitize(String input) {
    return input
        .replaceAll(RegExp(r'Bearer\s+[A-Za-z0-9-_=.]+'), 'Bearer [REDACTED]')
        .replaceAll(RegExp(r'password["\s:=]+[^,\s}]+', caseSensitive: false), 'password: [REDACTED]')
        .replaceAll(RegExp(r'\b\d{10}\b'), '[PHONE_REDACTED]');
  }
}
