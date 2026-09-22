import 'dart:ui';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Modern tactile card following Swiggy/Blinkit design language
class StudioCard extends StatefulWidget {
  const StudioCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderRadius = 22.0,
    this.customBorder,
    this.gradient,
    this.blurSigma = 16.0,
    this.enableSpecularRim = true,
    this.animateOnAppear = false,
    this.appearDelay = Duration.zero,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final double borderRadius;
  final Border? customBorder;
  final Gradient? gradient;
  final double blurSigma;
  final bool enableSpecularRim;
  final bool animateOnAppear;
  final Duration appearDelay;

  @override
  State<StudioCard> createState() => _StudioCardState();
}

class _StudioCardState extends State<StudioCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.985).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final radius = BorderRadius.circular(widget.borderRadius);

    final cardDecoration = BoxDecoration(
      color: isDark ? AppColors.glassCardDark : AppColors.lightCard,
      borderRadius: radius,
      gradient: widget.gradient ??
          (isDark
              ? AppColors.glassCardGradientDark
              : AppColors.glassCardGradientLight),
      border: widget.customBorder ??
          Border.all(
            color: isDark ? AppColors.glassBorderDark : AppColors.lightBorder,
            width: 0.9,
          ),
      boxShadow: [
        // Ambient soft depth shadow
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.35)
              : const Color(0x0A0F172A),
          blurRadius: 18,
          offset: const Offset(0, 6),
          spreadRadius: 0,
        ),
        // Subtle pastel chromatic vibrancy halo
        BoxShadow(
          color: (isDark ? AppColors.sky : AppColors.pastelPeach)
              .withValues(alpha: isDark ? 0.07 : 0.05),
          blurRadius: 20,
          offset: const Offset(0, 2),
        ),
      ],
    );

    Widget cardWidget = Container(
      width: double.infinity,
      padding: widget.padding,
      decoration: cardDecoration,
      child: widget.child,
    );

    if (widget.blurSigma > 0) {
      cardWidget = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: widget.blurSigma,
            sigmaY: widget.blurSigma,
          ),
          child: cardWidget,
        ),
      );
    }

    if (widget.onTap == null) return cardWidget;

    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) => _pressController.reverse(),
      onTapCancel: () => _pressController.reverse(),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: cardWidget,
      ),
    );
  }
}
