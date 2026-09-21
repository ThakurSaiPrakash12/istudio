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
      label: 'iStudio',
      child: Column(
        children: [
          Hero(
            tag: 'studio-mark',
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isDark
                    ? AppColors.skyGradient
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF7B3FE4), Color(0xFF5F259F)],
                      ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? AppColors.sky : AppColors.lightPrimary)
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
                    color: isDark ? AppColors.ink : Colors.white,
                    border: Border.all(
                      color: isDark ? AppColors.sky.withValues(alpha: 0.5) : AppColors.lightBorder,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.camera_rounded,
                    color: isDark ? AppColors.sky : AppColors.lightPrimary,
                    size: compact ? 22 : 32,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: compact ? 10 : 16),
          Text(
            'iSTUDIO',
            style: GoogleFonts.plusJakartaSans(
              color: textMain,
              fontSize: compact ? 22 : 30,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.sky.withValues(alpha: 0.12)
                  : AppColors.lightPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isDark
                    ? AppColors.sky.withValues(alpha: 0.3)
                    : AppColors.lightPrimary.withValues(alpha: 0.2),
                width: 0.8,
              ),
            ),
            child: Text(
              'STUDIO OS',
              style: GoogleFonts.plusJakartaSans(
                color: isDark ? AppColors.sky : AppColors.lightPrimary,
                fontSize: compact ? 9.5 : 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
