import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/invoice.dart';
import '../models/user.dart';
import 'api_config.dart';
import 'file_store.dart';

class InvoicePdfService {
  const InvoicePdfService._();

  static final _money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs. ',
    decimalDigits: 2,
  );
  static final _date = DateFormat('d MMMM yyyy');

  static const _navy = PdfColor.fromInt(0xFF1C2541);
  static const _ink = PdfColor.fromInt(0xFF0B1320);
  static const _aqua = PdfColor.fromInt(0xFF5BC0BE);
  static const _slate = PdfColor.fromInt(0xFF3A506B);
  static const _paper = PdfColor.fromInt(0xFFF4F7F5);
  static const _muted = PdfColor.fromInt(0xFF64748B);
  static const _line = PdfColor.fromInt(0xFFD7DEE8);

  static String fileName(Invoice invoice) {
    final safeNumber = invoice.number.replaceAll(RegExp(r'[^\w\-]+'), '_');
    return '$safeNumber.pdf';
  }

  static Future<Uint8List> buildBytes({
    required Invoice invoice,
    User? studio,
  }) async {
    Uint8List? logoBytes;
    if (studio != null && studio.logoUrl.trim().isNotEmpty) {
      final resolvedLogo = ApiConfig.resolveMedia(studio.logoUrl.trim());
      try {
        if (resolvedLogo.startsWith('data:image/')) {
          final base64Str = resolvedLogo.split(',').last;
          logoBytes = base64Decode(base64Str);
        } else if (resolvedLogo.startsWith('http://') ||
            resolvedLogo.startsWith('https://')) {
          try {
            final res = await http.get(Uri.parse(resolvedLogo));
            if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
              logoBytes = res.bodyBytes;
            }
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('Error loading logo in PDF: $e');
      }
    }

    // Offload CPU-intensive PDF layout and compression to background isolate
    return compute(
      _generatePdfBytes,
      _PdfParams(
        invoice: invoice,
        studio: studio,
        logoBytes: logoBytes,
      ),
    );
  }

  static Future<Uint8List> _generatePdfBytes(_PdfParams params) async {
    final invoice = params.invoice;
    final studio = params.studio;
    final logoBytes = params.logoBytes;

    final doc = pw.Document();
    final studioName = (studio?.displayStudioName.trim().isNotEmpty ?? false)
        ? studio!.displayStudioName
        : 'My Studio';
    final owner = studio?.displayOwner ?? '';
    final studioPhone = studio?.phone ?? '';
    final studioEmail = studio?.email ?? '';
    final instagram = studio?.instagram ?? '';
    final youtube = studio?.youtube ?? '';
    final website = studio?.website ?? '';
    final studioAddress = [
      studio?.address,
      studio?.city,
    ].where((part) => part != null && part.trim().isNotEmpty).join(', ');

    pw.ImageProvider? logoProvider;
    if (logoBytes != null && logoBytes.isNotEmpty) {
      logoProvider = pw.MemoryImage(logoBytes);
    }

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 36),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
          ),
          buildForeground: invoice.isPaid
              ? (context) => pw.FullPage(
                    ignoreMargins: true,
                    child: pw.Center(
                      child: pw.Transform.rotate(
                        angle: -0.45,
                        child: pw.Text(
                          'PAID',
                          style: pw.TextStyle(
                            color: PdfColor.fromInt(0x225BC0BE),
                            fontSize: 92,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 8,
                          ),
                        ),
                      ),
                    ),
                  )
              : null,
        ),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 16),
          padding: const pw.EdgeInsets.only(top: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _line, width: 0.8)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Thank you for trusting $studioName with your story.',
                style: const pw.TextStyle(color: _muted, fontSize: 9),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(color: _muted, fontSize: 9),
              ),
            ],
          ),
        ),
        build: (context) => [
          _header(
            studioName: studioName,
            owner: owner,
            phone: studioPhone,
            email: studioEmail,
            address: studioAddress,
            instagram: instagram,
            youtube: youtube,
            website: website,
            logoProvider: logoProvider,
            invoice: invoice,
          ),
          pw.SizedBox(height: 22),
          _metaRow(invoice),
          pw.SizedBox(height: 18),
          _itemsTable(invoice),
          pw.SizedBox(height: 16),
          _totals(invoice),
          pw.SizedBox(height: 18),
          _payment(invoice),
          pw.SizedBox(height: 16),
          _notes(invoice),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _header({
    required String studioName,
    required String owner,
    required String phone,
    required String email,
    required String address,
    required String instagram,
    required String youtube,
    required String website,
    required pw.ImageProvider? logoProvider,
    required Invoice invoice,
  }) {
    // Format social links cleanly
    final socialParts = <String>[];
    if (instagram.trim().isNotEmpty) {
      socialParts.add('Instagram: ${instagram.trim()}');
    } else {
      socialParts.add('Instagram: @${studioName.replaceAll(' ', '').toLowerCase()}');
    }
    if (youtube.trim().isNotEmpty) {
      socialParts.add('YouTube: ${youtube.trim()}');
    } else {
      socialParts.add('YouTube: @${studioName.replaceAll(' ', '').toLowerCase()}');
    }
    if (website.trim().isNotEmpty) {
      socialParts.add('Web: ${website.trim()}');
    }

    final initial = studioName.trim().isNotEmpty
        ? studioName.trim()[0].toUpperCase()
        : 'S';

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: pw.BoxDecoration(
        color: _navy,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Logo image or Monogram Logo Badge
              if (logoProvider != null) ...[
                pw.Container(
                  width: 52,
                  height: 52,
                  margin: const pw.EdgeInsets.only(right: 14),
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(10),
                    color: PdfColors.white,
                  ),
                  child: pw.ClipRRect(
                    horizontalRadius: 10,
                    verticalRadius: 10,
                    child: pw.Image(logoProvider, fit: pw.BoxFit.cover),
                  ),
                ),
              ] else ...[
                // Default Studio Monogram Logo Badge
                pw.Container(
                  width: 52,
                  height: 52,
                  margin: const pw.EdgeInsets.only(right: 14),
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(10),
                    color: _aqua,
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      initial,
                      style: pw.TextStyle(
                        color: _navy,
                        fontSize: 26,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      studioName.toUpperCase(),
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'PHOTOGRAPHY & CINEMATOGRAPHY ATELIER',
                      style: const pw.TextStyle(
                        color: _aqua,
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (owner.isNotEmpty || phone.isNotEmpty || email.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        [owner, phone, email].where((v) => v.isNotEmpty).join('  ·  '),
                        style: const pw.TextStyle(color: _paper, fontSize: 9),
                      ),
                    ],
                    if (address.isNotEmpty)
                      pw.Text(
                        address,
                        style: const pw.TextStyle(color: _paper, fontSize: 8.5),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'ESTIMATED COST',
                    style: pw.TextStyle(
                      color: _aqua,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.6,
                    ),
                  ),
                  pw.Text(
                    '& INVOICE STATEMENT',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    invoice.number,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3.5,
                    ),
                    decoration: pw.BoxDecoration(
                      color: _statusColor(invoice.status),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Text(
                      invoice.statusLabel.toUpperCase(),
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (socialParts.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0x225BC0BE),
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColor.fromInt(0x445BC0BE), width: 0.6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'PORTFOLIO LINKS:',
                    style: pw.TextStyle(
                      color: _aqua,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  pw.Text(
                    socialParts.join('   |   '),
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
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

  static pw.Widget _metaRow(Invoice invoice) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'BILL TO',
                style: pw.TextStyle(
                  color: _aqua,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                invoice.contactName,
                style: pw.TextStyle(
                  color: _ink,
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                invoice.eventName,
                style: const pw.TextStyle(color: _slate, fontSize: 10),
              ),
              if (invoice.phone.isNotEmpty)
                pw.Text(
                  invoice.phone,
                  style: const pw.TextStyle(color: _muted, fontSize: 10),
                ),
              if (invoice.address.isNotEmpty)
                pw.Text(
                  invoice.address,
                  style: const pw.TextStyle(color: _muted, fontSize: 10),
                ),
            ],
          ),
        ),
        pw.SizedBox(width: 16),
        pw.Container(
          width: 210,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: _paper,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: _line),
          ),
          child: pw.Column(
            children: [
              _kv('Invoice date', _date.format(invoice.issuedOn)),
              pw.SizedBox(height: 6),
              _kv('Due date', _date.format(invoice.dueDate)),
              pw.SizedBox(height: 6),
              _kv('Deliverables', '${invoice.deliverables.length}'),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _kv(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(color: _muted, fontSize: 9),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: _ink,
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  static pw.Widget _itemsTable(Invoice invoice) {
    return pw.Table(
      border: pw.TableBorder.symmetric(
        inside: const pw.BorderSide(color: _line, width: 0.5),
      ),
      columnWidths: const {
        0: pw.FixedColumnWidth(28),
        1: pw.FlexColumnWidth(4),
        2: pw.FlexColumnWidth(1.6),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: _navy,
            borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(6)),
          ),
          children: [
            _th('#'),
            _th('Deliverable'),
            _th('Amount', align: pw.TextAlign.right),
          ],
        ),
        ...invoice.deliverables.asMap().entries.map((entry) {
          final odd = entry.key.isOdd;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: odd ? _paper : PdfColors.white,
            ),
            children: [
              _td('${entry.key + 1}'),
              _td(entry.value.name),
              _td(_money.format(entry.value.cost), align: pw.TextAlign.right),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _th(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  static pw.Widget _td(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: pw.Text(
        text,
        textAlign: align,
        style: const pw.TextStyle(color: _ink, fontSize: 10),
      ),
    );
  }

  static pw.Widget _totals(Invoice invoice) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 250,
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _line),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          children: [
            _kv('Subtotal', _money.format(invoice.total)),
            pw.SizedBox(height: 6),
            _kv('Amount received', _money.format(invoice.amountReceived)),
            pw.SizedBox(height: 8),
            pw.Container(height: 0.8, color: _line),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Balance due',
                  style: pw.TextStyle(
                    color: _ink,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  _money.format(invoice.pendingAmount),
                  style: pw.TextStyle(
                    color: invoice.isPaid ? _aqua : _navy,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _payment(Invoice invoice) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _aqua, width: 0.9),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'PAYMENT METHOD',
            style: pw.TextStyle(
              color: _aqua,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'UPI',
            style: pw.TextStyle(
              color: _ink,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            invoice.upiId.trim().isEmpty
                ? 'Payment details will be shared separately.'
                : invoice.upiId.trim(),
            style: pw.TextStyle(
              color: _navy,
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Please mention ${invoice.number} in the UPI remarks while paying.',
            style: const pw.TextStyle(color: _muted, fontSize: 9),
          ),
        ],
      ),
    );
  }

  static pw.Widget _notes(Invoice invoice) {
    return pw.Text(
      'This invoice is generated for ${invoice.eventName}. '
      'Deliverables listed above are payable as per the studio agreement. '
      'Late payments may delay final delivery.',
      style: const pw.TextStyle(color: _muted, fontSize: 8),
    );
  }

  static PdfColor _statusColor(InvoiceStatus status) {
    return switch (status) {
      InvoiceStatus.paid => const PdfColor.fromInt(0xFF10B981),
      InvoiceStatus.pending => const PdfColor.fromInt(0xFF818CF8),
      InvoiceStatus.partial => const PdfColor.fromInt(0xFFFF9E79),
      InvoiceStatus.overdue => const PdfColor.fromInt(0xFFFB7185),
    };
  }

  static Future<String> saveToDevice({
    required Uint8List bytes,
    required String filename,
  }) async {
    if (kIsWeb) {
      await Printing.sharePdf(bytes: bytes, filename: filename);
      return filename;
    }
    return savePdfBytes(bytes, filename);
  }

  static Future<void> shareInvoice({
    required Invoice invoice,
    User? studio,
    Uint8List? bytes,
  }) async {
    final data = bytes ?? await buildBytes(invoice: invoice, studio: studio);
    final name = fileName(invoice);
    final message =
        'Invoice ${invoice.number} for ${invoice.eventName} — ${invoice.contactName}';

    try {
      final tempPath = await writeTempPdf(data, name);
      if (tempPath != null) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(tempPath, mimeType: 'application/pdf', name: name)],
            subject: 'Invoice ${invoice.number}',
            text: message,
            fileNameOverrides: [name],
          ),
        );
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(data, mimeType: 'application/pdf', name: name),
          ],
          subject: 'Invoice ${invoice.number}',
          text: message,
          fileNameOverrides: [name],
        ),
      );
    } catch (_) {
      await Printing.sharePdf(
        bytes: data,
        filename: name,
        subject: 'Invoice ${invoice.number}',
        body: message,
      );
    }
  }
}

class _PdfParams {
  final Invoice invoice;
  final User? studio;
  final Uint8List? logoBytes;

  const _PdfParams({
    required this.invoice,
    this.studio,
    this.logoBytes,
  });
}
