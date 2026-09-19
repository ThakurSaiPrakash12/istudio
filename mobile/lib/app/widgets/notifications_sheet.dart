import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/studio_notification.dart';
import '../providers/notifications_provider.dart';
import '../screens/events/event_details_screen.dart';
import '../theme/app_colors.dart';

enum NotificationFilter {
  all,
  within7Days,
  urgent,
  payments,
}

class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NotificationsSheet(),
    );
  }

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  NotificationFilter _selectedFilter = NotificationFilter.all;

  @override
  Widget build(BuildContext context) {
    final notifsProvider = context.watch<NotificationsProvider>();
    final all = notifsProvider.allNotifications;
    final textMain = context.textMain;
    final textMuted = context.textMuted;
    final accent = context.accentColor;
    final isDark = context.isDark;

    // Filter notifications based on tab
    final filtered = all.where((n) {
      switch (_selectedFilter) {
        case NotificationFilter.all:
          return true;
        case NotificationFilter.within7Days:
          return n.urgency != NotificationUrgency.payment;
        case NotificationFilter.urgent:
          return n.urgency == NotificationUrgency.critical ||
              n.urgency == NotificationUrgency.warning;
        case NotificationFilter.payments:
          return n.urgency == NotificationUrgency.payment;
      }
    }).toList();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: context.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: textMuted.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Notifications',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: textMain,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (notifsProvider.unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.urgencyCritical(context),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${notifsProvider.unreadCount} new',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Live 7-day countdowns & booking alerts',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (all.isNotEmpty)
                  TextButton(
                    onPressed: () => notifsProvider.markAllAsRead(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                    child: Text(
                      'Mark all read',
                      style: TextStyle(
                        color: accent,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: textMuted, size: 22),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Filter tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip(
                  context,
                  label: 'All (${all.length})',
                  filter: NotificationFilter.all,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  label:
                      'Within 7 Days (${notifsProvider.upcomingShootNotifications.length})',
                  filter: NotificationFilter.within7Days,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  label: 'Urgent',
                  filter: NotificationFilter.urgent,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  label: 'Payments',
                  filter: NotificationFilter.payments,
                ),
              ],
            ),
          ),
          const Divider(height: 16),

          // List of notifications
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState(context)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final notif = filtered[index];
                      return _buildNotificationCard(
                          context, notif, notifsProvider);
                    },
                  ),
          ),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required NotificationFilter filter,
  }) {
    final isSelected = _selectedFilter == filter;
    final accent = context.accentColor;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _selectedFilter = filter);
      },
      selectedColor: accent.withValues(alpha: 0.22),
      backgroundColor: context.innerBg,
      side: BorderSide(
        color: isSelected ? accent : context.cardBorder,
      ),
      labelStyle: TextStyle(
        color: isSelected ? accent : context.textMain,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    StudioNotification notif,
    NotificationsProvider provider,
  ) {
    final color = notif.urgency == NotificationUrgency.critical
        ? AppColors.urgencyCritical(context)
        : (notif.urgency == NotificationUrgency.warning
            ? AppColors.urgencyWarning(context)
            : (notif.urgency == NotificationUrgency.payment
                ? const Color(0xFFF59E0B)
                : AppColors.urgencyNotice(context)));

    final isUnread = !notif.isRead;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        provider.markAsRead(notif.id);
        if (notif.eventId != null) {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            PageRouteBuilder<void>(
              transitionDuration: const Duration(milliseconds: 280),
              pageBuilder: (_, _, _) =>
                  EventDetailsScreen(eventId: notif.eventId!),
              transitionsBuilder: (_, animation, _, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUnread
              ? color.withValues(alpha: 0.08)
              : context.innerBg.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isUnread
                ? color.withValues(alpha: 0.45)
                : context.cardBorder.withValues(alpha: 0.3),
            width: isUnread ? 1.2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(
                notif.urgency == NotificationUrgency.payment
                    ? Icons.receipt_long_rounded
                    : Icons.camera_alt_outlined,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            color: context.textMain,
                            fontSize: 14.5,
                            fontWeight:
                                isUnread ? FontWeight.w700 : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.message,
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Countdown Badge & Action
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: color.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          notif.countdownBadge,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: context.textMuted.withValues(alpha: 0.6),
                        ),
                        onPressed: () => provider.dismiss(notif.id),
                        tooltip: 'Dismiss',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 48,
            color: context.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'All caught up',
            style: TextStyle(
              color: context.textMain,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No notifications for the selected filter.',
            style: TextStyle(
              color: context.textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
