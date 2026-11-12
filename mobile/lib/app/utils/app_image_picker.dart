import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_snackbar.dart';

/// Centralized, production-grade image picker handler.
/// Handles:
/// - Camera and photo library permission states (denied, restricted, permanently denied)
/// - User cancellation (graceful null return)
/// - Missing camera on iPad / Simulators
/// - Resizing and compression (maxWidth: 2048, maxHeight: 2048, imageQuality: 85)
/// - Friendly user messaging with one-tap link to iOS Settings
class AppImagePicker {
  AppImagePicker._();

  static final ImagePicker _picker = ImagePicker();

  /// Safely picks an image from either Camera or Gallery.
  /// Never throws an unhandled exception.
  static Future<XFile?> pickImage(
    BuildContext context, {
    required ImageSource source,
    double maxWidth = 2048,
    double maxHeight = 2048,
    int imageQuality = 85,
  }) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );
      return picked;
    } on PlatformException catch (e) {
      if (!context.mounted) return null;
      _handlePlatformException(context, e, source);
      return null;
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.error(
          context,
          'Unable to select image. Please try again.',
        );
      }
      return null;
    }
  }

  /// Opens the device App Settings page
  static Future<void> openAppSettings() async {
    final uri = Uri.parse('app-settings:');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  static void _handlePlatformException(
    BuildContext context,
    PlatformException e,
    ImageSource source,
  ) {
    final code = e.code.toLowerCase();
    final message = (e.message ?? '').toLowerCase();

    final isCameraDenied = code.contains('camera_access_denied') ||
        message.contains('camera') ||
        code == 'camera_access_denied';

    final isPhotoDenied = code.contains('photo_access_denied') ||
        message.contains('photo') ||
        code == 'photo_access_denied';

    final isCameraUnavailable = code.contains('camera_unavailable') ||
        message.contains('camera unavailable') ||
        code.contains('no_available_camera');

    if (isCameraUnavailable) {
      AppSnackBar.info(
        context,
        'Camera is not available on this device. Please choose from your gallery.',
      );
      return;
    }

    if (source == ImageSource.camera && isCameraDenied) {
      _showPermissionDialog(
        context,
        title: 'Camera Permission Needed',
        content:
            'Clients Hub needs access to your camera to take studio photos and receipts. Please enable Camera access in Settings.',
      );
      return;
    }

    if (source == ImageSource.gallery && isPhotoDenied) {
      _showPermissionDialog(
        context,
        title: 'Photo Library Permission Needed',
        content:
            'Clients Hub needs access to your photo library to select photos. Please enable Photo access in Settings.',
      );
      return;
    }

    AppSnackBar.error(
      context,
      'Could not access ${source == ImageSource.camera ? 'camera' : 'photos'}. Please check permissions.',
    );
  }

  static void _showPermissionDialog(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
