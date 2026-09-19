import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

class StudioLogo extends StatelessWidget {
  const StudioLogo({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 56.0 : 84.0;
    final isDark = context.isDark;
    final textMain = context.textMain;

    return Semantics(
      header: true,
      label: 'Lumen Haute Studio',
      child: Column(
        children: [
          Hero(
            tag: 'lumen-mark',
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isDark
                    ? AppColors.goldGradient
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFE5C07B), Color(0xFFB8860B)],
                      ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? AppColors.gold : AppColors.lightPrimary)
                        .withValues(alpha: 0.4),
                    blurRadius: 28,
                    spreadRadius: 2,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: size * 0.76,
                  height: size * 0.76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? const Color(0xFF080C14) : Colors.white,
                    border: Border.all(
                      color: isDark ? AppColors.gold.withValues(alpha: 0.5) : AppColors.lightBorder,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.camera_rounded,
                    color: isDark ? AppColors.gold : AppColors.lightPrimary,
                    size: compact ? 22 : 32,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: compact ? 12 : 18),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'LUMEN',
                style: GoogleFonts.playfairDisplay(
                  color: textMain,
                  fontSize: compact ? 26 : 36,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.sky.withValues(alpha: 0.14)
                  : AppColors.lightPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isDark
                    ? AppColors.sky.withValues(alpha: 0.35)
                    : AppColors.lightPrimary.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              'PHOTOGRAPHY ATELIER',
              style: GoogleFonts.dmSans(
                color: isDark ? AppColors.gold : AppColors.lightPrimary,
                fontSize: compact ? 9.5 : 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
