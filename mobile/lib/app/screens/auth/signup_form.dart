import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/validators.dart';
import '../../widgets/studio_button.dart';
import '../../widgets/studio_text_field.dart';

class SignupForm extends StatefulWidget {
  const SignupForm({
    super.key,
    required this.isLoading,
    required this.onSubmit,
  });

  final bool isLoading;
  final Future<void> Function({
    required String username,
    required String phone,
    required String password,
  })
  onSubmit;

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }

    await widget.onSubmit(
      username: _usernameController.text,
      phone: _phoneController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StudioTextField(
              label: 'Username',
              hint: 'How should we address you?',
              controller: _usernameController,
              prefixIcon: Icons.person_outline_rounded,
              autofillHints: const [AutofillHints.username],
              validator: Validators.username,
            ),
            const SizedBox(height: 16),
            StudioTextField(
              label: 'Phone number',
              hint: '10-digit mobile number',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
              autofillHints: const [AutofillHints.telephoneNumber],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: Validators.phone,
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 28),
            StudioButton(
              label: 'Create account',
              isLoading: widget.isLoading,
              onPressed: widget.isLoading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
