import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/client.dart';
import '../../models/studio_event.dart';
import '../../providers/events_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/studio_app_bar.dart';
import '../../widgets/studio_button.dart';
import '../../widgets/studio_card.dart';
import '../../widgets/studio_text_field.dart';
import '../events/event_details_screen.dart';

class ClientDetailsScreen extends StatelessWidget {
  const ClientDetailsScreen({
    super.key,
    required this.clientId,
  });

  final String clientId;

  static final _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventsProvider>();
    final client = provider.getClientById(clientId);
    final textMain = context.textMain;
    final accent = context.accentColor;

    if (client == null) {
      return Scaffold(
        appBar: const StudioAppBar(
          title: 'Client Not Found',
          subtitle: 'LUMEN Studio',
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('This client could not be found.',
                  style: TextStyle(color: textMain)),
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

    final clientEvents = provider.getEventsForClient(client.id, clientName: client.name);
    final payments = provider.getPaymentsForClient(client.id, clientName: client.name);
    final totalValue = provider.getClientTotalValue(client.id, clientName: client.name);
    final totalReceived = provider.getClientTotalReceived(client.id, clientName: client.name);
    final totalRemaining = provider.getClientTotalRemaining(client.id, clientName: client.name);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            StudioAppBar(
              title: client.name,
              subtitle: '${clientEvents.length} ${clientEvents.length == 1 ? 'Event' : 'Events'} Linked',
              leading: IconButton(
                tooltip: 'Back',
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    color: textMain, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: [
                IconButton(
                  tooltip: 'Edit Client',
                  icon: Icon(Icons.edit_outlined,
                      color: accent, size: 20),
                  onPressed: () => _showEditClientSheet(context, client),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  // A. Client Contact Details Card
                  _buildContactCard(context, client),
                  const SizedBox(height: 16),

                  // B. Financial Summary
                  _buildFinancialSummary(
                    context,
                    totalValue: totalValue,
                    totalReceived: totalReceived,
                    totalRemaining: totalRemaining,
                  ),
                  const SizedBox(height: 16),

                  // C. Events Belonging to Client
                  _buildEventsSection(context, client, clientEvents),
                  const SizedBox(height: 16),

                  // D. Payment History
                  _buildPaymentHistorySection(
                    context,
                    client: client,
                    events: clientEvents,
                    payments: payments,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= A. Contact Details Card =================
  Widget _buildContactCard(BuildContext context, Client client) {
    final textMain = context.textMain;
    final textMuted = context.textMuted;
    final accent = context.accentColor;

    return StudioCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.3),
                      context.cardBorder.withValues(alpha: 0.5),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accent.withValues(alpha: 0.5)),
                ),
                alignment: Alignment.center,
                child: Text(
                  client.name.isNotEmpty ? client.name.characters.first.toUpperCase() : 'C',
                  style: GoogleFonts.plusJakartaSans(
                    color: textMain,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      style: GoogleFonts.plusJakartaSans(
                        color: textMain,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Client Contact Profile',
                      style: TextStyle(
                        color: textMuted.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: context.cardBorder.withValues(alpha: 0.3), height: 1),
          const SizedBox(height: 14),

          // Phone Row
          _buildInfoRow(
            context,
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: client.phone.isNotEmpty ? client.phone : 'Not provided',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Contact ${client.phone}'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          const SizedBox(height: 10),

          // Email Row
          _buildInfoRow(
            context,
            icon: Icons.email_outlined,
            label: 'Email',
            value: client.email.isNotEmpty ? client.email : 'Not provided',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Emailing ${client.email}'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),

          // Address Row
          if (client.address.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildInfoRow(
              context,
              icon: Icons.location_on_outlined,
              label: 'Address',
              value: client.address,
            ),
          ],

          // Notes Row
          if (client.notes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.innerBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.cardBorder.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.sticky_note_2_outlined,
                      size: 16, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      client.notes,
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    final textMain = context.textMain;
    final textMuted = context.textMuted;
    final accent = context.accentColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: accent.withValues(alpha: 0.85)),
            const SizedBox(width: 10),
            Text(
              '$label: ',
              style: TextStyle(
                color: textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textMain,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.open_in_new_rounded,
                size: 14,
                color: accent.withValues(alpha: 0.6),
              ),
          ],
        ),
      ),
    );
  }

  // ================= B. Financial Summary =================
  Widget _buildFinancialSummary(
    BuildContext context, {
    required double totalValue,
    required double totalReceived,
    required double totalRemaining,
  }) {
    final hasRemaining = totalRemaining > 0;
    final textMain = context.textMain;
    final textMuted = context.textMuted;
    final accent = context.accentColor;

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
                  'Financial Summary',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (hasRemaining)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: (context.isDark
                              ? const Color(0xFFE8B86D)
                              : const Color(0xFFD97706))
                          .withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (context.isDark
                                ? const Color(0xFFE8B86D)
                                : const Color(0xFFD97706))
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      '${_currency.format(totalRemaining)} Due',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.isDark
                            ? const Color(0xFFE8B86D)
                            : const Color(0xFFD97706),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'All Settled',
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.innerBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: context.cardBorder.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              children: [
                _buildFinanceRow(
                  context,
                  label: 'Total Event Value',
                  value: _currency.format(totalValue),
                  valueColor: textMain,
                ),
                Divider(color: context.cardBorder.withValues(alpha: 0.3), height: 16),
                _buildFinanceRow(
                  context,
                  label: 'Total Received',
                  value: _currency.format(totalReceived),
                  valueColor: accent,
                ),
                Divider(color: context.cardBorder.withValues(alpha: 0.3), height: 16),
                _buildFinanceRow(
                  context,
                  label: 'Total Remaining',
                  value: _currency.format(totalRemaining),
                  valueColor: hasRemaining
                      ? (context.isDark
                          ? const Color(0xFFE8B86D)
                          : const Color(0xFFD97706))
                      : textMuted,
                  subtitle: hasRemaining ? 'Pending client settlement' : 'Fully paid',
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
                    color: context.textMuted.withValues(alpha: 0.6),
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

  // ================= C. Events Belonging to Client =================
  Widget _buildEventsSection(
    BuildContext context,
    Client client,
    List<StudioEvent> events,
  ) {
    final textMain = context.textMain;
    final textMuted = context.textMuted;
    final accent = context.accentColor;

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
                  'Client Events',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${events.length} Total',
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (events.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No events booked for this client yet.',
                  style: TextStyle(color: textMuted, fontSize: 13),
                ),
              ),
            )
          else
            ...events.map((event) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildClientEventCard(context, event),
                )),
        ],
      ),
    );
  }

  Widget _buildClientEventCard(BuildContext context, StudioEvent event) {
    final dateStr = DateFormat('d MMM yyyy').format(event.startsAt);
    final statusColor = AppColors.statusColor(context, event.status);
    final textMain = context.textMain;
    final textMuted = context.textMuted;

    return Container(
      decoration: BoxDecoration(
        color: context.innerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.cardBorder.withValues(alpha: 0.35),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EventDetailsScreen(eventId: event.id),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
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
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$dateStr · ${event.eventType}',
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        event.status.label,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Add Payment',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EventDetailsScreen(
                                eventId: event.id,
                                autoOpenPayment: true,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: context.accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: context.accentColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded,
                                  size: 12, color: context.accentColor),
                              const SizedBox(width: 3),
                              Text(
                                '₹',
                                style: TextStyle(
                                  color: context.accentColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= D. Payment History =================
  Widget _buildPaymentHistorySection(
    BuildContext context, {
    required Client client,
    required List<StudioEvent> events,
    required List<PaymentRecord> payments,
  }) {
    final textMain = context.textMain;
    final textMuted = context.textMuted;
    final accent = context.accentColor;

    return StudioCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Payment History',
                  style: GoogleFonts.plusJakartaSans(
                    color: textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (payments.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No payments recorded yet.',
                  style: TextStyle(color: textMuted, fontSize: 13),
                ),
              ),
            )
          else
            ...payments.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.innerBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.payment_rounded, color: accent, size: 18),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.title,
                                    style: TextStyle(
                                      color: textMain,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${p.method.label} · ${DateFormat('d MMM yyyy').format(p.paidAt)}',
                                    style: TextStyle(
                                      color: textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _currency.format(p.amount),
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (p.reference != null)
                              Text(
                                'Ref: ${p.reference}',
                                style: TextStyle(color: textMuted, fontSize: 10),
                              )
                            else
                              const SizedBox.shrink(),
                            if (p.proof != null && p.proof!.isNotEmpty)
                              GestureDetector(
                                onTap: () => _showProofDialog(context, p),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: accent.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.attachment_rounded,
                                          size: 11, color: accent),
                                      const SizedBox(width: 3),
                                      Text(
                                        'View Proof',
                                        style: TextStyle(
                                          color: accent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              const SizedBox.shrink(),
                          ],
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  void _showProofDialog(BuildContext context, PaymentRecord p) {
    final proof = p.proof ?? '';
    final isNetworkImage = proof.startsWith('http');
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt_long_rounded,
                      color: context.accentColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Payment Proof',
                      style: GoogleFonts.plusJakartaSans(
                        color: context.textMain,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: context.textMuted, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (isNetworkImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    proof,
                    fit: BoxFit.contain,
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        height: 160,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (ctx, error, stackTrace) => Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: context.innerBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Could not load image.',
                          style: TextStyle(color: context.textMuted),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.innerBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.cardBorder.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.insert_drive_file_outlined,
                              color: context.accentColor, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              proof,
                              style: TextStyle(
                                color: context.textMain,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (p.reference != null && p.reference!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Ref: ${p.reference}',
                          style: TextStyle(
                            color: context.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              _buildFinanceRow(
                context,
                label: 'Method',
                value: p.method.label,
                valueColor: context.accentColor,
              ),
              const SizedBox(height: 6),
              _buildFinanceRow(
                context,
                label: 'Amount',
                value: _currency.format(p.amount),
                valueColor: context.textMain,
              ),
              const SizedBox(height: 6),
              _buildFinanceRow(
                context,
                label: 'Date',
                value: DateFormat('d MMM yyyy').format(p.paidAt),
                valueColor: context.textMain,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditClientSheet(BuildContext context, Client client) {
    final nameController = TextEditingController(text: client.name);
    final phoneController = TextEditingController(text: client.phone);
    final emailController = TextEditingController(text: client.email);
    final addressController = TextEditingController(text: client.address);
    final notesController = TextEditingController(text: client.notes);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
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
                      'Edit Client Profile',
                      style: GoogleFonts.plusJakartaSans(
                        color: sheetContext.textMain,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: sheetContext.textMuted),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                StudioTextField(
                  label: 'Full Name *',
                  controller: nameController,
                ),
                const SizedBox(height: 14),
                StudioTextField(
                  label: 'Phone Number *',
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                StudioTextField(
                  label: 'Email Address',
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                StudioTextField(
                  label: 'Address',
                  controller: addressController,
                ),
                const SizedBox(height: 14),
                StudioTextField(
                  label: 'Notes & Preferences',
                  controller: notesController,
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                StudioButton(
                  label: 'Save Profile',
                  onPressed: () {
                    final name = nameController.text.trim();
                    final phone = phoneController.text.trim();

                    if (name.isEmpty || phone.isEmpty) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(
                          content: Text('Name and phone are required.'),
                        ),
                      );
                      return;
                    }

                    final updated = client.copyWith(
                      name: name,
                      phone: phone,
                      email: emailController.text.trim(),
                      address: addressController.text.trim(),
                      notes: notesController.text.trim(),
                    );

                    context.read<EventsProvider>().updateClient(updated);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
