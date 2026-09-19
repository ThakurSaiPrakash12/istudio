import 'package:flutter/material.dart';

import '../models/studio_event.dart';

/// Universal studio palette supporting Liquid Glass Dark & Light themes
@immutable
class AppColors {
  const AppColors._();

  // ================= LUMEN Studio Palette (Electric Sky & Tactile Slate) =================
  // Radiant Sky Blue & Modern Tech Accents (Swiggy / Blinkit precision)
  static const Color sky = Color(0xFF0EA5E9);       // Sky Blue 500 (Primary Brand)
  static const Color skyLight = Color(0xFFE0F2FE);  // Sky 100 (Tint surfaces)
  static const Color skyDeep = Color(0xFF0284C7);   // Sky 600 (High contrast interactive)
  static const Color skyGlow = Color(0x260EA5E9);   // 15% Subtle Focus Ring
  static const Color skyCyan = Color(0xFF06B6D4);   // Cyan 500

  // Legacy aliases redirected to Sky Blue
  static const Color gold = sky;
  static const Color goldLight = skyLight;
  static const Color goldDeep = skyDeep;
  static const Color goldGlow = skyGlow;

  // Dark Mode Surfaces (Deep Obsidian Slate)
  static const Color ink = Color(0xFF0B0F19);        // Deep Slate Canvas
  static const Color navy = Color(0xFF131A2A);       // Dark Elevated Surface
  static const Color slate = Color(0xFF1E293B);      // Dark Card Surface
  static const Color paper = Color(0xFFF8FAFC);      // High Contrast Text
  static const Color muted = Color(0xFF94A3B8);      // Secondary Text
  static const Color mist = Color(0x6694A3B8);

  // Modern Tactile Surfaces (Dark Mode)
  static const Color glassSurfaceDark = Color(0xF2131A2A); 
  static const Color glassCardDark = Color(0xFF162032);    
  static const Color glassBorderDark = Color(0xFF24324D);  // Clean hairline border
  static const Color glassInnerDark = Color(0xFF0F1523);   // Inset container fill
  static const Color glassSpecular = Color(0x1F38BDF8);

  // Light Mode Surfaces (Clean, crisp Swiggy/Blinkit standard)
  static const Color lightScaffold = Color(0xFFF8FAFC);    // Ultra clean slate canvas
  static const Color lightCard = Color(0xFFFFFFFF);        // Pure white card
  static const Color lightTextMain = Color(0xFF0F172A);    // Crisp dark slate text
  static const Color lightTextMuted = Color(0xFF64748B);   // Balanced secondary text
  static const Color lightBorder = Color(0xFFE2E8F0);      // Hairline 0.8px border
  static const Color lightInputFill = Color(0xFFF1F5F9);   // Soft input container
  static const Color lightPrimary = Color(0xFF0284C7);     // Rich Sky Blue 600

  // Modern Tactile Surfaces (Light Mode)
  static const Color glassSurfaceLight = Color(0xF7FFFFFF);
  static const Color glassCardLight = Color(0xFFFFFFFF);
  static const Color glassBorderLight = Color(0xFFE2E8F0);
  static const Color glassInnerLight = Color(0xFFF1F5F9);

  // Aliases for backwards compatibility
  static const Color aqua = sky;
  static const Color midnight = ink;
  static const Color plum = navy;
  static const Color merlot = slate;
  static const Color blossom = sky;
  static const Color ivory = paper;
  static const Color blush = muted;

  // Gradients
  static const LinearGradient skyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
  );

  static const LinearGradient goldGradient = skyGradient;

  static const LinearGradient glassCardGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF182236),
      Color(0xFF131A2A),
    ],
  );

  static const LinearGradient glassCardGradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFFBFDFF),
    ],
  );

  // Helper resolvers for dynamic theme styling
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color scaffoldBackground(BuildContext context) =>
      isDark(context) ? ink : lightScaffold;

  static Color cardBackground(BuildContext context) =>
      isDark(context) ? glassCardDark : glassCardLight;

  static Color cardBorder(BuildContext context) =>
      isDark(context) ? glassBorderDark : glassBorderLight;

  static Color textMain(BuildContext context) =>
      isDark(context) ? paper : lightTextMain;

  static Color textMuted(BuildContext context) =>
      isDark(context) ? muted : lightTextMuted;

  static Color inputBackground(BuildContext context) =>
      isDark(context) ? glassInnerDark : lightInputFill;

  static Color innerContainerBackground(BuildContext context) =>
      isDark(context) ? glassInnerDark : glassInnerLight;

  static Color accent(BuildContext context) =>
      isDark(context) ? sky : lightPrimary;

  static Color expense(BuildContext context) =>
      isDark(context) ? const Color(0xFFF43F5E) : const Color(0xFFE11D48);

  static Color profit(BuildContext context) =>
      isDark(context) ? const Color(0xFF10B981) : const Color(0xFF059669);

  static Color statusColor(BuildContext context, EventStatus status) {
    final dark = isDark(context);
    switch (status) {
      case EventStatus.completed:
        return dark ? const Color(0xFF10B981) : const Color(0xFF059669);
      case EventStatus.inProgress:
        return dark ? sky : const Color(0xFF0284C7);
      case EventStatus.paymentDue:
        return dark ? const Color(0xFFF59E0B) : const Color(0xFFD97706);
      case EventStatus.upcoming:
        return dark ? sky : lightPrimary;
      case EventStatus.cancelled:
        return dark ? const Color(0xFFF43F5E) : const Color(0xFFDC2626);
    }
  }

  static Color urgencyCritical(BuildContext context) =>
      isDark(context) ? const Color(0xFFF43F5E) : const Color(0xFFE11D48);

  static Color urgencyWarning(BuildContext context) =>
      isDark(context) ? const Color(0xFFF59E0B) : const Color(0xFFD97706);

  static Color urgencyNotice(BuildContext context) =>
      isDark(context) ? sky : lightPrimary;

  static Color urgencyColor(BuildContext context, int daysLeft, int hoursLeft) {
    if (daysLeft == 0 && hoursLeft <= 24) {
      return urgencyCritical(context);
    } else if (daysLeft <= 3) {
      return urgencyWarning(context);
    }
    return urgencyNotice(context);
  }
}

@immutable
class StudioColors extends ThemeExtension<StudioColors> {
  const StudioColors({
    required this.blossom,
    required this.merlot,
    required this.plum,
    required this.midnight,
    required this.ivory,
    required this.blush,
    required this.mist,
    required this.cardBg,
    required this.cardBorder,
    required this.textMain,
    required this.textMuted,
    required this.innerContainerBg,
  });

  final Color blossom;
  final Color merlot;
  final Color plum;
  final Color midnight;
  final Color ivory;
  final Color blush;
  final Color mist;
  final Color cardBg;
  final Color cardBorder;
  final Color textMain;
  final Color textMuted;
  final Color innerContainerBg;

  static const StudioColors brand = StudioColors(
    blossom: AppColors.gold,
    merlot: AppColors.slate,
    plum: AppColors.navy,
    midnight: AppColors.ink,
    ivory: AppColors.paper,
    blush: AppColors.muted,
    mist: AppColors.mist,
    cardBg: AppColors.glassCardDark,
    cardBorder: AppColors.glassBorderDark,
    textMain: AppColors.paper,
    textMuted: AppColors.muted,
    innerContainerBg: AppColors.glassInnerDark,
  );

  static const StudioColors lightBrand = StudioColors(
    blossom: AppColors.lightPrimary,
    merlot: AppColors.lightBorder,
    plum: AppColors.lightInputFill,
    midnight: AppColors.lightTextMain,
    ivory: AppColors.lightTextMain,
    blush: AppColors.lightTextMuted,
    mist: Color(0x6664748B),
    cardBg: AppColors.glassCardLight,
    cardBorder: AppColors.glassBorderLight,
    textMain: AppColors.lightTextMain,
    textMuted: AppColors.lightTextMuted,
    innerContainerBg: AppColors.glassInnerLight,
  );

  @override
  StudioColors copyWith({
    Color? blossom,
    Color? merlot,
    Color? plum,
    Color? midnight,
    Color? ivory,
    Color? blush,
    Color? mist,
    Color? cardBg,
    Color? cardBorder,
    Color? textMain,
    Color? textMuted,
    Color? innerContainerBg,
  }) {
    return StudioColors(
      blossom: blossom ?? this.blossom,
      merlot: merlot ?? this.merlot,
      plum: plum ?? this.plum,
      midnight: midnight ?? this.midnight,
      ivory: ivory ?? this.ivory,
      blush: blush ?? this.blush,
      mist: mist ?? this.mist,
      cardBg: cardBg ?? this.cardBg,
      cardBorder: cardBorder ?? this.cardBorder,
      textMain: textMain ?? this.textMain,
      textMuted: textMuted ?? this.textMuted,
      innerContainerBg: innerContainerBg ?? this.innerContainerBg,
    );
  }

  @override
  StudioColors lerp(ThemeExtension<StudioColors>? other, double t) {
    if (other is! StudioColors) return this;
    return StudioColors(
      blossom: Color.lerp(blossom, other.blossom, t)!,
      merlot: Color.lerp(merlot, other.merlot, t)!,
      plum: Color.lerp(plum, other.plum, t)!,
      midnight: Color.lerp(midnight, other.midnight, t)!,
      ivory: Color.lerp(ivory, other.ivory, t)!,
      blush: Color.lerp(blush, other.blush, t)!,
      mist: Color.lerp(mist, other.mist, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      textMain: Color.lerp(textMain, other.textMain, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      innerContainerBg: Color.lerp(innerContainerBg, other.innerContainerBg, t)!,
    );
  }
}

extension StudioThemeX on BuildContext {
  bool get isDark => AppColors.isDark(this);
  StudioColors get studioColors =>
      Theme.of(this).extension<StudioColors>() ?? StudioColors.brand;
  Color get cardBg => AppColors.cardBackground(this);
  Color get cardBorder => AppColors.cardBorder(this);
  Color get textMain => AppColors.textMain(this);
  Color get textMuted => AppColors.textMuted(this);
  Color get accentColor => AppColors.accent(this);
  Color get innerBg => AppColors.innerContainerBackground(this);
  Color get scaffoldBg => AppColors.scaffoldBackground(this);
}
