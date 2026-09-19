import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Ambient liquid glass background with animated radial light orbs and depth
class AuthBackground extends StatefulWidget {
  const AuthBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AuthBackground> createState() => _AuthBackgroundState();
}

class _AuthBackgroundState extends State<AuthBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathController;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? AppColors.ink : AppColors.lightScaffold,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF050810),
                  Color(0xFF0A0F1D),
                  Color(0xFF0D1324),
                  Color(0xFF060A12),
                ]
              : const [
                  Color(0xFFFBFCFE),
                  Color(0xFFF0F5FA),
                  Color(0xFFE6EEF6),
                  Color(0xFFF7FAFC),
                ],
          stops: const [0.0, 0.35, 0.70, 1.0],
        ),
      ),
      child: AnimatedBuilder(
        animation: _breathController,
        builder: (context, child) {
          final breathVal = _breathController.value;
          return Stack(
            fit: StackFit.expand,
            children: [
              // Top-right radiant electric sky blue ambient aura
              Positioned(
                top: -120 + (breathVal * 12),
                right: -80 + (breathVal * 8),
                child: _LiquidAuraOrb(
                  size: 380,
                  color: isDark ? AppColors.sky : const Color(0xFFBAE6FD),
                  alpha: isDark ? (0.14 + breathVal * 0.06) : (0.26 + breathVal * 0.06),
                ),
              ),
              // Bottom-left cyan / electric ocean ambient aura
              Positioned(
                bottom: -80 - (breathVal * 10),
                left: -80 + (breathVal * 6),
                child: _LiquidAuraOrb(
                  size: 360,
                  color: isDark ? AppColors.skyCyan : const Color(0xFFE0F2FE),
                  alpha: isDark ? (0.10 + breathVal * 0.05) : (0.22 + breathVal * 0.05),
                ),
              ),
              // Center subtle neon azure ambient glow
              Positioned(
                top: 260 + (breathVal * 15),
                left: -40 - (breathVal * 8),
                child: _LiquidAuraOrb(
                  size: 300,
                  color: isDark ? AppColors.skyDeep : const Color(0xFFF0F9FF),
                  alpha: isDark ? (0.08 + breathVal * 0.04) : (0.18 + breathVal * 0.04),
                ),
              ),
              // Extra subtle top-left warm glow for dimension
              Positioned(
                top: 80,
                left: -60,
                child: _LiquidAuraOrb(
                  size: 200,
                  color: isDark ? const Color(0xFF7DD3FC) : const Color(0xFFE0F2FE),
                  alpha: isDark ? (0.04 + breathVal * 0.02) : (0.10 + breathVal * 0.03),
                ),
              ),
              Positioned.fill(child: widget.child),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _LiquidAuraOrb extends StatelessWidget {
  const _LiquidAuraOrb({
    required this.size,
    required this.color,
    required this.alpha,
  });

  final double size;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: alpha * 0.4),
              color.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.5, 0.85],
          ),
        ),
      ),
    );
  }
}
