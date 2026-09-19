import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Clean, high-performance ambient canvas for Swiggy/Blinkit grade apps
class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return ColoredBox(
      color: isDark ? AppColors.ink : AppColors.lightScaffold,
      child: child,
    );
  }
}

