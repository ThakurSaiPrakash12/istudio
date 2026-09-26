import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

class StudioTextField extends StatefulWidget {
  const StudioTextField({
    super.key,
    required this.label,
    this.hint = '',
    required this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.maxLines = 1,
    this.prefixIcon,
    this.validator,
    this.autofillHints,
    this.inputFormatters,
    this.onFieldSubmitted,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final int? maxLines;
  final IconData? prefixIcon;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<StudioTextField> createState() => _StudioTextFieldState();
}

class _StudioTextFieldState extends State<StudioTextField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    final textMain = AppColors.textMain(context);
    final textMuted = AppColors.textMuted(context);
    final isMultiline = !widget.obscureText && (widget.maxLines ?? 1) != 1;
    final keyboardType =
        isMultiline ? TextInputType.multiline : widget.keyboardType;
    final textInputAction =
        isMultiline ? TextInputAction.newline : widget.textInputAction;

    return LayoutBuilder(
      builder: (context, constraints) {
        final field = TextFormField(
          controller: widget.controller,
          obscureText: _obscured,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textAlignVertical:
              isMultiline ? TextAlignVertical.top : TextAlignVertical.center,
          validator: widget.validator,
          autofillHints: widget.autofillHints,
          inputFormatters: widget.inputFormatters,
          onFieldSubmitted: widget.onFieldSubmitted,
          style: TextStyle(color: textMain, fontSize: 16),
          cursorColor: AppColors.accent(context),
          decoration: InputDecoration(
            hintText: widget.hint.isNotEmpty ? widget.hint : null,
            isDense: true,
            errorMaxLines: 3,
            errorStyle: TextStyle(
              color: AppColors.isDark(context)
                  ? const Color(0xFFFF5252)
                  : const Color(0xFFDC2626),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            contentPadding: EdgeInsets.fromLTRB(
              widget.prefixIcon == null ? 16 : 8,
              isMultiline ? 14 : 14,
              widget.obscureText ? 8 : 16,
              14,
            ),
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(widget.prefixIcon, color: textMuted),
            suffixIcon: widget.obscureText
                ? IconButton(
                    tooltip: _obscured ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscured = !_obscured),
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: textMuted,
                    ),
                  )
                : null,
          ),
        );

        Widget content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: textMuted,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            field,
          ],
        );

        if (constraints.maxWidth.isFinite) {
          content = SizedBox(width: constraints.maxWidth, child: content);
        }

        return content;
      },
    );
  }
}
