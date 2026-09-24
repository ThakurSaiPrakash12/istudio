import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/validators.dart';
import '../../widgets/studio_button.dart';
import '../../widgets/studio_text_field.dart';

enum _ResetStep { verifyUsername, newPassword, success }

class ForgotPasswordSheet extends StatefulWidget {
  const ForgotPasswordSheet({
    super.key,
    this.initialUsername,
    this.initialPhone,
  });

  final String? initialUsername;
  final String? initialPhone;

  static Future<bool?> show(
    BuildContext context, {
    String? initialUsername,
    String? initialPhone,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ForgotPasswordSheet(
        initialUsername: initialUsername,
        initialPhone: initialPhone,
      ),
    );
  }

  @override
  State<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<ForgotPasswordSheet> {
  _ResetStep _step = _ResetStep.verifyUsername;
  bool _isLoading = false;
  String? _errorMessage;

  // Step 1: Verify Username
  final _usernameKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  String? _verifiedUsername;
  String? _verifiedResetToken;
  String? _maskedPhone;

  // Step 2: New Password
  final _passwordKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _usernameController =
        TextEditingController(text: widget.initialUsername ?? '');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyUsername() async {
    FocusScope.of(context).unfocus();
    if (!(_usernameKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();
    try {
      final res = await auth.verifyForgotPasswordUsername(_usernameController.text);
      if (!mounted) return;
      setState(() {
        _verifiedUsername =
            (res['username'] as String?)?.trim() ?? _usernameController.text.trim();
        _verifiedResetToken = res['resetToken'] as String?;
        _maskedPhone = res['maskedPhone'] as String?;
        _step = _ResetStep.newPassword;
      });
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage =
          'Unable to verify username. Please check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResetPassword() async {
    FocusScope.of(context).unfocus();
    if (!(_passwordKey.currentState?.validate() ?? false)) return;
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.resetPassword(
      username: _verifiedUsername,
      resetToken: _verifiedResetToken,
      newPassword: _newPasswordController.text,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        setState(() => _step = _ResetStep.success);
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (mounted) Navigator.of(context).pop(true);
        });
      } else {
        setState(() =>
            _errorMessage = auth.errorMessage ?? 'Unable to reset password.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: bottomInset + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.ink : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? AppColors.glassBorderDark : AppColors.lightBorder,
          width: 1.2,
        ),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Error Banner if present
            if (_errorMessage != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: Colors.redAccent, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Step Content
            if (_step == _ResetStep.verifyUsername)
              _buildVerifyUsernameStep(isDark),
            if (_step == _ResetStep.newPassword)
              _buildPasswordStep(isDark),
            if (_step == _ResetStep.success)
              _buildSuccessStep(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifyUsernameStep(bool isDark) {
    return Form(
      key: _usernameKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.sky.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_reset_rounded,
                    color: AppColors.sky, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reset Studio Password',
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.lightTextMain,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Enter your username to verify your account.',
                      style: TextStyle(
                        color:
                            isDark ? AppColors.muted : AppColors.lightTextMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          StudioTextField(
            label: 'Username',
            hint: 'Enter your studio username',
            controller: _usernameController,
            prefixIcon: Icons.alternate_email_rounded,
            autofillHints: const [AutofillHints.username],
            validator: Validators.username,
            onFieldSubmitted: (_) => _handleVerifyUsername(),
          ),
          const SizedBox(height: 22),
          StudioButton(
            label: 'Verify Username',
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _handleVerifyUsername,
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStep(bool isDark) {
    return Form(
      key: _passwordKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Verified user badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.pastelMint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.pastelMint.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  color: AppColors.pastelMint,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verified: @${_verifiedUsername ?? ''}',
                        style: TextStyle(
                          color:
                              isDark ? Colors.white : AppColors.lightTextMain,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      if (_maskedPhone != null && _maskedPhone!.isNotEmpty)
                        Text(
                          'Linked phone: $_maskedPhone',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.muted
                                : AppColors.lightTextMuted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _step = _ResetStep.verifyUsername;
                            _errorMessage = null;
                          });
                        },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.sky,
                  ),
                  child: const Text('Change'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Create New Password',
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.lightTextMain,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Enter a secure new password for your studio account.',
            style: TextStyle(
              color: isDark ? AppColors.muted : AppColors.lightTextMuted,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 20),
          StudioTextField(
            label: 'New password',
            hint: 'Minimum 8 characters',
            controller: _newPasswordController,
            obscureText: true,
            prefixIcon: Icons.lock_outline_rounded,
            validator: (val) {
              if (val == null || val.length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          StudioTextField(
            label: 'Confirm new password',
            hint: 'Re-enter your new password',
            controller: _confirmPasswordController,
            obscureText: true,
            prefixIcon: Icons.check_circle_outline_rounded,
            validator: (val) {
              if (val != _newPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
            onFieldSubmitted: (_) => _handleResetPassword(),
          ),
          const SizedBox(height: 24),
          StudioButton(
            label: 'Change Password',
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _handleResetPassword,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessStep(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.pastelMint.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.pastelMint.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.pastelMint,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Password Changed!',
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.lightTextMain,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your password has been successfully updated.\nYou can now sign in with your new password.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? AppColors.muted : AppColors.lightTextMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          StudioButton(
            label: 'Back to Sign In',
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}
