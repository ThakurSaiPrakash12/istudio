import 'package:flutter/material.dart';

import '../screens/auth/auth_screen.dart';
import '../screens/shell/app_shell.dart';
import 'smooth_page_route.dart';

class AppRoutes {
  const AppRoutes._();

  static const String auth = '/';
  static const String home = '/home';
}

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.auth:
        return SmoothPageRoute(
          settings: settings,
          builder: (_) => const AuthScreen(),
        );
      case AppRoutes.home:
        return SmoothPageRoute(
          settings: settings,
          builder: (_) => const AppShell(),
        );
      default:
        return SmoothPageRoute(
          settings: settings,
          builder: (_) => const AuthScreen(),
        );
    }
  }
}
