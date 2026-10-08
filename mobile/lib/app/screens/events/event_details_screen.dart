import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/invoice.dart';
import '../../models/studio_event.dart';
import '../../providers/auth_provider.dart';
import '../../providers/events_provider.dart';
import '../../routes/smooth_page_route.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/studio_app_bar.dart';
import '../../widgets/studio_button.dart';
import '../../widgets/studio_card.dart';
import '../../widgets/studio_text_field.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/animated_financial_text.dart';
import 'edit_event_screen.dart';
import '../../widgets/event_status_badge.dart';
import '../photographers/nearby_photographers_screen.dart';
import '../invoice/invoice_preview_screen.dart';
import '../../providers/invoices_provider.dart';
import '../../services/invoice_pdf_service.dart';

class EventDetailsScreen extends StatefulWidget {
  const EventDetailsScreen({
    super.key,
    required this.eventId,
    this.autoOpenPayment = false,
    this.autoOpenExpense = false,
  });

  final String eventId;
  final bool autoOpenPayment;
  final bool autoOpenExpense;

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _detailsController;
  // Pre-cached entrance animations — never recreated on rebuild
  late final Animation<double> _anim0;
  late final Animation<double> _anim1;
  late final Animation<double> _anim2;
  late final Animation<double> _anim3;
  late final Animation<double> _anim4;
  late final Animation<double> _anim5;
  late final Animation<double> _anim6;
  late final Animation<double> _anim7;

  static final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '\u20b9',
    decimalDigits: 0,
  );

  Animation<double> _interval(double begin, double end) => CurvedAnimation(
    parent: _detailsController,
    curve: Interval(begin, end, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    _detailsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    )..forward();
    // Create all intervals once — reused across rebuilds
    _anim0 = _interval(0.00, 0.28); // 7-day hero
    _anim1 = _interval(0.05, 0.34); // event header
    _anim2 = _interval(0.16, 0.48); // financial summary
    _anim3 = _interval(0.24, 0.56); // payment history
    _anim4 = _interval(0.32, 0.64); // expense summary
    _anim5 = _interval(0.40, 0.76); // work progress
    _anim6 = _interval(0.52, 0.86); // notes
    _anim7 = _interval(0.60, 0.94); // event invoice
    if (widget.autoOpenPayment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAddPaymentSheet(context, widget.eventId);
      });
    } else if (widget.autoOpenExpense) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAddExpenseSheet(context, widget.eventId);
      });
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Widget _entrance(Animation<double> anim, Widget child) =>
      FadeSlideIn(animation: anim, child: child);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventsProvider>();
    final event = provider.getById(widget.eventId);

    if (event == null) {
      if (provider.isLoading) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: const StudioAppBar(
            title: 'Loading Shoot...',
            subtitle: 'Event Details',
          ),
          body: const SafeArea(child: EventDetailsShimmer()),
        );
      }

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
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: context.textMain,
                    size: 22,
                  ),
                  tooltip: 'More options',
                  color: context.cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      Navigator.of(context).push(
                        SmoothPageRoute(
                          builder: (_) => EditEventScreen(event: event),
                        ),
                      );
                    } else if (value == 'delete') {
                      _confirmDeleteEvent(context, event);
                    } else if (value == 'duplicate') {
                      _duplicateEvent(context, event);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            color: context.accentColor,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Edit Event',
                            style: TextStyle(color: context.textMain),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          Icon(
                            Icons.copy_outlined,
                            color: context.textMuted,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Duplicate',
                            style: TextStyle(color: context.textMain),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: const [
                          Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFEF4444),
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Delete',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  // 7-Day Countdown Alert Hero (if within 7 days)
                  if (event.isWithin7Days)
                    _entrance(_anim0, _build7DayCountdownHero(context, event)),

                  // A. Event Header
                  _entrance(_anim1, _buildEventHeader(context, event)),
                  const SizedBox(height: 16),

                  // B. Financial Summary
                  _entrance(_anim2, _buildFinancialSummary(context, event)),
                  const SizedBox(height: 16),

                  // C. Payment History
                  _entrance(_anim3, _buildPaymentHistory(context, event)),
                  const SizedBox(height: 16),

                  // D. Expense Summary
                  _entrance(_anim4, _buildExpenseSummary(context, event)),
                  const SizedBox(height: 16),

                  // E. Work / Deliverables Progress
                  _entrance(_anim5, _buildWorkProgress(context, event)),
                  const SizedBox(height: 16),

                  // F. Event Notes
                  _entrance(_anim6, _buildNotesSection(context, event)),
                  const SizedBox(height: 16),

                  // G. Event Invoice (auto-generated)
                  _entrance(_anim7, _buildEventInvoiceSection(context, event)),
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
                          days == 0 ? 'TODAY' : 'SHOOT COMING UP',
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
              EventStatusBadge(event: event),
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
          const SizedBox(height: 10),
          // Find Nearby Photographers
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NearbyPhotographersScreen(event: event),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.accentColor.withValues(alpha: 0.15),
                      context.accentColor.withValues(alpha: 0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.accentColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: context.accentColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.search_rounded,
                        size: 16,
                        color: context.accentColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Find Nearby Photographers',
                            style: TextStyle(
                              color: context.accentColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            event.location.isNotEmpty
                                ? 'Near: ${event.location}'
                                : 'Search photographers near this event',
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
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: context.accentColor,
                    ),
                  ],
                ),
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
                    child: AnimatedFinancialText(
                      amount: remaining,
                      suffix: ' Due',
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
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: AnimatedFinancialText(
                          amount: event.netProfit,
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
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: Text(
              value,
              key: ValueKey(value),
              style: TextStyle(
                color: valueColor,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
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
                        _buildDeleteIconButton(
                          context,
                          tooltip: 'Delete payment',
                          onPressed: () => _deletePayment(context, event, p),
                        ),
                      ],
                    ),
                    ...[
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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildPaymentReceiptBadge(
                                context,
                                event.id,
                                p.id,
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => p.hasProof
                                    ? _showProofDialog(context, event.id, p)
                                    : _pickAndUploadProof(
                                        context,
                                        event.id,
                                        p.id,
                                        replacing: false,
                                      ),
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
                                        p.hasProof
                                            ? Icons.attachment_rounded
                                            : Icons
                                                  .add_photo_alternate_outlined,
                                        size: 11,
                                        color: context.accentColor,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        p.hasProof ? 'View Proof' : 'Add Proof',
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

  Widget _buildPaymentReceiptBadge(
    BuildContext context,
    String eventId,
    String paymentId,
  ) {
    final invoicesProvider = context.watch<InvoicesProvider?>();
    if (invoicesProvider == null) return const SizedBox.shrink();
    final matches = invoicesProvider.invoices.where(
      (inv) =>
          inv.paymentId == paymentId ||
          (inv.eventId == eventId && inv.paymentId == paymentId),
    );
    if (matches.isEmpty) return const SizedBox.shrink();
    final receipt = matches.first;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => InvoicePreviewScreen(invoice: receipt),
          ),
        );
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: context.accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: context.accentColor.withValues(alpha: 0.3),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_rounded, size: 11, color: context.accentColor),
            const SizedBox(width: 3),
            Text(
              'Receipt: ${receipt.number}',
              style: TextStyle(
                color: context.accentColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteIconButton(
    BuildContext context, {
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final danger = context.isDark
        ? const Color(0xFFF87171)
        : const Color(0xFFDC2626);
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: danger.withValues(alpha: context.isDark ? 0.12 : 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: danger.withValues(alpha: 0.28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            splashColor: danger.withValues(alpha: 0.2),
            highlightColor: danger.withValues(alpha: 0.1),
            child: SizedBox(
              width: 30,
              height: 30,
              child: Icon(
                Icons.delete_outline_rounded,
                size: 16,
                color: danger,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDeleteRecord(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgContext) => AlertDialog(
        backgroundColor: dlgContext.cardBg,
        title: Text(
          title,
          style: TextStyle(
            color: dlgContext.textMain,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '$message This cannot be undone.',
          style: TextStyle(color: dlgContext.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgContext).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: dlgContext.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dlgContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _deletePayment(
    BuildContext context,
    StudioEvent event,
    PaymentRecord payment,
  ) async {
    final confirmed = await _confirmDeleteRecord(
      context,
      title: 'Delete payment?',
      message:
          '"${payment.title}" (${_currency.format(payment.amount)}) will be removed and the balance due will increase.',
    );
    if (!confirmed || !context.mounted) return;
    await AppSnackBar.guard(
      context,
      context.read<EventsProvider>().deletePayment(event.id, payment.id),
      success: 'Payment of ${_currency.format(payment.amount)} deleted.',
      error: 'Could not delete payment.',
    );
  }

  Future<void> _deleteExpense(
    BuildContext context,
    StudioEvent event,
    ExpenseRecord expense,
  ) async {
    final confirmed = await _confirmDeleteRecord(
      context,
      title: 'Delete expense?',
      message:
          '"${expense.title}" (${_currency.format(expense.amount)}) will be removed from this event.',
    );
    if (!confirmed || !context.mounted) return;
    await _runDeleteExpense(context, event, expense);
  }

  Future<void> _runDeleteExpense(
    BuildContext context,
    StudioEvent event,
    ExpenseRecord expense,
  ) {
    return AppSnackBar.guard(
      context,
      context.read<EventsProvider>().deleteExpense(event.id, expense.id),
      success: 'Expense of ${_currency.format(expense.amount)} deleted.',
      error: 'Could not delete expense.',
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
                  'Add Expense',
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
                confirmDismiss: (_) => _confirmDeleteRecord(
                  context,
                  title: 'Delete expense?',
                  message:
                      '"${ex.title}" (${_currency.format(ex.amount)}) will be removed from this event.',
                ),
                onDismissed: (_) => _runDeleteExpense(context, event, ex),
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
                      _buildDeleteIconButton(
                        context,
                        tooltip: 'Delete expense',
                        onPressed: () => _deleteExpense(context, event, ex),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No workflow set up yet.',
                  style: TextStyle(color: context.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _seedWorkflow(context, event),
                  icon: Icon(
                    Icons.playlist_add_rounded,
                    color: context.accentColor,
                    size: 18,
                  ),
                  label: Text(
                    'Start ${event.eventType} Workflow',
                    style: TextStyle(color: context.accentColor),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: context.accentColor.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Workflow Deliverables',
                  style: TextStyle(
                    color: context.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddWorkDialog(context, event),
                  icon: Icon(
                    Icons.add_task_rounded,
                    size: 16,
                    color: context.accentColor,
                  ),
                  label: Text(
                    'Add Work',
                    style: TextStyle(
                      color: context.accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (nextTask == null)
              _buildAllWorkCompleteCard(context, event, completed, total)
            else
              _buildNextTaskCard(context, event, nextTask),
            const SizedBox(height: 18),
            ...stages.map((stage) => _buildStageSection(context, event, stage)),
          ],
        ],
      ),
    );
  }

  List<_WorkflowStage> _workflowStages(List<DeliverableTask> tasks) {
    // Group by stage label embedded in task title prefix (format: "STAGE: Task")
    final grouped = <String, List<DeliverableTask>>{};
    for (final task in tasks) {
      final stage = _stageForTask(task.title);
      grouped.putIfAbsent(stage, () => []).add(task);
    }
    // Preserve the canonical stage order for current event type
    final stageOrder = _canonicalStageOrder();
    final result = <_WorkflowStage>[];
    for (final stageName in stageOrder) {
      if (grouped.containsKey(stageName)) {
        result.add(_WorkflowStage(stageName, grouped[stageName]!));
      }
    }
    // Append any tasks in stages not in canonical order
    for (final entry in grouped.entries) {
      if (!stageOrder.contains(entry.key)) {
        result.add(_WorkflowStage(entry.key, entry.value));
      }
    }
    return result;
  }

  List<String> _canonicalStageOrder() {
    return const [
      'PRE-SHOOT',
      'SHOOT DAY',
      'BACKUP & SELECTION',
      'PHOTO EDITING',
      'VIDEO EDITING',
      'ALBUM',
      'FINAL DELIVERY',
    ];
  }

  String _stageForTask(String title) {
    final v = title.toLowerCase();
    // PRE-SHOOT keywords
    if (v.contains('requirement') ||
        v.contains('confirmed') ||
        v.contains('team assigned') ||
        v.contains('equipment') ||
        v.contains('gear') ||
        v.contains('shot list') ||
        v.contains('moodboard') ||
        v.contains('wardrobe') ||
        v.contains('consultation') ||
        v.contains('consult') ||
        v.contains('brief') ||
        v.contains('advance payment') ||
        v.contains('lookbook planning') ||
        v.contains('model casting') ||
        v.contains('crew briefing') ||
        v.contains('checklist') ||
        v.contains('studio setup') ||
        v.contains('baby-safe')) {
      return 'PRE-SHOOT';
    }
    // SHOOT DAY keywords
    if (v.contains('photography completed') ||
        v.contains('videography') ||
        v.contains('important moments') ||
        v.contains('shoot completed') ||
        v.contains('main wedding') ||
        v.contains('portrait session') ||
        v.contains('studio session') ||
        v.contains('shoot execution') ||
        v.contains('newborn shoot') ||
        v.contains('lookbook shoot') ||
        v.contains('coverage')) {
      return 'SHOOT DAY';
    }
    // BACKUP & SELECTION keywords
    if (v.contains('backup') ||
        v.contains('transferred') ||
        v.contains('transfer') ||
        v.contains('raw files') ||
        v.contains('client selection') ||
        v.contains('selection gallery') ||
        v.contains('selected photos') ||
        v.contains('finalized')) {
      return 'BACKUP & SELECTION';
    }
    // VIDEO EDITING keywords (before photo editing to prioritize video)
    if (v.contains('footage') ||
        v.contains('video editing') ||
        v.contains('color grading') ||
        v.contains('audio') ||
        v.contains('music') ||
        v.contains('final video') ||
        v.contains('cinematic') ||
        v.contains('highlight')) {
      return 'VIDEO EDITING';
    }
    // PHOTO EDITING keywords
    if (v.contains('culling') ||
        v.contains('basic editing') ||
        v.contains('color correction') ||
        v.contains('retouching') ||
        v.contains('retouch') ||
        v.contains('final review') ||
        v.contains('edit') ||
        v.contains('high-res')) {
      return 'PHOTO EDITING';
    }
    // ALBUM keywords
    if (v.contains('album') ||
        v.contains('print') ||
        v.contains('client approval') ||
        v.contains('album design')) {
      return 'ALBUM';
    }
    // FINAL DELIVERY keywords
    if (v.contains('exported') ||
        v.contains('delivered') ||
        v.contains('delivery') ||
        v.contains('deliver') ||
        v.contains('gallery') ||
        v.contains('cloud') ||
        v.contains('keepsake') ||
        v.contains('final payment') ||
        v.contains('packaging') ||
        v.contains('handed over')) {
      return 'FINAL DELIVERY';
    }
    return 'SHOOT DAY';
  }

  String _stageLabel(String stage) => stage;

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

  bool _isEventBeforeToday(StudioEvent event) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(
      event.startsAt.year,
      event.startsAt.month,
      event.startsAt.day,
    );
    return today.isBefore(eventDay);
  }

  void _toggleTask(BuildContext context, StudioEvent event, String taskId) {
    if (_isEventBeforeToday(event)) {
      final dateStr = DateFormat('d MMM yyyy').format(event.startsAt);
      AppSnackBar.error(
        context,
        'Checks will be active on event day ($dateStr) or after.',
      );
      return;
    }
    final wasCompleted = event.deliverables.any(
      (t) => t.id == taskId && t.isCompleted,
    );
    AppSnackBar.guard(
      context,
      context.read<EventsProvider>().toggleDeliverable(event.id, taskId),
      success: wasCompleted
          ? 'Work marked as pending.'
          : 'Work marked as done.',
      error: 'Could not update work status.',
    );
  }

  void _confirmDeleteTask(
    BuildContext context,
    String eventId,
    DeliverableTask task,
  ) {
    showDialog(
      context: context,
      builder: (dlgContext) => AlertDialog(
        backgroundColor: dlgContext.cardBg,
        title: Text(
          'Remove Work',
          style: TextStyle(
            color: dlgContext.textMain,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to remove "${task.title}" from this event?',
          style: TextStyle(color: dlgContext.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgContext).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: dlgContext.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(dlgContext).pop();
              AppSnackBar.guard(
                context,
                context.read<EventsProvider>().deleteDeliverable(
                  eventId,
                  task.id,
                ),
                success: '"${task.title}" removed.',
                error: 'Could not remove work.',
              );
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showAddWorkDialog(BuildContext context, StudioEvent event) {
    final titleController = TextEditingController();
    String selectedStage = 'SHOOT DAY';
    final stages = [
      'PRE-SHOOT',
      'SHOOT DAY',
      'BACKUP & SELECTION',
      'PHOTO EDITING',
      'VIDEO EDITING',
      'ALBUM',
      'FINAL DELIVERY',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (modalContext, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add Custom Work',
                    style: TextStyle(
                      color: modalContext.textMain,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: modalContext.textMuted),
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StudioTextField(
                label: 'Work / Task Title',
                hint: 'e.g. Drone Videography, Traditional Pooja...',
                controller: titleController,
              ),
              const SizedBox(height: 14),
              Text(
                'Stage',
                style: TextStyle(
                  color: modalContext.textMain,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: stages.map((st) {
                    final isSel = selectedStage == st;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          st,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSel
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSel
                                ? (modalContext.isDark
                                      ? AppColors.ink
                                      : Colors.white)
                                : modalContext.textMain,
                          ),
                        ),
                        selected: isSel,
                        showCheckmark: false,
                        selectedColor: modalContext.accentColor,
                        backgroundColor: modalContext.innerBg,
                        onSelected: (val) {
                          if (val) setModalState(() => selectedStage = st);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              StudioButton(
                label: 'Add Work',
                onPressed: () async {
                  final text = titleController.text.trim();
                  if (text.isEmpty) {
                    AppSnackBar.error(
                      sheetContext,
                      'Please enter a work title.',
                    );
                    return;
                  }
                  final newTask = DeliverableTask(
                    id: 'task-${DateTime.now().millisecondsSinceEpoch}',
                    title: '$selectedStage: $text',
                    isCompleted: false,
                  );
                  try {
                    await context.read<EventsProvider>().addDeliverable(
                      event.id,
                      newTask,
                    );
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                    if (context.mounted) {
                      AppSnackBar.success(
                        context,
                        '"$text" added to $selectedStage.',
                      );
                    }
                  } catch (e) {
                    if (sheetContext.mounted) {
                      AppSnackBar.error(
                        sheetContext,
                        e is ApiException ? e.message : 'Could not add work.',
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _seedWorkflow(BuildContext context, StudioEvent event) {
    final type = event.eventType.toLowerCase();
    final List<String> titles;

    if (type.contains('wedding')) {
      titles = [
        // PRE-SHOOT
        'Client requirements confirmed',
        'Date/time confirmed',
        'Location confirmed',
        'Team assigned',
        'Equipment checked',
        'Shot list prepared',
        'Advance payment received',
        // SHOOT DAY
        'Photography completed',
        'Videography completed',
        'Important moments captured',
        'Shoot completed',
        // BACKUP & SELECTION
        'Photos transferred',
        'Raw files backup done',
        'Client selection gallery shared',
        // PHOTO EDITING
        'Culling done',
        'Basic editing done',
        'Retouching done',
        'Final review done',
        // VIDEO EDITING
        'Footage organized',
        'Video editing done',
        'Color grading done',
        'Final video exported',
        // ALBUM
        'Album design approved',
        'Album sent for printing',
        // FINAL DELIVERY
        'Photos delivered to gallery',
        'Album handed over',
        'Final payment received',
      ];
    } else if (type.contains('maternity') || type.contains('newborn')) {
      titles = [
        // PRE-SHOOT
        'Client requirements confirmed',
        'Moodboard & wardrobe check',
        'Studio setup done',
        'Equipment checked',
        'Advance payment received',
        // SHOOT DAY
        'Portrait session completed',
        'Shoot completed',
        // BACKUP & SELECTION
        'Photos transferred',
        'Client selection gallery shared',
        // PHOTO EDITING
        'Culling done',
        'Retouching done',
        'High-res exports ready',
        // FINAL DELIVERY
        'Photos delivered to gallery',
        'Prints packaging done',
        'Final payment received',
      ];
    } else if (type.contains('commercial') || type.contains('brand')) {
      titles = [
        // PRE-SHOOT
        'Client requirements confirmed',
        'Lookbook planning done',
        'Model casting & fitting done',
        'Location confirmed',
        'Equipment checked',
        'Advance payment received',
        // SHOOT DAY
        'Photography completed',
        'Videography completed',
        'Lookbook shoot done',
        'Shoot completed',
        // BACKUP & SELECTION
        'Photos transferred',
        'Client selection finalized',
        // PHOTO EDITING
        'Culling done',
        'Retouching done',
        'Final review done',
        // VIDEO EDITING
        'Footage organized',
        'Video editing done',
        'Color grading done',
        'Final video exported',
        // FINAL DELIVERY
        'Files delivered to client',
        'Final payment received',
      ];
    } else {
      // Generic portrait/other
      titles = [
        // PRE-SHOOT
        'Client requirements confirmed',
        'Date/time confirmed',
        'Location confirmed',
        'Equipment checked',
        'Advance payment received',
        // SHOOT DAY
        'Photography completed',
        'Shoot completed',
        // BACKUP & SELECTION
        'Photos transferred',
        'Client selection gallery shared',
        // PHOTO EDITING
        'Culling done',
        'Retouching done',
        // FINAL DELIVERY
        'Photos delivered to gallery',
        'Final payment received',
      ];
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final tasks = titles.asMap().entries.map((e) {
      return DeliverableTask(
        id: 'wf-${event.id}-${now + e.key}',
        title: e.value,
      );
    }).toList();

    AppSnackBar.guard(
      context,
      context.read<EventsProvider>().addDeliverables(event.id, tasks),
      success: '${tasks.length} workflow tasks added.',
      error: 'Could not add workflow tasks.',
    );
  }

  Widget _buildNextTaskCard(
    BuildContext context,
    StudioEvent event,
    DeliverableTask task,
  ) {
    final isUpcoming = _isEventBeforeToday(event);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            if (isUpcoming)
              Row(
                children: [
                  Icon(
                    Icons.lock_clock_rounded,
                    size: 13,
                    color: context.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Active on ${DateFormat('d MMM').format(event.startsAt)}',
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _toggleTask(context, event, task.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.accentColor.withValues(
                  alpha: isUpcoming ? 0.06 : 0.12,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: context.accentColor.withValues(
                    alpha: isUpcoming ? 0.20 : 0.36,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.accentColor.withValues(
                      alpha: isUpcoming ? 0.03 : 0.08,
                    ),
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
                      isUpcoming
                          ? Icons.lock_outline_rounded
                          : _taskIcon(task.title),
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
                          isUpcoming
                              ? 'Unlocks on event date (${DateFormat('d MMM yyyy').format(event.startsAt)})'
                              : 'Continue ${_taskSubtitle(task).toLowerCase()}',
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
                    isUpcoming ? 'LOCKED' : 'START ->',
                    style: TextStyle(
                      color: isUpcoming
                          ? context.textMuted
                          : context.accentColor,
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
    StudioEvent event,
    int completed,
    int total,
  ) {
    final isFullPayment = event.remainingAmount <= 0.01;
    final isCompleted = event.status == EventStatus.completed;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted
            ? const Color(0xFF10B981).withValues(alpha: 0.12)
            : context.accentColor.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF10B981).withValues(alpha: 0.42)
              : context.accentColor.withValues(alpha: 0.42),
        ),
        boxShadow: [
          BoxShadow(
            color: (isCompleted ? const Color(0xFF10B981) : context.accentColor)
                .withValues(alpha: 0.10),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            isCompleted
                ? Icons.verified_rounded
                : Icons.pending_actions_rounded,
            color: isCompleted ? const Color(0xFF10B981) : context.accentColor,
            size: 30,
          ),
          const SizedBox(height: 8),
          Text(
            isCompleted ? 'EVENT COMPLETED' : 'ALL WORK COMPLETED',
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
            isCompleted
                ? '$completed / $total tasks finished & full payment received'
                : '$completed / $total tasks finished. Event will be completed after full payment (₹${event.remainingAmount.toStringAsFixed(0)} balance remaining).',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!isCompleted && !isFullPayment) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showAddPaymentSheet(context, event.id),
              icon: Icon(
                Icons.payment_rounded,
                size: 16,
                color: context.accentColor,
              ),
              label: Text(
                'Record Remaining Payment',
                style: TextStyle(
                  color: context.accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: context.accentColor.withValues(alpha: 0.4),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStageSection(
    BuildContext context,
    StudioEvent event,
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
              child: _buildTaskCard(context, event, task),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    StudioEvent event,
    DeliverableTask task,
  ) {
    final isCompleted = task.isCompleted;
    final isUpcoming = _isEventBeforeToday(event);
    final statusColor = isCompleted
        ? context.accentColor
        : (isUpcoming
              ? context.textMuted.withValues(alpha: 0.6)
              : context.textMuted);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _toggleTask(context, event, task.id),
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
                  key: ValueKey('${task.id}-$isCompleted-$isUpcoming'),
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
                          : (isUpcoming
                                ? context.textMuted.withValues(alpha: 0.4)
                                : context.textMuted),
                      width: 1.4,
                    ),
                  ),
                  child: Icon(
                    isCompleted
                        ? Icons.check_rounded
                        : (isUpcoming
                              ? Icons.lock_clock_rounded
                              : Icons.circle_outlined),
                    color: isCompleted
                        ? Colors.white
                        : (isUpcoming
                              ? context.textMuted.withValues(alpha: 0.6)
                              : Colors.transparent),
                    size: isUpcoming && !isCompleted ? 14 : 18,
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
                      isUpcoming && !isCompleted
                          ? 'Active on event date'
                          : _taskSubtitle(task),
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
              const SizedBox(width: 6),
              Text(
                isCompleted ? 'COMPLETED' : (isUpcoming ? 'LOCKED' : 'PENDING'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: context.textMuted.withValues(alpha: 0.6),
                ),
                tooltip: 'Remove work',
                onPressed: () => _confirmDeleteTask(context, event.id, task),
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

  // ================= G. Event Invoice =================
  Widget _buildEventInvoiceSection(BuildContext context, StudioEvent event) {
    final invoicesProvider = context.watch<InvoicesProvider?>();
    if (invoicesProvider == null) return const SizedBox.shrink();

    final invoices = invoicesProvider.getInvoicesForEvent(
      event.id,
      eventName: event.title,
    );
    // The most recent (first) invoice represents the latest payment state.
    final invoice = invoices.isNotEmpty ? invoices.first : null;

    final accent = context.accentColor;
    final textMain = context.textMain;
    final textMuted = context.textMuted;

    return StudioCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Header row ----
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Event Invoice',
                      style: GoogleFonts.plusJakartaSans(
                        color: textMain,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (invoice != null)
                      Text(
                        '${invoice.number} · ${DateFormat('d MMM yyyy').format(invoice.issuedOn)}',
                        style: TextStyle(color: textMuted, fontSize: 12),
                      )
                    else
                      Text(
                        'Auto-generated from event data',
                        style: TextStyle(color: textMuted, fontSize: 12),
                      ),
                  ],
                ),
              ),
              if (invoice != null) _buildInvoiceStatusChip(context, invoice),
            ],
          ),
          const SizedBox(height: 16),

          if (invoice == null) ...[
            // No invoice yet — show generate button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.innerBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.cardBorder),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_outlined,
                    size: 32,
                    color: textMuted.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No invoice yet',
                    style: TextStyle(
                      color: textMain,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Generate an invoice for this event to share with your client.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _generateAndPreviewInvoice(context, event),
                      icon: const Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Generate Invoice',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Invoice details card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.innerBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.cardBorder),
              ),
              child: Column(
                children: [
                  // Client info row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BILLED TO',
                              style: TextStyle(
                                color: textMuted,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              invoice.contactName.isNotEmpty
                                  ? invoice.contactName
                                  : event.clientName,
                              style: TextStyle(
                                color: textMain,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (invoice.phone.isNotEmpty)
                              Text(
                                invoice.phone,
                                style: TextStyle(
                                  color: textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            if (invoice.address.isNotEmpty)
                              Text(
                                invoice.address,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textMuted,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'DUE DATE',
                            style: TextStyle(
                              color: textMuted,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('d MMM yyyy').format(invoice.dueDate),
                            style: TextStyle(
                              color: textMain,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Divider(color: context.cardBorder, height: 20),
                  // Line items
                  ...invoice.deliverables.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(
                            Icons.collections_outlined,
                            size: 14,
                            color: accent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.name,
                              style: TextStyle(
                                color: textMain,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            _currency.format(item.cost),
                            style: TextStyle(
                              color: textMain,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(color: context.cardBorder, height: 16),
                  // Totals
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _currency.format(invoice.total),
                        style: TextStyle(
                          color: textMain,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Received',
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _currency.format(invoice.amountReceived),
                        style: TextStyle(
                          color: accent,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (invoice.pendingAmount > 0.01) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Balance Due',
                          style: TextStyle(
                            color: context.isDark
                                ? const Color(0xFFE8B86D)
                                : const Color(0xFFB57200),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _currency.format(invoice.pendingAmount),
                          style: TextStyle(
                            color: context.isDark
                                ? const Color(0xFFE8B86D)
                                : const Color(0xFFB57200),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (invoice.upiId.isNotEmpty) ...[
                    Divider(color: context.cardBorder, height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.qr_code_2_rounded,
                          size: 14,
                          color: textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'UPI: ${invoice.upiId}',
                          style: TextStyle(color: textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _shareInvoice(context, invoice),
                    icon: Icon(
                      Icons.ios_share_rounded,
                      size: 16,
                      color: accent,
                    ),
                    label: Text(
                      'Share PDF',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: accent.withValues(alpha: 0.45)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _previewInvoice(context, invoice),
                    icon: Icon(
                      Icons.visibility_outlined,
                      size: 16,
                      color: textMuted,
                    ),
                    label: Text(
                      'Preview',
                      style: TextStyle(
                        color: textMain,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.cardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Regenerate hint for past invoices
            if (invoices.length > 1) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () =>
                      _showInvoiceHistory(context, event, invoices),
                  icon: Icon(Icons.history_rounded, size: 14, color: textMuted),
                  label: Text(
                    'View all ${invoices.length} invoices',
                    style: TextStyle(color: textMuted, fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildInvoiceStatusChip(BuildContext context, Invoice invoice) {
    final Color chipColor;
    final String label;
    switch (invoice.status) {
      case InvoiceStatus.paid:
        chipColor = const Color(0xFF10B981);
        label = 'Paid ✓';
        break;
      case InvoiceStatus.partial:
        chipColor = const Color(0xFFF59E0B);
        label = 'Part Paid';
        break;
      case InvoiceStatus.overdue:
        chipColor = const Color(0xFFEF4444);
        label = 'Overdue';
        break;
      default:
        chipColor = context.accentColor;
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chipColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: chipColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _generateAndPreviewInvoice(
    BuildContext context,
    StudioEvent event,
  ) async {
    final invoicesProvider = context.read<InvoicesProvider?>();
    if (invoicesProvider == null) return;
    try {
      final client = context.read<EventsProvider>().getClientById(
        event.clientId ?? '',
      );
      final invoice = await invoicesProvider.ensureInvoiceForEvent(
        event,
        client: client,
      );
      if (!context.mounted) return;
      await InvoicePreviewScreen.open(context, invoice: invoice);
    } catch (_) {
      if (!context.mounted) return;
      AppSnackBar.error(context, 'Could not generate invoice.');
    }
  }

  Future<void> _shareInvoice(BuildContext context, Invoice invoice) async {
    try {
      final studio = context.read<AuthProvider?>()?.user;
      await InvoicePdfService.shareInvoice(invoice: invoice, studio: studio);
    } catch (_) {
      if (!context.mounted) return;
      AppSnackBar.error(context, 'Could not share invoice PDF.');
    }
  }

  void _previewInvoice(BuildContext context, Invoice invoice) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => InvoicePreviewScreen(invoice: invoice)),
    );
  }

  void _showInvoiceHistory(
    BuildContext context,
    StudioEvent event,
    List<Invoice> invoices,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sheetCtx.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Invoice History',
                style: GoogleFonts.plusJakartaSans(
                  color: sheetCtx.textMain,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                event.title,
                style: TextStyle(color: sheetCtx.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetCtx).size.height * 0.5,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: invoices.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final inv = invoices[index];
                    return InkWell(
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        _previewInvoice(context, inv);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: sheetCtx.innerBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: sheetCtx.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.receipt_rounded,
                              color: sheetCtx.accentColor,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    inv.number,
                                    style: TextStyle(
                                      color: sheetCtx.textMain,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    DateFormat(
                                      'd MMM yyyy',
                                    ).format(inv.issuedOn),
                                    style: TextStyle(
                                      color: sheetCtx.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _currency.format(inv.total),
                              style: TextStyle(
                                color: sheetCtx.accentColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: sheetCtx.textMuted,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Record Payment',
                                style: GoogleFonts.plusJakartaSans(
                                  color: context.textMain,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (event != null)
                                Text(
                                  '${event.title} · ${event.clientName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: context.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
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
                                ? (context.isDark
                                      ? AppColors.ink
                                      : Colors.white)
                                : context.textMuted,
                          ),
                          label: Text(method.label),
                          selected: isSelected,
                          selectedColor: context.accentColor,
                          backgroundColor: context.innerBg,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? (context.isDark
                                      ? AppColors.ink
                                      : Colors.white)
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
                              if (!val) {
                                proofController.clear();
                                proofBytes = null;
                                proofFilename = null;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    if (attachProof) ...[
                      const SizedBox(height: 10),
                      if (proofBytes != null) ...[
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
                              GestureDetector(
                                onTap: () => _showFullScreenMemoryProof(
                                  context,
                                  Uint8List.fromList(proofBytes!),
                                ),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(13),
                                      ),
                                      child: Image.memory(
                                        Uint8List.fromList(proofBytes!),
                                        height: 140,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
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
                                        proofFilename ??
                                            'Payment Proof Image Attached',
                                        style: TextStyle(
                                          color: context.textMain,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setModalState(() {
                                          proofController.clear();
                                          proofBytes = null;
                                          proofFilename = null;
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
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: context.innerBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: context.cardBorder),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.image_outlined,
                                color: context.textMuted,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No proof attached yet. Tap below to select.',
                                  style: TextStyle(
                                    color: context.textMuted,
                                    fontSize: 12,
                                  ),
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
                                ? 'Selecting...'
                                : (proofBytes != null
                                      ? 'Change Proof Image'
                                      : 'Select Proof Image'),
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
                                  AppSnackBar.error(
                                    sheetContext,
                                    'Please enter the payment amount.',
                                  );
                                  return;
                                }
                                if (amount == null || amount <= 0) {
                                  AppSnackBar.error(
                                    sheetContext,
                                    'Enter a valid amount greater than 0.',
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
                                String? proofError;
                                if (saved != null &&
                                    proofBytes != null &&
                                    proofFilename != null) {
                                  proofError = await provider
                                      .uploadPaymentProof(
                                        eventId,
                                        saved.id,
                                        proofBytes!,
                                        proofFilename!,
                                      );
                                }
                                if (!modalContext.mounted) return;
                                if (saved == null) {
                                  AppSnackBar.error(
                                    sheetContext,
                                    'Could not record payment. Please try again.',
                                  );
                                  return;
                                }
                                Navigator.of(sheetContext).pop();
                                if (proofError != null) {
                                  AppSnackBar.error(
                                    context,
                                    'Payment recorded, but proof upload failed: $proofError',
                                    duration: const Duration(seconds: 4),
                                  );
                                } else {
                                  // Auto-generate/update the event invoice silently
                                  final invProv = modalContext
                                      .read<InvoicesProvider?>();
                                  if (invProv != null) {
                                    final evp = modalContext
                                        .read<EventsProvider>();
                                    final updatedEvent = evp.findById(eventId);
                                    if (updatedEvent != null) {
                                      final client = evp.getClientById(
                                        updatedEvent.clientId ?? '',
                                      );
                                      invProv
                                          .ensureInvoiceForEvent(
                                            updatedEvent,
                                            client: client,
                                          )
                                          .ignore();
                                    }
                                  }
                                  AppSnackBar.success(
                                    context,
                                    'Payment of ₹${amount.toInt()} recorded!',
                                  );
                                }
                              } catch (e) {
                                if (sheetContext.mounted) {
                                  AppSnackBar.error(
                                    sheetContext,
                                    e is ApiException
                                        ? e.message
                                        : 'Could not record payment. Please try again.',
                                  );
                                }
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

  Future<bool> _pickAndUploadProof(
    BuildContext context,
    String eventId,
    String paymentId, {
    required bool replacing,
  }) async {
    final provider = context.read<EventsProvider>();
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
    } catch (_) {
      if (context.mounted) {
        AppSnackBar.error(context, 'Could not open the gallery.');
      }
      return false;
    }
    if (picked == null) return false;
    final bytes = await picked.readAsBytes();
    final error = await provider.uploadPaymentProof(
      eventId,
      paymentId,
      bytes,
      picked.name,
    );
    if (!context.mounted) return error == null;
    if (error != null) {
      AppSnackBar.error(context, 'Proof upload failed: $error');
      return false;
    }
    AppSnackBar.success(
      context,
      replacing ? 'Payment proof updated.' : 'Payment proof added.',
    );
    return true;
  }

  void _showProofDialog(
    BuildContext context,
    String eventId,
    PaymentRecord initialPayment,
  ) {
    var payment = initialPayment;
    var isUploading = false;
    var isDeleting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final dateStr = DateFormat(
            'd MMMM yyyy, h:mm a',
          ).format(payment.paidAt);
          final hasImageProof =
              payment.proof != null &&
              payment.proof!.trim().isNotEmpty &&
              (payment.proof!.startsWith('http') ||
                  payment.proof!.startsWith('data:image'));

          Future<void> replaceProof() async {
            setSheetState(() => isUploading = true);
            final ok = await _pickAndUploadProof(
              sheetContext,
              eventId,
              payment.id,
              replacing: payment.hasProof,
            );
            if (!sheetContext.mounted) return;
            final refreshed = sheetContext
                .read<EventsProvider>()
                .findById(eventId)
                ?.payments
                .where((p) => p.id == payment.id)
                .firstOrNull;
            setSheetState(() {
              isUploading = false;
              if (ok && refreshed != null) payment = refreshed;
            });
          }

          Future<void> deleteProof() async {
            final confirmed = await _confirmDeleteRecord(
              sheetContext,
              title: 'Delete proof?',
              message:
                  'The proof attached to "${payment.title}" will be removed. The payment itself will stay.',
            );
            if (!confirmed || !sheetContext.mounted) return;
            setSheetState(() => isDeleting = true);
            final provider = sheetContext.read<EventsProvider>();
            final ok = await AppSnackBar.guard(
              sheetContext,
              provider.removePaymentProof(eventId, payment.id),
              success: 'Payment proof deleted.',
              error: 'Could not delete proof.',
            );
            if (!sheetContext.mounted) return;
            setSheetState(() {
              isDeleting = false;
              if (ok) payment = payment.copyWith(proof: '');
            });
          }

          final isBusy = isUploading || isDeleting;
          final danger = context.isDark
              ? const Color(0xFFF87171)
              : const Color(0xFFDC2626);

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
                              color: context.accentColor.withValues(
                                alpha: 0.16,
                              ),
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
                            (payment.reference != null &&
                                    payment.reference!.trim().isNotEmpty)
                                ? payment.reference!.trim()
                                : 'None provided',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildProofActionButton(
                            color: context.accentColor,
                            isLoading: isUploading,
                            icon: payment.hasProof
                                ? Icons.edit_rounded
                                : Icons.upload_file_rounded,
                            label: isUploading
                                ? 'Uploading...'
                                : (payment.hasProof
                                      ? 'Replace Proof'
                                      : 'Add Proof'),
                            onPressed: isBusy ? null : replaceProof,
                          ),
                        ),
                        if (payment.hasProof) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildProofActionButton(
                              color: danger,
                              isLoading: isDeleting,
                              icon: Icons.delete_outline_rounded,
                              label: isDeleting
                                  ? 'Deleting...'
                                  : 'Delete Proof',
                              onPressed: isBusy ? null : deleteProof,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
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
      ),
    );
  }

  Widget _buildProofActionButton({
    required Color color,
    required bool isLoading,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withValues(alpha: 0.06),
        side: BorderSide(color: color.withValues(alpha: 0.45)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onPressed,
      icon: isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : Icon(icon, size: 18),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
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
    final event = context.read<EventsProvider>().findById(eventId);

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
                    if (event != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${event.title} · ${event.clientName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
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
                        if (titleController.text.trim().isEmpty) {
                          AppSnackBar.error(
                            sheetContext,
                            'Please enter an expense title.',
                          );
                          return;
                        }
                        if (amount == null || amount <= 0) {
                          AppSnackBar.error(
                            sheetContext,
                            'Enter a valid amount greater than 0.',
                          );
                          return;
                        }
                        final finalCategory =
                            category == 'Others' &&
                                customCategoryController.text.trim().isNotEmpty
                            ? customCategoryController.text.trim()
                            : (category == 'Others' ? 'Other' : category);

                        final expense = ExpenseRecord(
                          id: 'exp-${DateTime.now().millisecondsSinceEpoch}',
                          title: titleController.text.trim(),
                          amount: amount,
                          category: finalCategory,
                          incurredAt: DateTime.now(),
                        );
                        Navigator.of(sheetContext).pop();
                        AppSnackBar.guard(
                          context,
                          context.read<EventsProvider>().addExpense(
                            eventId,
                            expense,
                          ),
                          success: 'Expense of ₹${amount.toInt()} added.',
                          error: 'Could not add expense.',
                        );
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

  void _confirmDeleteEvent(BuildContext context, StudioEvent event) {
    final provider = context.read<EventsProvider>();
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete this event?',
          style: TextStyle(
            color: context.textMain,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This action cannot be undone.',
          style: TextStyle(color: context.textMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel', style: TextStyle(color: context.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true) return;
      try {
        await provider.deleteEvent(event.id);
        if (context.mounted) {
          final rootContext = Navigator.of(
            context,
            rootNavigator: true,
          ).context;
          Navigator.of(context).pop();
          AppSnackBar.success(rootContext, '"${event.title}" deleted.');
        }
      } catch (e) {
        if (context.mounted) {
          AppSnackBar.error(
            context,
            e is ApiException ? e.message : 'Failed to delete event.',
          );
        }
      }
    });
  }

  void _duplicateEvent(BuildContext context, StudioEvent event) {
    final now = DateTime.now();
    final newEvent = event.copyWith(
      id: 'dup-${now.millisecondsSinceEpoch}',
      title: '${event.title} (Copy)',
      status: EventStatus.upcoming,
      startsAt: event.startsAt.add(const Duration(days: 7)),
      payments: [],
      deliverables: event.deliverables
          .map((t) => DeliverableTask(id: 'dup-${t.id}', title: t.title))
          .toList(),
    );
    AppSnackBar.guard(
      context,
      context.read<EventsProvider>().addEvent(newEvent),
      success: 'Event duplicated.',
      error: 'Failed to duplicate event.',
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

  void _showFullScreenMemoryProof(BuildContext context, Uint8List bytes) {
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
                child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
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
