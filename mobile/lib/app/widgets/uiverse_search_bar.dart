import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Pixel-perfect Flutter port of the satyamchaudharydev Uiverse.io animated search input.
/// Features:
/// - Smooth animated bottom focus border expanding from center
/// - Adaptive border-radius morphing on focus
/// - Tactile search icon
/// - Smooth fade/scale clear button (reset) visible only when text is entered
/// - Fully responsive across any mobile aspect ratio
class UiverseSearchBar extends StatefulWidget {
  const UiverseSearchBar({
    super.key,
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.hintText = 'Type your text',
    this.borderColor,
    this.fillColor,
    this.height = 46.0,
    this.focusNode,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String hintText;
  final Color? borderColor;
  final Color? fillColor;
  final double height;
  final FocusNode? focusNode;

  @override
  State<UiverseSearchBar> createState() => _UiverseSearchBarState();
}

class _UiverseSearchBarState extends State<UiverseSearchBar>
    with SingleTickerProviderStateMixin {
  late final FocusNode _effectiveFocusNode;
  late final AnimationController _focusAnimController;
  late final Animation<double> _borderScaleAnimation;
  bool _isInternalFocusNode = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _effectiveFocusNode = FocusNode();
      _isInternalFocusNode = true;
    } else {
      _effectiveFocusNode = widget.focusNode!;
    }

    _focusAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), // --timing: 0.3s
    );

    _borderScaleAnimation = CurvedAnimation(
      parent: _focusAnimController,
      curve: Curves.easeOutCubic,
    );

    _effectiveFocusNode.addListener(_handleFocusChange);
    widget.controller.addListener(_handleTextChange);
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_handleFocusChange);
    widget.controller.removeListener(_handleTextChange);
    if (_isInternalFocusNode) {
      _effectiveFocusNode.dispose();
    }
    _focusAnimController.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_effectiveFocusNode.hasFocus) {
      _focusAnimController.forward();
    } else {
      _focusAnimController.reverse();
    }
    setState(() {});
  }

  void _handleTextChange() {
    setState(() {});
  }

  void _handleClear() {
    HapticFeedback.lightImpact();
    widget.controller.clear();
    widget.onChanged?.call('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final hasText = widget.controller.text.isNotEmpty;
    final isFocused = _effectiveFocusNode.hasFocus;

    // Palette aligned with Uiverse.io snippet:
    // border-color: #2f2ee9
    // icon: #8b8ba7
    final activeBorderColor = widget.borderColor ??
        (isDark ? const Color(0xFF6366F1) : const Color(0xFF2F2EE9));
    final iconColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF8B8BA7);
    final bg = widget.fillColor ??
        (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.85) : Colors.white);
    final textStyle = GoogleFonts.plusJakartaSans(
      color: context.textMain,
      fontSize: 14.0,
      fontWeight: FontWeight.w500,
    );
    final hintStyle = GoogleFonts.plusJakartaSans(
      color: context.textMuted.withValues(alpha: 0.75),
      fontSize: 13.5,
      fontWeight: FontWeight.w400,
    );

    // Responsive container with animated border radius (30px -> 8px on focus)
    final currentBorderRadius = isFocused ? 12.0 : 30.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      height: widget.height,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(currentBorderRadius),
        border: Border.all(
          color: isFocused
              ? activeBorderColor.withValues(alpha: 0.45)
              : (isDark
                  ? const Color(0xFF334155).withValues(alpha: 0.6)
                  : const Color(0xFFE2E8F0)),
          width: 1.0,
        ),
        boxShadow: [
          if (isFocused)
            BoxShadow(
              color: activeBorderColor.withValues(alpha: 0.15),
              blurRadius: 14,
              offset: const Offset(0, 4),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(currentBorderRadius),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Input Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Search Icon Button
                  IconButton(
                    icon: Icon(
                      Icons.search_rounded,
                      color: isFocused ? activeBorderColor : iconColor,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    splashRadius: 18,
                    onPressed: () => _effectiveFocusNode.requestFocus(),
                  ),
                  const SizedBox(width: 6),

                  // Text Field
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _effectiveFocusNode,
                      style: textStyle,
                      onChanged: widget.onChanged,
                      onSubmitted: widget.onSubmitted,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: widget.hintText,
                        hintStyle: hintStyle,
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),

                  // Reset/Clear Button (.reset in CSS snippet)
                  AnimatedScale(
                    scale: hasText ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: AnimatedOpacity(
                      opacity: hasText ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 180),
                      child: IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: iconColor,
                          size: 18,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        splashRadius: 18,
                        tooltip: 'Clear search',
                        onPressed: hasText ? _handleClear : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Animated Underline Border (.form:before in CSS snippet)
            // Expands horizontally from center on focus
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedBuilder(
                animation: _borderScaleAnimation,
                builder: (context, child) {
                  return FractionallySizedBox(
                    widthFactor: _borderScaleAnimation.value,
                    alignment: Alignment.center,
                    child: Container(
                      height: 2.2, // --border-height: 2px
                      decoration: BoxDecoration(
                        color: activeBorderColor,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: activeBorderColor.withValues(alpha: 0.6),
                            blurRadius: 4,
                            spreadRadius: 0.5,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
