import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app/providers/auth_provider.dart';
import 'app/providers/events_provider.dart';
import 'app/providers/invoices_provider.dart';
import 'app/providers/notifications_provider.dart';
import 'app/providers/theme_provider.dart';
import 'app/screens/auth/auth_screen.dart';
import 'app/screens/shell/app_shell.dart';
import 'app/services/crash_reporter.dart';
import 'app/theme/app_colors.dart';
import 'app/theme/app_theme.dart';
import 'app/widgets/error_boundary.dart';
import 'app/widgets/studio_splash.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>();

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Framework UI / rendering error capture
    FlutterError.onError = (FlutterErrorDetails details) {
      CrashReporter.instance.recordFlutterError(details);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (rootNavigatorKey.currentState?.canPop() ?? false) {
          rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
        }
      });
    };

    // 2. Uncaught asynchronous & engine exceptions (prevents OS termination)
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      CrashReporter.instance.recordError(
        error,
        stack,
        reason: 'PlatformDispatcher uncaught error',
      );
      return true; // Mark as handled to prevent OS crash dialogs or app termination
    };

    // 3. Graceful fallback widget for UI rendering exceptions
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return StudioErrorRecoveryView(
        error: details.exception,
        stackTrace: details.stack,
        onReturnHome: () {
          rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
        },
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
  }, (error, stack) {
    CrashReporter.instance.recordError(
      error,
      stack,
      reason: 'runZonedGuarded root zone error',
      fatal: true,
    );
  });
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
            title: 'Clients Hub',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.themeMode,
            builder: (context, childWidget) {
              return GlobalErrorBoundary(
                child: childWidget ?? const SizedBox.shrink(),
              );
            },
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
