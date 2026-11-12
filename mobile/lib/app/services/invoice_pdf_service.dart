import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/invoice.dart';
import '../models/user.dart';
import '../utils/validators.dart';
import 'api_config.dart';
import 'file_store.dart';

/// Single PDF pipeline used by invoices and receipts.
class InvoicePdfService {
  const InvoicePdfService._();

  static final _money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs. ',
    decimalDigits: 2,
  );
  static final _date = DateFormat('d MMMM yyyy');

  static const _ink = PdfColor.fromInt(0xFF0F172A);
  static const _navy = PdfColor.fromInt(0xFF1E293B);
  static const _aqua = PdfColor.fromInt(0xFF3B9CC4);
  static const _tint = PdfColor.fromInt(0xFFEFF6FB);
  static const _tintStrong = PdfColor.fromInt(0xFFE3EFF8);
  static const _tintBorder = PdfColor.fromInt(0xFFCFE4EF);
  static const _muted = PdfColor.fromInt(0xFF64748B);
  static const _body = PdfColor.fromInt(0xFF334155);
  static const _line = PdfColor.fromInt(0xFFE2E8F0);

  static String fileName(Invoice invoice, {User? studio}) {
    final studioName = _safeFilename(
      _firstNonEmpty([
        studio?.studioName,
        studio?.ownerName,
        studio?.username,
        'Studio',
      ]),
    );
    final number = _safeFilename(
      invoice.number.trim().isEmpty ? 'document' : invoice.number,
    );
    return '${studioName}_$number.pdf';
  }

  static Future<Uint8List> buildBytes({
    required Invoice invoice,
    User? studio,
  }) async {
    final results = await Future.wait([
      _fetchImage(studio?.logoUrl),
      _fetchImage(studio?.paymentQrUrl),
    ]);

    return compute(
      _generatePdfBytes,
      _PdfParams(
        invoice: invoice,
        studio: studio,
        logoBytes: results[0],
        qrBytes: results[1],
      ),
    );
  }

  static Future<Uint8List?> _fetchImage(String? url) async {
    final raw = url?.trim() ?? '';
    if (raw.isEmpty) return null;
    final resolved = ApiConfig.resolveMedia(raw);
    if (!resolved.startsWith('http://') && !resolved.startsWith('https://')) {
      return null;
    }
    try {
      final response = await http.get(Uri.parse(resolved));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
    } catch (_) {
      // The PDF still renders without the image.
    }
    return null;
  }

  static Future<Uint8List> _generatePdfBytes(_PdfParams params) async {
    final invoice = params.invoice;
    final studio = params.studio;
    final studioName = _firstNonEmpty([
      studio?.studioName,
      studio?.ownerName,
      studio?.username,
    ]);
    final logo = params.logoBytes == null
        ? null
        : pw.MemoryImage(params.logoBytes!);
    final qr = params.qrBytes == null ? null : pw.MemoryImage(params.qrBytes!);
    final socials = _socialLinks(studio);
    final hasUpi = invoice.upiId.trim().isNotEmpty;

    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 26, 32, 24),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
        footer: (context) => _footer(context, studioName),
        build: (context) => [
          _header(studio, studioName, logo, socials),
          pw.SizedBox(height: 12),
          pw.Container(height: 0.8, color: _line),
          pw.SizedBox(height: 14),
          _clientAndSummary(invoice),
          pw.SizedBox(height: 14),
          _tableHeader(),
          ..._tableRows(invoice),
          pw.SizedBox(height: 12),
          _totals(invoice),
          if (hasUpi || qr != null) ...[
            pw.SizedBox(height: 12),
            _payment(invoice, qr),
          ],
          if (socials.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _viewMyWork(socials),
          ],
          pw.SizedBox(height: 12),
          _terms(invoice),
        ],
      ),
    );
    return document.save();
  }

  // ---------------------------------------------------------------- Header

  static pw.Widget _header(
    User? studio,
    String studioName,
    pw.ImageProvider? logo,
    List<_SocialLink> socials,
  ) {
    final specialties = studio?.specialties.trim() ?? '';
    final location = _joinNonEmpty([studio?.address, studio?.city], ', ');
    final phone = _formatPhone(studio?.phone);
    final email = studio?.email.trim() ?? '';

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _logoBox(logo, studioName),
        pw.SizedBox(width: 18),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _studioTitle(studioName.isEmpty ? 'Your Studio' : studioName),
              if (specialties.isNotEmpty) ...[
                pw.SizedBox(height: 5),
                pw.Text(
                  specialties.toUpperCase(),
                  style: pw.TextStyle(
                    color: _body,
                    fontSize: 7.5,
                    letterSpacing: 2.2,
                  ),
                ),
              ],
              pw.SizedBox(height: 9),
              if (location.isNotEmpty) _iconLine(_Svg.pin, location),
              if (phone.isNotEmpty) _iconLine(_Svg.phone, phone),
              if (email.isNotEmpty) _iconLine(_Svg.mail, email),
            ],
          ),
        ),
        if (socials.isNotEmpty) ...[
          pw.Container(
            width: 0.8,
            height: 78,
            color: _line,
            margin: const pw.EdgeInsets.symmetric(horizontal: 16),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 6),
              ...socials.map(
                (link) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 9),
                  child: pw.UrlLink(
                    destination: link.url,
                    child: pw.Row(
                      children: [
                        pw.SvgImage(svg: link.icon, width: 12, height: 12),
                        pw.SizedBox(width: 8),
                        pw.Text(
                          link.display,
                          style: const pw.TextStyle(color: _body, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static pw.Widget _studioTitle(String name) {
    final words = name.toUpperCase().split(RegExp(r'\s+'));
    final style = pw.TextStyle(
      color: _ink,
      fontSize: 24,
      fontWeight: pw.FontWeight.bold,
    );
    if (words.length < 2) return pw.Text(words.first, style: style);
    return pw.RichText(
      text: pw.TextSpan(
        style: style,
        children: [
          pw.TextSpan(text: '${words.sublist(0, words.length - 1).join(' ')} '),
          pw.TextSpan(
            text: words.last,
            style: const pw.TextStyle(color: _aqua),
          ),
        ],
      ),
    );
  }

  static pw.Widget _logoBox(pw.ImageProvider? logo, String studioName) {
    const size = 82.0;
    if (logo != null) {
      return pw.Container(
        width: size,
        height: size,
        decoration: pw.BoxDecoration(
          color: _navy,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.ClipRRect(
          horizontalRadius: 8,
          verticalRadius: 8,
          child: pw.Image(logo, fit: pw.BoxFit.cover),
        ),
      );
    }
    final initial = studioName.isEmpty
        ? 'S'
        : studioName.substring(0, 1).toUpperCase();
    return pw.Container(
      width: size,
      height: size,
      decoration: pw.BoxDecoration(
        color: _navy,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Center(
        child: pw.Text(
          initial,
          style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 34,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------ Client & summary

  static pw.Widget _clientAndSummary(Invoice invoice) {
    final phone = _formatPhone(invoice.phone);
    final address = invoice.address.trim();
    final label = _documentLabel(invoice);

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 5,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 6),
              _label('CLIENT'),
              pw.SizedBox(height: 6),
              pw.Text(
                invoice.contactName.trim().isEmpty
                    ? 'Client'
                    : invoice.contactName.trim(),
                style: pw.TextStyle(
                  color: _ink,
                  fontSize: 17,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              if (phone.isNotEmpty) _iconLine(_Svg.phone, phone, size: 9.5),
              if (address.isNotEmpty) _iconLine(_Svg.pin, address, size: 9.5),
            ],
          ),
        ),
        pw.Container(
          width: 0.8,
          height: 110,
          color: _line,
          margin: const pw.EdgeInsets.symmetric(horizontal: 14),
        ),
        pw.Expanded(
          flex: 6,
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _tintBorder),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.fromLTRB(12, 10, 10, 9),
                  decoration: const pw.BoxDecoration(
                    color: _tint,
                    borderRadius: pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(8),
                      topRight: pw.Radius.circular(8),
                    ),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              _documentHeading(invoice),
                              style: pw.TextStyle(
                                color: _aqua,
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 1.8,
                              ),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              '& PROJECT SUMMARY',
                              style: const pw.TextStyle(
                                color: _muted,
                                fontSize: 6.5,
                                letterSpacing: 2.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: pw.BoxDecoration(
                          color: _navy,
                          borderRadius: pw.BorderRadius.circular(5),
                        ),
                        child: pw.Text(
                          invoice.number,
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 9.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(12, 8, 12, 6),
                  child: pw.Column(
                    children: [
                      _summaryRow(
                        _Svg.calendar,
                        '$label Date',
                        _date.format(invoice.issuedOn),
                      ),
                      _summaryRow(
                        _Svg.calendar,
                        'Due Date',
                        _date.format(invoice.dueDate),
                      ),
                      _summaryRow(
                        _Svg.document,
                        'Total Deliverables',
                        '${invoice.deliverables.length}',
                      ),
                      if (invoice.eventName.trim().isNotEmpty)
                        _summaryRow(
                          _Svg.clock,
                          'Event / Project',
                          invoice.eventName.trim(),
                          last: true,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _summaryRow(
    String icon,
    String label,
    String value, {
    bool last = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      decoration: last
          ? null
          : const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _line, width: 0.5),
              ),
            ),
      child: pw.Row(
        children: [
          pw.SvgImage(svg: icon, width: 10, height: 10),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Text(
              label,
              style: const pw.TextStyle(color: _body, fontSize: 9),
            ),
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
      ),
    );
  }

  // ----------------------------------------------------------------- Table

  static const _colIndex = 34.0;
  static const _colAmount = 120.0;

  static pw.Widget _tableHeader() {
    pw.Widget cell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
      return pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 9.5,
          fontWeight: pw.FontWeight.bold,
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const pw.BoxDecoration(
        color: _navy,
        borderRadius: pw.BorderRadius.only(
          topLeft: pw.Radius.circular(8),
          topRight: pw.Radius.circular(8),
        ),
      ),
      child: pw.Row(
        children: [
          pw.SizedBox(width: _colIndex, child: cell('#')),
          pw.Expanded(child: cell('Deliverable')),
          pw.SizedBox(
            width: _colAmount,
            child: cell('Amount', align: pw.TextAlign.right),
          ),
        ],
      ),
    );
  }

  static List<pw.Widget> _tableRows(Invoice invoice) {
  final items = invoice.deliverables;

  if (items.isEmpty) {
    return [
      _tableRow(index: '-', name: 'No items added', amount: '-'),
    ];
  }

  return [
    for (var i = 0; i < items.length; i++)
      _tableRow(
        index: '${i + 1}',
        name: items[i].name,
        amount: items[i].cost > 0
            ? _money.format(items[i].cost)
            : '',
      ),
  ];
}

  static pw.Widget _tableRow({
    required String index,
    required String name,
    required String amount,
  }) {
    const style = pw.TextStyle(color: _ink, fontSize: 9.5);
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: _line, width: 0.8),
          right: pw.BorderSide(color: _line, width: 0.8),
          bottom: pw.BorderSide(color: _line, width: 0.8),
        ),
      ),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: _colIndex,
            child: pw.Text(index, style: style),
          ),
          pw.Expanded(child: pw.Text(name, style: style)),
          pw.SizedBox(
            width: _colAmount,
            child: pw.Text(amount, textAlign: pw.TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Totals

  static pw.Widget _totals(Invoice invoice) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 240,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _line),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: pw.Column(
                children: [
                  _totalRow('Subtotal', _money.format(invoice.total)),
                  _totalRow(
                    'Amount received',
                    _money.format(invoice.amountReceived),
                  ),
                ],
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.fromLTRB(14, 11, 14, 11),
              decoration: const pw.BoxDecoration(
                color: _tintStrong,
                borderRadius: pw.BorderRadius.only(
                  bottomLeft: pw.Radius.circular(8),
                  bottomRight: pw.Radius.circular(8),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Balance due',
                    style: pw.TextStyle(
                      color: _ink,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    _money.format(invoice.pendingAmount),
                    style: pw.TextStyle(
                      color: _ink,
                      fontSize: 13.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _totalRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 9),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(color: _muted, fontSize: 9)),
          pw.Text(value, style: const pw.TextStyle(color: _ink, fontSize: 9)),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- Payment

  static pw.Widget _payment(Invoice invoice, pw.ImageProvider? qr) {
    final upiId = invoice.upiId.trim();

    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _tintBorder, width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            flex: 4,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _label('PAYMENT METHOD'),
                pw.SizedBox(height: 10),
                pw.Row(
                  children: [
                    pw.Container(
                      width: 34,
                      height: 34,
                      decoration: pw.BoxDecoration(
                        color: _tint,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          'UPI',
                          style: pw.TextStyle(
                            color: _navy,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            upiId.isNotEmpty ? 'UPI ID' : 'UPI',
                            style: pw.TextStyle(
                              color: _ink,
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            upiId.isNotEmpty ? upiId : 'Scan the QR to pay',
                            style: const pw.TextStyle(
                              color: _ink,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.Container(
            width: 0.8,
            height: 50,
            color: _line,
            margin: const pw.EdgeInsets.symmetric(horizontal: 14),
          ),
          pw.Expanded(
            flex: 5,
            child: pw.RichText(
              text: pw.TextSpan(
                style: const pw.TextStyle(
                  color: _body,
                  fontSize: 8.5,
                  lineSpacing: 3,
                ),
                children: [
                  const pw.TextSpan(text: 'Please mention '),
                  pw.WidgetSpan(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: pw.BoxDecoration(
                        color: _tint,
                        borderRadius: pw.BorderRadius.circular(3),
                      ),
                      child: pw.Text(
                        invoice.number,
                        style: pw.TextStyle(
                          color: _ink,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const pw.TextSpan(
                    text: ' in the UPI remarks while making the payment.',
                  ),
                ],
              ),
            ),
          ),
          if (qr != null) ...[
            pw.SizedBox(width: 12),
            pw.Column(
              children: [
                pw.Container(
                  width: 64,
                  height: 64,
                  padding: const pw.EdgeInsets.all(3),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    border: pw.Border.all(color: _line),
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Image(qr, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Scan to Pay',
                  style: const pw.TextStyle(color: _body, fontSize: 7.5),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------- View my work

  static pw.Widget _viewMyWork(List<_SocialLink> links) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _tint,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            flex: 4,
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(left: 6, right: 10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'VIEW MY WORK',
                    style: pw.TextStyle(
                      color: _ink,
                      fontSize: 10.5,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.4,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Explore my latest work on ${_joinNonEmpty(links.map((l) => l.label).toList(), ', ')}.',
                    style: const pw.TextStyle(
                      color: _body,
                      fontSize: 8.5,
                      lineSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (final link in links) ...[
            pw.SizedBox(width: 8),
            pw.Expanded(
              flex: 3,
              child: pw.UrlLink(
                destination: link.url,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 9,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    border: pw.Border.all(color: _line),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    children: [
                      pw.SvgImage(svg: link.icon, width: 15, height: 15),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        link.display,
                        maxLines: 1,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          color: _ink,
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        link.caption,
                        style: const pw.TextStyle(color: _muted, fontSize: 7),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static List<_SocialLink> _socialLinks(User? studio) {
    final links = <_SocialLink>[];
    void add(
      String label,
      String caption,
      String? value,
      String? prefix,
      String icon, {
      List<String> domains = const [],
    }) {
      final raw = value?.trim() ?? '';
      if (raw.isEmpty) return;
      final isUrl =
          prefix == null || Validators.looksLikeUrl(raw, domains: domains);
      final name = raw.replaceFirst('@', '');
      final url = isUrl
          ? (Validators.parseUrl(raw)?.toString() ?? raw)
          : '$prefix$name';
      final display = isUrl
          ? raw.replaceFirst(RegExp(r'^https?://(www\.)?'), '')
          : '@$name';
      links.add(_SocialLink(label, caption, display, url, icon));
    }

    add(
      'Instagram',
      'Instagram',
      studio?.instagram,
      'https://instagram.com/',
      _Svg.instagram,
      domains: Validators.instagramDomains,
    );
    add(
      'YouTube',
      'YouTube',
      studio?.youtube,
      'https://youtube.com/@',
      _Svg.youtube,
      domains: Validators.youtubeDomains,
    );
    add('Website', 'Portfolio', studio?.website, null, _Svg.globe);
    return links;
  }

  // ----------------------------------------------------------------- Terms

  static pw.Widget _terms(Invoice invoice) {
    final terms = switch (_documentKind(invoice)) {
      _DocumentKind.invoice => [
        'Advance payment confirms the booking.',
        'Remaining amount to be paid on or before the due date (${_date.format(invoice.dueDate)}).',
        'Please mention ${invoice.number} in the payment remarks.',
        'Delivery timelines may vary by package and project scope.',
      ],
      _DocumentKind.receipt => [
        'This receipt confirms the payments received so far.',
        'Any balance due is payable before final delivery.',
        'Please keep this receipt for your records.',
      ],
    };

    // Wrapped in a Container so MultiPage moves the block as a whole.
    return pw.Container(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'TERMS & CONDITIONS',
            style: pw.TextStyle(
              color: _ink,
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.4,
            ),
          ),
          pw.SizedBox(height: 7),
          ...terms.map(
            (term) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4, left: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 3,
                    height: 3,
                    margin: const pw.EdgeInsets.only(top: 3.5, right: 8),
                    decoration: const pw.BoxDecoration(
                      color: _body,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      term,
                      style: const pw.TextStyle(color: _body, fontSize: 8.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Footer

  static pw.Widget _footer(pw.Context context, String studioName) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14),
      padding: const pw.EdgeInsets.only(top: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _line, width: 0.8)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              studioName.isEmpty
                  ? 'Thank you for trusting us with your story.'
                  : 'Thank you for trusting $studioName with your story.',
              style: const pw.TextStyle(color: _body, fontSize: 9),
            ),
          ),
          pw.Container(
            width: 0.8,
            height: 14,
            color: _line,
            margin: const pw.EdgeInsets.symmetric(horizontal: 18),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(color: _muted, fontSize: 8.5),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- Helpers

  static pw.Widget _iconLine(String icon, String text, {double size = 9}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SvgImage(svg: icon, width: size + 1, height: size + 1),
          pw.SizedBox(width: 10),
          pw.Flexible(
            child: pw.Text(
              text,
              style: pw.TextStyle(color: _body, fontSize: size),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _label(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        color: _muted,
        fontSize: 7.5,
        fontWeight: pw.FontWeight.bold,
        letterSpacing: 1.8,
      ),
    );
  }

  static String _formatPhone(String? value) {
    final raw = value?.trim() ?? '';
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    return raw;
  }

  static _DocumentKind _documentKind(Invoice invoice) {
    final number = invoice.number.toUpperCase();
    if (number.startsWith('REC')) return _DocumentKind.receipt;
    return _DocumentKind.invoice;
  }

  static String _documentLabel(Invoice invoice) {
    return switch (_documentKind(invoice)) {
      _DocumentKind.invoice => 'Invoice',
      _DocumentKind.receipt => 'Receipt',
    };
  }

  static String _documentHeading(Invoice invoice) {
    return switch (_documentKind(invoice)) {
      _DocumentKind.invoice => 'INVOICE',
      _DocumentKind.receipt => 'PAYMENT RECEIPT',
    };
  }

  static String documentTitle(Invoice invoice) => _documentLabel(invoice);

  static String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final clean = value?.trim() ?? '';
      if (clean.isNotEmpty) return clean;
    }
    return '';
  }

  static String _joinNonEmpty(List<String?> values, [String sep = '  |  ']) {
    return values
        .map((value) => value?.trim() ?? '')
        .where((value) => value.isNotEmpty)
        .join(sep);
  }

  static String _safeFilename(String value) {
    final safe = value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_');
    return safe.isEmpty ? 'Studio' : safe;
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
    Rect? sharePositionOrigin,
  }) async {
    final data = bytes ?? await buildBytes(invoice: invoice, studio: studio);
    final name = fileName(invoice, studio: studio);
    final message =
        '${_documentLabel(invoice)} ${invoice.number} for ${invoice.contactName}';
    final safeOrigin = sharePositionOrigin ?? const Rect.fromLTWH(0, 0, 100, 100);
    try {
      final tempPath = await writeTempPdf(data, name);
      final files = tempPath == null
          ? [XFile.fromData(data, mimeType: 'application/pdf', name: name)]
          : [XFile(tempPath, mimeType: 'application/pdf', name: name)];
      await SharePlus.instance.share(
        ShareParams(
          files: files,
          subject: name,
          text: message,
          sharePositionOrigin: safeOrigin,
          fileNameOverrides: [name],
        ),
      );
    } catch (_) {
      await Printing.sharePdf(
        bytes: data,
        filename: name,
        subject: name,
        body: message,
        bounds: safeOrigin,
      );
    }
  }
}

enum _DocumentKind { invoice, receipt }

class _SocialLink {
  const _SocialLink(
    this.label,
    this.caption,
    this.display,
    this.url,
    this.icon,
  );

  final String label;
  final String caption;
  final String display;
  final String url;
  final String icon;
}

class _PdfParams {
  const _PdfParams({
    required this.invoice,
    this.studio,
    this.logoBytes,
    this.qrBytes,
  });

  final Invoice invoice;
  final User? studio;
  final Uint8List? logoBytes;
  final Uint8List? qrBytes;
}

/// 24x24 Material-style icons rendered as vector SVG inside the PDF.
abstract final class _Svg {
  static const _c = '#334155';

  static String _icon(String path, [String color = _c]) =>
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
      '<path fill="$color" d="$path"/></svg>';

  static final phone = _icon(
    'M6.62 10.79c1.44 2.83 3.76 5.14 6.59 6.59l2.2-2.2c.27-.27.67-.36 1.02-.24 '
    '1.12.37 2.33.57 3.57.57.55 0 1 .45 1 1V20c0 .55-.45 1-1 1-9.39 0-17-7.61-17-17 '
    '0-.55.45-1 1-1h3.5c.55 0 1 .45 1 1 0 1.25.2 2.45.57 3.57.11.35.03.74-.25 1.02l-2.2 2.2z',
  );

  static final mail = _icon(
    'M20 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2z'
    'm0 14H4V8l8 5 8-5v10zm-8-7L4 6h16l-8 5z',
  );

  static final pin = _icon(
    'M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7z'
    'm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z',
  );

  static final calendar = _icon(
    'M20 3h-1V1h-2v2H7V1H5v2H4c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V5'
    'c0-1.1-.9-2-2-2zm0 18H4V8h16v13z',
  );

  static final document = _icon(
    'M14 2H6c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 1.99 2H18c1.1 0 2-.9 2-2V8l-6-6z'
    'm2 16H8v-2h8v2zm0-4H8v-2h8v2zm-3-5V3.5L18.5 9H13z',
  );

  static final clock = _icon(
    'M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2z'
    'M12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67z',
  );

  static final globe = _icon(
    'M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 17.93'
        'c-3.95-.49-7-3.85-7-7.93 0-.62.08-1.21.21-1.79L9 15v1c0 1.1.9 2 2 2v1.93zm6.9-2.54'
        'c-.26-.81-1-1.39-1.9-1.39h-1v-3c0-.55-.45-1-1-1H8v-2h2c.55 0 1-.45 1-1V7h2c1.1 0 2-.9 2-2'
        'v-.41c2.93 1.19 5 4.06 5 7.41 0 2.08-.8 3.97-2.1 5.39z',
    '#1D4ED8',
  );

  static const instagram =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
      '<rect x="2.5" y="2.5" width="19" height="19" rx="5.5" fill="none" '
      'stroke="#E1306C" stroke-width="2.2"/>'
      '<circle cx="12" cy="12" r="4.3" fill="none" stroke="#E1306C" stroke-width="2.2"/>'
      '<circle cx="17.4" cy="6.6" r="1.3" fill="#E1306C"/></svg>';

  static const youtube =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
      '<rect x="1" y="4.5" width="22" height="15" rx="4.5" fill="#FF0000"/>'
      '<path d="M10 8.6v6.8l5.8-3.4z" fill="#FFFFFF"/></svg>';
}
