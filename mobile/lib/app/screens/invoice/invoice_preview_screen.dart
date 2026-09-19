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
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, _, _) => InvoicePreviewScreen(
          invoice: invoice,
          isDraft: isDraft,
        ),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
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
        filename: InvoicePdfService.fileName(_invoice),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invoice saved to $path')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not download the invoice.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final studio = context.read<AuthProvider>().user;
      await InvoicePdfService.shareInvoice(invoice: _invoice, studio: studio);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not share the invoice.')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${saved.number} saved to history.')),
      );
      Navigator.of(context).pop(saved);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the invoice.')),
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
          widget.isDraft ? 'Preview invoice' : _invoice.number,
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
            tooltip: 'Share invoice',
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
              pdfFileName: InvoicePdfService.fileName(_invoice),
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
                      label: const FittedBox(child: Text('Download')),
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
                      label: const FittedBox(child: Text('Share')),
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
                          foregroundColor: context.isDark
                              ? AppColors.ink
                              : Colors.white,
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
