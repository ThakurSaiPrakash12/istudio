import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/auth_background.dart';
import '../../widgets/auth_mode_toggle.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/studio_logo.dart';
import 'login_form.dart';
import 'signup_form.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logo;
  late final Animation<double> _toggle;
  late final Animation<double> _card;
  bool _isLogin = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logo = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
    );
    _toggle = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.65, curve: Curves.easeOutCubic),
    );
    _card = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleLogin(String phone, String password) async {
    final auth = context.read<AuthProvider>();
    final success = await auth.login(phone: phone, password: password);
    if (!success && mounted) {
      _showError(auth.errorMessage);
    }
  }

  Future<void> _handleSignup({
    required String username,
    required String phone,
    required String password,
  }) async {
    final auth = context.read<AuthProvider>();
    final success = await auth.signup(
      username: username,
      phone: phone,
      password: password,
    );
    if (!success && mounted) {
      _showError(auth.errorMessage);
    }
  }

  void _showError(String? message) {
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 760;
              final maxWidth = constraints.maxWidth > 600 ? 460.0 : 520.0;
              final width = math.min(constraints.maxWidth, maxWidth);
              return Align(
                alignment: compact ? Alignment.topCenter : Alignment.center,
                child: SizedBox(
                  width: width,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: constraints.maxWidth > 600 ? 32 : 22,
                      vertical: compact ? 12 : 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FadeSlideIn(
                          animation: _logo,
                          child: StudioLogo(compact: compact),
                        ),
                        SizedBox(height: compact ? 16 : 28),
                        FadeSlideIn(
                          animation: _toggle,
                          child: AuthModeToggle(
                            isLogin: _isLogin,
                            onChanged: (value) {
                              if (_isLogin == value) return;
                              setState(() => _isLogin = value);
                              context.read<AuthProvider>().clearError();
                            },
                          ),
                        ),
                        SizedBox(height: compact ? 14 : 22),
                        FadeSlideIn(
                          animation: _card,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _AuthCard(
                                isLogin: _isLogin,
                                isLoading: isLoading,
                                onLogin: _handleLogin,
                                onSignup: _handleSignup,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.isLogin,
    required this.isLoading,
    required this.onLogin,
    required this.onSignup,
  });

  final bool isLogin;
  final bool isLoading;
  final Future<void> Function(String phone, String password) onLogin;
  final Future<void> Function({
    required String username,
    required String phone,
    required String password,
  })
  onSignup;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: context.cardBorder),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : const Color(0x0D0F172A),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isLogin ? 'Welcome back' : 'Join the studio',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: context.textMain,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isLogin
                ? 'Sign in with your phone number and password.'
                : 'Create your account to book sessions and view galleries.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.textMuted),
          ),
          const SizedBox(height: 18),
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final authError = auth.errorMessage;
              if (authError == null || authError.isEmpty) {
                return const SizedBox.shrink();
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        authError,
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => auth.clearError(),
                      child: const Icon(Icons.close_rounded,
                          color: Color(0xFFEF4444), size: 16),
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(
            width: double.infinity,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: <Widget>[...previousChildren, ?currentChild],
                  );
                },
                child: SizedBox(
                  width: double.infinity,
                  child: isLogin
                      ? LoginForm(
                          key: const ValueKey('login-form'),
                          isLoading: isLoading,
                          onSubmit: onLogin,
                        )
                      : SignupForm(
                          key: const ValueKey('signup-form'),
                          isLoading: isLoading,
                          onSubmit: onSignup,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
