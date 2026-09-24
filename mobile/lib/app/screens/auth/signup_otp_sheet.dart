import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/studio_button.dart';

class SignupOtpSheet extends StatefulWidget {
  const SignupOtpSheet({
    super.key,
    required this.username,
    required this.phone,
    required this.password,
    this.initialCooldown = 60,
    this.initialDebugOtp,
  });

  final String username;
  final String phone;
  final String password;
  final int initialCooldown;
  final String? initialDebugOtp;

  static Future<bool?> show(
    BuildContext context, {
    required String username,
    required String phone,
    required String password,
    int initialCooldown = 60,
    String? initialDebugOtp,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SignupOtpSheet(
        username: username,
        phone: phone,
        password: password,
        initialCooldown: initialCooldown,
        initialDebugOtp: initialDebugOtp,
      ),
    );
  }

  @override
  State<SignupOtpSheet> createState() => _SignupOtpSheetState();
}

class _SignupOtpSheetState extends State<SignupOtpSheet> {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  int _cooldownSeconds = 60;
  Timer? _cooldownTimer;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startCooldown(widget.initialCooldown);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _otpFocusNodes[0].requestFocus();
      if (widget.initialDebugOtp != null &&
          widget.initialDebugOtp!.isNotEmpty &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.sky,
            duration: const Duration(seconds: 10),
            content: Text('Your verification code: ${widget.initialDebugOtp}'),
            action: SnackBarAction(
              label: 'Auto-fill',
              textColor: Colors.white,
              onPressed: () {
                final otp = widget.initialDebugOtp!;
                for (int i = 0; i < 6 && i < otp.length; i++) {
                  _otpControllers[i].text = otp[i];
                }
                _handleVerify();
              },
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
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

  Future<void> _handleResend() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();
    try {
      final res = await auth.sendSignupOtp(
        username: widget.username,
        phone: widget.phone,
      );
      final cd = (res['cooldownSeconds'] as num?)?.toInt() ?? 60;
      final debugOtp = res['debugOtp'] as String?;
      _startCooldown(cd);

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
                _handleVerify();
              },
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() =>
          _errorMessage = 'Unable to resend code. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVerify() async {
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
    final success = await auth.verifySignupAndLogin(
      username: widget.username,
      phone: widget.phone,
      password: widget.password,
      otp: otp,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() =>
            _errorMessage = auth.errorMessage ?? 'Unable to complete verification.');
      }
    }
  }

  void _onOtpChanged(int index, String value) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < 6 && i < digits.length; i++) {
        _otpControllers[i].text = digits[i];
      }
      if (digits.length >= 6) {
        _otpFocusNodes[5].unfocus();
        _handleVerify();
      } else {
        _otpFocusNodes[digits.length].requestFocus();
      }
      return;
    }

    if (value.isNotEmpty && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    if (_otpControllers.every((c) => c.text.isNotEmpty)) {
      _handleVerify();
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
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

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.sky.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_outlined,
                    color: AppColors.sky, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
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
                      'Code sent to +91 ${widget.phone}',
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
          const SizedBox(height: 20),

          // Error Banner
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

          // 6 PIN boxes
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
                    onPressed: _isLoading ? null : _handleResend,
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
            label: 'Confirm & Register Studio',
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _handleVerify,
          ),
        ],
      ),
    );
  }
}
