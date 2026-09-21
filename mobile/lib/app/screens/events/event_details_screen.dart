import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/studio_event.dart';
import '../../providers/events_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/studio_app_bar.dart';
import '../../widgets/studio_button.dart';
import '../../widgets/studio_card.dart';
import '../../widgets/studio_text_field.dart';

class EventDetailsScreen extends StatefulWidget {
  const EventDetailsScreen({
    super.key,
    required this.eventId,
    this.autoOpenPayment = false,
  });

  final String eventId;
  final bool autoOpenPayment;

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  static final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '\u20b9',
    decimalDigits: 0,
  );
  @override
  void initState() {
    super.initState();
    if (widget.autoOpenPayment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAddPaymentSheet(context, widget.eventId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventsProvider>();
    final event = provider.getById(widget.eventId);

    if (event == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: const StudioAppBar(
          title: 'Event Not Found',
          subtitle: 'Event not found',
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This event could not be found.',
                style: TextStyle(color: context.textMain),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            StudioAppBar(
              title: event.title,
              subtitle: '${event.eventType} Details',
              leading: IconButton(
                tooltip: 'Back',
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: context.textMain,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: [
                IconButton(
                  tooltip: 'Edit Event',
                  icon: Icon(
                    Icons.edit_outlined,
                    color: context.accentColor,
                    size: 20,
                  ),
                  onPressed: () => _showEditEventDialog(context, event),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  // 7-Day Countdown Alert Hero (if within 7 days)
                  if (event.isWithin7Days)
                    _build7DayCountdownHero(context, event),

                  // A. Event Header
                  _buildEventHeader(context, event),
                  const SizedBox(height: 16),

                  // B. Financial Summary
                  _buildFinancialSummary(context, event),
                  const SizedBox(height: 16),

                  // C. Payment History
                  _buildPaymentHistory(context, event),
                  const SizedBox(height: 16),

                  // D. Expense Summary
                  _buildExpenseSummary(context, event),
                  const SizedBox(height: 16),

                  // E. Work / Deliverables Progress
                  _buildWorkProgress(context, event),
                  const SizedBox(height: 16),

                  // F. Event Notes
                  _buildNotesSection(context, event),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= 7-Day Countdown Hero =================
  Widget _build7DayCountdownHero(BuildContext context, StudioEvent event) {
    final days = event.daysUntilStart;
    final hours = event.hoursUntilStart;
    final mins = event.minutesUntilStart;
    final urgencyColor = AppColors.urgencyColor(context, days, hours);
    final isDark = context.isDark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isDark
              ? [urgencyColor.withValues(alpha: 0.22), context.cardBg]
              : [urgencyColor.withValues(alpha: 0.12), Colors.white],
        ),
        border: Border.all(
          color: urgencyColor.withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: urgencyColor.withValues(alpha: isDark ? 0.2 : 0.1),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: urgencyColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
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
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          days == 0
                              ? 'TODAY'
                              : 'SHOOT COMING UP',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: urgencyColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                event.countdownFormatted,
                style: TextStyle(
                  color: urgencyColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Clock units
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: context.innerBg.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: context.cardBorder.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildClockUnit(
                  context,
                  days.clamp(0, 99).toString().padLeft(2, '0'),
                  'DAYS',
                  urgencyColor,
                ),
                Text(
                  ':',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: urgencyColor,
                  ),
                ),
                _buildClockUnit(
                  context,
                  hours.clamp(0, 23).toString().padLeft(2, '0'),
                  'HOURS',
                  urgencyColor,
                ),
                Text(
                  ':',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: urgencyColor,
                  ),
                ),
                _buildClockUnit(
                  context,
                  mins.clamp(0, 59).toString().padLeft(2, '0'),
                  'MINS',
                  urgencyColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Scheduled start: ${event.startTime} on ${DateFormat('EEEE, d MMMM yyyy').format(event.startsAt)} at ${event.location}.',
            style: TextStyle(color: context.textMuted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _buildClockUnit(
    BuildContext context,
    String val,
    String unit,
    Color accent,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          val,
          style: GoogleFonts.dmSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: context.textMain,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: context.textMuted,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  // ================= A. Header =================
  Widget _buildEventHeader(BuildContext context, StudioEvent event) {
    final dateStr = DateFormat('d MMMM yyyy').format(event.startsAt);
    final dayStr = DateFormat('EEEE').format(event.startsAt);

    return StudioCard(
      padding: const EdgeInsets.all(20),
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: context.textMain,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${event.eventType} · Client: ${event.clientName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(context, event.status),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: context.innerBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.cardBorder),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      color: context.accentColor,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$dateStr ($dayStr) · ${event.startTime} - ${event.endTime}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textMain,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: context.accentColor,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        event.location,
                        style: TextStyle(
                          color: context.textMain,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, EventStatus status) {
    final color = AppColors.statusColor(context, status);
    IconData icon;
    switch (status) {
      case EventStatus.completed:
        icon = Icons.check_circle_outline_rounded;
        break;
      case EventStatus.inProgress:
        icon = Icons.timelapse_rounded;
        break;
      case EventStatus.paymentDue:
        icon = Icons.error_outline_rounded;
        break;
      case EventStatus.upcoming:
        icon = Icons.schedule_rounded;
        break;
      case EventStatus.cancelled:
        icon = Icons.cancel_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.isDark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              status.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= B. Financial Summary =================
  Widget _buildFinancialSummary(BuildContext context, StudioEvent event) {
    final remaining = event.remainingAmount;
    final hasRemaining = remaining > 0;
    final dueColor = context.isDark
        ? const Color(0xFFE8B86D)
        : const Color(0xFFB57200);

    return StudioCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Payment Details',
                  style: GoogleFonts.plusJakartaSans(
                    color: context.textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (hasRemaining)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: dueColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: dueColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      '${_currency.format(remaining)} Due',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: dueColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Paid ✓',
                    style: TextStyle(
                      color: context.accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Financial Grid
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.innerBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.cardBorder),
            ),
            child: Column(
              children: [
                _buildFinanceRow(
                  context,
                  label: 'Total Amount',
                  value: _currency.format(event.totalAmount),
                  valueColor: context.textMain,
                ),
                Divider(color: context.cardBorder, height: 16),
                _buildFinanceRow(
                  context,
                  label: 'Received',
                  value: _currency.format(event.amountReceived),
                  valueColor: context.accentColor,
                ),
                Divider(color: context.cardBorder, height: 16),
                _buildFinanceRow(
                  context,
                  label: 'Due Amount',
                  value: _currency.format(event.remainingAmount),
                  valueColor: hasRemaining ? dueColor : context.textMuted,
                  subtitle: hasRemaining
                      ? 'Pending client settlement'
                      : 'Settled',
                ),
                Divider(color: context.cardBorder, height: 16),
                _buildFinanceRow(
                  context,
                  label: 'Expenses',
                  value: _currency.format(event.totalExpenses),
                  valueColor: AppColors.expense(context),
                  subtitle: '${event.expenses.length} items',
                ),
                Divider(
                  color: context.accentColor.withValues(alpha: 0.4),
                  height: 20,
                ),
                // Prominent Net Profit
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profit',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.textMain,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Received − Expenses',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          _currency.format(event.netProfit),
                          style: GoogleFonts.plusJakartaSans(
                            color: event.netProfit >= 0
                                ? AppColors.profit(context)
                                : AppColors.expense(context),
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceRow(
    BuildContext context, {
    required String label,
    required String value,
    required Color valueColor,
    String? subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textMuted.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ================= C. Payment History =================
  Widget _buildPaymentHistory(BuildContext context, StudioEvent event) {
    return StudioCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payments',
                style: GoogleFonts.plusJakartaSans(
                  color: context.textMain,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _showAddPaymentSheet(context, widget.eventId),
                icon: Icon(Icons.add, size: 16, color: context.accentColor),
                label: Text(
                  'Add Payment',
                  style: TextStyle(color: context.accentColor, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (event.payments.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.innerBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'No payments recorded',
                style: TextStyle(color: context.textMuted, fontSize: 13),
              ),
            )
          else
            ...event.payments.map((p) {
              final dateStr = DateFormat('d MMM yyyy').format(p.paidAt);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: context.innerBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: context.accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            p.method.icon,
                            color: context.accentColor,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.textMain,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Row(
                                children: [
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: context.cardBorder,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        p.method.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: context.textMain,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      dateStr,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: context.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              _currency.format(p.amount),
                              style: TextStyle(
                                color: context.accentColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (p.reference != null || p.hasProof) ...[
                      const SizedBox(height: 6),
                      Divider(color: context.cardBorder, height: 1),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (p.reference != null)
                            Text(
                              'Ref: ${p.reference}',
                              style: TextStyle(
                                color: context.textMuted,
                                fontSize: 11,
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                          if (p.hasProof)
                            InkWell(
                              onTap: () => _showProofDialog(context, p),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: context.accentColor.withValues(
                                    alpha: 0.16,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: context.accentColor.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.attachment_rounded,
                                      size: 11,
                                      color: context.accentColor,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'View Proof',
                                      style: TextStyle(
                                        color: context.accentColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Received',
                style: TextStyle(
                  color: context.textMain,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                _currency.format(event.amountReceived),
                style: TextStyle(
                  color: context.accentColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= D. Expense Summary =================
  Widget _buildExpenseSummary(BuildContext context, StudioEvent event) {
    final expColor = AppColors.expense(context);

    return StudioCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Event Expenses',
                style: GoogleFonts.plusJakartaSans(
                  color: context.textMain,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _showAddExpenseSheet(context, event.id),
                icon: Icon(Icons.add, size: 16, color: context.accentColor),
                label: Text(
                  '+ Add Expense',
                  style: TextStyle(color: context.accentColor, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (event.expenses.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.innerBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'No expenses recorded yet.',
                style: TextStyle(color: context.textMuted, fontSize: 13),
              ),
            )
          else
            ...event.expenses.map((ex) {
              return Dismissible(
                key: Key(ex.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: expColor.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                onDismissed: (_) {
                  context.read<EventsProvider>().deleteExpense(event.id, ex.id);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: context.innerBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: expColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.receipt_outlined,
                          color: expColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ex.title,
                              style: TextStyle(
                                color: context.textMain,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${ex.category} · ${DateFormat('d MMM').format(ex.incurredAt)}',
                              style: TextStyle(
                                color: context.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _currency.format(ex.amount),
                        style: TextStyle(
                          color: expColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Expenses',
                style: TextStyle(
                  color: context.textMain,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                _currency.format(event.totalExpenses),
                style: TextStyle(
                  color: expColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= E. Work Progress =================
  Widget _buildWorkProgress(BuildContext context, StudioEvent event) {
    final completed = event.completedTasksCount;
    final total = event.totalTasksCount;
    final percent = (event.progressRatio * 100).round();
    DeliverableTask? nextTask;
    for (final task in event.deliverables) {
      if (!task.isCompleted) {
        nextTask = task;
        break;
      }
    }
    final stages = _workflowStages(event.deliverables);

    return StudioCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Work Progress',
                  style: GoogleFonts.plusJakartaSans(
                    color: context.textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  '$completed / $total',
                  key: ValueKey('progress-count-$completed-$total'),
                  style: GoogleFonts.plusJakartaSans(
                    color: context.accentColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              '$percent% Complete',
              key: ValueKey('progress-percent-$percent'),
              style: TextStyle(
                color: context.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: event.progressRatio),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: context.cardBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    context.accentColor,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          if (event.deliverables.isEmpty)
            Text(
              'No deliverables listed for this shoot.',
              style: TextStyle(color: context.textMuted, fontSize: 13),
            )
          else ...[
            if (nextTask == null)
              _buildAllWorkCompleteCard(context, completed, total)
            else
              _buildNextTaskCard(context, event.id, nextTask),
            const SizedBox(height: 18),
            ...stages.map(
              (stage) => _buildStageSection(context, event.id, stage),
            ),
          ],
        ],
      ),
    );
  }

  List<_WorkflowStage> _workflowStages(List<DeliverableTask> tasks) {
    final grouped = <String, List<DeliverableTask>>{
      'Shoot': [],
      'Post Production': [],
      'Delivery': [],
    };

    for (final task in tasks) {
      grouped[_stageForTask(task.title)]!.add(task);
    }

    return grouped.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => _WorkflowStage(entry.key, entry.value))
        .toList();
  }

  String _stageForTask(String title) {
    final value = title.toLowerCase();
    if (value.contains('selection') ||
        value.contains('edit') ||
        value.contains('retouch') ||
        value.contains('color') ||
        value.contains('grade') ||
        value.contains('cinematic') ||
        value.contains('highlight')) {
      return 'Post Production';
    }
    if (value.contains('album') ||
        value.contains('print') ||
        value.contains('delivery') ||
        value.contains('deliver') ||
        value.contains('gallery') ||
        value.contains('cloud') ||
        value.contains('keepsake')) {
      return 'Delivery';
    }
    return 'Shoot';
  }

  String _stageLabel(String stage) => stage.toUpperCase();

  String _taskSubtitle(DeliverableTask task) => _stageForTask(task.title);

  IconData _taskIcon(String title) {
    final value = title.toLowerCase();
    if (value.contains('video') || value.contains('cinematic')) {
      return value.contains('edit') ? Icons.movie_outlined : Icons.videocam;
    }
    if (value.contains('backup') || value.contains('raw')) {
      return Icons.storage_rounded;
    }
    if (value.contains('selection') || value.contains('gallery')) {
      return Icons.photo_library_outlined;
    }
    if (value.contains('edit') ||
        value.contains('retouch') ||
        value.contains('color')) {
      return Icons.auto_awesome;
    }
    if (value.contains('album')) {
      return Icons.menu_book_outlined;
    }
    if (value.contains('print')) {
      return Icons.print_outlined;
    }
    if (value.contains('delivery') ||
        value.contains('deliver') ||
        value.contains('keepsake') ||
        value.contains('packaging')) {
      return Icons.inventory_2_outlined;
    }
    if (value.contains('brief') || value.contains('consult')) {
      return Icons.assignment_outlined;
    }
    return Icons.camera_alt_outlined;
  }

  void _toggleTask(BuildContext context, String eventId, String taskId) {
    context.read<EventsProvider>().toggleDeliverable(eventId, taskId);
  }

  Widget _buildNextTaskCard(
    BuildContext context,
    String eventId,
    DeliverableTask task,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NEXT UP',
          style: TextStyle(
            color: context.accentColor,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _toggleTask(context, eventId, task.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: context.accentColor.withValues(alpha: 0.36),
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.accentColor.withValues(alpha: 0.08),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: context.accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _taskIcon(task.title),
                      color: context.accentColor,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.textMain,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Continue ${_taskSubtitle(task).toLowerCase()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'START ->',
                    style: TextStyle(
                      color: context.accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAllWorkCompleteCard(
    BuildContext context,
    int completed,
    int total,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.accentColor.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.accentColor.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: context.accentColor.withValues(alpha: 0.10),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.verified_rounded, color: context.accentColor, size: 28),
          const SizedBox(height: 8),
          Text(
            'ALL WORK COMPLETED',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.textMain,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$completed / $total tasks finished',
            style: TextStyle(
              color: context.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageSection(
    BuildContext context,
    String eventId,
    _WorkflowStage stage,
  ) {
    final completed = stage.tasks.where((task) => task.isCompleted).length;
    final total = stage.tasks.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _stageLabel(stage.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$completed / $total',
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...stage.tasks.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildTaskCard(context, eventId, task),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    String eventId,
    DeliverableTask task,
  ) {
    final isCompleted = task.isCompleted;
    final statusColor = isCompleted ? context.accentColor : context.textMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _toggleTask(context, eventId, task.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: isCompleted
                ? context.accentColor.withValues(alpha: 0.10)
                : context.innerBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCompleted
                  ? context.accentColor.withValues(alpha: 0.38)
                  : context.cardBorder,
            ),
          ),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  );
                },
                child: Container(
                  key: ValueKey('${task.id}-$isCompleted'),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? context.accentColor
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCompleted
                          ? context.accentColor
                          : context.textMuted,
                      width: 1.4,
                    ),
                  ),
                  child: Icon(
                    isCompleted ? Icons.check_rounded : Icons.circle_outlined,
                    color: isCompleted
                        ? Colors.white
                        : Colors.transparent,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(_taskIcon(task.title), color: statusColor, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isCompleted
                            ? context.textMain.withValues(alpha: 0.78)
                            : context.textMain,
                        fontSize: 14,
                        fontWeight: isCompleted
                            ? FontWeight.w600
                            : FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _taskSubtitle(task),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isCompleted ? 'COMPLETED' : 'PENDING',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= F. Notes =================
  Widget _buildNotesSection(BuildContext context, StudioEvent event) {
    return StudioCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notes',
            style: GoogleFonts.plusJakartaSans(
              color: context.textMain,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            event.notes.isNotEmpty
                ? event.notes
                : 'No notes recorded for this event.',
            style: TextStyle(
              color: context.textMain,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ================= Dialogs / Sheets =================
  void _showAddPaymentSheet(BuildContext context, String eventId) {
    final titleController = TextEditingController(text: 'Payment');
    final amountController = TextEditingController();
    final refController = TextEditingController();
    final proofController = TextEditingController();
    final event = context.read<EventsProvider>().findById(eventId);

    PaymentMethod selectedMethod = PaymentMethod.upi;
    bool attachProof = false;
    bool isUploadingProof = false;
    bool isSavingPayment = false;
    List<int>? proofBytes;
    String? proofFilename;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Record Payment',
                          style: GoogleFonts.plusJakartaSans(
                            color: context.textMain,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: context.textMuted),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    StudioTextField(
                      label: 'Payment Description',
                      hint: 'e.g. Advance, Second Payment, Balance',
                      controller: titleController,
                    ),
                    const SizedBox(height: 14),
                    StudioTextField(
                      label: 'Amount (₹)',
                      hint: 'e.g. 25000',
                      controller: amountController,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 14),

                    // Payment Method selector
                    Text(
                      'Payment Method',
                      style: TextStyle(
                        color: context.textMain,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: PaymentMethod.values.map((method) {
                        final isSelected = selectedMethod == method;
                        return ChoiceChip(
                          avatar: Icon(
                            method.icon,
                            size: 14,
                            color: isSelected
                                ? (context.isDark ? AppColors.ink : Colors.white)
                                : context.textMuted,
                          ),
                          label: Text(method.label),
                          selected: isSelected,
                          selectedColor: context.accentColor,
                          backgroundColor: context.innerBg,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? (context.isDark ? AppColors.ink : Colors.white)
                                : context.textMain,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() => selectedMethod = method);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    StudioTextField(
                      label: 'Reference / Txn ID (Optional)',
                      hint: 'e.g. UPI/2026/10294 or Bank Ref',
                      controller: refController,
                    ),
                    const SizedBox(height: 14),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Attach Payment Proof',
                          style: TextStyle(
                            color: context.textMain,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Switch(
                          value: attachProof,
                          activeThumbColor: context.accentColor,
                          onChanged: (val) {
                            setModalState(() {
                              attachProof = val;
                              if (val && proofController.text.isEmpty) {
                                proofController.text =
                                    'receipt_${selectedMethod.name}_${DateTime.now().millisecondsSinceEpoch % 10000}.jpg';
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    if (attachProof) ...[
                      const SizedBox(height: 10),
                      if (proofController.text.trim().isNotEmpty) ...[
                        Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: context.innerBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: context.accentColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (proofController.text.startsWith('http') ||
                                  proofController.text.startsWith('data:'))
                                GestureDetector(
                                  onTap: () => _showFullScreenProof(
                                    context,
                                    proofController.text.trim(),
                                  ),
                                  child: Stack(
                                    children: [
                                      Image.network(
                                        proofController.text.trim(),
                                        height: 140,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Container(
                                          height: 80,
                                          color: context.cardBg,
                                          alignment: Alignment.center,
                                          child: Text(
                                            'Proof Image: ${proofController.text}',
                                            style: TextStyle(
                                              color: context.textMuted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: 8,
                                        bottom: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.7,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.zoom_in_rounded,
                                                color: Colors.white,
                                                size: 14,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Tap to preview',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF10B981),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Payment Proof Image Attached',
                                        style: TextStyle(
                                          color: context.textMain,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setModalState(() {
                                          proofController.clear();
                                        });
                                      },
                                      child: const Text(
                                        'Remove',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: isUploadingProof
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.cloud_upload_outlined,
                                  size: 18,
                                ),
                          label: Text(
                            isUploadingProof
                                ? 'Uploading Image to Cloud...'
                                : (proofController.text.trim().isNotEmpty
                                      ? 'Change Proof Image'
                                      : 'Upload Image (Cloudinary)'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.accentColor,
                            side: BorderSide(
                              color: context.accentColor.withValues(alpha: 0.5),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: isUploadingProof
                              ? null
                              : () async {
                                  setModalState(() => isUploadingProof = true);
                                  try {
                                    final picked = await ImagePicker()
                                        .pickImage(
                                          source: ImageSource.gallery,
                                          imageQuality: 85,
                                        );
                                    if (picked != null) {
                                      final bytes = await picked.readAsBytes();
                                      final fname = picked.name.toLowerCase();
                                      proofBytes = bytes;
                                      proofFilename = picked.name;
                                      setModalState(() {
                                        proofController.text = picked.name;

                                        if (fname.contains('card') ||
                                            fname.contains('pos')) {
                                          selectedMethod = PaymentMethod.card;
                                        } else if (fname.contains('bank') ||
                                            fname.contains('utr') ||
                                            fname.contains('transfer')) {
                                          selectedMethod =
                                              PaymentMethod.bankTransfer;
                                        } else {
                                          selectedMethod = PaymentMethod.upi;
                                        }

                                        if (titleController.text
                                                .trim()
                                                .isEmpty ||
                                            titleController.text.trim() ==
                                                'Payment') {
                                          if (selectedMethod ==
                                              PaymentMethod.card) {
                                            titleController.text =
                                                'Credit/Debit Card Payment';
                                          } else if (selectedMethod ==
                                              PaymentMethod.bankTransfer) {
                                            titleController.text =
                                                'Bank Transfer Payment';
                                          } else {
                                            titleController.text =
                                                'UPI Payment';
                                          }
                                        }

                                        final rem = event?.remainingAmount ?? 0;
                                        if (amountController.text
                                                .trim()
                                                .isEmpty &&
                                            rem > 0) {
                                          amountController.text = rem
                                              .toInt()
                                              .toString();
                                        }
                                      });
                                    }
                                  } catch (e) {
                                    debugPrint('Upload proof error: $e');
                                  } finally {
                                    setModalState(
                                      () => isUploadingProof = false,
                                    );
                                  }
                                },
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    StudioButton(
                      label: 'Log Payment',
                      onPressed: isSavingPayment
                          ? null
                          : () async {
                              setModalState(() => isSavingPayment = true);
                              try {
                                final amountText = amountController.text.trim();
                                final amount = double.tryParse(amountText);
                                if (amountText.isEmpty) {
                                  ScaffoldMessenger.of(
                                    sheetContext,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please enter the payment amount.',
                                      ),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }
                                if (amount == null || amount <= 0) {
                                  ScaffoldMessenger.of(
                                    sheetContext,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Enter a valid amount greater than 0.',
                                      ),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }
                                final payment = PaymentRecord(
                                  id: 'pay-${DateTime.now().millisecondsSinceEpoch}',
                                  title: titleController.text.trim().isEmpty
                                      ? 'Payment'
                                      : titleController.text.trim(),
                                  amount: amount,
                                  paidAt: DateTime.now(),
                                  method: selectedMethod,
                                  reference:
                                      refController.text.trim().isNotEmpty
                                      ? refController.text.trim()
                                      : null,
                                  proof: null,
                                );
                                final provider = modalContext
                                    .read<EventsProvider>();
                                final saved = await provider.addPayment(
                                  eventId,
                                  payment,
                                );
                                if (saved != null &&
                                    proofBytes != null &&
                                    proofFilename != null) {
                                  await provider.uploadPaymentProof(
                                    eventId,
                                    saved.id,
                                    proofBytes!,
                                    proofFilename!,
                                  );
                                }
                                if (!modalContext.mounted) return;
                                Navigator.of(sheetContext).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Payment of ₹${amount.toInt()} recorded!',
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              } finally {
                                if (modalContext.mounted) {
                                  setModalState(() => isSavingPayment = false);
                                }
                              }
                            },
                      isLoading: isSavingPayment,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showProofDialog(BuildContext context, PaymentRecord payment) {
    final dateStr = DateFormat('d MMMM yyyy, h:mm a').format(payment.paidAt);
    final hasImageProof =
        payment.proof != null &&
        payment.proof!.trim().isNotEmpty &&
        (payment.proof!.startsWith('http') ||
            payment.proof!.startsWith('data:image'));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              24,
              20,
              MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Payment Proof & Receipt',
                        style: GoogleFonts.plusJakartaSans(
                          color: context.textMain,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: context.textMuted),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.innerBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: context.accentColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: context.accentColor.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.verified_outlined,
                            color: context.accentColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _currency.format(payment.amount),
                          style: GoogleFonts.plusJakartaSans(
                            color: context.textMain,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Payment Verified · ${payment.method.label}',
                          style: TextStyle(
                            color: context.accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (hasImageProof) ...[
                          const SizedBox(height: 14),
                          GestureDetector(
                            onTap: () =>
                                _showFullScreenProof(context, payment.proof!),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    payment.proof!,
                                    height: 160,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, stack) =>
                                        Container(
                                          height: 80,
                                          color: context.cardBg,
                                          child: Center(
                                            child: Text(
                                              'Image Proof: ${payment.proof}',
                                              style: TextStyle(
                                                color: context.textMuted,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ),
                                  ),
                                ),
                                Positioned(
                                  right: 8,
                                  bottom: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.7,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.zoom_in_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Full Screen',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Divider(color: context.cardBorder, height: 1),
                        const SizedBox(height: 14),
                        _buildProofDetailRow(
                          context,
                          'Description',
                          payment.title,
                        ),
                        const SizedBox(height: 8),
                        _buildProofDetailRow(context, 'Date & Time', dateStr),
                        const SizedBox(height: 8),
                        _buildProofDetailRow(
                          context,
                          'Transaction Ref',
                          payment.reference ?? 'REF-AUTO-9281',
                        ),
                        const SizedBox(height: 8),
                        _buildProofDetailRow(
                          context,
                          'Attachment File',
                          payment.proof ?? 'receipt_doc.pdf',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  StudioButton(
                    label: 'Done',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProofDetailRow(
    BuildContext context,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(color: context.textMuted, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: context.textMain,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _showAddExpenseSheet(BuildContext context, String eventId) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final customCategoryController = TextEditingController();
    String category = 'Crew';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Event Expense',
                      style: GoogleFonts.plusJakartaSans(
                        color: context.textMain,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    StudioTextField(
                      label: 'Expense Description',
                      hint: 'e.g. Freelancer Photographer, Travel, Printing',
                      controller: titleController,
                    ),
                    const SizedBox(height: 14),
                    StudioTextField(
                      label: 'Amount (₹)',
                      hint: 'e.g. 15000',
                      controller: amountController,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Category',
                      style: TextStyle(color: context.textMain, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          [
                            'Crew',
                            'Travel',
                            'Equipment',
                            'Printing',
                            'Studio',
                            'Others',
                          ].map((cat) {
                            final selected = category == cat;
                            return ChoiceChip(
                              label: Text(cat),
                              selected: selected,
                              onSelected: (val) {
                                if (val) setModalState(() => category = cat);
                              },
                              selectedColor: context.accentColor.withValues(
                                alpha: 0.25,
                              ),
                              backgroundColor: context.innerBg,
                              labelStyle: TextStyle(
                                color: selected
                                    ? context.accentColor
                                    : context.textMain,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                              ),
                            );
                          }).toList(),
                    ),
                    if (category == 'Others') ...[
                      const SizedBox(height: 12),
                      StudioTextField(
                        label: 'Custom Category Name',
                        hint: 'e.g. Catering, Venue, Maintenance',
                        controller: customCategoryController,
                      ),
                    ],
                    const SizedBox(height: 20),
                    StudioButton(
                      label: 'Save Expense',
                      onPressed: () {
                        final amount = double.tryParse(
                          amountController.text.trim(),
                        );
                        if (amount != null &&
                            amount > 0 &&
                            titleController.text.trim().isNotEmpty) {
                          final finalCategory =
                              category == 'Others' &&
                                  customCategoryController.text
                                      .trim()
                                      .isNotEmpty
                              ? customCategoryController.text.trim()
                              : (category == 'Others' ? 'Other' : category);

                          final expense = ExpenseRecord(
                            id: 'exp-${DateTime.now().millisecondsSinceEpoch}',
                            title: titleController.text.trim(),
                            amount: amount,
                            category: finalCategory,
                            incurredAt: DateTime.now(),
                          );
                          context.read<EventsProvider>().addExpense(
                            eventId,
                            expense,
                          );
                          Navigator.of(sheetContext).pop();
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditEventDialog(BuildContext context, StudioEvent event) {
    EventStatus selectedStatus = event.status;
    final notesController = TextEditingController(text: event.notes);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (modalContext, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Edit Event Details',
                style: GoogleFonts.plusJakartaSans(
                  color: context.textMain,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: TextStyle(
                        color: context.textMain,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...EventStatus.values.map((status) {
                      final isSelected = selectedStatus == status;
                      return InkWell(
                        onTap: () {
                          setDialogState(() => selectedStatus = status);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? context.accentColor.withValues(alpha: 0.15)
                                : context.innerBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? context.accentColor
                                  : context.cardBorder,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: isSelected
                                    ? context.accentColor
                                    : context.textMuted,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                status.label,
                                style: TextStyle(
                                  color: context.textMain,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    StudioTextField(
                      label: 'Notes & Instructions',
                      hint:
                          'Edit shoot notes, client requirements or special instructions...',
                      controller: notesController,
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: context.textMuted),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.accentColor,
                    foregroundColor: context.isDark ? AppColors.ink : Colors.white,
                  ),
                  onPressed: () {
                    context.read<EventsProvider>().updateEvent(
                      event.copyWith(
                        status: selectedStatus,
                        notes: notesController.text.trim(),
                      ),
                    );
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showFullScreenProof(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    },
                    errorBuilder: (_, _, _) => const Center(
                      child: Text(
                        'Could not load image proof.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkflowStage {
  const _WorkflowStage(this.name, this.tasks);

  final String name;
  final List<DeliverableTask> tasks;
}
