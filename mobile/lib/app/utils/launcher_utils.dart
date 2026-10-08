import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_snackbar.dart';

class LauncherUtils {
  const LauncherUtils._();

  /// Launch the native dialer app with [phoneNumber].
  static Future<bool> makePhoneCall(BuildContext context, String phoneNumber) async {
    final clean = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.isEmpty) {
      _showFeedback(context, 'No phone number provided');
      return false;
    }

    HapticFeedback.lightImpact();
    final uri = Uri.parse('tel:$clean');
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      } else {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        _showFeedback(context, 'Could not open dialer for $phoneNumber');
      }
      return false;
    }
  }

  /// Launch native email client with [emailAddress].
  static Future<bool> sendEmail(BuildContext context, String emailAddress) async {
    final clean = emailAddress.trim();
    if (clean.isEmpty) {
      _showFeedback(context, 'No email address provided');
      return false;
    }

    HapticFeedback.lightImpact();
    final uri = Uri.parse('mailto:$clean');
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      } else {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        _showFeedback(context, 'Could not open email app for $clean');
      }
      return false;
    }
  }

  /// Launch WhatsApp with [phoneNumber] and optional [prefilledMessage].
  static Future<bool> openWhatsApp(
    BuildContext context,
    String phoneNumber, {
    String? prefilledMessage,
  }) async {
    final cleanDigits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (cleanDigits.isEmpty) {
      _showFeedback(context, 'No phone number provided');
      return false;
    }
    final normalized =
        cleanDigits.length == 10 ? '91$cleanDigits' : cleanDigits;
    final textParam =
        prefilledMessage != null ? Uri.encodeComponent(prefilledMessage) : '';
    final urlString =
        'https://wa.me/$normalized${textParam.isNotEmpty ? '?text=$textParam' : ''}';
    final uri = Uri.parse(urlString);

    HapticFeedback.lightImpact();
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        return await launchUrl(uri);
      }
    } catch (_) {
      if (context.mounted) {
        _showFeedback(context, 'Could not open WhatsApp for $phoneNumber');
      }
      return false;
    }
  }

  static void _showFeedback(BuildContext context, String message) {
    AppSnackBar.error(context, message);
  }
}
