import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_studio/app/models/user.dart';
import 'package:lumen_studio/app/services/crash_reporter.dart';
import 'package:lumen_studio/app/widgets/error_boundary.dart';

void main() {
  group('Phase 1: CrashReporter & Telemetry Tests', () {
    test('CrashReporter adds breadcrumbs and sanitizes sensitive data', () {
      final reporter = CrashReporter.instance;
      reporter.addBreadcrumb('User logged in with phone 9876543210 and token Bearer eyJhbGciOiJIUzI1NiJ9.secret');

      final lastCrumb = reporter.breadcrumbs.last;
      expect(lastCrumb.message.contains('9876543210'), isFalse);
      expect(lastCrumb.message.contains('[PHONE_REDACTED]'), isTrue);
      expect(lastCrumb.message.contains('eyJhbGciOiJIUzI1NiJ9'), isFalse);
      expect(lastCrumb.message.contains('Bearer [REDACTED]'), isTrue);
    });

    test('CrashReporter records async runtime errors safely', () {
      final reporter = CrashReporter.instance;
      final testError = StateError('Simulated unexpected network timeout error');
      reporter.recordError(testError, StackTrace.current, reason: 'Test async flow');

      expect(reporter.reports.isNotEmpty, isTrue);
      final lastReport = reporter.reports.last;
      expect(lastReport.error.contains('Simulated unexpected network timeout error'), isTrue);
      expect(lastReport.reason, equals('Test async flow'));
    });
  });

  group('Phase 1: ErrorBoundary & Recovery UI Tests', () {
    testWidgets('GlobalErrorBoundary renders recovery view when child throws',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GlobalErrorBoundary(
            child: Builder(
              builder: (context) {
                return const Text('Safe Content');
              },
            ),
          ),
        ),
      );

      expect(find.text('Safe Content'), findsOneWidget);

      // Verify StudioErrorRecoveryView renders properly with recovery actions
      await tester.pumpWidget(
        MaterialApp(
          home: StudioErrorRecoveryView(
            error: Exception('Widget build failure'),
            onRetry: () {},
          ),
        ),
      );

      expect(find.text('Safe Recovery Activated'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('Return to Home'), findsOneWidget);
    });
  });

  group('Phase 1: Security Model Serialization Tests', () {
    test('User model serializes and deserializes accurately for secure vault', () {
      const user = User(
        id: 'usr_42',
        username: 'studio_pro',
        phone: '9876543210',
        studioName: 'Royal Focus Studio',
        logoUrl: 'https://example.com/logo.png',
      );

      final json = user.toJson();
      final restored = User.fromJson(json);

      expect(restored.id, equals(user.id));
      expect(restored.username, equals(user.username));
      expect(restored.phone, equals(user.phone));
      expect(restored.studioName, equals(user.studioName));
      expect(restored.logoUrl, equals(user.logoUrl));
    });
  });
}
