import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../models/invoice.dart';
import '../../providers/auth_provider.dart';
import '../../providers/invoices_provider.dart';
import '../../services/api_service.dart';
import '../../services/invoice_pdf_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_snackbar.dart';
import '../../routes/smooth_page_route.dart';

class InvoicePreviewScreen extends StatefulWidget {
  const InvoicePreviewScreen({
    super.key,
    required this.invoice,
    this.isDraft = false,
  });

  final Invoice invoice;
  final bool isDraft;

  static Future<Invoice?> open(
    BuildContext context, {
    required Invoice invoice,
    bool isDraft = false,
  }) {
    return Navigator.of(context).push<Invoice?>(
      SmoothPageRoute(
        builder: (_) => InvoicePreviewScreen(
          invoice: invoice,
          isDraft: isDraft,
        ),
      ),
    );
  }

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  late Invoice _invoice;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
  }

  Future<void> _download() async {
    setState(() => _busy = true);
    try {
      final studio = context.read<AuthProvider>().user;
      final bytes = await InvoicePdfService.buildBytes(
        invoice: _invoice,
        studio: studio,
      );
      final path = await InvoicePdfService.saveToDevice(
        bytes: bytes,
        filename: InvoicePdfService.fileName(_invoice, studio: studio),
      );
      if (!mounted) return;
      AppSnackBar.success(
        context,
        '${InvoicePdfService.documentTitle(_invoice)} saved to $path',
        duration: const Duration(seconds: 3),
      );
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.error(
        context,
        'Could not download ${InvoicePdfService.documentTitle(_invoice).toLowerCase()}.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final studio = context.read<AuthProvider>().user;
      final box = context.findRenderObject() as RenderBox?;
      final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
      await InvoicePdfService.shareInvoice(
        invoice: _invoice,
        studio: studio,
        sharePositionOrigin: origin,
      );
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.error(
        context,
        'Could not share ${InvoicePdfService.documentTitle(_invoice).toLowerCase()}.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveDraft() async {
    setState(() => _busy = true);
    try {
      final provider = context.read<InvoicesProvider>();
      final saved = await provider.addInvoice(_invoice);
      await provider.rememberUpi(saved.upiId);
      if (!mounted) return;
      AppSnackBar.success(
        context,
        '${InvoicePdfService.documentTitle(saved)} ${saved.number} saved.',
      );
      Navigator.of(context).pop(saved);
    } on ApiException catch (error) {
      if (!mounted) return;
      AppSnackBar.error(context, error.message);
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.error(
        context,
        'Could not save ${InvoicePdfService.documentTitle(_invoice).toLowerCase()}.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final studio = context.watch<AuthProvider>().user;
    final accent = context.accentColor;
    final textMain = context.textMain;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Text(
          widget.isDraft
              ? 'Preview ${InvoicePdfService.documentTitle(_invoice)}'
              : '${InvoicePdfService.documentTitle(_invoice)} / ${_invoice.number}',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 19,
            color: textMain,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Download PDF',
            onPressed: _busy ? null : _download,
            icon: const Icon(Icons.download_rounded),
          ),
          IconButton(
            tooltip: 'Share ${InvoicePdfService.documentTitle(_invoice).toLowerCase()}',
            onPressed: _busy ? null : _share,
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PdfPreview(
              build: (format) => InvoicePdfService.buildBytes(
                invoice: _invoice,
                studio: studio,
              ),
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              allowPrinting: false,
              allowSharing: false,
              useActions: false,
              pdfFileName: InvoicePdfService.fileName(_invoice, studio: studio),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _download,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const FittedBox(child: Text('Download PDF')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textMain,
                        side: BorderSide(color: context.cardBorder),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _share,
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: const FittedBox(child: Text('Share PDF')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textMain,
                        side: BorderSide(color: context.cardBorder),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  if (widget.isDraft) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy ? null : _saveDraft,
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(_busy ? 'Saving…' : 'Save'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
