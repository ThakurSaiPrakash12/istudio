import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Apple Logo Icon using official Apple icon shape
class AppleLogo extends StatelessWidget {
  const AppleLogo({super.key, this.size = 20.0, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.apple,
      size: size,
      color: color,
    );
  }
}

/// Official Apple HIG compliant Sign in with Apple button
class AppleSignInButton extends StatefulWidget {
  const AppleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.label = 'Sign in with Apple',
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  @override
  State<AppleSignInButton> createState() => _AppleSignInButtonState();
}

class _AppleSignInButtonState extends State<AppleSignInButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final enabled = widget.onPressed != null && !widget.isLoading;

    // Apple Human Interface Guidelines:
    // In dark mode: white background with black text/icon
    // In light mode: black background with white text/icon
    final bgColor = isDark ? Colors.white : Colors.black;
    final fgColor = isDark ? Colors.black : Colors.white;

    return AnimatedScale(
      scale: _isPressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTapDown: enabled
              ? (_) {
                  HapticFeedback.lightImpact();
                  setState(() => _isPressed = true);
                }
              : null,
          onTapUp: enabled ? (_) => setState(() => _isPressed = false) : null,
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: enabled ? widget.onPressed : null,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isLoading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                    ),
                  )
                else ...[
                  AppleLogo(size: 22, color: fgColor),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      widget.label,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: fgColor,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

