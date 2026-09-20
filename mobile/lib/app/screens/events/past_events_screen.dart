import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/studio_event.dart';
import '../../providers/events_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/studio_app_bar.dart';
import '../../widgets/studio_card.dart';
import '../../widgets/payment_proof_preview.dart';
import 'event_details_screen.dart';
import '../../routes/smooth_page_route.dart';

class PastEventsScreen extends StatefulWidget {
  const PastEventsScreen({super.key});

  @override
  State<PastEventsScreen> createState() => _PastEventsScreenState();
}

class _PastEventsScreenState extends State<PastEventsScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  bool _newestFirst = true;

  static final _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  final List<String> _categories = [
    'All',
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
    final allPast = provider.pastEvents;
    final textMain = context.textMain;
    final textMuted = context.textMuted;
    final accent = context.accentColor;

    final query = _searchController.text.trim().toLowerCase();
    final filtered = allPast.where((event) {
      final matchesCategory = _selectedCategory == 'All' ||
          (_selectedCategory == 'Others'
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

    if (_newestFirst) {
      filtered.sort((a, b) => b.startsAt.compareTo(a.startsAt));
    } else {
      filtered.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              children: [
                StudioAppBar(
                  title: 'Past Events',
                  subtitle: 'Completed shoots & business history',
                  leading: IconButton(
                    tooltip: 'Back',
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: textMain, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  actions: [
                    IconButton(
                      tooltip: _newestFirst ? 'Sort: Newest' : 'Sort: Oldest',
                      icon: Icon(
                        _newestFirst
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        color: accent,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _newestFirst = !_newestFirst);
                      },
                    ),
                  ],
                ),
                // Search Bar & Filter chips
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(color: textMain, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search past shoots, clients, locations...',
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
                              Icon(Icons.history_toggle_off_rounded,
                                  size: 48,
                                  color: textMuted.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              Text(
                                'No completed shoots match your filter',
                                style: TextStyle(
                                  color: textMain,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
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
                            return _buildPastEventCard(context, event);
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

  Widget _buildPastEventCard(BuildContext context, StudioEvent event) {
    final dateStr = DateFormat('d MMM yyyy').format(event.startsAt);
    final textMain = context.textMain;
    final textMuted = context.textMuted;
    final statusColor = AppColors.statusColor(context, EventStatus.completed);

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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(
                  Icons.photo_camera_rounded,
                  color: statusColor,
                  size: 20,
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
                      style: GoogleFonts.plusJakartaSans(
                        color: textMain,
                        fontSize: 17,
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
              const SizedBox(width: 6),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: statusColor, size: 12),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Completed',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Financial snapshot row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: context.innerBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: context.cardBorder.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildCompactMetric(
                      context, 'Total', _currency.format(event.totalAmount)),
                ),
                Container(
                    width: 1,
                    height: 24,
                    color: context.cardBorder.withValues(alpha: 0.3)),
                Expanded(
                  child: _buildCompactMetric(
                      context, 'Received', _currency.format(event.amountReceived)),
                ),
                Container(
                    width: 1,
                    height: 24,
                    color: context.cardBorder.withValues(alpha: 0.3)),
                Expanded(
                  child: _buildCompactMetric(
                      context, 'Expenses', _currency.format(event.totalExpenses),
                      valueColor: AppColors.expense(context)),
                ),
                Container(
                    width: 1,
                    height: 24,
                    color: context.cardBorder.withValues(alpha: 0.3)),
                Expanded(
                  child: _buildCompactMetric(
                      context, 'Net Profit', _currency.format(event.netProfit),
                      valueColor: AppColors.profit(context), isBold: true),
                ),
              ],
            ),
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
}
