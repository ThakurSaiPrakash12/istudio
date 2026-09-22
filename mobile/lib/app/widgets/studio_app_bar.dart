import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/notifications_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import 'notifications_sheet.dart';

class StudioAppBar extends StatelessWidget implements PreferredSizeWidget {
  const StudioAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.showNotificationBell = true,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showNotificationBell;

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 64 : 78);

  @override
  Widget build(BuildContext context) {
    final unreadCount = showNotificationBell
        ? (context.watch<NotificationsProvider?>()?.unreadCount ?? 0)
        : 0;
    final hasUrgent = showNotificationBell
        ? (context.watch<NotificationsProvider?>()?.hasUrgentAlert ?? false)
        : false;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => LinearGradient(
                        colors: context.isDark
                            ? const [
                                Color(0xFFFFFFFF),
                                Color(0xFFBAE6FD),
                                Color(0xFF38BDF8),
                              ]
                            : const [
                                Color(0xFF0F172A),
                                Color(0xFF0284C7),
                              ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(bounds),
                      child: Text(
                        title,
                        maxLines: 1,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted(context),
                              letterSpacing: 0.2,
                            ),
                      ),
                    ),
                ],
              ),
            ),
            // Theme toggle with smooth pill bg
            Container(
              decoration: BoxDecoration(
                color: AppColors.innerContainerBackground(context).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: IconButton(
                tooltip: context.isDark
                    ? 'Switch to Light mode'
                    : 'Switch to Dark mode',
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) => RotationTransition(
                    turns: Tween(begin: 0.75, end: 1.0).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: Icon(
                    context.isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    key: ValueKey(context.isDark),
                    color: AppColors.textMuted(context),
                    size: 20,
                  ),
                ),
                onPressed: () =>
                    context.read<ThemeProvider?>()?.toggleTheme(),
              ),
            ),
            if (showNotificationBell)
              _NotificationBellButton(
                unreadCount: unreadCount,
                hasUrgent: hasUrgent,
              ),
            ...?actions,
          ],
        ),
      ),
    );
  }
}

class _NotificationBellButton extends StatelessWidget {
  const _NotificationBellButton({
    required this.unreadCount,
    required this.hasUrgent,
  });

  final int unreadCount;
  final bool hasUrgent;

  @override
  Widget build(BuildContext context) {
    final badgeColor = hasUrgent
        ? AppColors.urgencyCritical(context)
        : AppColors.accent(context);

    return Semantics(
      label: 'Notifications ($unreadCount unread)',
      button: true,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            tooltip: 'Notifications',
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                unreadCount > 0
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none_rounded,
                key: ValueKey(unreadCount > 0),
                color: AppColors.textMain(context),
                size: 24,
              ),
            ),
            onPressed: () => NotificationsSheet.show(context),
          ),
          if (unreadCount > 0)
            Positioned(
              top: 8,
              right: 8,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: badgeColor.withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
