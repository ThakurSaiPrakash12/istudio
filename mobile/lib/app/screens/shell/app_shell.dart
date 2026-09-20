import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/events_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/auth_background.dart';
import '../calendar/calendar_screen.dart';
import '../clients/clients_screen.dart';
import '../home/home_screen.dart';
import '../invoice/invoice_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _pages = [
    HomeScreen(),
    CalendarScreen(),
    InvoiceScreen(),
    ClientsScreen(),
  ];

  void _switchTab(int newIndex) {
    if (newIndex == _index) return;
    HapticFeedback.lightImpact();
    setState(() => _index = newIndex);
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

    return AuthBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Persistent Kept-Alive Tab Stack with silky smooth cross-fade
            for (int i = 0; i < _pages.length; i++)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: i != _index,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeInOutCubic,
                    opacity: i == _index ? 1.0 : 0.0,
                    child: TickerMode(
                      enabled: i == _index,
                      child: _pages[i],
                    ),
                  ),
                ),
              ),

            // Floating Frosted Glass Dock
            Positioned(
              left: 16,
              right: 16,
              bottom: bottomInset + 14,
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
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            borderRadius: radius,
            color: isDark
                ? AppColors.glassSurfaceDark.withValues(alpha: 0.90)
                : Colors.white.withValues(alpha: 0.88),
            border: Border.all(
              color: isDark ? AppColors.glassBorderDark : AppColors.lightBorder,
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.35)
                    : const Color(0x120F172A),
                blurRadius: 18,
                offset: const Offset(0, 6),
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
                  label: 'Invoices',
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
        widget.isDark ? AppColors.sky : AppColors.lightPrimary;
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
                color: widget.isSelected
                    ? activeColor.withValues(
                        alpha: widget.isDark ? 0.16 : 0.12)
                    : Colors.transparent,
                border: Border.all(
                  color: widget.isSelected
                      ? activeColor.withValues(
                          alpha: widget.isDark ? 0.35 : 0.25)
                      : Colors.transparent,
                  width: 1.1,
                ),
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
                                  color: widget.isUrgentBadge
                                      ? AppColors.urgencyWarning(context)
                                      : AppColors.urgencyCritical(context),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (widget.isUrgentBadge
                                              ? AppColors.urgencyWarning(
                                                  context)
                                              : AppColors.urgencyCritical(
                                                  context))
                                          .withValues(alpha: 0.7),
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
                              ? activeColor
                              : inactiveColor,
                          fontSize: 10,
                          fontWeight: widget.isSelected
                              ? FontWeight.w800
                              : FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                        child: Text(widget.label, maxLines: 1),
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
