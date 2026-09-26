import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Centralized Motion & Animation Design System for iStudio.
///
/// Designed for 120Hz ProMotion displays, Play Store battery and rendering efficiency,
/// and consistent micro-interactions across the entire application.
class AppMotion {
  const AppMotion._();

  // ---------------------------------------------------------------------------
  // Standard Durations
  // ---------------------------------------------------------------------------
  /// Ultra-fast micro-interactions (tap feedback, icons, checkmarks)
  static const Duration fast = Duration(milliseconds: 160);

  /// Standard transitions (cards, chips, toggles, content switchers)
  static const Duration standard = Duration(milliseconds: 260);

  /// Medium transitions (dialogs, bottom sheets, tab transitions)
  static const Duration medium = Duration(milliseconds: 320);

  /// Page route navigation transitions
  static const Duration page = Duration(milliseconds: 320);

  /// Expressive delight animations (celebratory particles, particle bursts)
  static const Duration delight = Duration(milliseconds: 480);

  // ---------------------------------------------------------------------------
  // Easing Curves
  // ---------------------------------------------------------------------------
  /// iOS / Blinkit / Swiggy fluid ease-out standard curve
  static const Curve fluid = Cubic(0.16, 1.0, 0.3, 1.0);

  /// Bouncy spring curve for micro-interactions (presses, button releases)
  static const Curve spring = Curves.easeOutBack;

  /// Expressive snappy spring curve
  static const Curve springSnappy = Cubic(0.34, 1.56, 0.64, 1.0);

  /// Smooth deceleration curve for entrances
  static const Curve enter = Curves.easeOutCubic;

  /// Smooth acceleration curve for exits
  static const Curve exit = Curves.easeInCubic;

  /// Checks if system animations are disabled (Accessibility Play Store standard)
  static bool areAnimationsDisabled(BuildContext context) {
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }
}

/// A lightweight, GPU-optimized entrance animation widget with staggered slide + fade.
///
/// Automatically respects system accessibility settings to satisfy Google Play standards.
class MotionEntrance extends StatefulWidget {
  const MotionEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppMotion.medium,
    this.offset = const Offset(0.0, 0.08),
    this.curve = AppMotion.fluid,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final Curve curve;

  @override
  State<MotionEntrance> createState() => _MotionEntranceState();
}

class _MotionEntranceState extends State<MotionEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    final curved = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    _slide = Tween<Offset>(begin: widget.offset, end: Offset.zero).animate(curved);

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.areAnimationsDisabled(context)) {
      return widget.child;
    }

    return RepaintBoundary(
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Universal tactile micro-interaction wrapper.
///
/// Gives any card, button, or widget a smooth scale bounce (0.97) + haptic feedback on touch.
class MotionPressable extends StatefulWidget {
  const MotionPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressScale = 0.965,
    this.duration = const Duration(milliseconds: 140),
    this.enableHaptics = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressScale;
  final Duration duration;
  final bool enableHaptics;

  @override
  State<MotionPressable> createState() => _MotionPressableState();
}

class _MotionPressableState extends State<MotionPressable> {
  bool _pressed = false;

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (widget.enableHaptics) {
      HapticFeedback.selectionClick();
    }
    setState(() => _pressed = true);
  }

  void _onTapUp(TapUpDetails _) {
    if (_pressed) setState(() => _pressed = false);
  }

  void _onTapCancel() {
    if (_pressed) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null && widget.onLongPress == null;
    if (disabled || AppMotion.areAnimationsDisabled(context)) {
      return GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: widget.child,
      );
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? widget.pressScale : 1.0,
        duration: widget.duration,
        curve: AppMotion.spring,
        child: widget.child,
      ),
    );
  }
}
