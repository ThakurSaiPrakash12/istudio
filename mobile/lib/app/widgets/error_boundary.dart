import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/crash_reporter.dart';
import '../theme/app_colors.dart';

/// Top-level safety boundary that catches build-time exceptions
/// and displays a graceful self-healing recovery view.
class GlobalErrorBoundary extends StatefulWidget {
  const GlobalErrorBoundary({
    super.key,
    required this.child,
    this.onReset,
  });

  final Widget child;
  final VoidCallback? onReset;

  @override
  State<GlobalErrorBoundary> createState() => _GlobalErrorBoundaryState();
}

class _GlobalErrorBoundaryState extends State<GlobalErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
  }

  void _reset() {
    setState(() {
      _error = null;
      _stackTrace = null;
    });
    widget.onReset?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return StudioErrorRecoveryView(
        error: _error!,
        stackTrace: _stackTrace,
        onRetry: _reset,
      );
    }

    return _ErrorCatcher(
      onError: (error, stackTrace) {
        CrashReporter.instance.recordError(
          error,
          stackTrace,
          reason: 'GlobalErrorBoundary intercepted build error',
        );
        setState(() {
          _error = error;
          _stackTrace = stackTrace;
        });
      },
      child: widget.child,
    );
  }
}

class _ErrorCatcher extends StatelessWidget {
  const _ErrorCatcher({
    required this.child,
    required this.onError,
  });

  final Widget child;
  final void Function(Object error, StackTrace? stackTrace) onError;

  @override
  Widget build(BuildContext context) {
    try {
      return child;
    } catch (e, stack) {
      onError(e, stack);
      return const SizedBox.shrink();
    }
  }
}

/// A premium, reassuring recovery view shown whenever a component fails to render.
class StudioErrorRecoveryView extends StatelessWidget {
  const StudioErrorRecoveryView({
    super.key,
    required this.error,
    this.stackTrace,
    this.onRetry,
    this.onReturnHome,
  });

  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;
  final VoidCallback? onReturnHome;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ink,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppColors.sky.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.sky.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_fix_high_rounded,
                    color: AppColors.sky,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Safe Recovery Activated',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'A temporary screen glitch was isolated to keep your data safe and prevent the app from closing.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (onRetry != null) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text(
                          'Try Again',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sky,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        if (onReturnHome != null) {
                          onReturnHome!();
                        } else {
                          final nav = Navigator.maybeOf(context);
                          if (nav != null && nav.canPop()) {
                            nav.popUntil((route) => route.isFirst);
                          }
                          onRetry?.call();
                        }
                      },
                      icon: const Icon(Icons.home_rounded, size: 16),
                      label: const Text(
                        'Return to Home',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Debug Info:\n$error\n\n$stackTrace',
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
