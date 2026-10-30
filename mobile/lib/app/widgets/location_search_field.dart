import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/location_search_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_snackbar.dart';
import '../utils/geo_distance_utils.dart';
import '../utils/google_maps_location_parser.dart';
import 'google_maps_location_sheet.dart';

class LocationSearchField extends StatefulWidget {
  const LocationSearchField({
    super.key,
    required this.label,
    required this.controller,
    required this.onLocationSelected,
    this.hint = 'Search venue, hall, palace, or area...',
    this.initialLatitude,
    this.initialLongitude,
    this.referenceLatitude,
    this.referenceLongitude,
    this.referenceLabel,
    this.locationSearchService,
    this.onCoordinatesCleared,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final void Function(PlaceLocation place) onLocationSelected;
  final String hint;
  final double? initialLatitude;
  final double? initialLongitude;
  final double? referenceLatitude;
  final double? referenceLongitude;
  final String? referenceLabel;
  final LocationSearchService? locationSearchService;
  final VoidCallback? onCoordinatesCleared;
  final String? Function(String?)? validator;

  @override
  State<LocationSearchField> createState() => _LocationSearchFieldState();
}

class _LocationSearchFieldState extends State<LocationSearchField> {
  late final LocationSearchService _service;
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _linkInputController = TextEditingController();
  final _googleMapsParser = GoogleMapsLocationParser();

  Timer? _debounce;
  bool _searching = false;
  List<PlaceLocation> _suggestions = [];
  bool _hasCoordinates = false;
  String? _selectedText;

  @override
  void initState() {
    super.initState();
    _service = widget.locationSearchService ?? LocationSearchService();
    _hasCoordinates = widget.initialLatitude != null &&
        widget.initialLongitude != null &&
        !widget.initialLatitude!.isNaN &&
        !widget.initialLongitude!.isNaN &&
        widget.initialLatitude != 0.0 &&
        widget.initialLongitude != 0.0;

    if (_hasCoordinates) {
      _selectedText = widget.controller.text.trim();
    }

    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.unfocus(disposition: UnfocusDisposition.scope);
    _focusNode.dispose();
    _linkInputController.dispose();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted) return;
    if (!_focusNode.hasFocus) {
      final text = widget.controller.text.trim();
      if (text.isNotEmpty &&
          !_hasCoordinates &&
          widget.locationSearchService != null) {
        _autoGeocode(text);
      }
      setState(() => _suggestions = []);
    }
  }

  void _onTextChanged() {
    if (!mounted) return;
    final query = widget.controller.text.trim();
    if (_hasCoordinates && query != _selectedText) {
      setState(() => _hasCoordinates = false);
      _selectedText = null;
      widget.onCoordinatesCleared?.call();
    }
    if (query.isEmpty) {
      _debounce?.cancel();
      setState(() => _suggestions = []);
      return;
    }

    // Only active when custom search service is injected (for tests/custom mode)
    if (widget.locationSearchService != null) {
      final syncCoords = GoogleMapsLocationParser.parseSync(query);
      if (syncCoords != null) {
        _debounce?.cancel();
        final name = syncCoords.placeName ??
            (query.contains('http') ? 'Pinned Location' : query);
        _selectPlace(PlaceLocation(
          name: name,
          displayName: name,
          latitude: syncCoords.latitude,
          longitude: syncCoords.longitude,
        ));
        return;
      }

      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), () async {
        if (!mounted) return;
        setState(() => _searching = true);
        try {
          final places = await _service.searchPlaces(
            query,
            latitude: widget.referenceLatitude,
            longitude: widget.referenceLongitude,
          );
          if (!mounted) return;
          setState(() {
            _suggestions = places;
            _searching = false;
          });
        } catch (_) {
          if (!mounted) return;
          setState(() => _searching = false);
        }
      });
    }
  }

  Future<void> _autoGeocode(String query) async {
    try {
      final place = await _service.geocodeLocation(
        query,
        latitude: widget.referenceLatitude,
        longitude: widget.referenceLongitude,
      );
      if (place != null && mounted && widget.controller.text.trim() == query) {
        setState(() {
          _hasCoordinates = true;
          _selectedText = query;
        });
        widget.onLocationSelected(place);
      }
    } catch (_) {}
  }

  Future<void> _resolvePastedLink(String link) async {
    final clean = GoogleMapsLocationParser.normalizeInput(link);
    if (clean.isEmpty) {
      if (mounted) {
        AppSnackBar.info(context, 'Please paste a Google Maps link.');
      }
      return;
    }

    if (!GoogleMapsLocationParser.isGoogleMapsUrlOrCoords(clean)) {
      if (mounted) {
        AppSnackBar.error(
          context,
          'Invalid link or coordinates. Please paste a valid Google Maps link or coordinates.',
        );
      }
      return;
    }

    setState(() => _searching = true);
    try {
      final res = await _googleMapsParser.parseAsync(clean);
      if (res != null && mounted) {
        ReverseGeocodeResult? details;
        try {
          details = await _googleMapsParser.reverseGeocodeDetails(
            res.latitude,
            res.longitude,
          );
        } catch (_) {}

        String? name = details?.displayName ?? res.placeName;
        if (name == null ||
            name.isEmpty ||
            RegExp(r'^[-+]?\d').hasMatch(name)) {
          name = await _googleMapsParser.reverseGeocode(
                  res.latitude, res.longitude) ??
              name;
        }
        final finalName = name ??
            (widget.label.toLowerCase().contains('studio')
                ? 'Studio Location'
                : 'Venue Location');

        _selectPlace(PlaceLocation(
          name: finalName,
          displayName: details?.displayName ?? finalName,
          latitude: res.latitude,
          longitude: res.longitude,
          city: details?.city,
          state: details?.state,
          district: details?.district,
          country: details?.country,
        ));

        if (mounted) {
          AppSnackBar.success(
            context,
            'Location locked: ${finalName.split(',').first.trim()}',
            duration: const Duration(seconds: 3),
          );
        }
        return;
      } else {
        if (mounted) {
          AppSnackBar.error(
            context,
            'Could not find location from this link. Please copy a direct Google Maps pin link.',
          );
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _openGoogleMapsApp() async {
    HapticFeedback.selectionClick();
    final Uri url;
    final text = widget.controller.text.trim();
    if (text.isNotEmpty && !text.startsWith('http')) {
      url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(text)}',
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

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      if (!GoogleMapsLocationParser.isGoogleMapsUrlOrCoords(text)) {
        if (mounted) {
          AppSnackBar.error(
            context,
            'Clipboard does not contain a valid Google Maps link. Please open Google Maps, share & copy link.',
          );
        }
        return;
      }
      HapticFeedback.selectionClick();
      _linkInputController.text = text;
      await _resolvePastedLink(text);
    } else {
      if (mounted) {
        AppSnackBar.info(context, 'Clipboard is empty.');
      }
    }
  }

  void _selectPlace(PlaceLocation place) {
    if (!mounted) return;
    widget.controller.removeListener(_onTextChanged);
    widget.controller.text = place.displayName;
    widget.controller.addListener(_onTextChanged);

    setState(() {
      _suggestions = [];
      _hasCoordinates = true;
      _linkInputController.clear();
    });
    _selectedText = place.displayName;

    _focusNode.unfocus();
    if (mounted) widget.onLocationSelected(place);
  }

  void _clearLocation() {
    widget.controller.clear();
    _linkInputController.clear();
    setState(() {
      _hasCoordinates = false;
      _selectedText = null;
      _suggestions = [];
    });
    widget.onCoordinatesCleared?.call();
  }

  Future<void> _openGoogleMapsPicker() async {
    final result = await GoogleMapsLocationSheet.show(
      context,
      initialAddress: widget.controller.text.trim(),
      initialLatitude: widget.initialLatitude,
      initialLongitude: widget.initialLongitude,
    );
    if (result != null && mounted) {
      _selectPlace(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGoogleMaps = widget.locationSearchService == null;
    final isStudio = widget.label.toLowerCase().contains('studio');

    // Custom injected search service mode (e.g. for unit tests)
    if (!isGoogleMaps) {
      return _buildSearchServiceMode(context, isDark);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.textMain,
              ),
            ),
            if (_hasCoordinates)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 13,
                    color: AppColors.pastelMint,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Location locked',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.pastelMint,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),

        // If coordinates are already locked/verified, show Verified Card
        if (_hasCoordinates)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.pastelMint
                  .withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.pastelMint
                    .withValues(alpha: isDark ? 0.35 : 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
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
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              isStudio
                                  ? 'Studio Location Verified'
                                  : 'Venue Location Verified',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.pastelMint,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: AppColors.pastelMint,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.controller.text.isNotEmpty
                            ? widget.controller.text
                            : (_selectedText ?? 'Pinned on Google Maps'),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: context.textMain,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Change location',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: context.textMuted,
                  onPressed: _clearLocation,
                ),
              ],
            ),
          )
        else ...[
          // STEP 1 Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'STEP 1',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: context.accentColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isStudio
                            ? 'Open Google Maps & find your studio'
                            : 'Open Google Maps & find venue',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.textMain,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  isStudio
                      ? '1. Search your studio or long-press to drop a pin on your building.\n2. Tap "Share" ➔ "Copy link".'
                      : '1. Search the event venue or long-press to drop a pin.\n2. Tap "Share" ➔ "Copy link".',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    height: 1.5,
                    color: context.textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openGoogleMapsApp,
                    icon: const Icon(Icons.map_rounded, size: 18),
                    label: const Text(
                      'Open Google Maps App',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.accentColor,
                      side: BorderSide(
                        color: context.accentColor
                            .withValues(alpha: isDark ? 0.45 : 0.35),
                      ),
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
          const SizedBox(height: 10),

          // STEP 2 Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'STEP 2',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: context.accentColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Paste Google Maps Link',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.textMain,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _pasteFromClipboard,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.content_paste_rounded,
                              size: 14,
                              color: context.accentColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Paste',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: context.accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _linkInputController,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.textMain,
                  ),
                  decoration: InputDecoration(
                    hintText: isStudio
                        ? 'Paste Google Maps link (maps.app.goo.gl/...)'
                        : 'Paste Google Maps link of venue (maps.app.goo.gl/...)',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: context.textMuted,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF131B2B)
                        : const Color(0xFFF8FAFC),
                    prefixIcon: Icon(
                      Icons.link_rounded,
                      size: 18,
                      color: context.accentColor,
                    ),
                    suffixIcon: _searching
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
                            color: context.accentColor,
                            onPressed: () {
                              final text = _linkInputController.text.trim();
                              if (text.isNotEmpty) {
                                _resolvePastedLink(text);
                              }
                            },
                          ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.sky, width: 1.5),
                    ),
                  ),
                  onChanged: (text) {
                    final query = text.trim();
                    if (GoogleMapsLocationParser.isGoogleMapsUrlOrCoords(query)) {
                      _debounce?.cancel();
                      _debounce =
                          Timer(const Duration(milliseconds: 300), () {
                        if (mounted) _resolvePastedLink(query);
                      });
                    }
                  },
                  onFieldSubmitted: (v) {
                    final text = v.trim();
                    if (text.isEmpty) return;
                    if (!GoogleMapsLocationParser.isGoogleMapsUrlOrCoords(text)) {
                      AppSnackBar.error(
                        context,
                        'Please paste a valid Google Maps link or coordinates.',
                      );
                    } else {
                      _resolvePastedLink(text);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSearchServiceMode(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.textMain,
              ),
            ),
            if (_hasCoordinates)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 13,
                    color: AppColors.pastelMint,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Location locked',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.pastelMint,
                    ),
                  ),
                ],
              )
            else
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _openGoogleMapsPicker,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.map_rounded,
                        size: 13,
                        color: context.accentColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Google Maps Pin',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: context.accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          validator: widget.validator,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: context.textMain,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: context.textMuted,
            ),
            filled: true,
            fillColor: context.cardBg,
            prefixIcon: Icon(
              Icons.location_on_outlined,
              size: 19,
              color: _hasCoordinates ? AppColors.pastelMint : context.textMuted,
            ),
            suffixIcon: _searching
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
                : widget.controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 17),
                        color: context.textMuted,
                        onPressed: () {
                          widget.controller.clear();
                          setState(() {
                            _hasCoordinates = false;
                            _suggestions = [];
                          });
                        },
                      )
                    : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _hasCoordinates
                    ? AppColors.pastelMint.withValues(alpha: 0.5)
                    : context.cardBorder,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.sky, width: 1.5),
            ),
          ),
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _suggestions.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: context.cardBorder.withValues(alpha: 0.5),
                ),
                itemBuilder: (ctx, idx) {
                  final place = _suggestions[idx];
                  double? distanceKm;
                  if (widget.referenceLatitude != null &&
                      widget.referenceLongitude != null &&
                      !widget.referenceLatitude!.isNaN &&
                      !widget.referenceLongitude!.isNaN) {
                    distanceKm = GeoDistanceUtils.calculateHaversineKm(
                      widget.referenceLatitude!,
                      widget.referenceLongitude!,
                      place.latitude,
                      place.longitude,
                    );
                  }

                  return Material(
                    color: Colors.transparent,
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.sky.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.place_rounded,
                          size: 16,
                          color: AppColors.sky,
                        ),
                      ),
                      title: Text(
                        place.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textMain,
                        ),
                      ),
                      subtitle: Text(
                        place.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: context.textMuted,
                        ),
                      ),
                      trailing: distanceKm != null
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: (distanceKm < 25
                                        ? AppColors.pastelMint
                                        : AppColors.sky)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: (distanceKm < 25
                                          ? AppColors.pastelMint
                                          : AppColors.sky)
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.near_me_rounded,
                                    size: 11,
                                    color: distanceKm < 25
                                        ? AppColors.pastelMint
                                        : AppColors.sky,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${distanceKm.toStringAsFixed(1)} km',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: distanceKm < 25
                                          ? AppColors.pastelMint
                                          : AppColors.sky,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : null,
                      onTap: () => _selectPlace(place),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
