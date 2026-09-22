import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app/providers/auth_provider.dart';
import 'app/providers/events_provider.dart';
import 'app/providers/invoices_provider.dart';
import 'app/screens/auth/auth_screen.dart';
import 'app/screens/shell/app_shell.dart';
import 'app/theme/app_colors.dart';
import 'app/theme/app_theme.dart';
import 'app/widgets/studio_splash.dart';

import 'app/providers/notifications_provider.dart';
import 'app/providers/theme_provider.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error recovery: intercepts screen issues and redirects safely to Home
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (rootNavigatorKey.currentState?.canPop() ?? false) {
        rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
    });
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: AppColors.ink,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.sky.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.sky.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: AppColors.sky,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Screen Issue Detected',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Redirecting you safely back to your Studio Home...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sky,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    rootNavigatorKey.currentState
                        ?.popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.home_rounded, size: 16),
                  label: const Text(
                    'Return to Home',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.ink,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const IStudioApp());
}

class IStudioApp extends StatelessWidget {
  const IStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..bootstrap()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..bootstrap()),
        ChangeNotifierProxyProvider<AuthProvider, EventsProvider>(
          create: (_) => EventsProvider(),
          update: (_, auth, events) {
            final provider = events ?? EventsProvider();
            provider.syncAuth(auth);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<EventsProvider, NotificationsProvider>(
          create: (_) => NotificationsProvider(),
          update: (_, events, previous) {
            final notifs = previous ?? NotificationsProvider();
            notifs.syncEvents(events);
            return notifs;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, InvoicesProvider>(
          create: (_) => InvoicesProvider(),
          update: (_, auth, previous) {
            final invoices = previous ?? InvoicesProvider();
            invoices.syncAuth(auth);
            return invoices;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            navigatorKey: rootNavigatorKey,
            title: 'iStudio',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.themeMode,
            home: const _AuthGate(),
          );
        },
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isBootstrapping) {
      return const StudioSplash();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: [...previousChildren, ?currentChild],
        );
      },
      child: auth.isLoggedIn
          ? const AppShell(key: ValueKey('home'))
          : const AuthScreen(key: ValueKey('auth')),
    );
  }
}
