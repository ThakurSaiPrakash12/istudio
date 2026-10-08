import 'package:flutter/material.dart';

import '../models/studio_event.dart';

/// Universal studio palette — Unique Pastel Liquid Glass Spectrum
@immutable
class AppColors {
  const AppColors._();

  // ================= Unique Pastel Studio Palette =================
  // Luminous Pastel Periwinkle (Strictly 0xFF818CF8 maintained as primary brand)
  static const Color sky = Color(0xFF818CF8);       // Luminous Pastel Periwinkle (Primary Brand)
  static const Color skyLight = Color(0xFFEEF2FF);  // Soft Periwinkle Tint (chips/badges)
  static const Color skyDeep = Color(0xFF6366F1);   // Radiant Iris Accent
  static const Color skyGlow = Color(0x33818CF8);   // 20% Pastel Periwinkle Focus/Aura Ring
  static const Color skyCyan = Color(0xFFA5B4FC);   // Soft Periwinkle Mist
  
  // Studio Pastel Spectrum (Strictly 0xFF818CF8 maintained, zero peach/pink gradients)
  static const Color pastelPeach = Color(0xFF818CF8); // Mapped strictly to 0xFF818CF8
  static const Color pastelMint = Color(0xFF6EE7B7);  // Fresh Pastel Mint (Earnings / Paid / Success)
  static const Color pastelRose = Color(0xFF818CF8);  // Mapped to 0xFF818CF8 per user instruction
  static const Color receivedGreen = pastelMint;      // Pastel Mint for Payments Received

  // Aliases for compatibility
  static const Color gold = Color(0xFF818CF8);
  static const Color goldLight = Color(0xFFEEF2FF);
  static const Color goldDeep = Color(0xFF6366F1);
  static const Color goldGlow = Color(0x33818CF8);

  // Dark Mode Surfaces (Obsidian Mist with Refractive Depth)
  static const Color ink = Color(0xFF0C0E14);        // Cosmic obsidian canvas
  static const Color navy = Color(0xFF141824);       // Elevated Surface
  static const Color slate = Color(0xFF1C2232);      // Elevated Card Surface
  static const Color paper = Color(0xFFF8FAFC);      // Crisp Text
  static const Color muted = Color(0xFF94A3B8);      // Secondary Text
  static const Color mist = Color(0x3394A3B8);

  // Liquid Glass Surfaces (Dark Mode - Full Vibrancy & Refraction with Substantial Background)
  static const Color glassSurfaceDark = Color(0xF0141824); // Frosted liquid glass body
  static const Color glassCardDark = Color(0xEB161C2C);    // 92% deep frosted liquid glass card
  static const Color glassSheetDark = Color(0xF5121622);   // 96% frosted sheet backdrop
  static const Color glassBorderDark = Color(0x33A5B4FC);  // Pastel periwinkle refractive rim
  static const Color glassInnerDark = Color(0x2B101420);   // Inset container fill
  static const Color glassSpecular = Color(0x38FFFFFF);    // Specular highlight on glass edge

  // Light Mode Surfaces (Pearlescent Crystal with Soft Pastel Glow)
  static const Color lightScaffold = Color(0xFFF7F8FC);    // Pearlescent canvas
  static const Color lightCard = Color(0xEBFFFFFF);        // Frosted milk glass card
  static const Color lightSheet = Color(0xF8FFFFFF);       // Frosted milk glass sheet
  static const Color lightTextMain = Color(0xFF0F172A);    // Deep slate text
  static const Color lightTextMuted = Color(0xFF64748B);   // Slate muted text
  static const Color lightBorder = Color(0x29818CF8);      // Soft pastel periwinkle hairline border
  static const Color lightInputFill = Color(0xF5FFFFFF);   // Clean frosted input fill
  static const Color lightPrimary = Color(0xFF818CF8);     // Pastel Periwinkle

  // Liquid Glass Surfaces (Light Mode)
  static const Color glassSurfaceLight = Color(0xEBFFFFFF);
  static const Color glassCardLight = Color(0xEBFFFFFF);
  static const Color glassBorderLight = Color(0x33818CF8);
  static const Color glassInnerLight = Color(0x73EEF2FF);

  // Aliases for backwards compatibility
  static const Color aqua = sky;
  static const Color midnight = ink;
  static const Color plum = navy;
  static const Color merlot = slate;
  static const Color blossom = sky;
  static const Color ivory = paper;
  static const Color blush = muted;

  // Gradients (Strictly 0xFF818CF8 Periwinkle / Iris spectrum - NO peach, NO pink)
  static const LinearGradient studioHeaderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E2436),
      Color(0xFF151926),
    ],
  );

  static const LinearGradient skyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF818CF8), Color(0xFF6366F1)],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF818CF8), Color(0xFF6366F1)],
  );

  static const LinearGradient glassCardGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xEB222B3D),
      Color(0xEB161C2C),
    ],
  );

  static const LinearGradient glassCardGradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xF5FFFFFF),
      Color(0xD9F3F6FD),
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
      pastelRose;

  static Color profit(BuildContext context) =>
      pastelMint;

  static Color statusColor(BuildContext context, EventStatus status) {
    switch (status) {
      case EventStatus.completed:
        return pastelMint;
      case EventStatus.inProgress:
        return sky;
      case EventStatus.paymentDue:
        return pastelPeach;
      case EventStatus.upcoming:
        return sky;
      case EventStatus.cancelled:
        return pastelRose;
    }
  }

  static Color eventDisplayStatusColor(BuildContext context, String displayStatus) {
    switch (displayStatus) {
      case 'Completed':
        return pastelMint;
      case 'Upcoming':
      case 'Today':
      case 'Past · In Progress':
        return sky;
      case 'Past / Needs Update':
        return pastelPeach;
      case 'Cancelled':
      default:
        return pastelRose;
    }
  }

  static Color urgencyCritical(BuildContext context) =>
      pastelRose;

  static Color urgencyWarning(BuildContext context) =>
      pastelPeach;

  static Color urgencyNotice(BuildContext context) =>
      sky;

  static Color urgencyColor(BuildContext context, int daysLeft, int hoursLeft) {
    if (daysLeft == 0 && hoursLeft <= 24) {
      return urgencyCritical(context);
    } else if (daysLeft <= 3) {
      return urgencyWarning(context);
    }
    return urgencyNotice(context);
  }
  // ================= 26. Full Light + Dark Studio Theme Palette =================
  // Dark Theme Palette Specifications
  static const Color darkBg1 = Color(0xFF070A12);
  static const Color darkBg2 = Color(0xFF0B1020);
  static const Color darkBg3 = Color(0xFF10172A);

  static const Color darkSurface1 = Color(0xFF111827);
  static const Color darkSurface2 = Color(0xFF151D30);
  static const Color darkSurface3 = Color(0xFF182136);

  static const Color darkTextPrimary = Color(0xFFF5F7FF);
  static const Color darkTextSecondary = Color(0xFFA7B1C8);
  static const Color darkTextMuted = Color(0xFF69748C);
  static const Color darkBorderTransparent = Color(0x2EFFFFFF);

  // Light Theme Palette Specifications
  static const Color lightBg1 = Color(0xFFF6F8FC);
  static const Color lightBg2 = Color(0xFFEEF2F8);
  static const Color lightBg3 = Color(0xFFFFFFFF);

  static const Color lightSurface1 = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFF3F5FA);

  static const Color lightTextPrimary = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF5B6475);
  static const Color lightTextTertiary = Color(0xFF7B8496);
  static const Color lightBorderColor = Color(0xFFDCE2EE);

  // Accents
  // Dark: Cyan -> Blue -> Violet
  static const Color darkAccentCyan = Color(0xFF00E5FF);
  static const Color darkAccentBlue = Color(0xFF38BDF8);
  static const Color darkAccentIndigo = Color(0xFF6366F1);
  static const Color darkAccentViolet = Color(0xFF8B5CF6);

  // Light: Deeper contrast Cyan -> Blue -> Violet
  static const Color lightAccentCyan = Color(0xFF0891B2);
  static const Color lightAccentBlue = Color(0xFF4F46E5);
  static const Color lightAccentViolet = Color(0xFF7C3AED);

  // Gradients matching the luminous signature cyan -> blue -> violet aesthetic
  static const LinearGradient darkCtaGradient = LinearGradient(
    colors: [
      Color(0xFF00E5FF),
      Color(0xFF38BDF8),
      Color(0xFF6366F1),
      Color(0xFFA855F7),
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient lightCtaGradient = LinearGradient(
    colors: [
      Color(0xFF00C6FF),
      Color(0xFF3B82F6),
      Color(0xFF8B5CF6),
      Color(0xFFA855F7),
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient darkToggleGradient = LinearGradient(
    colors: [
      Color(0xFF00E5FF),
      Color(0xFF38BDF8),
      Color(0xFF6366F1),
      Color(0xFFA855F7),
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient lightToggleGradient = LinearGradient(
    colors: [
      Color(0xFF00C6FF),
      Color(0xFF3B82F6),
      Color(0xFF8B5CF6),
      Color(0xFFA855F7),
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
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
    blossom: AppColors.sky,
    merlot: AppColors.slate,
    plum: AppColors.navy,
    midnight: AppColors.ink,
    ivory: AppColors.paper,
    blush: AppColors.muted,
    mist: AppColors.mist,
    cardBg: AppColors.glassCardDark,
    cardBorder: AppColors.glassBorderDark,
    textMain: AppColors.darkTextPrimary,
    textMuted: AppColors.darkTextMuted,
    innerContainerBg: AppColors.glassInnerDark,
  );

  static const StudioColors lightBrand = StudioColors(
    blossom: AppColors.lightAccentBlue,
    merlot: AppColors.lightBorderColor,
    plum: AppColors.lightSurface2,
    midnight: AppColors.lightTextPrimary,
    ivory: AppColors.lightTextPrimary,
    blush: AppColors.lightTextMuted,
    mist: Color(0x666B5B7B),
    cardBg: AppColors.lightSurface1,
    cardBorder: AppColors.lightBorderColor,
    textMain: AppColors.lightTextPrimary,
    textMuted: AppColors.lightTextMuted,
    innerContainerBg: AppColors.lightSurface2,
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
      Theme.of(this).extension<StudioColors>() ?? (isDark ? StudioColors.brand : StudioColors.lightBrand);
  Color get cardBg => isDark
      ? AppColors.darkSurface1.withValues(alpha: 0.78)
      : AppColors.lightSurface1.withValues(alpha: 0.92);
  Color get cardBorder =>
      isDark ? AppColors.darkBorderTransparent : AppColors.lightBorderColor;
  Color get textMain =>
      isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  Color get textSecondary =>
      isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
  Color get textMuted =>
      isDark ? AppColors.darkTextMuted : AppColors.lightTextTertiary;
  Color get accentColor =>
      isDark ? AppColors.darkAccentBlue : AppColors.lightAccentBlue;
  Color get inputBg => isDark
      ? AppColors.darkSurface2.withValues(alpha: 0.60)
      : AppColors.lightSurface2;
  Color get inputBorder =>
      isDark ? Colors.white.withValues(alpha: 0.12) : AppColors.lightBorderColor;
  Color get inputFocusBorder =>
      isDark ? AppColors.darkAccentBlue : AppColors.lightAccentBlue;
  Color get innerBg => isDark
      ? AppColors.darkSurface2
      : AppColors.lightSurface2;
  Color get scaffoldBg =>
      isDark ? AppColors.darkBg1 : AppColors.lightBg1;
  LinearGradient get ctaGradient =>
      isDark ? AppColors.darkCtaGradient : AppColors.lightCtaGradient;
  LinearGradient get toggleGradient =>
      isDark ? AppColors.darkToggleGradient : AppColors.lightToggleGradient;
}
