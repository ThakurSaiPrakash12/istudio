import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/location_search_service.dart';
import '../theme/app_colors.dart';
import '../utils/geo_distance_utils.dart';

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

  Timer? _debounce;
  bool _searching = false;
  List<PlaceLocation> _suggestions = [];
  bool _hasCoordinates = false;
  String? _selectedText;

  @override
  void initState() {
    super.initState();
    _service = widget.locationSearchService ?? LocationSearchService();
    _hasCoordinates =
        widget.initialLatitude != null &&
        widget.initialLongitude != null &&
        !widget.initialLatitude!.isNaN &&
        !widget.initialLongitude!.isNaN;
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
    _focusNode.dispose();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      // User tapped outside; auto-geocode if text exists but coordinates are not yet set
      final text = widget.controller.text.trim();
      if (text.isNotEmpty && !_hasCoordinates) {
        _autoGeocode(text);
      }
      setState(() => _suggestions = []);
    }
  }

  void _onTextChanged() {
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

  void _selectPlace(PlaceLocation place) {
    widget.controller.removeListener(_onTextChanged);
    widget.controller.text = place.displayName;
    widget.controller.addListener(_onTextChanged);

    setState(() {
      _suggestions = [];
      _hasCoordinates = true;
    });
    _selectedText = place.displayName;

    _focusNode.unfocus();
    widget.onLocationSelected(place);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              ),
          ],
        ),
        const SizedBox(height: 7),
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

        // Live suggestions overlay
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
