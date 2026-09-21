import 'dart:convert';
import 'package:flutter/material.dart';

import '../services/api_config.dart';
import '../theme/app_colors.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    this.logoUrl,
    this.size = 44,
    this.heroTag,
  });

  final String? logoUrl;
  final double size;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final resolved = ApiConfig.resolveMedia(logoUrl);
    final accent = context.accentColor;
    final iconColor = isDark ? Colors.white : AppColors.lightPrimary;

    Widget avatarContent;
    if (resolved.isEmpty) {
      avatarContent = Icon(
        Icons.camera_alt_rounded,
        color: iconColor,
        size: size * 0.42,
      );
    } else if (resolved.startsWith('data:image/')) {
      try {
        final base64Str = resolved.split(',').last;
        final bytes = base64Decode(base64Str);
        avatarContent = Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.camera_alt_rounded,
            color: iconColor,
            size: size * 0.42,
          ),
        );
      } catch (_) {
        avatarContent = Icon(
          Icons.camera_alt_rounded,
          color: iconColor,
          size: size * 0.42,
        );
      }
    } else {
      avatarContent = Image.network(
        resolved,
        fit: BoxFit.cover,
        width: size,
        height: size,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: SizedBox(
              width: size * 0.35,
              height: size * 0.35,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: accent,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.camera_alt_rounded,
            color: iconColor,
            size: size * 0.42,
          );
        },
      );
    }

    final container = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? AppColors.glassCardDark : AppColors.lightInputFill,
        border: Border.all(
          color: isDark ? AppColors.glassBorderDark : AppColors.lightBorder,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.25) : const Color(0x0A0F172A),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(child: avatarContent),
    );

    if (heroTag != null && heroTag!.isNotEmpty) {
      return Hero(tag: heroTag!, child: container);
    }

    return container;
  }
}
