import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

class AuthModeToggle extends StatelessWidget {
  const AuthModeToggle({
    super.key,
    required this.isLogin,
    required this.onChanged,
  });

  final bool isLogin;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Semantics(
      label: isLogin ? 'Sign in selected' : 'Sign up selected',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: isDark ? AppColors.glassInnerDark : AppColors.glassInnerLight,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
                width: 1.2,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tabWidth = (constraints.maxWidth - 4) / 2;
                return Stack(
                  children: [
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutBack,
                      alignment: isLogin
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: Container(
                        width: tabWidth,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: AppColors.skyGradient,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.sky.withValues(alpha: isDark ? 0.35 : 0.22),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        _Tab(
                          label: 'Sign in',
                          selected: isLogin,
                          onTap: () => onChanged(true),
                        ),
                        _Tab(
                          label: 'Sign up',
                          selected: !isLogin,
                          onTap: () => onChanged(false),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          height: 44,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : context.textMuted,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 14,
                letterSpacing: 0.3,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}
