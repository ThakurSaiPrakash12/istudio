import 'package:flutter/material.dart';

import '../models/studio_event.dart';

/// Universal studio palette — PhonePe Deep Indigo & Warm Purple
@immutable
class AppColors {
  const AppColors._();

  // ================= PhonePe Signature Palette =================
  // Deep Indigo & Vibrant Purple (PhonePe signature)
  static const Color sky = Color(0xFF5F259F);       // Deep Indigo / PhonePe Brand Purple
  static const Color skyLight = Color(0xFFF0EBF8);  // Subtle lavender tint (chips/badges only)
  static const Color skyDeep = Color(0xFF4A148C);   // Rich Purple (High contrast interactive)
  static const Color skyGlow = Color(0x265F259F);   // 15% Subtle Focus Ring
  static const Color skyCyan = Color(0xFF6739B7);   // Vibrant Purple Accent
  static const Color receivedGreen = Color(0xFF10B981); // Emerald Green for Payments Received

  // Legacy aliases redirected to PhonePe
  static const Color gold = sky;
  static const Color goldLight = skyLight;
  static const Color goldDeep = skyDeep;
  static const Color goldGlow = skyGlow;

  // Dark Mode Surfaces (Clean Neutral Dark, NOT purple!)
  static const Color ink = Color(0xFF0F1015);        // Clean deep neutral canvas
  static const Color navy = Color(0xFF181A22);       // Dark Elevated Surface
  static const Color slate = Color(0xFF222430);      // Dark Card Surface
  static const Color paper = Color(0xFFF9FAFB);      // High Contrast Text
  static const Color muted = Color(0xFF9CA3AF);      // Neutral Secondary Text
  static const Color mist = Color(0x409CA3AF);

  // Modern Tactile Surfaces (Dark Mode)
  static const Color glassSurfaceDark = Color(0xF2181A22);
  static const Color glassCardDark = Color(0xFF181A22);
  static const Color glassBorderDark = Color(0xFF282A36);  // Clean hairline dark border
  static const Color glassInnerDark = Color(0xFF12131A);   // Inset container fill
  static const Color glassSpecular = Color(0x1F6739B7);

  // Light Mode Surfaces (Authentic PhonePe: Clean grey scaffold + Pure white cards)
  static const Color lightScaffold = Color(0xFFF4F5F8);    // Clean PhonePe grey canvas (NOT purple!)
  static const Color lightCard = Color(0xFFFFFFFF);        // Pure crisp white card
  static const Color lightTextMain = Color(0xFF111827);    // Deep neutral slate text
  static const Color lightTextMuted = Color(0xFF6B7280);   // Neutral grey secondary
  static const Color lightBorder = Color(0xFFE5E7EB);      // Hairline neutral grey border
  static const Color lightInputFill = Color(0xFFFFFFFF);   // Clean white input container
  static const Color lightPrimary = Color(0xFF5F259F);     // PhonePe Deep Purple

  // Modern Tactile Surfaces (Light Mode)
  static const Color glassSurfaceLight = Color(0xF7FFFFFF);
  static const Color glassCardLight = Color(0xFFFFFFFF);
  static const Color glassBorderLight = Color(0xFFE5E7EB);
  static const Color glassInnerLight = Color(0xFFF9FAFB);

  // Aliases for backwards compatibility
  static const Color aqua = sky;
  static const Color midnight = ink;
  static const Color plum = navy;
  static const Color merlot = slate;
  static const Color blossom = sky;
  static const Color ivory = paper;
  static const Color blush = muted;

  // Gradients
  static const LinearGradient phonePeHeaderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5F259F), Color(0xFF6739B7)],
  );

  static const LinearGradient skyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6739B7), Color(0xFF5F259F)],
  );

  static const LinearGradient goldGradient = skyGradient;

  static const LinearGradient glassCardGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E202B),
      Color(0xFF181A22),
    ],
  );

  static const LinearGradient glassCardGradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFFFFFFF),
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
      isDark(context) ? const Color(0xFFFF6B6B) : const Color(0xFFE11D48);

  static Color profit(BuildContext context) =>
      isDark(context) ? const Color(0xFF10B981) : const Color(0xFF059669);

  static Color statusColor(BuildContext context, EventStatus status) {
    final dark = isDark(context);
    switch (status) {
      case EventStatus.completed:
        return dark ? const Color(0xFF10B981) : const Color(0xFF059669);
      case EventStatus.inProgress:
        return dark ? sky : const Color(0xFF5F259F);
      case EventStatus.paymentDue:
        return dark ? const Color(0xFFFF9F43) : const Color(0xFFD97706);
      case EventStatus.upcoming:
        return dark ? sky : lightPrimary;
      case EventStatus.cancelled:
        return dark ? const Color(0xFFFF6B6B) : const Color(0xFFDC2626);
    }
  }

  static Color urgencyCritical(BuildContext context) =>
      isDark(context) ? const Color(0xFFFF6B6B) : const Color(0xFFE11D48);

  static Color urgencyWarning(BuildContext context) =>
      isDark(context) ? const Color(0xFFFF9F43) : const Color(0xFFD97706);

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
    mist: Color(0x666B5B7B),
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
