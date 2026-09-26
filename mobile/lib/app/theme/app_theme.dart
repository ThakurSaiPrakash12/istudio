import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../routes/smooth_page_route.dart';
import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static const PageTransitionsTheme _pageTransitionsTheme =
      PageTransitionsTheme(
    builders: {
      TargetPlatform.android: SmoothPageTransitionsBuilder(),
      TargetPlatform.iOS: SmoothPageTransitionsBuilder(),
      TargetPlatform.macOS: SmoothPageTransitionsBuilder(),
      TargetPlatform.windows: SmoothPageTransitionsBuilder(),
      TargetPlatform.linux: SmoothPageTransitionsBuilder(),
      TargetPlatform.fuchsia: SmoothPageTransitionsBuilder(),
    },
  );

  static ThemeData get dark {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.sky,
      onPrimary: Colors.white,
      secondary: AppColors.sky,
      onSecondary: Colors.white,
      tertiary: AppColors.pastelMint,
      onTertiary: Color(0xFF0C0E14),
      error: AppColors.pastelRose,
      onError: Colors.white,
      surface: AppColors.ink,
      onSurface: AppColors.paper,
      surfaceContainerHighest: AppColors.navy,
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.glassBorderDark,
      outlineVariant: Color(0x1AFFFFFF),
      shadow: Color(0x80000000),
      scrim: Color(0x99000000),
      inverseSurface: AppColors.paper,
      onInverseSurface: AppColors.ink,
      inversePrimary: AppColors.skyDeep,
    );

    final font = GoogleFonts.plusJakartaSansTextTheme();
    final body = font;
    final display = font;
    final textTheme = font.apply(
      bodyColor: AppColors.paper,
      displayColor: AppColors.paper,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.ink,
      canvasColor: AppColors.ink,
      pageTransitionsTheme: _pageTransitionsTheme,
      textTheme: textTheme,
      extensions: const [StudioColors.brand],
      splashFactory: InkRipple.splashFactory,
      cardTheme: CardThemeData(
        color: AppColors.glassCardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(
            color: AppColors.glassBorderDark,
            width: 0.8,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.navy,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.glassBorderDark, width: 0.8),
        ),
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: AppColors.paper,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.navy,
        modalBackgroundColor: AppColors.navy,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.glassInnerDark,
        selectedColor: AppColors.sky.withValues(alpha: 0.22),
        disabledColor: AppColors.slate.withValues(alpha: 0.2),
        labelStyle: body.bodySmall?.copyWith(color: AppColors.paper),
        secondaryLabelStyle: body.bodySmall?.copyWith(color: AppColors.sky),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: const StadiumBorder(
          side: BorderSide(color: AppColors.glassBorderDark, width: 1.1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x1FFFFFFF),
        thickness: 1,
        space: 24,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.paper,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: display.titleLarge?.copyWith(
          color: AppColors.paper,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sky,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.slate.withValues(alpha: 0.4),
          disabledForegroundColor: AppColors.mist,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: const StadiumBorder(),
          textStyle: body.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.sky,
          shape: const StadiumBorder(),
          textStyle: body.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.glassInnerDark,
        hintStyle: body.bodyMedium?.copyWith(color: AppColors.muted.withValues(alpha: 0.7)),
        labelStyle: body.bodyMedium?.copyWith(color: AppColors.muted),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(
            color: AppColors.glassBorderDark,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(
            color: AppColors.glassBorderDark,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppColors.sky, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Color(0xFFFF5252), width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Color(0xFFFF5252), width: 1.6),
        ),
        errorMaxLines: 3,
        errorStyle: body.bodySmall?.copyWith(
          color: const Color(0xFFFF5252),
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.glassCardDark,
        indicatorColor: AppColors.sky.withValues(alpha: 0.22),
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return body.labelMedium?.copyWith(
            color: selected ? AppColors.sky : AppColors.muted,
            fontWeight: FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.sky : AppColors.muted,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.navy,
        contentTextStyle: body.bodyMedium?.copyWith(color: AppColors.paper),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: AppColors.glassBorderDark),
        ),
      ),
    );
  }

  static ThemeData get light {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.sky,
      onPrimary: Colors.white,
      secondary: AppColors.sky,
      onSecondary: Colors.white,
      tertiary: AppColors.pastelMint,
      onTertiary: Color(0xFF0F172A),
      error: AppColors.pastelRose,
      onError: Colors.white,
      surface: AppColors.lightCard,
      onSurface: AppColors.lightTextMain,
      surfaceContainerHighest: AppColors.lightInputFill,
      onSurfaceVariant: AppColors.lightTextMuted,
      outline: AppColors.lightBorder,
      outlineVariant: Color(0xFFE5E7EB),
      shadow: Color(0x0F000000),
      scrim: Color(0x33000000),
      inverseSurface: AppColors.lightTextMain,
      onInverseSurface: Colors.white,
      inversePrimary: AppColors.skyDeep,
    );

    final font = GoogleFonts.plusJakartaSansTextTheme();
    final body = font;
    final display = font;
    final textTheme = font.apply(
      bodyColor: AppColors.lightTextMain,
      displayColor: AppColors.lightTextMain,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.lightScaffold,
      canvasColor: AppColors.lightScaffold,
      pageTransitionsTheme: _pageTransitionsTheme,
      textTheme: textTheme,
      extensions: const [StudioColors.lightBrand],
      splashFactory: InkRipple.splashFactory,
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.lightBorder, width: 0.8),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightCard,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: AppColors.lightTextMain,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.lightTextMuted),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightCard,
        modalBackgroundColor: AppColors.lightCard,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightInputFill,
        selectedColor: AppColors.lightPrimary.withValues(alpha: 0.16),
        disabledColor: AppColors.lightBorder,
        labelStyle: body.bodySmall?.copyWith(color: AppColors.lightTextMain),
        secondaryLabelStyle: body.bodySmall?.copyWith(color: AppColors.lightPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: const StadiumBorder(
          side: BorderSide(color: AppColors.lightBorder, width: 1.1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightBorder,
        thickness: 1,
        space: 24,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.lightTextMain,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: display.titleLarge?.copyWith(
          color: AppColors.lightTextMain,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lightPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.lightBorder,
          disabledForegroundColor: AppColors.lightTextMuted,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: const StadiumBorder(),
          textStyle: body.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.lightPrimary,
          shape: const StadiumBorder(),
          textStyle: body.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightInputFill,
        hintStyle: body.bodyMedium?.copyWith(color: AppColors.lightTextMuted),
        labelStyle: body.bodyMedium?.copyWith(color: AppColors.lightTextMuted),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppColors.lightPrimary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.6),
        ),
        errorMaxLines: 3,
        errorStyle: body.bodySmall?.copyWith(
          color: const Color(0xFFDC2626),
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.lightCard,
        indicatorColor: AppColors.lightPrimary.withValues(alpha: 0.16),
        elevation: 1,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return body.labelMedium?.copyWith(
            color: selected ? AppColors.lightPrimary : AppColors.lightTextMuted,
            fontWeight: FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.lightPrimary : AppColors.lightTextMuted,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.lightTextMain,
        contentTextStyle: body.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }
}
