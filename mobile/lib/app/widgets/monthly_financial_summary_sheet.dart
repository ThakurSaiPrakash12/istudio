import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/studio_event.dart';
import '../providers/events_provider.dart';
import '../screens/events/event_details_screen.dart';
import '../routes/smooth_page_route.dart';
import '../theme/app_colors.dart';
import 'studio_card.dart';

class MonthlyFinancialSummarySheet extends StatefulWidget {
  const MonthlyFinancialSummarySheet({
    super.key,
    this.initialMonth,
  });

  final DateTime? initialMonth;

  static Future<void> show(BuildContext context, {DateTime? initialMonth}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MonthlyFinancialSummarySheet(initialMonth: initialMonth),
    );
  }

  @override
  State<MonthlyFinancialSummarySheet> createState() =>
      _MonthlyFinancialSummarySheetState();
}

class _MonthlyFinancialSummarySheetState
    extends State<MonthlyFinancialSummarySheet> {
  late DateTime _selectedMonth;

  static final _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = widget.initialMonth != null
        ? DateTime(widget.initialMonth!.year, widget.initialMonth!.month)
        : DateTime(now.year, now.month);
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'SELECT MONTH & YEAR',
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventsProvider = context.watch<EventsProvider>();
    final allEvents = eventsProvider.events;

    final textMain = context.textMain;
    final textMuted = context.textMuted;
    final accent = context.accentColor;
    final isDark = context.isDark;

    // Filter events conducted / scheduled in the selected calendar month (excluding cancelled)
    final monthEvents = allEvents.where((e) {
      return e.startsAt.year == _selectedMonth.year &&
          e.startsAt.month == _selectedMonth.month &&
          e.status != EventStatus.cancelled;
    }).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    // Core financial calculations based on formula:
    // Total Income = sum of event amounts for events in that month
    // Total Received = sum of payments received for those events
    // Total Expenditure = sum of expenses recorded for those events
    // Amount Left = Total Received - Total Expenditure
    final totalEvents = monthEvents.length;
    final totalIncome = monthEvents.fold(0.0, (acc, e) => acc + e.totalAmount);
    final totalReceived =
        monthEvents.fold(0.0, (acc, e) => acc + e.amountReceived);
    final totalExpenditure =
        monthEvents.fold(0.0, (acc, e) => acc + e.totalExpenses);
    final amountLeft = totalReceived - totalExpenditure;

    final netPositive = amountLeft >= 0;
    final netColor =
        netPositive ? const Color(0xFF10B981) : AppColors.urgencyCritical(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.88,
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Monthly Earnings',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: textMain,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Income, collections & expenses',
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
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: textMuted, size: 22),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Month Navigation Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.innerBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.cardBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: 'Previous Month',
                        icon: Icon(Icons.chevron_left_rounded, color: textMain),
                        onPressed: _previousMonth,
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: _pickMonth,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_month_rounded,
                                  color: accent, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('MMMM yyyy').format(_selectedMonth),
                                style: GoogleFonts.plusJakartaSans(
                                  color: textMain,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next Month',
                        icon: Icon(Icons.chevron_right_rounded, color: textMain),
                        onPressed: _nextMonth,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Scrollable Content: Summary Card + Events Breakdown
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    // Premium Financial Hero Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: isDark
                            ? LinearGradient(
                                colors: [
                                  const Color(0xFF1E293B),
                                  const Color(0xFF0F172A),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : LinearGradient(
                                colors: [
                                  Colors.white,
                                  context.innerBg,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.12),
                            blurRadius: 18,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '$totalEvents ${totalEvents == 1 ? 'Shoot' : 'Shoots'}',
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.insights_rounded,
                                color: accent,
                                size: 22,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatTile(
                                  context,
                                  label: 'Total Booked',
                                  value: _currency.format(totalIncome),
                                  valueColor: textMain,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatTile(
                                  context,
                                  label: 'Received',
                                  value: _currency.format(totalReceived),
                                  valueColor: AppColors.receivedGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatTile(
                                  context,
                                  label: 'Expenses',
                                  value: _currency.format(totalExpenditure),
                                  valueColor: AppColors.urgencyWarning(context),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatTile(
                                  context,
                                  label: 'Profit (Net)',
                                  value: _currency.format(amountLeft),
                                  valueColor: netColor,
                                  isBold: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Event Breakdown Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Shoots Breakdown',
                          style: GoogleFonts.plusJakartaSans(
                            color: textMain,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: context.innerBg,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: context.cardBorder),
                          ),
                          child: Text(
                            '${monthEvents.length} Items',
                            style: TextStyle(
                              color: textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Event List or Empty State
                    if (monthEvents.isEmpty)
                      StudioCard(
                        borderRadius: 20,
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 36,
                                color: textMuted.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No events conducted in ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: textMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: monthEvents.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final event = monthEvents[index];
                          return _buildEventBreakdownCard(context, event);
                        },
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

  Widget _buildStatTile(
    BuildContext context, {
    required String label,
    required String value,
    required Color valueColor,
    bool isBold = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.innerBg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cardBorder.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 15,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventBreakdownCard(BuildContext context, StudioEvent event) {
    final textMain = context.textMain;
    final textMuted = context.textMuted;
    final accent = context.accentColor;
    final dateStr = DateFormat('d MMM yyyy').format(event.startsAt);
    final netProfit = event.netProfit;
    final isNetPositive = netProfit >= 0;

    return StudioCard(
      borderRadius: 18,
      padding: const EdgeInsets.all(14),
      onTap: () {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          SmoothPageRoute(
            builder: (_) => EventDetailsScreen(eventId: event.id),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Event Name & Date
          Row(
            children: [
              Expanded(
                child: Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textMain,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dateStr,
                style: TextStyle(
                  color: textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
          const SizedBox(height: 10),

          // Row 2: Income/Received | Expenses | Net Amount
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: context.innerBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Received / Value',
                        style: TextStyle(color: textMuted, fontSize: 10),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${_currency.format(event.amountReceived)} / ${_currency.format(event.totalAmount)}',
                          style: TextStyle(
                            color: accent,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: context.cardBorder,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Expenses',
                        style: TextStyle(color: textMuted, fontSize: 10),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _currency.format(event.totalExpenses),
                          style: TextStyle(
                            color: AppColors.urgencyWarning(context),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: context.cardBorder,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Net Amount',
                        style: TextStyle(color: textMuted, fontSize: 10),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _currency.format(netProfit),
                          style: TextStyle(
                            color: isNetPositive
                                ? const Color(0xFF10B981)
                                : AppColors.urgencyCritical(context),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
