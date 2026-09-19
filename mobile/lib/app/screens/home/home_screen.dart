import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/studio_event.dart';
import '../../providers/auth_provider.dart';
import '../../providers/events_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/countdown_chip.dart';
import '../../widgets/event_countdown_banner.dart';
import '../../widgets/notifications_sheet.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/studio_app_bar.dart';
import '../../widgets/studio_card.dart';
import '../events/create_event_sheet.dart';
import '../events/event_details_screen.dart';
import '../events/past_events_screen.dart';
import '../events/upcoming_events_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _staggerController;
  int _currentCarouselIndex = 0;
  bool _dismissedHeroAlert = false;

  static final _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Animation<double> _staggered(double begin, double end) =>
      CurvedAnimation(
        parent: _staggerController,
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
      );

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final eventsProvider = context.watch<EventsProvider>();
    final notifsProvider = context.watch<NotificationsProvider?>();

    final upcoming = eventsProvider.upcomingEvents;
    final past = eventsProvider.pastEvents.take(4).toList();

    final shootsWithin7Days = upcoming.where((e) => e.isWithin7Days).toList();
    final nearestHeroEvent =
        shootsWithin7Days.isNotEmpty ? shootsWithin7Days.first : null;

    final totalBalanceDue =
        upcoming.fold(0.0, (acc, e) => acc + e.remainingAmount);

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            children: [
              StudioAppBar(
                title: user?.displayStudioName ?? 'LUMEN',
                subtitle: 'Photography Atelier',
                showNotificationBell: true,
                actions: [
                  Semantics(
                    button: true,
                    label: 'Open profile',
                    child: IconButton(
                      tooltip: 'Profile',
                      onPressed: () {
                        Navigator.of(context).push(
                          PageRouteBuilder<void>(
                            transitionDuration:
                                const Duration(milliseconds: 280),
                            pageBuilder: (_, _, _) =>
                                const ProfileScreen(),
                            transitionsBuilder: (_, animation, _, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                          ),
                        );
                      },
                      icon: ProfileAvatar(
                          logoUrl: user?.logoUrl, size: 40),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                  children: [
                    // 1. Welcome Greeting & Studio Header
                    _AnimatedSection(
                      animation: _staggered(0.0, 0.25),
                      child: _buildEditorialHeader(
                        context,
                        ownerName: user?.displayOwner ?? 'Photographer',
                        greeting: _getGreeting(),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 2. KPI Summary Ribbon
                    _AnimatedSection(
                      animation: _staggered(0.08, 0.35),
                      child: _buildKpiRibbon(
                        context,
                        upcomingCount: upcoming.length,
                        within7DaysCount: shootsWithin7Days.length,
                        balanceDue: totalBalanceDue,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 3. 7-Day Countdown Alert Hero Banner
                    if (nearestHeroEvent != null &&
                        !_dismissedHeroAlert) ...[
                      _AnimatedSection(
                        animation: _staggered(0.15, 0.45),
                        child: EventCountdownBanner(
                          event: nearestHeroEvent,
                          onDismiss: () =>
                              setState(() => _dismissedHeroAlert = true),
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],

                    // 4. Quick Action Controls Bar
                    _AnimatedSection(
                      animation: _staggered(0.20, 0.50),
                      child: _buildQuickActionBar(context, notifsProvider),
                    ),
                    const SizedBox(height: 26),

                    // 5. Upcoming Events Section Header
                    _AnimatedSection(
                      animation: _staggered(0.28, 0.58),
                      child: _buildSectionHeader(
                        context,
                        title: 'Upcoming Events',
                        badgeCount: upcoming.length,
                        actionLabel: 'View all →',
                        onAction: () {
                          Navigator.of(context).push(
                            PageRouteBuilder<void>(
                              transitionDuration:
                                  const Duration(milliseconds: 280),
                              pageBuilder: (_, _, _) =>
                                  const UpcomingEventsScreen(),
                              transitionsBuilder:
                                  (_, animation, _, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 6. Upcoming Events Carousel
                    _AnimatedSection(
                      animation: _staggered(0.35, 0.65),
                      child: upcoming.isEmpty
                          ? _buildEmptyUpcomingState(context)
                          : _buildUpcomingCarousel(
                              context, upcoming.take(6).toList()),
                    ),

                    const SizedBox(height: 30),

                    // 7. Past Events Portfolio Header
                    _AnimatedSection(
                      animation: _staggered(0.45, 0.75),
                      child: _buildSectionHeader(
                        context,
                        title: 'Past Events',
                        actionLabel: 'View all →',
                        onAction: () {
                          Navigator.of(context).push(
                            PageRouteBuilder<void>(
                              transitionDuration:
                                  const Duration(milliseconds: 280),
                              pageBuilder: (_, _, _) =>
                                  const PastEventsScreen(),
                              transitionsBuilder:
                                  (_, animation, _, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 8. Past Events List
                    _AnimatedSection(
                      animation: _staggered(0.55, 0.85),
                      child: past.isEmpty
                          ? StudioCard(
                              borderRadius: 999,
                              padding: const EdgeInsets.all(22),
                              child: Center(
                                child: Text(
                                  'No completed shoots recorded yet.',
                                  style: TextStyle(
                                    color: context.textMuted
                                        .withValues(alpha: 0.8),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            )
                          : Column(
                              children: past
                                  .map((event) => Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: 12),
                                        child: _buildPastEventCard(
                                            context, event),
                                      ))
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

  // ================= 1. Editorial Header =================
  Widget _buildEditorialHeader(
    BuildContext context, {
    required String ownerName,
    required String greeting,
  }) {
    final textMain = context.textMain;
    final textMuted = context.textMuted;
    final accent = context.accentColor;
    final dateStr = DateFormat('EEEE, d MMMM').format(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: accent.withValues(alpha: 0.30),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 12, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    'PRO STUDIO',
                    style: TextStyle(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                dateStr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '$greeting, $ownerName',
          style: GoogleFonts.playfairDisplay(
            color: textMain,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Live studio schedule, bookings & 7-day countdown alerts',
          style: TextStyle(
            color: textMuted,
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  // ================= 2. KPI Ribbon =================
  Widget _buildKpiRibbon(
    BuildContext context, {
    required int upcomingCount,
    required int within7DaysCount,
    required double balanceDue,
  }) {
    final accent = context.accentColor;
    return Row(
      children: [
        Expanded(
          child: _buildKpiTile(
            context,
            title: 'Upcoming',
            value: '$upcomingCount',
            subtitle: 'Booked shoots',
            icon: Icons.calendar_month_rounded,
            accentColor: accent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildKpiTile(
            context,
            title: 'In 7 Days',
            value: '$within7DaysCount',
            subtitle:
                within7DaysCount > 0 ? 'Urgent attention' : 'On schedule',
            icon: Icons.timer_outlined,
            accentColor: within7DaysCount > 0
                ? AppColors.urgencyWarning(context)
                : accent,
            highlight: within7DaysCount > 0,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildKpiTile(
            context,
            title: 'Balance',
            value: _currency.format(balanceDue),
            subtitle: balanceDue > 0 ? 'Pending' : 'All clear',
            icon: Icons.account_balance_wallet_outlined,
            accentColor: balanceDue > 0
                ? AppColors.urgencyWarning(context)
                : const Color(0xFF10B981),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiTile(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    bool highlight = false,
  }) {
    final textMain = context.textMain;
    final textMuted = context.textMuted;

    return StudioCard(
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      customBorder: highlight
          ? Border.all(
              color: accentColor.withValues(alpha: 0.50), width: 1.3)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(icon, size: 13, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.dmSans(
                color: textMain,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: highlight
                  ? accentColor
                  : textMuted.withValues(alpha: 0.8),
              fontSize: 10.5,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ================= 3. Quick Action Bar =================
  Widget _buildQuickActionBar(
      BuildContext context, NotificationsProvider? notifs) {
    final unread = notifs?.unreadCount ?? 0;
    final isDark = context.isDark;

    return Row(
      children: [
        // "+ Add Event" primary pill button
        Expanded(
          flex: 5,
          child: _PressableButton(
            onTap: () => CreateEventSheet.show(context),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                gradient: isDark
                    ? AppColors.skyGradient
                    : const LinearGradient(
                        colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                      ),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.45),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.sky
                        .withValues(alpha: isDark ? 0.35 : 0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.add_rounded,
                      color: Color(0xFF040C1A),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '+ Add Event',
                      style: TextStyle(
                        color: Color(0xFF040C1A),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Alerts Button
        Expanded(
          flex: 4,
          child: _PressableButton(
            onTap: () => NotificationsSheet.show(context),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.glassCardDark : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: unread > 0
                      ? AppColors.urgencyCritical(context)
                          .withValues(alpha: 0.6)
                      : (isDark
                          ? AppColors.glassBorderDark
                          : AppColors.lightBorder),
                  width: 1.2,
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_active_outlined,
                      color: unread > 0
                          ? AppColors.urgencyCritical(context)
                          : context.textMain,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      unread > 0 ? 'Alerts ($unread)' : 'Alerts',
                      style: TextStyle(
                        color: unread > 0
                            ? AppColors.urgencyCritical(context)
                            : context.textMain,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ================= 4. Section Header =================
  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    int? badgeCount,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    final accent = context.accentColor;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.playfairDisplay(
                    color: context.textMain,
                    fontWeight: FontWeight.w700,
                    fontSize: 19,
                  ),
                ),
              ),
              if (badgeCount != null && badgeCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: onAction,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            child: Text(
              actionLabel,
              style: TextStyle(
                color: accent,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ================= 5. Upcoming Carousel =================
  Widget _buildUpcomingCarousel(
      BuildContext context, List<StudioEvent> events) {
    final accent = context.accentColor;
    final border = context.cardBorder;

    return Column(
      children: [
        SizedBox(
          height: 230,
          child: PageView.builder(
            controller: _pageController,
            itemCount: events.length,
            onPageChanged: (index) {
              setState(() => _currentCarouselIndex = index);
            },
            itemBuilder: (context, index) {
              final event = events[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: _buildUpcomingCard(context, event),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        // Pill-shaped page dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(events.length, (index) {
            final isCurrent = index == _currentCarouselIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3.5),
              width: isCurrent ? 24 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isCurrent
                    ? accent
                    : border.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ================= 6. Upcoming VIP Shoot Card =================
  Widget _buildUpcomingCard(BuildContext context, StudioEvent event) {
    final dateStr = DateFormat('d MMM yyyy').format(event.startsAt);
    final dayStr = DateFormat('EEEE').format(event.startsAt);
    final remaining = event.remainingAmount;
    final accent = context.accentColor;
    final textMain = context.textMain;
    final textMuted = context.textMuted;
    final isWithin7Days = event.isWithin7Days;

    return StudioCard(
      borderRadius: 28,
      padding: const EdgeInsets.all(18),
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder<void>(
            transitionDuration: const Duration(milliseconds: 280),
            pageBuilder: (_, _, _) =>
                EventDetailsScreen(eventId: event.id),
            transitionsBuilder: (_, animation, _, child) {
              return FadeTransition(
                  opacity: animation, child: child);
            },
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Row: Monogram, Title, Countdown
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.28),
                      accent.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: accent.withValues(alpha: 0.35)),
                ),
                child: Center(
                  child: Text(
                    event.clientName.isNotEmpty
                        ? event.clientName.characters.first
                            .toUpperCase()
                        : 'S',
                    style: GoogleFonts.playfairDisplay(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
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
                      style: GoogleFonts.playfairDisplay(
                        color: textMain,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${event.clientName} · ${event.eventType}',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isWithin7Days)
                CountdownChip(
                  daysLeft: event.daysUntilStart,
                  hoursLeft: event.hoursUntilStart,
                )
              else
                _buildStatusBadge(context, event.status),
            ],
          ),

          // Middle Row: Date, Day & Venue Capsule
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: context.innerBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: context.cardBorder.withValues(alpha: 0.30),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month_outlined,
                    color: accent, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: dateStr,
                          style: TextStyle(
                            color: textMain,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text:
                              ' · $dayStr · ${event.location}',
                          style: TextStyle(
                            color: textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Bottom Row: Financial status & CTA
          Row(
            children: [
              Expanded(
                child: Text(
                  remaining > 0
                      ? '${_currency.format(remaining)} due'
                      : '✓ All Settled',
                  style: TextStyle(
                    color: remaining > 0
                        ? AppColors.urgencyWarning(context)
                        : const Color(0xFF10B981),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Shoot Brief',
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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

  // ================= 7. Empty State =================
  Widget _buildEmptyUpcomingState(BuildContext context) {
    return StudioCard(
      borderRadius: 32,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.camera_alt_outlined,
              size: 36,
              color: context.accentColor.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No upcoming shoots scheduled',
            style: GoogleFonts.playfairDisplay(
              color: context.textMain,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add your photography bookings to track 7-day countdowns.',
            style: TextStyle(color: context.textMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => CreateEventSheet.show(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('+ Add First Shoot'),
          ),
        ],
      ),
    );
  }

  // ================= 8. Past Event Card =================
  Widget _buildPastEventCard(BuildContext context, StudioEvent event) {
    final dateStr = DateFormat('d MMM yyyy').format(event.startsAt);
    final textMain = context.textMain;
    final textMuted = context.textMuted;
    const statusColor = Color(0xFF10B981);

    return StudioCard(
      borderRadius: 28,
      padding: const EdgeInsets.all(16),
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder<void>(
            transitionDuration: const Duration(milliseconds: 280),
            pageBuilder: (_, _, _) =>
                EventDetailsScreen(eventId: event.id),
            transitionsBuilder: (_, animation, _, child) {
              return FadeTransition(
                  opacity: animation, child: child);
            },
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.playfairDisplay(
                        color: textMain,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$dateStr · ${event.eventType} · ${event.location}',
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
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.30),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.check_circle_rounded,
                        color: statusColor, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'Completed',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Financial snapshot ribbon
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: context.innerBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildCompactMetric(
                      context, 'Total',
                      _currency.format(event.totalAmount)),
                ),
                Expanded(
                  child: _buildCompactMetric(
                      context, 'Received',
                      _currency.format(event.amountReceived)),
                ),
                Expanded(
                  child: _buildCompactMetric(
                    context,
                    'Expenses',
                    _currency.format(event.totalExpenses),
                    valueColor: AppColors.expense(context),
                  ),
                ),
                Expanded(
                  child: _buildCompactMetric(
                    context,
                    'Net Profit',
                    _currency.format(event.netProfit),
                    valueColor: AppColors.profit(context),
                    isBold: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMetric(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: valueColor ?? context.textMain,
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(BuildContext context, EventStatus status) {
    final color = AppColors.statusColor(context, status);

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border:
            Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        status.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ===================== Animated Section Widget =====================
class _AnimatedSection extends StatelessWidget {
  const _AnimatedSection({
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

// ===================== Pressable Button Widget =====================
class _PressableButton extends StatefulWidget {
  const _PressableButton({
    required this.child,
    required this.onTap,
  });

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<_PressableButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
