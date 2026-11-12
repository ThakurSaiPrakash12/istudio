
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/studio_button.dart';
import '../../widgets/studio_text_field.dart';

/// Three-step forgot-password flow:
///   1. Enter username OR email → server sends OTP to account email
///   2. Enter the 6-digit OTP from email
///   3. Set new password
enum _ResetStep { lookup, verifyOtp, newPassword, success }

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
  _ResetStep _step = _ResetStep.lookup;
  bool _isLoading = false;
  String? _errorMessage;

  // Step 1 — Lookup
  final _lookupKey = GlobalKey<FormState>();
  late final TextEditingController _identifierController;
  String? _maskedEmail;
  String? _lookupToken; // short-lived JWT from server

  // Step 2 — OTP
  final _otpKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  String? _resetToken; // short-lived JWT returned after OTP is verified

  // Step 3 — New Password
  final _passwordKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _identifierController = TextEditingController(
      text: widget.initialUsername ?? '',
    );
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Step 1 ────────────────────────────────────────────────────────────────
  Future<void> _handleLookup() async {
    FocusScope.of(context).unfocus();
    if (!(_lookupKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();
    try {
      final res = await auth.forgotPasswordLookup(_identifierController.text.trim());
      if (!mounted) return;
      setState(() {
        _maskedEmail = res['maskedEmail'] as String? ?? '';
        _lookupToken = res['lookupToken'] as String?;
        _step = _ResetStep.verifyOtp;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
        AppSnackBar.error(context, e.message);
      }
    } catch (_) {
      const msg = 'Unable to send code. Please check your connection.';
      if (mounted) {
        setState(() => _errorMessage = msg);
        AppSnackBar.error(context, msg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Step 2 ────────────────────────────────────────────────────────────────
  Future<void> _handleVerifyOtp() async {
    FocusScope.of(context).unfocus();
    if (!(_otpKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();
    try {
      final resetToken = await auth.forgotPasswordVerifyOtp(
        lookupToken: _lookupToken ?? '',
        otp: _otpController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _resetToken = resetToken;
        _step = _ResetStep.newPassword;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
        AppSnackBar.error(context, e.message);
      }
    } catch (_) {
      const msg = 'Invalid or expired code. Please try again.';
      if (mounted) {
        setState(() => _errorMessage = msg);
        AppSnackBar.error(context, msg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Resend OTP ────────────────────────────────────────────────────────────
  Future<void> _handleResend() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _otpController.clear();
    });

    final auth = context.read<AuthProvider>();
    try {
      final res = await auth.forgotPasswordLookup(_identifierController.text.trim());
      if (!mounted) return;
      setState(() {
        _maskedEmail = res['maskedEmail'] as String? ?? _maskedEmail;
        _lookupToken = res['lookupToken'] as String?;
      });
      if (mounted) AppSnackBar.info(context, 'A new code has been sent.');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
        AppSnackBar.error(context, e.message);
      }
    } catch (_) {
      if (mounted) AppSnackBar.error(context, 'Unable to resend code.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Step 3 ────────────────────────────────────────────────────────────────
  Future<void> _handleResetPassword() async {
    FocusScope.of(context).unfocus();
    if (!(_passwordKey.currentState?.validate() ?? false)) return;
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match.');
      AppSnackBar.error(context, 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.resetPassword(
      resetToken: _resetToken!,
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
        final message = auth.errorMessage ?? 'Unable to reset password.';
        setState(() => _errorMessage = message);
        AppSnackBar.error(context, message);
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
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
            // Drag handle
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

            // Step progress indicator
            if (_step != _ResetStep.success) _buildStepIndicator(isDark),
            if (_step != _ResetStep.success) const SizedBox(height: 20),

            // Error banner
            if (_errorMessage != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.35)),
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

            // Step content
            if (_step == _ResetStep.lookup) _buildLookupStep(isDark),
            if (_step == _ResetStep.verifyOtp) _buildOtpStep(isDark),
            if (_step == _ResetStep.newPassword) _buildPasswordStep(isDark),
            if (_step == _ResetStep.success) _buildSuccessStep(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(bool isDark) {
    final steps = [_ResetStep.lookup, _ResetStep.verifyOtp, _ResetStep.newPassword];
    final labels = ['Identify', 'Verify', 'Reset'];
    final currentIndex = steps.indexOf(_step).clamp(0, steps.length - 1);

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final lineActive = (i ~/ 2) < currentIndex;
          return Expanded(
            child: Container(
              height: 2,
              color: lineActive
                  ? AppColors.sky
                  : (isDark ? Colors.white12 : Colors.black12),
            ),
          );
        }
        final stepIdx = i ~/ 2;
        final done = stepIdx < currentIndex;
        final active = stepIdx == currentIndex;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done || active
                    ? AppColors.sky
                    : (isDark ? Colors.white10 : Colors.black12),
              ),
              child: Center(
                child: done
                    ? const Icon(Icons.check_rounded,
                        size: 15, color: Colors.white)
                    : Text(
                        '${stepIdx + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? Colors.white
                              : (isDark ? Colors.white38 : Colors.black38),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              labels[stepIdx],
              style: TextStyle(
                fontSize: 10,
                color: done || active
                    ? AppColors.sky
                    : (isDark ? Colors.white38 : Colors.black38),
                fontWeight:
                    active ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildLookupStep(bool isDark) {
    return Form(
      key: _lookupKey,
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
                      'Reset Your Password',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white
                            : AppColors.lightTextMain,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Enter your username or email and we\'ll send a code.',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.muted
                            : AppColors.lightTextMuted,
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
            label: 'Username or Email',
            hint: 'Enter your username or email address',
            controller: _identifierController,
            prefixIcon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [
              AutofillHints.username,
              AutofillHints.email,
            ],
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Enter your username or email address.';
              }
              return null;
            },
            onFieldSubmitted: (_) => _handleLookup(),
          ),
          const SizedBox(height: 22),
          StudioButton(
            label: 'Send Verification Code',
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _handleLookup,
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep(bool isDark) {
    return Form(
      key: _otpKey,
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
                child: const Icon(Icons.mark_email_read_rounded,
                    color: AppColors.sky, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Check Your Email',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white
                            : AppColors.lightTextMain,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'A 6-digit code was sent to ${_maskedEmail ?? "your email"}.',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.muted
                            : AppColors.lightTextMuted,
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
            label: 'Verification Code',
            hint: '6-digit code from email',
            controller: _otpController,
            prefixIcon: Icons.pin_rounded,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            validator: (val) {
              if (val == null || val.trim().length != 6) {
                return 'Enter the 6-digit code from your email.';
              }
              if (RegExp(r'[^0-9]').hasMatch(val.trim())) {
                return 'Code must contain digits only.';
              }
              return null;
            },
            onFieldSubmitted: (_) => _handleVerifyOtp(),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => setState(() {
                          _step = _ResetStep.lookup;
                          _errorMessage = null;
                        }),
                style: TextButton.styleFrom(
                  foregroundColor: isDark
                      ? AppColors.muted
                      : AppColors.lightTextMuted,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('← Change', style: TextStyle(fontSize: 13)),
              ),
              TextButton(
                onPressed: _isLoading ? null : _handleResend,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.sky,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Resend Code',
                    style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StudioButton(
            label: 'Verify Code',
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _handleVerifyOtp,
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
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.pastelMint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.pastelMint.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded,
                    color: AppColors.pastelMint, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Identity verified — set your new password.',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white
                          : AppColors.lightTextMain,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
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
            'Enter a secure new password for your account.',
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
                  width: 1.5),
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: AppColors.pastelMint, size: 40),
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
