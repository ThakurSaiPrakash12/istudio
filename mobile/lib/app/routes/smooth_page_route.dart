import 'package:flutter/material.dart';

/// Ultra-smooth cubic easing curve (iOS / Blinkit / Swiggy standard).
const Curve kSmoothEaseOut = Cubic(0.16, 1.0, 0.3, 1.0);
const Curve kSmoothEaseIn = Curves.easeInCubic;

/// Builds the premium page transition used throughout iStudio:
/// - Incoming page: gentle horizontal slide from right (6% offset) + smooth opacity fade
/// - Background page: subtle parallax shift left (-3% offset) + slight scale (0.98)
Widget buildSmoothPageTransition({
  required Animation<double> animation,
  required Animation<double> secondaryAnimation,
  required Widget child,
}) {
  final primaryCurve = CurvedAnimation(
    parent: animation,
    curve: kSmoothEaseOut,
    reverseCurve: kSmoothEaseIn,
  );

  final secondaryCurve = CurvedAnimation(
    parent: secondaryAnimation,
    curve: kSmoothEaseOut,
    reverseCurve: kSmoothEaseIn,
  );

  final slideIn = Tween<Offset>(
    begin: const Offset(0.06, 0.0),
    end: Offset.zero,
  ).animate(primaryCurve);

  final fadeIn = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(primaryCurve);

  final slideOut = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(-0.03, 0.0),
  ).animate(secondaryCurve);

  final scaleOut = Tween<double>(
    begin: 1.0,
    end: 0.98,
  ).animate(secondaryCurve);

  return RepaintBoundary(
    child: SlideTransition(
      position: slideOut,
      child: ScaleTransition(
        scale: scaleOut,
        child: SlideTransition(
          position: slideIn,
          child: FadeTransition(
            opacity: fadeIn,
            child: child,
          ),
        ),
      ),
    ),
  );
}

/// Premium smooth page transition used across the app.
class SmoothPageRoute<T> extends PageRouteBuilder<T> {
  SmoothPageRoute({
    required WidgetBuilder builder,
    super.settings,
    this.enter = const Duration(milliseconds: 320),
    this.exit = const Duration(milliseconds: 260),
  }) : super(
          transitionDuration: enter,
          reverseTransitionDuration: exit,
          pageBuilder: (context, _, _) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (MediaQuery.disableAnimationsOf(context)) {
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
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return buildSmoothPageTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}
