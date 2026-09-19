import 'dart:ui';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Premium Liquid Glass Card with frosted blur, specular highlights, and ambient glow
class StudioCard extends StatefulWidget {
  const StudioCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.borderRadius = 32.0,
    this.customBorder,
    this.gradient,
    this.blurSigma = 18.0,
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
  late AnimationController _appearController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _appearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(
      parent: _appearController,
      curve: Curves.easeOutCubic,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _appearController,
      curve: Curves.easeOutCubic,
    ));

    if (widget.animateOnAppear) {
      Future.delayed(widget.appearDelay, () {
        if (mounted) _appearController.forward();
      });
    } else {
      _appearController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _appearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final radius = BorderRadius.circular(widget.borderRadius);

    final cardDecoration = BoxDecoration(
      borderRadius: radius,
      gradient: widget.gradient ??
          (isDark
              ? AppColors.glassCardGradientDark
              : AppColors.glassCardGradientLight),
      border: widget.customBorder ??
          Border.all(
            color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
            width: 1.2,
          ),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.35)
              : const Color(0x0A0F172A),
          blurRadius: 24,
          offset: const Offset(0, 8),
          spreadRadius: 0,
        ),
        if (isDark)
          BoxShadow(
            color: AppColors.sky.withValues(alpha: 0.04),
            blurRadius: 40,
            offset: const Offset(0, 2),
          ),
      ],
    );

    Widget innerContent = Container(
      width: double.infinity,
      padding: widget.padding,
      decoration: cardDecoration,
      child: Stack(
        children: [
          // Specular top refraction highlight
          if (widget.enableSpecularRim)
            Positioned(
              top: 0,
              left: 20,
              right: 20,
              height: 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: isDark ? 0.2 : 0.5),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          widget.child,
        ],
      ),
    );

    Widget glassContent = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: widget.blurSigma, sigmaY: widget.blurSigma),
        child: innerContent,
      ),
    );

    // Wrap with appear animation
    glassContent = FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: glassContent,
      ),
    );

    if (widget.onTap == null) return glassContent;

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        splashColor: isDark
            ? AppColors.sky.withValues(alpha: 0.12)
            : AppColors.lightPrimary.withValues(alpha: 0.08),
        highlightColor: isDark
            ? AppColors.sky.withValues(alpha: 0.06)
            : AppColors.lightPrimary.withValues(alpha: 0.04),
        onTap: widget.onTap,
        child: glassContent,
      ),
    );
  }
}
