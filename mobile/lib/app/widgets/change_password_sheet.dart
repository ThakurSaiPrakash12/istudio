import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../utils/validators.dart';
import 'studio_button.dart';
import 'studio_text_field.dart';

class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ChangePasswordSheet(),
    );
  }

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  int _step = 1; // 1: Verify current password, 2: Set new password
  bool _isLoading = false;
  String? _errorMessage;

  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifyOldPassword() async {
    if (!(_step1FormKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyCurrentPassword(
      _currentPasswordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      setState(() {
        _step = 2;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage = auth.errorMessage ?? 'Current password is incorrect.';
      });
    }
  }

  Future<void> _submitNewPassword() async {
    if (!(_step2FormKey.currentState?.validate() ?? false)) return;

    final currentPass = _currentPasswordController.text;
    final newPass = _newPasswordController.text;

    if (currentPass == newPass) {
      setState(() {
        _errorMessage = 'New password cannot be the same as your current password.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.changePassword(
      currentPassword: currentPass,
      newPassword: newPass,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _errorMessage = auth.errorMessage ?? 'Unable to update password. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textMain = context.textMain;
    final textMuted = context.textMuted;
    final accent = context.accentColor;
    final isDark = context.isDark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: context.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 44,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: textMuted.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Top Bar with Step indicator
                    Row(
                      children: [
                        if (_step == 2)
                          IconButton(
                            icon: Icon(Icons.arrow_back_rounded, color: textMain),
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _step = 1;
                                      _errorMessage = null;
                                    });
                                  },
                            tooltip: 'Back to current password',
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.lock_rounded, color: accent, size: 20),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _step == 1
                                    ? 'Verify Current Password'
                                    : 'Create New Password',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: textMain,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _step == 1
                                    ? 'Step 1 of 2: Security verification'
                                    : 'Step 2 of 2: Update password',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: textMuted),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Cancel',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Error banner
                    if (_errorMessage != null) ...[
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5252).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFF5252).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFFF5252),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Color(0xFFFF5252),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Animated Step Content
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.04, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: _step == 1
                          ? _buildStep1(isDark, textMuted)
                          : _buildStep2(isDark, textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1(bool isDark, Color textMuted) {
    return KeyedSubtree(
      key: const ValueKey('step_1'),
      child: Form(
        key: _step1FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Before modifying your password, please confirm your existing password to protect your studio account.',
              style: TextStyle(
                color: textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            StudioTextField(
              label: 'Current Password',
              hint: 'Enter your existing password',
              controller: _currentPasswordController,
              obscureText: true,
              prefixIcon: Icons.key_outlined,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _verifyOldPassword(),
              validator: (v) => Validators.password(v),
            ),
            const SizedBox(height: 24),
            StudioButton(
              label: 'Verify & Continue',
              icon: Icons.arrow_forward_rounded,
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _verifyOldPassword,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2(bool isDark, Color textMuted) {
    return KeyedSubtree(
      key: const ValueKey('step_2'),
      child: Form(
        key: _step2FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create a new, strong password with at least 8 characters.',
              style: TextStyle(
                color: textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            StudioTextField(
              label: 'New Password',
              hint: 'At least 8 characters',
              controller: _newPasswordController,
              obscureText: true,
              prefixIcon: Icons.lock_outline_rounded,
              textInputAction: TextInputAction.next,
              validator: (v) => Validators.password(v, isNew: true),
            ),
            const SizedBox(height: 14),
            StudioTextField(
              label: 'Confirm New Password',
              hint: 'Re-enter new password',
              controller: _confirmPasswordController,
              obscureText: true,
              prefixIcon: Icons.lock_reset_rounded,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submitNewPassword(),
              validator: (v) => Validators.confirmPassword(
                v,
                _newPasswordController.text,
              ),
            ),
            const SizedBox(height: 24),
            StudioButton(
              label: 'Update Password',
              icon: Icons.check_circle_outline_rounded,
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _submitNewPassword,
            ),
          ],
        ),
      ),
    );
  }
}
