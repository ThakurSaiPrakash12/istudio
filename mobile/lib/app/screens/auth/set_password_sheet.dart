import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/validators.dart';
import '../../widgets/studio_button.dart';
import '../../widgets/studio_text_field.dart';

class SetPasswordSheet extends StatefulWidget {
  const SetPasswordSheet({super.key, this.isOptional = false});

  final bool isOptional;

  static Future<bool?> show(BuildContext context, {bool isOptional = false}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: isOptional,
      enableDrag: isOptional,
      backgroundColor: Colors.transparent,
      builder: (context) => SetPasswordSheet(isOptional: isOptional),
    );
  }

  @override
  State<SetPasswordSheet> createState() => _SetPasswordSheetState();
}

class _SetPasswordSheetState extends State<SetPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.heavyImpact();
      return;
    }

    if (_passwordController.text != _confirmController.text) {
      HapticFeedback.heavyImpact();
      setState(() => _errorMessage = 'Passwords do not match.');
      AppSnackBar.error(context, 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.setPassword(_passwordController.text);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        final rootContext = Navigator.of(context, rootNavigator: true).context;
        Navigator.of(context).pop(true);
        if (rootContext.mounted) {
          AppSnackBar.success(rootContext, 'Password set successfully.');
        }
      } else {
        final message = auth.errorMessage ?? 'Unable to set password.';
        setState(() => _errorMessage = message);
        AppSnackBar.error(context, message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: widget.isOptional,
      child: Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
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
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.sky.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_reset_rounded,
                        color: AppColors.sky, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set Your Password',
                          style: TextStyle(
                            color:
                                isDark ? Colors.white : AppColors.lightTextMain,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Create a password for your account so you can sign in directly with your email or username anytime.',
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
                  if (widget.isOptional)
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                ],
              ),
              const SizedBox(height: 20),

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

              StudioTextField(
                label: 'Create password',
                hint: 'At least 8 characters',
                controller: _passwordController,
                obscureText: true,
                prefixIcon: Icons.lock_outline_rounded,
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) => Validators.password(value, isNew: true),
              ),
              const SizedBox(height: 16),

              StudioTextField(
                label: 'Confirm password',
                hint: 'Re-enter your password',
                controller: _confirmController,
                obscureText: true,
                prefixIcon: Icons.verified_user_outlined,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) =>
                    Validators.confirmPassword(value, _passwordController.text),
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),

              StudioButton(
                label: 'Save Password & Continue',
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _submit,
              ),

              if (widget.isOptional) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
                  child: Text(
                    'Skip for now',
                    style: TextStyle(
                      color: isDark ? AppColors.muted : AppColors.lightTextMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
