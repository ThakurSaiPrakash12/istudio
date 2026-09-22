import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class StudioButton extends StatefulWidget {
  const StudioButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.height = 54.0,
    this.isSecondary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double height;
  final bool isSecondary;

  @override
  State<StudioButton> createState() => _StudioButtonState();
}

class _StudioButtonState extends State<StudioButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;
    final isDark = AppColors.isDark(context);

    final radius = BorderRadius.circular(999);

    // Primary Liquid Glass Sky Blue vs Secondary Frosted Obsidian Pill
    final decoration = widget.isSecondary
        ? BoxDecoration(
            borderRadius: radius,
            color: isDark ? AppColors.glassCardDark : Colors.white,
            border: Border.all(
              color: isDark ? AppColors.glassBorderDark : AppColors.lightBorder,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          )
        : BoxDecoration(
            borderRadius: radius,
            gradient: AppColors.skyGradient,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.sky.withValues(alpha: isDark ? 0.35 : 0.28),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          );

    final textColor = widget.isSecondary
        ? (isDark ? AppColors.paper : AppColors.lightTextMain)
        : Colors.white;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutBack,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: enabled ? 1.0 : 0.5,
            child: Container(
              width: double.infinity,
              height: widget.height,
              decoration: decoration,
              child: Stack(
                children: [
                  // Specular Glass Highlight on the top edge
                  if (!widget.isSecondary)
                    Positioned(
                      top: 0,
                      left: 18,
                      right: 18,
                      height: 1.2,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.0),
                              Colors.white.withValues(alpha: 0.6),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: widget.isLoading
                          ? SizedBox(
                              key: const ValueKey('btn_loading'),
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                valueColor: AlwaysStoppedAnimation<Color>(textColor),
                              ),
                            )
                          : Row(
                              key: const ValueKey('btn_content'),
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.icon != null) ...[
                                  Icon(widget.icon, color: textColor, size: 18),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  widget.label,
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
