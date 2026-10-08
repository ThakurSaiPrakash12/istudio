import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';

enum SnackType { success, error, info }

class AppSnackBar {
  const AppSnackBar._();

  static const Color _successColor = Color(0xFF16A34A);
  static const Color _errorColor = Color(0xFFDC2626);
  static const Color _infoColor = Color(0xFF334155);

  static const Duration _defaultDuration = Duration(seconds: 10);

  static OverlayEntry? _overlayEntry;
  static Timer? _overlayTimer;

  static void success(
    BuildContext context,
    String message, {
    Duration duration = _defaultDuration,
  }) => show(context, message, type: SnackType.success, duration: duration);

  static void error(
    BuildContext context,
    String message, {
    Duration duration = _defaultDuration,
  }) => show(context, message, type: SnackType.error, duration: duration);

  static void info(
    BuildContext context,
    String message, {
    Duration duration = _defaultDuration,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
  }) => show(
    context,
    message,
    type: SnackType.info,
    duration: duration,
    icon: icon,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  /// Awaits [future], then shows [success] (if given) or a red snackbar with
  /// the API error message, falling back to [error].
  static Future<bool> guard(
    BuildContext context,
    Future<Object?> future, {
    String? success,
    required String error,
  }) async {
    try {
      await future;
      if (success != null && context.mounted) {
        AppSnackBar.success(context, success);
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.error(context, e is ApiException ? e.message : error);
      }
      return false;
    }
  }

  static void show(
    BuildContext context,
    String message, {
    SnackType type = SnackType.info,
    Duration duration = _defaultDuration,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (!context.mounted) return;

    final (Color bg, IconData defaultIcon) = switch (type) {
      SnackType.success => (_successColor, Icons.check_circle_rounded),
      SnackType.error => (_errorColor, Icons.error_rounded),
      SnackType.info => (_infoColor, Icons.info_rounded),
    };
    final content = _SnackContent(message: message, icon: icon ?? defaultIcon);

    // A SnackBar renders on the page Scaffold, which is hidden behind
    // bottom sheets and dialogs, so popups get an overlay toast instead.
    if (ModalRoute.of(context) is PopupRoute) {
      _showOverlay(context, content, bg, duration);
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      _showOverlay(context, content, bg, duration);
      return;
    }

    _removeOverlay();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: bg,
          duration: duration,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: content,
          action: actionLabel != null && onAction != null
              ? SnackBarAction(
                  label: actionLabel,
                  textColor: Colors.amberAccent,
                  onPressed: onAction,
                )
              : type == SnackType.error
              ? SnackBarAction(
                  label: 'Dismiss',
                  textColor: Colors.white,
                  onPressed: () {},
                )
              : null,
        ),
      );
  }

  static void _showOverlay(
    BuildContext context,
    Widget content,
    Color bg,
    Duration? duration,
  ) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _removeOverlay();
    final entry = OverlayEntry(
      builder: (ctx) => _OverlayToast(
        background: bg,
        onDismiss: _removeOverlay,
        child: content,
      ),
    );
    _overlayEntry = entry;
    overlay.insert(entry);
    _overlayTimer = Timer(duration ?? _defaultDuration, _removeOverlay);
  }

  static void _removeOverlay() {
    _overlayTimer?.cancel();
    _overlayTimer = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _SnackContent extends StatelessWidget {
  const _SnackContent({required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _OverlayToast extends StatelessWidget {
  const _OverlayToast({
    required this.background,
    required this.onDismiss,
    required this.child,
  });

  final Color background;
  final VoidCallback onDismiss;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + 12;
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, -20 * (1 - t)),
            child: child,
          ),
        ),
        child: Material(
          color: background,
          elevation: 6,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onDismiss,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
