import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/invoice.dart';
import '../../models/studio_event.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/events_provider.dart';
import '../../providers/invoices_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/countdown_chip.dart';
import '../../widgets/event_countdown_banner.dart';
import '../../widgets/monthly_financial_summary_sheet.dart';
import '../../widgets/notifications_sheet.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/studio_card.dart';
import '../events/create_event_sheet.dart';
import '../events/event_details_screen.dart';
import '../events/past_events_screen.dart';
import '../events/upcoming_events_screen.dart';
import '../profile/profile_screen.dart';
import '../shell/app_shell.dart';
import '../../routes/smooth_page_route.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final PageController _bannerPageController;
  late final AnimationController _staggerController;
  int _currentCarouselIndex = 0;
  int _currentBannerIndex = 0;
  bool _dismissedHeroAlert = false;
  Timer? _bannerAutoScrollTimer;

  static final _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
    _bannerPageController = PageController(viewportFraction: 1.0);
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    // Auto-scroll banners every 4 seconds
    _bannerAutoScrollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) {
        if (!mounted || !_bannerPageController.hasClients) return;
        final nextPage = (_currentBannerIndex + 1) % 3;
        _bannerPageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      },
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bannerPageController.dispose();
    _staggerController.dispose();
    _bannerAutoScrollTimer?.cancel();
    super.dispose();
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
    final invoicesProvider = context.watch<InvoicesProvider>();
    final notifsProvider = context.watch<NotificationsProvider?>();

    final upcoming = eventsProvider.upcomingEvents;
    final past = eventsProvider.pastEvents.take(4).toList();
    final overview = invoicesProvider.overview;
    final unreadAlerts = notifsProvider?.unreadCount ?? 0;

    final shootsWithin7Days = upcoming.where((e) => e.isWithin7Days).toList();
    final nearestHeroEvent =
        shootsWithin7Days.isNotEmpty ? shootsWithin7Days.first : null;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              children: [
                // 1. Pastel Liquid Glass Studio Header
                _buildStudioHeader(
                  context,
                  user: user,
                  unreadAlerts: unreadAlerts,
                ),

                // 2. Main Content Body
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      130 + MediaQuery.paddingOf(context).bottom,
                    ),
                    children: [
                      // Studio Quick Actions
                      _AnimatedSection(
                        animation: _staggered(0.0, 0.25),
                        child: _buildQuickActionGrid(context),
                      ),
                      const SizedBox(height: 12),

                      // Studio Earnings & Dues Strip
                      _AnimatedSection(
                        animation: _staggered(0.06, 0.32),
                        child: _buildEarningsStrip(context, overview),
                      ),
                      const SizedBox(height: 14),

                      // Promotional Banners Carousel
                      _AnimatedSection(
                        animation: _staggered(0.12, 0.40),
                        child: _buildBannerCarousel(context),
                      ),
                      const SizedBox(height: 18),

                    // 4. 7-Day Countdown Alert Hero Banner
                    if (nearestHeroEvent != null &&
                        !_dismissedHeroAlert) ...[
                      _AnimatedSection(
                        animation: _staggered(0.20, 0.50),
                        child: EventCountdownBanner(
                          event: nearestHeroEvent,
                          onDismiss: () =>
                              setState(() => _dismissedHeroAlert = true),
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],

                    // 5. Coming Up Section Header
                    _AnimatedSection(
                      animation: _staggered(0.28, 0.58),
                      child: _buildSectionHeader(
                        context,
                        title: 'Coming Up',
                        badgeCount: upcoming.length,
                        actionLabel: 'See all',
                        onAction: () {
                          Navigator.of(context).push(
                            SmoothPageRoute(
                              builder: (_) => const UpcomingEventsScreen(),
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

                    // 7. Done Section Header
                    _AnimatedSection(
                      animation: _staggered(0.45, 0.75),
                      child: _buildSectionHeader(
                        context,
                        title: 'Done',
                        actionLabel: 'See all',
                        onAction: () {
                          Navigator.of(context).push(
                            SmoothPageRoute(
                              builder: (_) => const PastEventsScreen(),
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
                                  'No shoots yet',
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
    ),
  );
}

  // ================= 1. Pastel Liquid Glass Studio Header =================
  Widget _buildStudioHeader(
    BuildContext context, {
    required User? user,
    required int unreadAlerts,
  }) {
    final dateStr = DateFormat('EEE, d MMM').format(DateTime.now());
    final isDark = context.isDark;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : (hour < 17 ? 'Good afternoon' : 'Good evening');

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0x59232E44),
                      Color(0x3B151B27),
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xF2FFFFFF),
                      Color(0xD9EEF2FF),
                    ],
                  ),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(26)),
            border: Border.all(
              color: isDark
                  ? const Color(0x38A5B4FC)
                  : const Color(0x33818CF8),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.35)
                    : const Color(0x100F172A),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: AppColors.sky.withValues(alpha: isDark ? 0.14 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              // Profile Avatar with subtle pastel ring
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  SmoothPageRoute(builder: (_) => const ProfileScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.sky.withValues(alpha: 0.65),
                      width: 1.5,
                    ),
                  ),
                  child: ProfileAvatar(logoUrl: user?.logoUrl, size: 42),
                ),
              ),
              const SizedBox(width: 12),
              // Studio & Greeting
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user?.displayStudioName ?? 'Studio',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: isDark
                            ? AppColors.paper
                            : AppColors.lightTextMain,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$greeting · $dateStr',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.muted
                            : AppColors.lightTextMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Theme Toggle
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.sky.withValues(alpha: 0.12)
                      : AppColors.sky.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isDark
                        ? AppColors.sky.withValues(alpha: 0.25)
                        : AppColors.sky.withValues(alpha: 0.20),
                    width: 0.9,
                  ),
                ),
                child: IconButton(
                  tooltip: isDark ? 'Light mode' : 'Dark mode',
                  iconSize: 20,
                  color: isDark ? AppColors.sky : AppColors.skyDeep,
                  icon: Icon(
                    isDark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                  ),
                  onPressed: () =>
                      context.read<ThemeProvider?>()?.toggleTheme(),
                ),
              ),
              const SizedBox(width: 6),
              // Notification Bell
              _buildHeaderNotificationBell(context, unreadAlerts),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderNotificationBell(BuildContext context, int unreadAlerts) {
    final isDark = context.isDark;
    return Semantics(
      label: 'Notifications ($unreadAlerts unread)',
      button: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.sky.withValues(alpha: 0.12)
                  : AppColors.sky.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isDark
                    ? AppColors.sky.withValues(alpha: 0.25)
                    : AppColors.sky.withValues(alpha: 0.20),
                width: 0.9,
              ),
            ),
            child: IconButton(
              tooltip: 'Notifications',
              iconSize: 20,
              color: isDark ? AppColors.sky : AppColors.skyDeep,
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => NotificationsSheet.show(context),
            ),
          ),
          if (unreadAlerts > 0)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppColors.pastelRose,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  unreadAlerts > 9 ? '9+' : '$unreadAlerts',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ================= 2. Studio Quick Action Grid =================
  Widget _buildQuickActionGrid(BuildContext context) {
    final isDark = context.isDark;

    return StudioCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Studio Services',
                style: TextStyle(
                  color: isDark ? AppColors.paper : AppColors.lightTextMain,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.sky.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Quick 4',
                  style: TextStyle(
                    color: AppColors.sky,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _QuickActionItem(
                icon: Icons.camera_alt_rounded,
                label: 'New Shoot',
                color: const Color(0xFF818CF8), // Pastel Periwinkle
                isDark: isDark,
                onTap: () => CreateEventSheet.show(context),
              ),
              _QuickActionItem(
                icon: Icons.receipt_long_rounded,
                label: 'Make Bill',
                color: const Color(0xFF93C5FD), // Pastel Soft Sky
                isDark: isDark,
                onTap: () => AppShellScope.of(context)?.switchTab(2),
              ),
              _QuickActionItem(
                icon: Icons.calendar_month_rounded,
                label: 'Calendar',
                color: const Color(0xFF6EE7B7), // Pastel Mint
                isDark: isDark,
                onTap: () => AppShellScope.of(context)?.switchTab(1),
              ),
              _QuickActionItem(
                icon: Icons.people_rounded,
                label: 'Clients',
                color: const Color(0xFFC084FC), // Pastel Lilac
                isDark: isDark,
                onTap: () => AppShellScope.of(context)?.switchTab(3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= 3. Studio Earnings Strip =================
  Widget _buildEarningsStrip(BuildContext context, InvoiceOverview overview) {
    final isDark = context.isDark;

    return StudioCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 20,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.sky.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: AppColors.sky,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Studio Earnings',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.muted : AppColors.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _currency.format(overview.received),
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.pastelMint,
                      ),
                    ),
                    Text(
                      ' recvd',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.muted : AppColors.lightTextMuted,
                      ),
                    ),
                    if (overview.pending > 0) ...[
                      Text(
                        ' · ',
                        style: TextStyle(
                          color: isDark ? AppColors.muted : AppColors.lightTextMuted,
                        ),
                      ),
                      Text(
                        _currency.format(overview.pending),
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.sky,
                        ),
                      ),
                      Text(
                        ' due',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.muted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => MonthlyFinancialSummarySheet.show(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.sky.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Summary',
                    style: TextStyle(
                      color: AppColors.sky,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 3),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppColors.sky,
                    size: 9,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= 3. Promotional Banner Carousel =================
  Widget _buildBannerCarousel(BuildContext context) {
    final banners = [
      _BannerData(
        title: 'Send Bills with QR',
        subtitle: 'Fast & easy receipts to WhatsApp',
        icon: Icons.receipt_long_rounded,
        actionLabel: 'Make Bill',
        gradient: AppColors.skyGradient,
        onTap: () => AppShellScope.of(context)?.switchTab(2),
      ),
      _BannerData(
        title: 'Plan Studio Shoots',
        subtitle: 'Never double-book wedding dates',
        icon: Icons.calendar_today_rounded,
        actionLabel: 'Calendar',
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9F43), Color(0xFFE65100)],
        ),
        onTap: () => AppShellScope.of(context)?.switchTab(1),
      ),
      _BannerData(
        title: 'Monthly Earnings',
        subtitle: 'Check income, profit & pending',
        icon: Icons.account_balance_wallet_rounded,
        actionLabel: 'See Profit',
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF047857)],
        ),
        onTap: () => MonthlyFinancialSummarySheet.show(context),
      ),
    ];

    return Column(
      children: [
        SizedBox(
          height: 126,
          child: PageView.builder(
            controller: _bannerPageController,
            physics: const BouncingScrollPhysics(),
            itemCount: banners.length,
            onPageChanged: (index) {
              setState(() => _currentBannerIndex = index);
            },
            itemBuilder: (context, index) {
              final banner = banners[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: banner.onTap,
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: banner.gradient,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: banner.gradient.colors.first.withValues(alpha: 0.32),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 16, 18, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  banner.title,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  banner.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.90),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        banner.actionLabel,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Colors.white,
                                        size: 11,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              banner.icon,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Banner dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(banners.length, (index) {
            final isCurrent = index == _currentBannerIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isCurrent ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isCurrent
                    ? context.accentColor
                    : context.cardBorder.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
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
                  style: GoogleFonts.plusJakartaSans(
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionLabel,
                  style: TextStyle(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(Icons.arrow_forward_ios_rounded,
                    color: accent, size: 10),
              ],
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
            physics: const BouncingScrollPhysics(),
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

  // ================= 6. Upcoming Shoot Card =================
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
          SmoothPageRoute(
            builder: (_) => EventDetailsScreen(eventId: event.id),
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
                    style: GoogleFonts.plusJakartaSans(
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
                      style: GoogleFonts.plusJakartaSans(
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
                      : 'Paid ✓',
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
                    'View',
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
            'No shoots yet',
            style: GoogleFonts.plusJakartaSans(
              color: context.textMain,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add your first shoot',
            style: TextStyle(color: context.textMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => CreateEventSheet.show(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('+ New Shoot'),
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
          SmoothPageRoute(
            builder: (_) => EventDetailsScreen(eventId: event.id),
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
                      style: GoogleFonts.plusJakartaSans(
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
                      'Done',
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
                      context, 'Got',
                      _currency.format(event.amountReceived)),
                ),
                Expanded(
                  child: _buildCompactMetric(
                    context,
                    'Spent',
                    _currency.format(event.totalExpenses),
                    valueColor: AppColors.expense(context),
                  ),
                ),
                Expanded(
                  child: _buildCompactMetric(
                    context,
                    'Profit',
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

// ===================== Quick Action Item Widget =====================
class _QuickActionItem extends StatelessWidget {
  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              style: TextStyle(
                color: isDark ? AppColors.paper : const Color(0xFF1F2937),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== Banner Data Model =====================
class _BannerData {
  const _BannerData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.actionLabel,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final String actionLabel;
  final VoidCallback? onTap;
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
