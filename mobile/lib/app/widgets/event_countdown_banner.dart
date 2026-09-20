import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/studio_event.dart';
import '../models/studio_notification.dart';
import '../screens/events/event_details_screen.dart';
import '../routes/smooth_page_route.dart';
import '../theme/app_colors.dart';

/// Liquid Glass styled Hero 7-Day Countdown Alert Banner
class EventCountdownBanner extends StatelessWidget {
  const EventCountdownBanner({
    super.key,
    required this.event,
    this.notification,
    this.onDismiss,
  });

  final StudioEvent event;
  final StudioNotification? notification;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final diff = event.timeUntilStart;
    final days = event.daysUntilStart;
    final hours = event.hoursUntilStart;
    final mins = event.minutesUntilStart;
    final isDark = context.isDark;

    final urgencyColor = AppColors.urgencyColor(context, days, hours);
    final textMain = context.textMain;
    final textMuted = context.textMuted;

    final String urgencyHeadline;
    if (days == 0 && hours <= 0) {
      urgencyHeadline = '🔥 HAPPENING TODAY';
    } else if (days == 0) {
      urgencyHeadline = '🚨 IMMINENT SHOOT · ${hours}H LEFT';
    } else if (days <= 3) {
      final dayStr = days == 1 ? '1 DAY' : '$days DAYS';
      urgencyHeadline = '⚡ UPCOMING SHOOT · $dayStr, ${hours}H LEFT';
    } else {
      urgencyHeadline = '📅 7-DAY ALERT · $days DAYS, ${hours}H LEFT';
    }

    final radius = BorderRadius.circular(32);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  urgencyColor.withValues(alpha: 0.22),
                  const Color(0xCC0F1626),
                  const Color(0xEB0A0F1D),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  urgencyColor.withValues(alpha: 0.14),
                  Colors.white.withValues(alpha: 0.95),
                  Colors.white.withValues(alpha: 0.98),
                ],
              ),
        border: Border.all(
          color: urgencyColor.withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: urgencyColor.withValues(alpha: isDark ? 0.25 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: radius,
              onTap: () {
                Navigator.of(context).push(
                  SmoothPageRoute(
                    builder: (_) => EventDetailsScreen(eventId: event.id),
                  ),
                );
              },
              child: Stack(
                children: [
                  // Specular Glass Top Rim
                  Positioned(
                    top: 0,
                    left: 20,
                    right: 20,
                    height: 1.2,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.6),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Urgency Tag & Dismiss Button
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4.5),
                                decoration: BoxDecoration(
                                  color: urgencyColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: urgencyColor.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: urgencyColor,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: urgencyColor.withValues(alpha: 0.8),
                                            blurRadius: 5,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: Text(
                                        urgencyHeadline,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: urgencyColor,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (onDismiss != null) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: textMuted.withValues(alpha: 0.7),
                                ),
                                onPressed: onDismiss,
                                tooltip: 'Dismiss alert',
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 14),

                        // 2. Event Title & Client Subtitle
                        Text(
                          event.title,
                          style: GoogleFonts.plusJakartaSans(
                            color: textMain,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.person_outline_rounded,
                                size: 14, color: textMuted),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                '${event.clientName} · ${event.eventType} shoot at ${event.location}',
                                style: TextStyle(
                                  color: textMuted,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 3. Digital Countdown Units
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.glassInnerDark
                                : AppColors.glassInnerLight,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.glassBorderDark
                                  : AppColors.glassBorderLight,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildTimerUnit(
                                context,
                                value: days.clamp(0, 99).toString().padLeft(2, '0'),
                                unit: 'DAYS',
                                accent: urgencyColor,
                              ),
                              _buildColon(context, urgencyColor),
                              _buildTimerUnit(
                                context,
                                value: hours.clamp(0, 23).toString().padLeft(2, '0'),
                                unit: 'HOURS',
                                accent: urgencyColor,
                              ),
                              _buildColon(context, urgencyColor),
                              _buildTimerUnit(
                                context,
                                value: mins.clamp(0, 59).toString().padLeft(2, '0'),
                                unit: 'MINS',
                                accent: urgencyColor,
                              ),
                              _buildColon(context, urgencyColor),
                              _buildTimerUnit(
                                context,
                                value: (diff.inSeconds % 60)
                                    .clamp(0, 59)
                                    .toString()
                                    .padLeft(2, '0'),
                                unit: 'SECS',
                                accent: urgencyColor,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 4. Action Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                event.countdownFormatted,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: urgencyColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Open Shoot Details',
                                  style: TextStyle(
                                    color: textMain,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: textMain,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerUnit(
    BuildContext context, {
    required String value,
    required String unit,
    required Color accent,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: context.textMain,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          unit,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: context.textMuted,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildColon(BuildContext context, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: accent.withValues(alpha: 0.65),
        ),
      ),
    );
  }
}
