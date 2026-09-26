import 'package:flutter/material.dart';

import 'auth_background.dart';
import 'studio_logo.dart';
import 'uiverse_loader.dart';

class StudioSplash extends StatefulWidget {
  const StudioSplash({super.key});

  @override
  State<StudioSplash> createState() => _StudioSplashState();
}

class _StudioSplashState extends State<StudioSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final reveal = reduceMotion
        ? const AlwaysStoppedAnimation<double>(1)
        : CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

    return Scaffold(
      body: AuthBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: reveal,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.96, end: 1).animate(reveal),
                  child: const StudioLogo(),
                ),
              ),
              const SizedBox(height: 28),
              const UiverseLoader(),
            ],
          ),
        ),
      ),
    );
  }
}
