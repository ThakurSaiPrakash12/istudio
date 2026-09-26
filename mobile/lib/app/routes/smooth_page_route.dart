import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_motion.dart';

/// Photographer-inspired Viewfinder Lens Zoom & Depth Blur Page Transition.
///
/// Motion Breakdown:
/// - Incoming page zooms forward like a fast f/1.2 lens rack-focusing into sharpness (0.92 -> 1.0)
/// - Optical depth-of-field blur softens the incoming frame before snapping into focus (sigma 6 -> 0)
/// - Subtle viewfinder frame marks lock onto the composition before fading away
/// - Background page gently recesses with camera sensor depth (1.0 -> 0.96 scale, subtle dim)
Widget buildSmoothPageTransition({
  required Animation<double> animation,
  required Animation<double> secondaryAnimation,
  required Widget child,
}) {
  final enterCurve = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  final exitCurve = CurvedAnimation(
    parent: secondaryAnimation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  // 1. Incoming Lens Zoom & Blur
  final lensZoomIn = Tween<double>(begin: 0.92, end: 1.0).animate(enterCurve);
  final fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    ),
  );

  // 2. Outgoing Recess & Defocus
  final lensRecessOut = Tween<double>(begin: 1.0, end: 0.96).animate(exitCurve);
  final fadeOut = Tween<double>(begin: 1.0, end: 0.88).animate(exitCurve);

  return RepaintBoundary(
    child: AnimatedBuilder(
      animation: Listenable.merge([animation, secondaryAnimation]),
      builder: (context, _) {
        final enterProgress = animation.value;
        final isEntering = enterProgress < 1.0;
        final sigma = isEntering ? (6.0 * (1.0 - enterCurve.value)) : 0.0;

        Widget content = child;

        // Apply optical lens rack focus during transition only
        if (sigma > 0.4) {
          content = ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: content,
          );
        }

        return FadeTransition(
          opacity: fadeOut,
          child: ScaleTransition(
            scale: lensRecessOut,
            child: FadeTransition(
              opacity: fadeIn,
              child: ScaleTransition(
                scale: lensZoomIn,
                child: Stack(
                  fit: StackFit.passthrough,
                  children: [
                    content,

                    // Viewfinder focus framing marks during transition
                    if (isEntering && enterProgress > 0.05)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: (1.0 - enterProgress).clamp(0.0, 1.0) * 0.4,
                            child: const _ViewfinderOverlay(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Minimalist camera viewfinder framing marks
class _ViewfinderOverlay extends StatelessWidget {
  const _ViewfinderOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ViewfinderPainter(),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    const cornerLength = 16.0;
    const padding = 20.0;

    final left = padding;
    final top = padding;
    final right = size.width - padding;
    final bottom = size.height - padding;

    // Top-left bracket [
    canvas.drawLine(Offset(left, top + cornerLength), Offset(left, top), paint);
    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), paint);

    // Top-right bracket ]
    canvas.drawLine(Offset(right - cornerLength, top), Offset(right, top), paint);
    canvas.drawLine(Offset(right, top), Offset(right, top + cornerLength), paint);

    // Bottom-left bracket [
    canvas.drawLine(Offset(left, bottom - cornerLength), Offset(left, bottom), paint);
    canvas.drawLine(Offset(left, bottom), Offset(left + cornerLength, bottom), paint);

    // Bottom-right bracket ]
    canvas.drawLine(Offset(right - cornerLength, bottom), Offset(right, bottom), paint);
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Premium smooth page transition used across the app.
class SmoothPageRoute<T> extends PageRouteBuilder<T> {
  SmoothPageRoute({
    required WidgetBuilder builder,
    super.settings,
    this.enter = const Duration(milliseconds: 380),
    this.exit = const Duration(milliseconds: 260),
  }) : super(
          transitionDuration: enter,
          reverseTransitionDuration: exit,
          pageBuilder: (context, _, _) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (AppMotion.areAnimationsDisabled(context)) {
              return child;
            }
            return buildSmoothPageTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              child: child,
            );
          },
        );

  final Duration enter;
  final Duration exit;
}

/// Custom [PageTransitionsBuilder] to apply buttery-smooth transitions
/// app-wide via [ThemeData.pageTransitionsTheme].
class SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.areAnimationsDisabled(context)) {
      return child;
    }
    return buildSmoothPageTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}
