import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/invoice.dart';
import '../../providers/auth_provider.dart';
import '../../providers/invoices_provider.dart';
import '../../services/api_service.dart';
import '../../services/invoice_pdf_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/studio_card.dart';
import 'invoice_preview_screen.dart';
import 'invoice_sheets.dart';

class InvoiceHistoryTab extends StatefulWidget {
  const InvoiceHistoryTab({super.key});

  @override
  State<InvoiceHistoryTab> createState() => _InvoiceHistoryTabState();
}

class _InvoiceHistoryTabState extends State<InvoiceHistoryTab> {
  InvoiceFilter _filter = InvoiceFilter.all;

  static final _money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  Color _statusColor(BuildContext context, InvoiceStatus status) {
    return switch (status) {
      InvoiceStatus.paid => context.accentColor,
      InvoiceStatus.pending =>
        context.isDark ? const Color(0xFF64B5F6) : const Color(0xFF0284C7),
      InvoiceStatus.partial =>
        context.isDark ? const Color(0xFFE8B86D) : const Color(0xFFD97706),
      InvoiceStatus.overdue =>
        context.isDark ? const Color(0xFFFF7A8A) : const Color(0xFFDC2626),
    };
  }

  Future<void> _openActions(Invoice invoice) async {
    final action = await InvoiceActionsSheet.show(context, invoice);
    if (action == null || !mounted) return;
    final provider = context.read<InvoicesProvider>();
    final latest = provider.getById(invoice.id) ?? invoice;

    try {
      switch (action) {
      case InvoiceSheetAction.paid:
        await provider.markAsPaid(latest.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${latest.number} marked as paid.')),
        );
      case InvoiceSheetAction.partial:
        final amount = await PartialPaymentSheet.show(
          context,
          invoice: latest,
        );
        if (amount == null || !mounted) return;
        await provider.markPartiallyPaid(latest.id, amount);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment added to ${latest.number}.')),
        );
      case InvoiceSheetAction.extendDue:
        final picked = await showDatePicker(
          context: context,
          initialDate: latest.dueDate.isAfter(DateTime.now())
              ? latest.dueDate
              : DateTime.now(),
          firstDate: latest.issuedOn,
          lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: context.accentColor,
                  surface: context.cardBg,
                  onSurface: context.textMain,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked == null || !mounted) return;
        await provider.extendDueDate(latest.id, picked);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Due date moved to ${DateFormat('d MMM yyyy').format(picked)}.',
            ),
          ),
        );
      case InvoiceSheetAction.share:
        try {
          final studio = context.read<AuthProvider>().user;
          await InvoicePdfService.shareInvoice(
            invoice: latest,
            studio: studio,
          );
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not share the invoice.')),
          );
        }
      case InvoiceSheetAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Delete invoice?'),
              content: Text(
                '${latest.number} will be removed from history. This cannot be undone.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    'Delete',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            );
          },
        );
        if (confirmed != true || !mounted) return;
        await provider.deleteInvoice(latest.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${latest.number} deleted.')),
        );
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update the invoice.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvoicesProvider>();
    if (!provider.isReady) {
      return const Center(child: CircularProgressIndicator());
    }
    final overview = provider.overview;
    final invoices = provider.filtered(_filter);
    final textMain = context.textMain;
    final textMuted = context.textMuted;
    final accent = context.accentColor;

    return Column(
      children: [
        if (provider.errorMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextButton(
              onPressed: () => provider.loadRemote(),
              child: Text(
                provider.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: _OverviewCard(
                  label: 'Total',
                  value: _money.format(overview.total),
                  icon: Icons.receipt_long_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OverviewCard(
                  label: 'Received',
                  value: _money.format(overview.received),
                  icon: Icons.south_west_rounded,
                  valueColor: context.accentColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OverviewCard(
                  label: 'Pending',
                  value: _money.format(overview.pending),
                  icon: Icons.north_east_rounded,
                  valueColor: overview.pending > 0
                      ? (context.isDark
                          ? const Color(0xFFE8B86D)
                          : const Color(0xFFD97706))
                      : context.accentColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: InvoiceFilter.values.map((filter) {
              final selected = _filter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 8),
                child: FilterChip(
                  label: Text(filter.label),
                  selected: selected,
                  selectedColor: accent,
                  backgroundColor: context.cardBg,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: selected
                        ? (context.isDark ? AppColors.ink : Colors.white)
                        : textMain,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: selected
                        ? accent
                        : context.cardBorder.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onSelected: (value) {
                    if (value) setState(() => _filter = filter);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: invoices.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 48,
                          color: textMuted.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No invoices here',
                          style: GoogleFonts.plusJakartaSans(
                            color: textMain,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Create an invoice or try another filter.',
                          style: TextStyle(color: textMuted, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: invoices.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final invoice = invoices[index];
                    final color = _statusColor(context, invoice.status);
                    return StudioCard(
                      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => InvoicePreviewScreen.open(
                                context,
                                invoice: invoice,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.receipt_long_rounded,
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          invoice.number,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: textMain,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          invoice.eventName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${invoice.contactName} · due ${DateFormat('d MMM').format(invoice.dueDate)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: textMuted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 92),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            _money.format(invoice.total),
                                            maxLines: 1,
                                            style: TextStyle(
                                              color: textMain,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.16),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            invoice.statusLabel,
                                            style: TextStyle(
                                              color: color,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: 'Invoice actions for ${invoice.number}',
                            child: IconButton(
                              tooltip: 'More actions',
                              onPressed: () => _openActions(invoice),
                              icon: Icon(
                                Icons.more_vert_rounded,
                                color: textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final color = valueColor ?? context.textMain;
    return StudioCard(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: context.textMuted),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
