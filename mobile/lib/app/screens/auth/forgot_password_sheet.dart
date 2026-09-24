import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/validators.dart';
import '../../widgets/studio_button.dart';
import '../../widgets/studio_text_field.dart';

enum _ResetStep { phone, otp, newPassword, success }

class ForgotPasswordSheet extends StatefulWidget {
  const ForgotPasswordSheet({super.key, this.initialPhone});

  final String? initialPhone;

  static Future<bool?> show(BuildContext context, {String? initialPhone}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ForgotPasswordSheet(initialPhone: initialPhone),
    );
  }

  @override
  State<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<ForgotPasswordSheet> {
  _ResetStep _step = _ResetStep.phone;
  bool _isLoading = false;
  String? _errorMessage;

  // Step 1: Phone
  final _phoneKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;

  // Step 2: OTP
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  int _cooldownSeconds = 60;
  Timer? _cooldownTimer;
  String? _verifiedResetToken;

  // Step 3: New Password
  final _passwordKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.initialPhone ?? '');
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _phoneController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  Future<void> _handleSendOtp() async {
    FocusScope.of(context).unfocus();
    if (!(_phoneKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();
    try {
      final res = await auth.sendForgotPasswordOtp(_phoneController.text);
      final cd = (res['cooldownSeconds'] as num?)?.toInt() ?? 60;
      final debugOtp = res['debugOtp'] as String?;
      _startCooldown(cd);
      setState(() {
        _step = _ResetStep.otp;
      });
      // Auto focus first OTP digit
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _otpFocusNodes[0].requestFocus();
      });

      if (debugOtp != null && debugOtp.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.sky,
            duration: const Duration(seconds: 10),
            content: Text('Your verification code: $debugOtp'),
            action: SnackBarAction(
              label: 'Auto-fill',
              textColor: Colors.white,
              onPressed: () {
                for (int i = 0; i < 6 && i < debugOtp.length; i++) {
                  _otpControllers[i].text = debugOtp[i];
                }
                _handleVerifyOtp();
              },
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() =>
          _errorMessage = 'Unable to send verification code. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVerifyOtp() async {
    FocusScope.of(context).unfocus();
    final otp = _otpControllers.map((c) => c.text.trim()).join();
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter the complete 6-digit code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();
    try {
      final token = await auth.verifyForgotPasswordOtp(
        phone: _phoneController.text,
        otp: otp,
      );
      _verifiedResetToken = token;
      setState(() {
        _step = _ResetStep.newPassword;
      });
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Invalid or expired code. Please try again.');
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

    if (_verifiedResetToken == null) {
      setState(() => _errorMessage = 'Session expired. Please request a new code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.resetPassword(
      resetToken: _verifiedResetToken!,
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

  void _onOtpChanged(int index, String value) {
    if (value.length > 1) {
      // Pasted full 6-digit code
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < 6 && i < digits.length; i++) {
        _otpControllers[i].text = digits[i];
      }
      if (digits.length >= 6) {
        _otpFocusNodes[5].unfocus();
        _handleVerifyOtp();
      } else {
        _otpFocusNodes[digits.length].requestFocus();
      }
      return;
    }

    if (value.isNotEmpty && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    if (_otpControllers.every((c) => c.text.isNotEmpty)) {
      _handleVerifyOtp();
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.redAccent, size: 18),
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
            if (_step == _ResetStep.phone) _buildPhoneStep(isDark),
            if (_step == _ResetStep.otp) _buildOtpStep(isDark),
            if (_step == _ResetStep.newPassword) _buildPasswordStep(isDark),
            if (_step == _ResetStep.success) _buildSuccessStep(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneStep(bool isDark) {
    return Form(
      key: _phoneKey,
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
                      'We will send a 6-digit verification code.',
                      style: TextStyle(
                        color: isDark ? AppColors.muted : AppColors.lightTextMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          StudioTextField(
            label: 'Registered phone number',
            hint: '10-digit mobile number',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_outlined,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            validator: Validators.phone,
          ),
          const SizedBox(height: 24),
          StudioButton(
            label: 'Send Verification Code',
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _handleSendOtp,
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verify Your Number',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.lightTextMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Code sent to +91 ${_phoneController.text}',
                  style: TextStyle(
                    color: isDark ? AppColors.muted : AppColors.lightTextMuted,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => setState(() => _step = _ResetStep.phone),
              child: const Text('Edit Phone', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 6 Discrete PIN Boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 44,
              height: 52,
              child: KeyboardListener(
                focusNode: FocusNode(),
                onKeyEvent: (event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.backspace &&
                      _otpControllers[index].text.isEmpty &&
                      index > 0) {
                    _otpFocusNodes[index - 1].requestFocus();
                  }
                },
                child: TextField(
                  controller: _otpControllers[index],
                  focusNode: _otpFocusNodes[index],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.lightTextMain,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: isDark
                        ? AppColors.glassInnerDark
                        : AppColors.lightInputFill,
                    contentPadding: EdgeInsets.zero,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.glassBorderDark
                            : AppColors.lightBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.sky,
                        width: 1.8,
                      ),
                    ),
                  ),
                  onChanged: (val) => _onOtpChanged(index, val),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),

        // Resend Timer
        Center(
          child: _cooldownSeconds > 0
              ? Text(
                  'Resend code in ${_cooldownSeconds}s',
                  style: TextStyle(
                    color: isDark ? AppColors.muted : AppColors.lightTextMuted,
                    fontSize: 12.5,
                  ),
                )
              : TextButton.icon(
                  onPressed: _isLoading ? null : _handleSendOtp,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text(
                    'Resend Code',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 20),
        StudioButton(
          label: 'Verify Code',
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _handleVerifyOtp,
        ),
      ],
    );
  }

  Widget _buildPasswordStep(bool isDark) {
    return Form(
      key: _passwordKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            'Enter a secure password for your studio account.',
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
          ),
          const SizedBox(height: 24),
          StudioButton(
            label: 'Update Password',
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _handleResetPassword,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessStep(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
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
            'Password Updated!',
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.lightTextMain,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You can now sign in with your new password.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? AppColors.muted : AppColors.lightTextMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
