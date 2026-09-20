import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/studio_event.dart';
import '../../providers/events_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/countdown_chip.dart';
import '../../widgets/payment_proof_preview.dart';
import '../../widgets/studio_app_bar.dart';
import '../../widgets/studio_card.dart';
import 'create_event_sheet.dart';
import 'event_details_screen.dart';
import '../../routes/smooth_page_route.dart';

class UpcomingEventsScreen extends StatefulWidget {
  const UpcomingEventsScreen({super.key});

  @override
  State<UpcomingEventsScreen> createState() => _UpcomingEventsScreenState();
}

class _UpcomingEventsScreenState extends State<UpcomingEventsScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';

  static final _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  final List<String> _categories = [
    'All',
    'Within 7 Days',
    'Wedding',
    'Maternity',
    'Commercial',
    'Newborn',
    'Portrait',
    'Others',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventsProvider>();
    final allUpcoming = provider.upcomingEvents;
    final textMain = context.textMain;
    final textMuted = context.textMuted;
    final accent = context.accentColor;

    final query = _searchController.text.trim().toLowerCase();
    final filtered = allUpcoming.where((event) {
      final matchesCategory = _selectedCategory == 'All' ||
          (_selectedCategory == 'Within 7 Days'
              ? event.isWithin7Days
              : _selectedCategory == 'Others'
                  ? !const [
                      'wedding',
                      'maternity',
                      'commercial',
                      'newborn',
                      'portrait',
                      'pre-wedding',
                      'fashion',
                      'event'
                    ].contains(event.eventType.toLowerCase()) ||
                    event.eventType.toLowerCase() == 'others'
                  : event.eventType.toLowerCase() ==
                      _selectedCategory.toLowerCase());
      final matchesSearch = query.isEmpty ||
          event.title.toLowerCase().contains(query) ||
          event.clientName.toLowerCase().contains(query) ||
          event.location.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              children: [
                StudioAppBar(
                  title: 'Upcoming Events',
                  subtitle: 'Scheduled shoots & bookings',
                  leading: IconButton(
                    tooltip: 'Back',
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: textMain, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  actions: [
                    IconButton(
                      tooltip: 'Add Event',
                      icon: Icon(Icons.add_circle_outline_rounded,
                          color: accent, size: 24),
                      onPressed: () => CreateEventSheet.show(context),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(color: textMain, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search upcoming shoots, clients, venues...',
                          prefixIcon: Icon(Icons.search, color: textMuted, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: textMuted, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: context.cardBg,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final cat = _categories[idx];
                            final isSelected = _selectedCategory == cat;
                            return ChoiceChip(
                              label: Text(cat),
                              selected: isSelected,
                              onSelected: (val) {
                                if (val) setState(() => _selectedCategory = cat);
                              },
                              selectedColor: accent.withValues(alpha: 0.25),
                              backgroundColor: context.cardBg,
                              side: BorderSide(
                                color: isSelected
                                    ? accent
                                    : context.cardBorder,
                              ),
                              labelStyle: TextStyle(
                                color: isSelected ? accent : textMain,
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_today_rounded,
                                  size: 48,
                                  color: textMuted.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              Text(
                                'No upcoming events found',
                                style: TextStyle(
                                  color: textMain,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accent,
                                  foregroundColor: context.isDark ? AppColors.ink : Colors.white,
                                ),
                                onPressed: () => CreateEventSheet.show(context),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('+ Add Event'),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final event = filtered[index];
                            return _buildUpcomingEventCard(context, event);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingEventCard(BuildContext context, StudioEvent event) {
    final dateStr = DateFormat('d MMM yyyy').format(event.startsAt);
    final dayStr = DateFormat('EEEE').format(event.startsAt);
    final remaining = event.remainingAmount;
    final textMain = context.textMain;
    final textMuted = context.textMuted;
    final accent = context.accentColor;

    return StudioCard(
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(
                  Icons.camera_alt_outlined,
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: textMain,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Client: ${event.clientName} · ${event.eventType}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (event.isWithin7Days)
                CountdownChip(
                  daysLeft: event.daysUntilStart,
                  hoursLeft: event.hoursUntilStart,
                )
              else
                Flexible(child: _buildStatusBadge(context, event.status)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: context.innerBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded,
                    color: accent, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$dateStr · $dayStr',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textMain,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.location_on_outlined,
                    color: textMuted, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    event.location,
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  remaining > 0
                      ? '${_currency.format(remaining)} due'
                      : 'Fully Paid',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: remaining > 0
                        ? (context.isDark
                            ? const Color(0xFFE8B86D)
                            : const Color(0xFFD97706))
                        : accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Total: ${_currency.format(event.totalAmount)}',
                  maxLines: 1,
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (event.payments.any((payment) => payment.hasProof)) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: PaymentProofPreviewButton(payments: event.payments),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, EventStatus status) {
    final color = AppColors.statusColor(context, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
