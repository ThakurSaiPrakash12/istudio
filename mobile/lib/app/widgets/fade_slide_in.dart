import 'package:flutter/material.dart';

/// GPU-composited fade + slide entrance widget.
/// Uses FadeTransition + SlideTransition so it never blocks content on rebuild.
/// Respects MediaQuery.disableAnimations for accessibility.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.animation,
    required this.child,
    this.beginOffset = const Offset(0, 0.06),
  });

  final Animation<double> animation;
  final Widget child;
  final Offset beginOffset;

  @override
  Widget build(BuildContext context) {
    // Honour reduce-motion / accessibility settings
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) return child;

    final slide = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(animation);

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: slide,
        child: child,
      ),
    );
  }
}
