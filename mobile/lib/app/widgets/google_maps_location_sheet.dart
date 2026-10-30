import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/location_search_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_snackbar.dart';
import '../utils/google_maps_location_parser.dart';

class GoogleMapsLocationSheet extends StatefulWidget {
  const GoogleMapsLocationSheet({
    super.key,
    this.initialAddress,
    this.initialLatitude,
    this.initialLongitude,
    required this.onLocationConfirmed,
  });

  final String? initialAddress;
  final double? initialLatitude;
  final double? initialLongitude;
  final ValueChanged<PlaceLocation> onLocationConfirmed;

  static Future<PlaceLocation?> show(
    BuildContext context, {
    String? initialAddress,
    double? initialLatitude,
    double? initialLongitude,
  }) {
    return showModalBottomSheet<PlaceLocation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => GoogleMapsLocationSheet(
        initialAddress: initialAddress,
        initialLatitude: initialLatitude,
        initialLongitude: initialLongitude,
        onLocationConfirmed: (place) => Navigator.of(context).pop(place),
      ),
    );
  }

  @override
  State<GoogleMapsLocationSheet> createState() => _GoogleMapsLocationSheetState();
}

class _GoogleMapsLocationSheetState extends State<GoogleMapsLocationSheet> {
  final _inputController = TextEditingController();
  final _nameController = TextEditingController();
  final _parser = GoogleMapsLocationParser();

  bool _resolving = false;
  ParsedCoordinates? _parsedCoords;
  String? _resolvedAddress;
  ReverseGeocodeResult? _reverseDetails;

  @override
  void initState() {
    super.initState();
    // Start clean with NO default location.
    // The "Location Found" card will ONLY show after the user pastes and verifies a link!
    _nameController.text = '';
    _inputController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _inputController.removeListener(_onInputChanged);
    _inputController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _parsedCoords = null;
        _resolvedAddress = null;
      });
      return;
    }

    // Only parse if it's a valid Google Maps URL
    if (GoogleMapsLocationParser.isGoogleMapsUrlOrCoords(text)) {
      final syncRes = GoogleMapsLocationParser.parseSync(text);
      if (syncRes != null) {
        setState(() {
          _parsedCoords = syncRes;
          if (_nameController.text.trim().isEmpty && syncRes.placeName != null) {
            _nameController.text = syncRes.placeName!;
          }
        });
      }
    }
  }

  Future<void> _handleParse() async {
    final rawText = _inputController.text.trim();
    if (rawText.isEmpty) {
      AppSnackBar.info(context, 'Please paste a Google Maps link first.');
      return;
    }

    if (!GoogleMapsLocationParser.isGoogleMapsUrlOrCoords(rawText)) {
      AppSnackBar.error(
        context,
        'Invalid link or coordinates. Please paste a valid Google Maps link or coordinates.',
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _resolving = true);

    try {
      final res = await _parser.parseAsync(rawText);
      if (res != null) {
        ReverseGeocodeResult? details;
        try {
          details = await _parser.reverseGeocodeDetails(res.latitude, res.longitude);
        } catch (_) {}

        String? addr = details?.displayName ?? res.placeName;
        if (addr == null || addr.isEmpty || RegExp(r'^[-+]?\d').hasMatch(addr)) {
          addr = await _parser.reverseGeocode(res.latitude, res.longitude) ?? addr;
        }

        if (mounted) {
          setState(() {
            _parsedCoords = res;
            _resolvedAddress = addr;
            _reverseDetails = details;
            if (addr != null && addr.isNotEmpty) {
              _nameController.text = addr;
            }
          });
          AppSnackBar.success(
            context,
            addr != null && addr.isNotEmpty
                ? 'Location found: ${addr.split(',').first.trim()}'
                : 'Studio location locked!',
            duration: const Duration(seconds: 3),
          );
        }
      } else {
        if (mounted) {
          AppSnackBar.error(
            context,
            'Could not find location from this link. Please copy a direct Google Maps pin link.',
          );
        }
      }
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      if (!GoogleMapsLocationParser.isGoogleMapsUrlOrCoords(text)) {
        if (mounted) {
          AppSnackBar.error(
            context,
            'Clipboard text is not a valid Google Maps link. Please copy a link from Google Maps.',
          );
        }
        return;
      }
      HapticFeedback.selectionClick();
      _inputController.text = text;
      await _handleParse();
    } else {
      if (mounted) {
        AppSnackBar.info(context, 'Clipboard is empty.');
      }
    }
  }

  Future<void> _openGoogleMaps() async {
    HapticFeedback.selectionClick();
    final searchQuery = _nameController.text.trim();
    final Uri url;

    if (searchQuery.isNotEmpty) {
      url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(searchQuery)}',
      );
    } else {
      url = Uri.parse('https://www.google.com/maps');
    }

    try {
      final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!ok) {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(context, 'Could not open Google Maps app.');
      }
    }
  }

  Future<void> _previewOnMap() async {
    if (_parsedCoords == null) return;
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${_parsedCoords!.latitude},${_parsedCoords!.longitude}',
    );
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _confirm() {
    if (_parsedCoords == null) return;
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : _resolvedAddress ?? 'Studio Location';

    final place = PlaceLocation(
      name: name,
      displayName: name,
      latitude: _parsedCoords!.latitude,
      longitude: _parsedCoords!.longitude,
      city: _reverseDetails?.city,
      state: _reverseDetails?.state,
      district: _reverseDetails?.district,
      country: _reverseDetails?.country,
    );

    widget.onLocationConfirmed(place);
  }

  @override
  Widget build(BuildContext context) {
    final textMain = context.textMain;
    final textMuted = context.textMuted;
    final accent = context.accentColor;
    final isDark = context.isDark;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 20,
            right: 20,
            top: 14,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xF5121622) : const Color(0xF8FFFFFF),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: accent.withValues(alpha: isDark ? 0.30 : 0.20),
              width: 1.0,
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: textMuted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: accent.withValues(alpha: 0.3)),
                      ),
                      child: Icon(Icons.add_location_alt_rounded,
                          color: accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Exact Location via Google Maps',
                            style: GoogleFonts.plusJakartaSans(
                              color: textMain,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Enables 100% accurate Discover & Nearby searches',
                            style: TextStyle(color: textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: textMuted),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Step 1: Open Google Maps button
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF161B29)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF263045)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'STEP 1',
                              style: TextStyle(
                                color: accent,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Open Google Maps & find your studio',
                              style: TextStyle(
                                color: textMain,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '1. Search your studio or long-press to drop a pin on your building.\n'
                        '2. Tap "Share" ➔ "Copy link".',
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openGoogleMaps,
                          icon: const Icon(Icons.map_rounded, size: 18),
                          label: const Text('Open Google Maps App'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: accent,
                            side: BorderSide(
                                color: accent.withValues(alpha: 0.45)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Step 2: Paste link or coordinates
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF161B29)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF263045)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'STEP 2',
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Paste Google Maps Link',
                                style: TextStyle(
                                  color: textMain,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: _pasteFromClipboard,
                            icon: const Icon(Icons.content_paste_rounded, size: 14),
                            label: const Text('Paste', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              foregroundColor: accent,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _inputController,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: textMain,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Paste Google Maps link (maps.app.goo.gl/...)',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: textMuted.withValues(alpha: 0.65),
                          ),
                          filled: true,
                          fillColor: context.cardBg,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: context.cardBorder),
                          ),
                          suffixIcon: _resolving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Center(
                                    child: SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.sky,
                                      ),
                                    ),
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.arrow_forward_rounded,
                                      size: 18),
                                  color: accent,
                                  onPressed: _handleParse,
                                ),
                        ),
                        onSubmitted: (_) => _handleParse(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Location Found card — shows readable address, coordinates hidden
                if (_parsedCoords != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.pastelMint.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.pastelMint.withValues(alpha: 0.40),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.pastelMint.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.pastelMint,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Location Found',
                                style: TextStyle(
                                  color: AppColors.pastelMint,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _nameController.text.trim().isNotEmpty
                                    ? _nameController.text.trim()
                                    : (_resolvedAddress ?? 'Location pinned successfully'),
                                style: GoogleFonts.plusJakartaSans(
                                  color: textMain,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Verify pin in Google Maps',
                          icon: Icon(Icons.open_in_new_rounded,
                              color: accent, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: _previewOnMap,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _confirm,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Apply Location'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

