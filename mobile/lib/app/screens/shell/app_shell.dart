import '../../providers/language_provider.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/events_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../calendar/calendar_screen.dart';
import '../clients/clients_screen.dart';
import '../home/home_screen.dart';
import '../invoice/invoice_screen.dart';
import '../photographers/nearby_photographers_screen.dart';
import '../profile/profile_screen.dart';
import '../../routes/smooth_page_route.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  late final List<Widget> _pages = const [
    HomeScreen(),
    CalendarScreen(),
    InvoiceScreen(),
    ClientsScreen(),
    NearbyPhotographersScreen(),
  ];

  void _switchTab(int newIndex) {
    if (newIndex == _index) return;
    HapticFeedback.lightImpact();
    setState(() => _index = newIndex);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final user = auth.user;
      // Show a location prompt only for existing users who have filled their
      // basic profile but haven't linked a Google Maps location yet.
      if (user != null &&
          user.hasBasicProfileFilled &&
          !user.hasVerifiedLocation &&
          !auth.hasVerifiedGoogleMaps) {
        _showLocationPrompt();
      }
    });
  }

  void _showLocationPrompt() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (sheetCtx) {
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
        final accent = AppColors.gold;
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: isDark ? 0.18 : 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.location_on_rounded,
                          color: accent, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Link Your Studio Location',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Required for discovery & client bookings',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              color: isDark
                                  ? Colors.white54
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Your studio doesn\'t have a Google Maps location linked yet. Add it in your profile so clients can find you and your studio appears in nearby searches.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    height: 1.5,
                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(sheetCtx).pop();
                      Navigator.of(context).push(
                        SmoothPageRoute(
                          builder: (_) => const ProfileScreen(initialEditing: true),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_location_alt_rounded, size: 18),
                    label: Text(
                      'Update Location in Profile',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                    child: Text(
                      'Remind me later',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        color: isDark ? Colors.white54 : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventsProvider = context.watch<EventsProvider>();
    final notifsProvider = context.watch<NotificationsProvider?>();

    final shootsIn7Days =
        eventsProvider.events.where((e) => e.isWithin7Days).length;
    final unreadAlerts = notifsProvider?.unreadCount ?? 0;

    final isDark = context.isDark;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final animationsDisabled = AppMotion.areAnimationsDisabled(context);

    return AppShellScope(
      switchTab: _switchTab,
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground(context),
        resizeToAvoidBottomInset: false,
        body: Stack(
            children: [
              // GPU-optimized Kept-Alive Tab Stack with directional slide & scale page transition
              for (int i = 0; i < _pages.length; i++)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: i != _index,
                    child: RepaintBoundary(
                      child: animationsDisabled
                          ? (i == _index ? _pages[i] : const SizedBox.shrink())
                          : AnimatedSlide(
                              duration: AppMotion.medium,
                              curve: AppMotion.fluid,
                              offset: i == _index
                                  ? Offset.zero
                                  : Offset(i > _index ? 0.05 : -0.05, 0.0),
                              child: AnimatedScale(
                                duration: AppMotion.medium,
                                curve: AppMotion.fluid,
                                scale: i == _index ? 1.0 : 0.985,
                                child: AnimatedOpacity(
                                  duration: AppMotion.standard,
                                  curve: Curves.easeInOutCubic,
                                  opacity: i == _index ? 1.0 : 0.0,
                                  child: TickerMode(
                                    enabled: i == _index,
                                    child: _pages[i],
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),

              // Floating Frosted Liquid Glass Dock with Refraction & Pastel Vibrancy
              Positioned(
                left: 16,
                right: 16,
                bottom: bottomInset + 14,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOutCubic,
                  offset: keyboardVisible ? const Offset(0, 1.8) : Offset.zero,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeInOut,
                    opacity: keyboardVisible ? 0.0 : 1.0,
                    child: IgnorePointer(
                      ignoring: keyboardVisible,
                      child: Center(
                        heightFactor: 1.0,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: _LiquidGlassDock(
                            currentIndex: _index,
                            onTabSelected: _switchTab,
                            isDark: isDark,
                            shootsIn7Days: shootsIn7Days,
                            unreadAlerts: unreadAlerts,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}

class _LiquidGlassDock extends StatelessWidget {
  const _LiquidGlassDock({
    required this.currentIndex,
    required this.onTabSelected,
    required this.isDark,
    required this.shootsIn7Days,
    required this.unreadAlerts,
  });

  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final bool isDark;
  final int shootsIn7Days;
  final int unreadAlerts;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            borderRadius: radius,
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
            border: Border.all(
              color: isDark ? const Color(0x38A5B4FC) : const Color(0x33818CF8),
              width: 1.1,
            ),
            boxShadow: [
              // Atmospheric soft depth shadow
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.45)
                    : const Color(0x140F172A),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
              // Pastel periwinkle ambient refraction glow
              BoxShadow(
                color: AppColors.sky.withValues(alpha: isDark ? 0.22 : 0.16),
                blurRadius: 24,
                offset: const Offset(0, 4),
                spreadRadius: -2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                _DockItem(
                  icon: Icons.space_dashboard_outlined,
                  activeIcon: Icons.space_dashboard_rounded,
                  label: 'Home',
                  isSelected: currentIndex == 0,
                  onTap: () => onTabSelected(0),
                  isDark: isDark,
                  badgeCount: unreadAlerts,
                ),
                _DockItem(
                  icon: Icons.calendar_month_outlined,
                  activeIcon: Icons.calendar_month_rounded,
                  label: 'Calendar',
                  isSelected: currentIndex == 1,
                  onTap: () => onTabSelected(1),
                  isDark: isDark,
                  badgeCount: shootsIn7Days,
                  isUrgentBadge: shootsIn7Days > 0,
                ),
                _DockItem(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long_rounded,
                  label: 'Receipt',
                  isSelected: currentIndex == 2,
                  onTap: () => onTabSelected(2),
                  isDark: isDark,
                ),
                _DockItem(
                  icon: Icons.badge_outlined,
                  activeIcon: Icons.badge_rounded,
                  label: 'Clients',
                  isSelected: currentIndex == 3,
                  onTap: () => onTabSelected(3),
                  isDark: isDark,
                ),
                _DockItem(
                  icon: Icons.person_search_outlined,
                  activeIcon: Icons.person_search_rounded,
                  label: 'Discover',
                  isSelected: currentIndex == 4,
                  onTap: () => onTabSelected(4),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatefulWidget {
  const _DockItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
    this.badgeCount = 0,
    this.isUrgentBadge = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;
  final int badgeCount;
  final bool isUrgentBadge;

  @override
  State<_DockItem> createState() => _DockItemState();
}

class _DockItemState extends State<_DockItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _springController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.92)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.92, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 65,
      ),
    ]).animate(_springController);
    _springController.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant _DockItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _springController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor =
        widget.isDark ? const Color(0xFFA5B4FC) : AppColors.sky;
    final inactiveColor =
        widget.isDark ? AppColors.muted : AppColors.lightTextMuted;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: widget.onTap,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: widget.isSelected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.sky.withValues(
                              alpha: widget.isDark ? 0.35 : 0.22),
                          AppColors.sky.withValues(
                              alpha: widget.isDark ? 0.16 : 0.10),
                        ],
                      )
                    : null,
                border: Border.all(
                  color: widget.isSelected
                      ? AppColors.sky.withValues(
                          alpha: widget.isDark ? 0.60 : 0.45)
                      : Colors.transparent,
                  width: 1.2,
                ),
                boxShadow: widget.isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.sky.withValues(
                              alpha: widget.isDark ? 0.28 : 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 240),
                            switchInCurve: Curves.easeOutCubic,
                            child: Icon(
                              widget.isSelected
                                  ? widget.activeIcon
                                  : widget.icon,
                              key: ValueKey(widget.isSelected),
                              size: 20,
                              color: widget.isSelected
                                  ? activeColor
                                  : inactiveColor,
                            ),
                          ),
                          if (widget.badgeCount > 0)
                            Positioned(
                              right: -5,
                              top: -4,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: AppColors.sky,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.sky.withValues(alpha: 0.7),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          color: widget.isSelected
                              ? (widget.isDark
                                  ? const Color(0xFFF8FAFC)
                                  : AppColors.lightTextMain)
                              : inactiveColor,
                          fontSize: 10,
                          fontWeight: widget.isSelected
                              ? FontWeight.w800
                              : FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                        child: Text(context.tr(widget.label), maxLines: 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppShellScope extends InheritedWidget {
  const AppShellScope({
    super.key,
    required this.switchTab,
    required super.child,
  });

  final ValueChanged<int> switchTab;

  static AppShellScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppShellScope>();

  @override
  bool updateShouldNotify(AppShellScope oldWidget) => false;
}

