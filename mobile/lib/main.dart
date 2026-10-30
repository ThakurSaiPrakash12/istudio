import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app/providers/auth_provider.dart';
import 'app/providers/events_provider.dart';
import 'app/providers/invoices_provider.dart';
import 'app/providers/notifications_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app/l10n/app_localizations.dart';
import 'app/providers/language_provider.dart';
import 'app/providers/theme_provider.dart';
import 'app/screens/auth/auth_screen.dart';
import 'app/screens/onboarding/app_features_showcase_screen.dart';
import 'app/screens/onboarding/studio_onboarding_screen.dart';
import 'app/screens/shell/app_shell.dart';
import 'app/services/crash_reporter.dart';
import 'app/theme/app_colors.dart';
import 'app/theme/app_theme.dart';
import 'app/widgets/studio_splash.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>();

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Framework UI / rendering error capture
    FlutterError.onError = (FlutterErrorDetails details) {
      CrashReporter.instance.recordFlutterError(details);
      // Keep Flutter's original diagnostics visible during development.
      // Do not replace framework errors with a custom recovery screen.
      FlutterError.presentError(details);
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
        ChangeNotifierProvider(create: (_) => LanguageProvider()..bootstrap()),
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
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, themeProvider, languageProvider, child) {
          return MaterialApp(
            navigatorKey: rootNavigatorKey,
            title: 'Clients Hub',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.themeMode,
            locale: languageProvider.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            scrollBehavior: const FluidScrollBehavior(),
            home: const _AuthGate(),
          );
        },
      ),
    );
  }
}

/// Universal 120Hz-tuned fluid scrolling behavior:
/// - Smooth bouncing scroll physics across Android, iOS, and all platforms
/// - Eliminates rigid clamping and jarring edge stops
/// - Delivers natural rubber-band momentum so list motion feels weightless
class FluidScrollBehavior extends MaterialScrollBehavior {
  const FluidScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
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
      child: !auth.isLoggedIn
          ? const AuthScreen(key: ValueKey('auth'))
          : !auth.hasSeenFeatureTour
              ? const AppFeaturesShowcaseScreen(key: ValueKey('features_tour'))
              // New user or truly incomplete profile → full onboarding form
              : (auth.user!.isProfileIncomplete && !auth.user!.hasBasicProfileFilled)
                  ? const StudioOnboardingScreen(key: ValueKey('onboarding'))
                  // Existing user with basic info filled but no Google Maps → enter app,
                  // AppShell shows a location prompt popup instead of full onboarding
                  : const AppShell(key: ValueKey('home')),
    );
  }
}
