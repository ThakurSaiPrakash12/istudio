import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/invoice.dart';
import '../../providers/auth_provider.dart';
import '../../providers/invoices_provider.dart';
import '../../services/api_service.dart';
import '../../services/invoice_pdf_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/studio_card.dart';
import '../../widgets/shimmer_loading.dart';
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
      InvoiceStatus.paid => AppColors.pastelMint,
      InvoiceStatus.pending => AppColors.sky,
      InvoiceStatus.partial => AppColors.pastelPeach,
      InvoiceStatus.overdue => AppColors.pastelRose,
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
        AppSnackBar.success(context, '${latest.number} marked as paid.');
      case InvoiceSheetAction.partial:
        final amount = await PartialPaymentSheet.show(
          context,
          invoice: latest,
        );
        if (amount == null || !mounted) return;
        await provider.markPartiallyPaid(latest.id, amount);
        if (!mounted) return;
        AppSnackBar.success(context, 'Payment added to ${latest.number}.');
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
        AppSnackBar.success(
          context,
          'Due date moved to ${DateFormat('d MMM yyyy').format(picked)}.',
        );
      case InvoiceSheetAction.share:
        try {
          final studio = context.read<AuthProvider>().user;
          final box = context.findRenderObject() as RenderBox?;
          final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
          await InvoicePdfService.shareInvoice(
            invoice: latest,
            studio: studio,
            sharePositionOrigin: origin,
          );
        } catch (_) {
          if (!mounted) return;
          AppSnackBar.error(context, 'Could not share the invoice.');
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
        AppSnackBar.success(context, '${latest.number} deleted.');
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      AppSnackBar.error(context, error.message);
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.error(context, 'Could not update the invoice.');
    }
  }

  Widget _buildInvoiceFilterButton(BuildContext context, InvoicesProvider provider) {
    final isAll = _filter == InvoiceFilter.all;
    final accent = context.accentColor;

    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: 'Filter Bills',
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openInvoiceFilterSheet(context, provider),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isAll
                  ? context.cardBg
                  : accent.withValues(alpha: context.isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isAll ? context.cardBorder : accent,
                width: isAll ? 1 : 1.4,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 15,
                  color: isAll ? context.textMuted : accent,
                ),
                const SizedBox(width: 6),
                Text(
                  _filter.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isAll ? context.textMain : accent,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: isAll ? context.textMuted : accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openInvoiceFilterSheet(BuildContext context, InvoicesProvider provider) async {
    HapticFeedback.lightImpact();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + MediaQuery.paddingOf(context).bottom),
          decoration: BoxDecoration(
            color: sheetContext.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: sheetContext.cardBorder, width: 1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: sheetContext.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: sheetContext.accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.tune_rounded, color: sheetContext.accentColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Filter Bills',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: sheetContext.textMain,
                    ),
                  ),
                  const Spacer(),
                  if (_filter != InvoiceFilter.all)
                    TextButton(
                      onPressed: () {
                        setState(() => _filter = InvoiceFilter.all);
                        Navigator.of(sheetContext).pop();
                      },
                      child: Text(
                        'Reset to All',
                        style: TextStyle(color: sheetContext.accentColor, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ...InvoiceFilter.values.map((filter) {
                final isSelected = _filter == filter;
                final count = provider.filtered(filter).length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      setState(() => _filter = filter);
                      Navigator.of(sheetContext).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? sheetContext.accentColor.withValues(alpha: sheetContext.isDark ? 0.18 : 0.1)
                            : sheetContext.innerBg.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? sheetContext.accentColor : sheetContext.cardBorder.withValues(alpha: 0.5),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            size: 18,
                            color: isSelected ? sheetContext.accentColor : sheetContext.textMuted,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              filter.label,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: sheetContext.textMain,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? sheetContext.accentColor.withValues(alpha: 0.2)
                                  : sheetContext.cardBorder.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? sheetContext.accentColor : sheetContext.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvoicesProvider>();
    if (!provider.isReady) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          ShimmerCard(rows: 3, height: 100),
          SizedBox(height: 14),
          ShimmerCard(rows: 4, height: 120),
          SizedBox(height: 14),
          ShimmerCard(rows: 4, height: 120),
          SizedBox(height: 14),
          ShimmerCard(rows: 4, height: 120),
        ],
      );
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
                  valueColor: AppColors.pastelMint,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OverviewCard(
                  label: 'Pending',
                  value: _money.format(overview.pending),
                  icon: Icons.north_east_rounded,
                  valueColor: overview.pending > 0
                      ? AppColors.pastelPeach
                      : AppColors.pastelMint,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                'Recent Bills',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textMain,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${invoices.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
              const Spacer(),
              // Hamburger / Filter button
              _buildInvoiceFilterButton(context, provider),
            ],
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
                          'No bills yet',
                          style: GoogleFonts.plusJakartaSans(
                            color: textMain,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Make a bill or try another filter.',
                          style: TextStyle(color: textMuted, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    4,
                    16,
                    130 + MediaQuery.paddingOf(context).bottom,
                  ),
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
                            label: 'Actions for ${invoice.number}',
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
