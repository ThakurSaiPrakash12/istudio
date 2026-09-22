import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/studio_event.dart';
import '../theme/app_colors.dart';

class PaymentProofPreviewButton extends StatelessWidget {
  const PaymentProofPreviewButton({
    super.key,
    required this.payments,
  });

  final List<PaymentRecord> payments;

  @override
  Widget build(BuildContext context) {
    final proofCount = payments.where((payment) => payment.hasProof).length;
    if (proofCount == 0) return const SizedBox.shrink();

    return TextButton.icon(
      onPressed: () => PaymentProofPreview.show(context, payments),
      style: TextButton.styleFrom(
        foregroundColor: context.accentColor,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: const Icon(Icons.visibility_outlined, size: 15),
      label: Text(
        proofCount == 1 ? 'Preview proof' : 'Preview proofs ($proofCount)',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class PaymentProofPreview {
  const PaymentProofPreview._();

  static void show(BuildContext context, List<PaymentRecord> payments) {
    final proofs = payments.where((payment) => payment.hasProof).toList();
    if (proofs.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt_long_rounded,
                      color: sheetContext.accentColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Payment Proof',
                      style: GoogleFonts.plusJakartaSans(
                        color: sheetContext.textMain,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: Icon(Icons.close, color: sheetContext.textMuted),
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: proofs
                        .map(
                          (payment) => _ProofTile(
                            payment: payment,
                            onTap: () =>
                                _showFullScreen(sheetContext, payment.proof!),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _showFullScreen(BuildContext context, String proof) {
    final isImage = proof.startsWith('http') || proof.startsWith('data:image');
    if (!isImage) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: context.cardBg,
          title: Text('Payment Proof', style: TextStyle(color: context.textMain)),
          content: Text(proof, style: TextStyle(color: context.textMuted)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Close', style: TextStyle(color: context.accentColor)),
            ),
          ],
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black.withValues(alpha: 0.92),
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 700),
                child: _buildImage(proof),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildImage(String proof) {
    if (proof.startsWith('data:image')) {
      try {
        return Image.memory(
          base64Decode(proof.substring(proof.indexOf(',') + 1)),
          fit: BoxFit.contain,
        );
      } catch (_) {
        return const Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Could not load image proof.',
            style: TextStyle(color: Colors.white70),
          ),
        );
      }
    }

    return Image.network(
      proof,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Could not load image proof.',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}

class _ProofTile extends StatelessWidget {
  const _ProofTile({required this.payment, required this.onTap});

  final PaymentRecord payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(payment.method.icon, color: context.accentColor),
      title: Text(payment.title, style: TextStyle(color: context.textMain)),
      subtitle: Text(
        '${payment.method.label} · ${payment.amount.toStringAsFixed(0)}',
        style: TextStyle(color: context.textMuted, fontSize: 12),
      ),
      trailing: Icon(Icons.open_in_new_rounded, color: context.accentColor, size: 18),
      onTap: onTap,
    );
  }
}
