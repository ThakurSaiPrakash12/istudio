import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Ambient liquid canvas with subtle pastel refraction orbs
class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Stack(
      children: [
        // Base canvas
        Positioned.fill(
          child: ColoredBox(
            color: isDark ? AppColors.ink : AppColors.lightScaffold,
          ),
        ),

        // Ambient Pastel Periwinkle Orb (Top-Right)
        Positioned(
          top: -80,
          right: -60,
          width: 340,
          height: 340,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.sky.withValues(alpha: isDark ? 0.15 : 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Ambient Pastel Peach Blossom Orb (Mid-Left)
        Positioned(
          top: 240,
          left: -100,
          width: 320,
          height: 320,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.pastelPeach.withValues(alpha: isDark ? 0.12 : 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Ambient Pastel Mint Whisper (Bottom-Right behind dock for rich refraction)
        Positioned(
          bottom: 20,
          right: -40,
          width: 300,
          height: 300,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.pastelMint.withValues(alpha: isDark ? 0.09 : 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Main screen hierarchy
        Positioned.fill(child: child),
      ],
    );
  }
}

