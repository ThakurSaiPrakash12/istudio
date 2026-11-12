import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/apple_sign_in_button.dart';
import '../../widgets/auth_background.dart';
import '../../widgets/auth_mode_toggle.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/google_sign_in_button.dart';
import '../../widgets/studio_logo.dart';
import '../legal/legal_screen.dart';
import '../onboarding/app_features_showcase_screen.dart';
import 'login_form.dart';
import 'set_password_sheet.dart';
import 'signup_form.dart';
import 'signup_otp_sheet.dart';

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

  Future<void> _handleLogin(String identifier, String password) async {
    final auth = context.read<AuthProvider>();
    final success = await auth.login(identifier: identifier, password: password);
    if (!mounted) return;
    if (success) {
      AppSnackBar.success(context, 'Signed in successfully. Welcome back!');
    } else {
      _showError(auth.errorMessage ?? 'Sign in failed. Please try again.');
    }
  }

  Future<void> _handleSignup({
    required String username,
    required String email,
    required String password,
    String? phone,
  }) async {
    final auth = context.read<AuthProvider>();
    try {
      final res = await auth.sendSignupEmailOtp(
        username: username,
        email: email,
      );
      if (!mounted) return;
      final cd = (res['cooldownSeconds'] as num?)?.toInt() ?? 60;
      await SignupOtpSheet.show(
        context,
        username: username,
        email: email,
        password: password,
        phone: phone,
        initialCooldown: cd,
      );
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Unable to send verification code. Please try again.');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final auth = context.read<AuthProvider>();
    final success = await auth.signInWithGoogle();
    if (success && mounted) {
      AppSnackBar.success(context, 'Signed in with Google.');
      if (auth.user?.needsPasswordSetup == true) {
        await SetPasswordSheet.show(context);
      }
    } else if (!success && mounted && auth.errorMessage != null) {
      _showError(auth.errorMessage);
    }
  }

  Future<void> _handleAppleSignIn() async {
    final auth = context.read<AuthProvider>();
    final success = await auth.signInWithApple();
    if (success && mounted) {
      AppSnackBar.success(context, 'Signed in with Apple.');
      if (auth.user?.needsPasswordSetup == true) {
        await SetPasswordSheet.show(context);
      }
    } else if (!success && mounted && auth.errorMessage != null) {
      _showError(auth.errorMessage);
    }
  }

  void _showError(String? message) {
    if (message == null || !mounted) return;
    AppSnackBar.error(context, message);
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
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.isDark
                                  ? const Color(0xFF1E293B).withValues(alpha: 0.65)
                                  : Colors.white.withValues(alpha: 0.88),
                              border: Border.all(
                                color: context.isDark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : const Color(0xFFE2E8F0),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: context.isDark
                                      ? const Color(0xFF818CF8).withValues(alpha: 0.25)
                                      : const Color(0xFF6366F1).withValues(alpha: 0.18),
                                  blurRadius: 14,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: IconButton(
                              tooltip: context.isDark
                                  ? 'Switch to Light Theme'
                                  : 'Switch to Dark Theme',
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                context.read<ThemeProvider>().toggleTheme();
                              },
                              icon: Icon(
                                context.isDark
                                    ? Icons.light_mode_outlined
                                    : Icons.wb_sunny_outlined,
                                color: context.isDark
                                    ? const Color(0xFF93C5FD)
                                    : const Color(0xFF6366F1),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
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
                                onGoogleSignIn: _handleGoogleSignIn,
                                onAppleSignIn: _handleAppleSignIn,
                              ),
                              const SizedBox(height: 12),
                              Center(
                                child: TextButton.icon(
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.of(context).push(
                                      AppFeaturesShowcaseScreen.route(
                                        isStandalone: true,
                                      ),
                                    );
                                  },
                                  icon: Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 15,
                                    color: context.accentColor,
                                  ),
                                  label: Text(
                                    context.tr('New here? Discover all app features →'),
                                    style: GoogleFonts.plusJakartaSans(
                                      color: context.accentColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const _LegalFooter(),
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

class _LegalFooter extends StatelessWidget {
  const _LegalFooter();

  @override
  Widget build(BuildContext context) {
    final baseStyle = GoogleFonts.plusJakartaSans(
      color: context.textMuted,
      fontSize: 12,
      height: 1.5,
    );
    final linkStyle = baseStyle.copyWith(
      color: context.accentColor,
      fontWeight: FontWeight.w700,
    );

    Widget link(String label, LegalDocument doc) => InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => LegalScreen.open(context, doc),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Text(label, style: linkStyle),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(context.tr('By continuing, you agree to our '), style: baseStyle),
          link(context.tr('Terms & Conditions'), LegalDocument.terms),
          Text(context.tr(' and '), style: baseStyle),
          link(context.tr('Privacy Policy'), LegalDocument.privacy),
        ],
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
    required this.onGoogleSignIn,
    required this.onAppleSignIn,
  });

  final bool isLogin;
  final bool isLoading;
  final Future<void> Function(String identifier, String password) onLogin;
  final Future<void> Function({
    required String username,
    required String email,
    required String password,
    String? phone,
  })
  onSignup;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onAppleSignIn;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0D1527).withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.85),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.50)
                    : const Color(0x140F172A),
                blurRadius: isDark ? 36 : 28,
                spreadRadius: isDark ? 2 : 2,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 6,
                children: [
                  Text(
                    isLogin ? context.tr('Welcome') : context.tr('Create'),
                    style: GoogleFonts.playfairDisplay(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: isDark
                          ? const [
                              Color(0xFF38BDF8),
                              Color(0xFF818CF8),
                              Color(0xFFA855F7),
                            ]
                          : const [
                              Color(0xFF00B4D8),
                              Color(0xFF3B82F6),
                              Color(0xFF7C3AED),
                              Color(0xFFA855F7),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Text(
                      isLogin ? context.tr('back') : context.tr('account'),
                      style: GoogleFonts.alexBrush(
                        color: Colors.white,
                        fontSize: isLogin ? 44 : 38,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isLogin
                    ? 'Sign in to your Clients Hub account\nand continue your creative journey.'
                    : 'Join Clients Hub and start managing\nyour studio creative journey.',
                style: GoogleFonts.plusJakartaSans(
                  color: context.textSecondary,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
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
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  thickness: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.textMuted,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  thickness: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS) ...[
            AppleSignInButton(
              isLoading: isLoading,
              label: isLogin
                  ? context.tr('Sign in with Apple')
                  : context.tr('Sign up with Apple'),
              onPressed: isLoading ? null : onAppleSignIn,
            ),
            const SizedBox(height: 12),
          ],
          GoogleSignInButton(
            isLoading: isLoading,
            label: isLogin ? context.tr('Sign in with Google') : context.tr('Sign up with Google'),
            onPressed: isLoading ? null : onGoogleSignIn,
          ),
        ],
      ),
    ),
  ),
);
  }
}
