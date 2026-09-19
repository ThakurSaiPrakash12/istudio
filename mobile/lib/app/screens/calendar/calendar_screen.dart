import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/studio_event.dart';
import '../../providers/events_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/countdown_chip.dart';
import '../../widgets/month_calendar.dart';
import '../../widgets/studio_app_bar.dart';
import '../../widgets/studio_card.dart';
import '../events/create_event_sheet.dart';
import '../events/event_details_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  late AnimationController _enterController;

  static final _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _enterController.dispose();
    super.dispose();
  }

  Animation<double> _staggered(double begin, double end) =>
      CurvedAnimation(
        parent: _enterController,
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
      );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventsProvider>();
    final allEvents = provider.events;
    final today = _dateOnly(DateTime.now());

    final textMain = context.textMain;
    final textMuted = context.textMuted;
    final accent = context.accentColor;

    final dayEvents = allEvents.where((event) {
      final date = event.startsAt;
      return date.year == _selected.year &&
          date.month == _selected.month &&
          date.day == _selected.day;
    }).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    final upcomingEvents = allEvents
        .where((event) {
          final eventDay = _dateOnly(event.startsAt);
          final hasUpcomingStatus = event.status == EventStatus.upcoming ||
              event.status == EventStatus.inProgress;
          return hasUpcomingStatus && !eventDay.isBefore(today);
        })
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    final marked = allEvents
        .map(
          (event) => DateTime(
            event.startsAt.year,
            event.startsAt.month,
            event.startsAt.day,
          ),
        )
        .toSet();

    final upcomingDays =
        upcomingEvents.map((event) => _dateOnly(event.startsAt)).toSet();
    final nearestUpcomingDay = upcomingEvents.isEmpty
        ? null
        : _dateOnly(upcomingEvents.first.startsAt);

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            children: [
              StudioAppBar(
                title: 'Calendar',
                subtitle: 'Booked sessions & shoot schedule',
                actions: [
                  IconButton(
                    tooltip: 'Book Shoot',
                    icon: Icon(Icons.add_circle_outline_rounded,
                        color: accent, size: 22),
                    onPressed: () => CreateEventSheet.show(context),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                  children: [
                    // Calendar Card
                    FadeTransition(
                      opacity: _staggered(0.0, 0.35),
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        ).animate(_staggered(0.0, 0.35)),
                        child: StudioCard(
                          borderRadius: 28,
                          padding: const EdgeInsets.all(16),
                          child: MonthCalendar(
                            visibleMonth: _month,
                            selectedDay: _selected,
                            markedDays: marked,
                            upcomingDays: upcomingDays,
                            nearestUpcomingDay: nearestUpcomingDay,
                            onMonthChanged: (value) =>
                                setState(() => _month = value),
                            onDaySelected: (value) =>
                                setState(() => _selected = value),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Selected Day Header
                    FadeTransition(
                      opacity: _staggered(0.15, 0.50),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat('EEEE, d MMMM').format(_selected),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.playfairDisplay(
                                color: textMain,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: accent.withValues(alpha: 0.28)),
                            ),
                            child: Text(
                              '${dayEvents.length} ${dayEvents.length == 1 ? 'Shoot' : 'Shoots'}',
                              style: TextStyle(
                                color: accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Day Events
                    FadeTransition(
                      opacity: _staggered(0.30, 0.70),
                      child: dayEvents.isEmpty
                          ? StudioCard(
                              borderRadius: 28,
                              padding: const EdgeInsets.all(24),
                              child: Center(
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: accent.withValues(alpha: 0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.event_available_outlined,
                                        color: textMuted.withValues(alpha: 0.6),
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'No shoots booked for this date.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Column(
                              children: dayEvents
                                  .map(
                                    (event) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: _buildEventCard(context, event),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openEventDetails(BuildContext context, StudioEvent event) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, _, _) => EventDetailsScreen(eventId: event.id),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, StudioEvent event) {
    final amountDue = event.remainingAmount;
    final amountText =
        amountDue > 0 ? _currency.format(amountDue) : 'Paid in Full';
    final accent = context.accentColor;
    final textMain = context.textMain;
    final textMuted = context.textMuted;

    return StudioCard(
      borderRadius: 28,
      onTap: () => _openEventDetails(context, event),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Circular monogram
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.25),
                      accent.withValues(alpha: 0.08),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: accent.withValues(alpha: 0.30)),
                ),
                child: Center(
                  child: Text(
                    event.clientName.isNotEmpty
                        ? event.clientName.characters.first.toUpperCase()
                        : 'S',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textMain,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${event.clientName} · ${event.eventType}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (event.isWithin7Days)
                CountdownChip(
                  daysLeft: event.daysUntilStart,
                  hoursLeft: event.hoursUntilStart,
                  compact: true,
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    event.eventType,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Time & Location pill
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: context.innerBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded, size: 14, color: accent),
                const SizedBox(width: 6),
                Text(
                  '${event.startTime} – ${event.endTime}',
                  style: TextStyle(
                      color: textMain,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 16),
                Icon(Icons.location_on_outlined,
                    size: 14, color: textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    event.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textMuted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Balance: $amountText',
                style: TextStyle(
                  color: amountDue > 0
                      ? AppColors.urgencyWarning(context)
                      : const Color(0xFF10B981),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Details',
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(Icons.arrow_forward_ios_rounded,
                      color: accent, size: 10),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
