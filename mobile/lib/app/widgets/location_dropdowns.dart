import '../providers/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../utils/india_locations.dart';
import 'studio_text_field.dart';

/// Country, State and District/City selector.
/// - Allows selecting Country (defaults to 'India').
/// - If Country is 'India' (or 'Indai'), shows Indian State & District dropdowns
///   with district filtered by state and auto-reset when state changes.
/// - If Country is any foreign country, shows international text input fields
///   for State/Province/Region and City/District/Area.
class LocationDropdowns extends StatefulWidget {
  const LocationDropdowns({
    super.key,
    required this.stateController,
    required this.districtController,
    this.cityController,
    this.countryController,
    this.stateValidator,
    this.districtValidator,
    this.countryValidator,
  });

  final TextEditingController stateController;
  final TextEditingController districtController;
  final TextEditingController? cityController;
  final TextEditingController? countryController;
  final String? Function(String?)? stateValidator;
  final String? Function(String?)? districtValidator;
  final String? Function(String?)? countryValidator;

  @override
  State<LocationDropdowns> createState() => _LocationDropdownsState();
}

class _LocationDropdownsState extends State<LocationDropdowns> {
  late final TextEditingController _countryController;
  bool _ownsCountryController = false;

  String? _selectedState;
  String? _selectedDistrict;
  bool _customCountryMode = false;
  final TextEditingController _customCountryController = TextEditingController();

  static const List<Map<String, String>> popularCountries = [
    {'name': 'India', 'flag': '🇮🇳'},
    {'name': 'United States', 'flag': '🇺🇸'},
    {'name': 'United Kingdom', 'flag': '🇬🇧'},
    {'name': 'Canada', 'flag': '🇨🇦'},
    {'name': 'Australia', 'flag': '🇦🇺'},
    {'name': 'United Arab Emirates', 'flag': '🇦🇪'},
    {'name': 'Singapore', 'flag': '🇸🇬'},
    {'name': 'Germany', 'flag': '🇩🇪'},
    {'name': 'France', 'flag': '🇫🇷'},
    {'name': 'Saudi Arabia', 'flag': '🇸🇦'},
    {'name': 'Malaysia', 'flag': '🇲🇾'},
    {'name': 'New Zealand', 'flag': '🇳🇿'},
    {'name': 'South Africa', 'flag': '🇿🇦'},
    {'name': 'Other Country', 'flag': '🌐'},
  ];

  bool get _isIndia {
    final c = _countryController.text.trim().toLowerCase();
    return c == 'india' || c == 'indai' || c.isEmpty;
  }

  @override
  void initState() {
    super.initState();
    if (widget.countryController != null) {
      _countryController = widget.countryController!;
    } else {
      _countryController = TextEditingController();
      _ownsCountryController = true;
    }

    if (_countryController.text.trim().isEmpty) {
      // Default to India
      _countryController.text = 'India';
    }

    final initialCountry = _countryController.text.trim();
    final isKnown = popularCountries.any((p) => p['name']!.toLowerCase() == initialCountry.toLowerCase());
    if (!isKnown && initialCountry.isNotEmpty) {
      _customCountryMode = true;
      _customCountryController.text = initialCountry;
    }

    _syncFromControllers();
    widget.stateController.addListener(_onStateControllerUpdated);
    widget.districtController.addListener(_onDistrictControllerUpdated);
    _countryController.addListener(_onCountryControllerUpdated);
  }

  @override
  void dispose() {
    widget.stateController.removeListener(_onStateControllerUpdated);
    widget.districtController.removeListener(_onDistrictControllerUpdated);
    _countryController.removeListener(_onCountryControllerUpdated);
    _customCountryController.dispose();
    if (_ownsCountryController) {
      _countryController.dispose();
    }
    super.dispose();
  }

  void _syncFromControllers() {
    final s = widget.stateController.text.trim();
    final d = widget.districtController.text.trim();

    _selectedState = s.isNotEmpty ? s : null;
    _selectedDistrict = d.isNotEmpty ? d : null;

    if (_isIndia && _selectedDistrict != null && widget.cityController != null) {
      if (widget.cityController!.text.trim().isEmpty) {
        widget.cityController!.text = _selectedDistrict!;
      }
    }
  }

  void _onCountryControllerUpdated() {
    final c = _countryController.text.trim();
    final isKnown = popularCountries.any(
      (p) => p['name']!.toLowerCase() == c.toLowerCase(),
    );
    if (!isKnown && c.isNotEmpty && c.toLowerCase() != 'india') {
      _customCountryMode = true;
      if (_customCountryController.text != c) {
        _customCountryController.text = c;
      }
    } else {
      _customCountryMode = false;
    }
    _syncFromControllers();
    setState(() {});
  }

  void _onStateControllerUpdated() {
    final s = widget.stateController.text.trim();
    if (s != _selectedState) {
      setState(() {
        _selectedState = s.isNotEmpty ? s : null;
        if (_isIndia) {
          final validDistricts = _getDistrictsForState(_selectedState);
          if (_selectedDistrict != null && !validDistricts.contains(_selectedDistrict)) {
            _selectedDistrict = null;
            widget.districtController.text = '';
            if (widget.cityController != null) {
              widget.cityController!.text = '';
            }
          }
        }
      });
    }
  }

  void _onDistrictControllerUpdated() {
    final d = widget.districtController.text.trim();
    if (d != _selectedDistrict) {
      setState(() {
        _selectedDistrict = d.isNotEmpty ? d : null;
        if (widget.cityController != null && d.isNotEmpty && widget.cityController!.text.trim().isEmpty) {
          widget.cityController!.text = d;
        }
      });
    }
  }

  List<String> _getStates() {
    final list = List<String>.from(IndiaLocations.states);
    if (_selectedState != null && !list.contains(_selectedState)) {
      list.insert(0, _selectedState!);
    }
    return list;
  }

  List<String> _getDistrictsForState(String? state) {
    if (state == null || state.isEmpty) return [];
    final districts = List<String>.from(IndiaLocations.districtsByState[state] ?? []);
    if (_selectedDistrict != null && !districts.contains(_selectedDistrict)) {
      districts.insert(0, _selectedDistrict!);
    }
    return districts;
  }

  void _onCountrySelected(String countryName) {
    setState(() {
      if (countryName == 'Other Country') {
        _customCountryMode = true;
        _countryController.text = _customCountryController.text.trim();
      } else {
        _customCountryMode = false;
        final wasIndia = _isIndia;
        _countryController.text = countryName;
        final nowIndia = _isIndia;

        // Reset if switching between India and Foreign
        if (wasIndia != nowIndia) {
          _selectedState = null;
          _selectedDistrict = null;
          widget.stateController.text = '';
          widget.districtController.text = '';
          if (widget.cityController != null) {
            widget.cityController!.text = '';
          }
        }
      }
    });
  }

  void _onCustomCountryChanged(String value) {
    _countryController.text = value.trim();
    setState(() {});
  }

  void _onStateChanged(String? newState) {
    if (_selectedState == newState) return;
    setState(() {
      _selectedState = newState;
      // Reset district whenever state changes
      _selectedDistrict = null;
      widget.stateController.text = newState ?? '';
      widget.districtController.text = '';
      if (widget.cityController != null) {
        widget.cityController!.text = '';
      }
    });
  }

  void _onDistrictChanged(String? newDistrict) {
    setState(() {
      _selectedDistrict = newDistrict;
      widget.districtController.text = newDistrict ?? '';
      if (widget.cityController != null) {
        widget.cityController!.text = newDistrict ?? '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final accent = context.accentColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Country Selector ───────────────────────────────────────────────
        _buildCountrySelector(context, isDark, accent),
        const SizedBox(height: 14),

        // If custom country mode, show custom country textfield
        if (_customCountryMode) ...[
          StudioTextField(
            label: context.tr('Enter Country Name *'),
            hint: 'e.g. Japan, Brazil, Italy...',
            controller: _customCountryController,
            prefixIcon: Icons.public_rounded,
            onChanged: _onCustomCountryChanged,
            validator: widget.countryValidator ??
                (v) => (v == null || v.trim().isEmpty) ? context.tr('Enter Country Name *') : null,
          ),
          const SizedBox(height: 14),
        ],

        // ── Conditional State & District ──────────────────────────────────
        if (_isIndia) ...[
          // India: Two Dropdowns with strict district mapping
          _buildDropdown(
            context: context,
            isDark: isDark,
            accent: accent,
            label: context.tr('State / Region *'),
            hint: context.tr('Select State'),
            value: _selectedState,
            items: _getStates(),
            prefixIcon: Icons.map_outlined,
            onChanged: _onStateChanged,
            validator: widget.stateValidator ??
                (v) => (v == null || v.trim().isEmpty) ? context.tr('Select your state') : null,
          ),
          const SizedBox(height: 14),
          _buildDropdown(
            context: context,
            isDark: isDark,
            accent: accent,
            label: context.tr('District / Area *'),
            hint: _selectedState == null ? context.tr('Select state first') : context.tr('Select District'),
            value: _selectedDistrict,
            items: _getDistrictsForState(_selectedState),
            prefixIcon: Icons.location_city_outlined,
            enabled: _selectedState != null && _getDistrictsForState(_selectedState).isNotEmpty,
            onChanged: _selectedState != null && _getDistrictsForState(_selectedState).isNotEmpty
                ? _onDistrictChanged
                : null,
            validator: widget.districtValidator ??
                (v) => (v == null || v.trim().isEmpty) ? context.tr('Select your district') : null,
          ),
        ] else ...[
          // Foreign Country: Text fields for State/Province & City/Area
          StudioTextField(
            label: context.tr('State / Province / Region *'),
            hint: context.tr('e.g. California, Ontario, London, Bavaria'),
            controller: widget.stateController,
            prefixIcon: Icons.map_outlined,
            validator: widget.stateValidator ??
                (v) => (v == null || v.trim().isEmpty) ? context.tr('Enter your state or province') : null,
          ),
          const SizedBox(height: 14),
          StudioTextField(
            label: context.tr('City / District / Area *'),
            hint: context.tr('e.g. Los Angeles, Toronto, Westminster, Munich'),
            controller: widget.districtController,
            prefixIcon: Icons.location_city_outlined,
            onChanged: (val) {
              if (widget.cityController != null) {
                widget.cityController!.text = val;
              }
            },
            validator: widget.districtValidator ??
                (v) => (v == null || v.trim().isEmpty) ? context.tr('Enter your city or area') : null,
          ),
        ],
      ],
    );
  }

  Widget _buildCountrySelector(BuildContext context, bool isDark, Color accent) {
    final currentCountry = _countryController.text.trim();
    final borderColor = isDark ? const Color(0xFF2A3245) : const Color(0xFFE2E8F0);
    final fillColor = isDark ? const Color(0xFF141926) : const Color(0xFFFAFBFD);

    final selectedCountryEntry = popularCountries.firstWhere(
      (c) => c['name']!.toLowerCase() == currentCountry.toLowerCase(),
      orElse: () => _customCountryMode
          ? popularCountries.last
          : {'name': currentCountry.isNotEmpty ? currentCountry : 'India', 'flag': '🌐'},
    );

    return Container(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: 1.4,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: ButtonTheme(
          alignedDropdown: true,
          child: DropdownButton<String>(
            value: selectedCountryEntry['name'],
            isExpanded: true,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: accent,
              size: 20,
            ),
            dropdownColor: isDark ? const Color(0xFF1A2035) : Colors.white,
            style: GoogleFonts.plusJakartaSans(
              color: context.textMain,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            selectedItemBuilder: (ctx) => popularCountries.map((c) {
              return Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Row(
                  children: [
                    Text(c['flag']!, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            context.tr('Country *'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: context.textMuted,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            _customCountryMode && _customCountryController.text.isNotEmpty
                                ? _customCountryController.text
                                : c['name']!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              color: context.textMain,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            items: popularCountries.map((c) {
              final isSelected = c['name'] == selectedCountryEntry['name'];
              return DropdownMenuItem<String>(
                value: c['name'],
                child: Row(
                  children: [
                    Text(c['flag']!, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        c['name']!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? accent : context.textMain,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_rounded, size: 16, color: accent),
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                _onCountrySelected(val);
              }
            },
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required BuildContext context,
    required bool isDark,
    required Color accent,
    required String label,
    required String hint,
    required String? value,
    required List<String> items,
    required IconData prefixIcon,
    required void Function(String?)? onChanged,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    final borderColor = isDark ? const Color(0xFF2A3245) : const Color(0xFFE2E8F0);
    final fillColor = isDark
        ? (enabled ? const Color(0xFF141926) : const Color(0xFF0E1320))
        : (enabled ? const Color(0xFFFAFBFD) : const Color(0xFFF3F4F6));

    final effectiveValue = items.contains(value) ? value : null;

    return FormField<String>(
      initialValue: effectiveValue,
      validator: validator,
      builder: (fieldState) {
        final hasError = fieldState.hasError;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasError
                      ? Colors.red.shade400
                      : (enabled ? borderColor : borderColor.withValues(alpha: 0.5)),
                  width: 1.4,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: ButtonTheme(
                  alignedDropdown: true,
                  child: DropdownButton<String>(
                    value: effectiveValue,
                    isExpanded: true,
                    isDense: false,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: enabled ? accent : context.textMuted.withValues(alpha: 0.4),
                      size: 20,
                    ),
                    dropdownColor: isDark ? const Color(0xFF1A2035) : Colors.white,
                    style: GoogleFonts.plusJakartaSans(
                      color: context.textMain,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    hint: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Row(
                        children: [
                          Icon(
                            prefixIcon,
                            size: 18,
                            color: enabled ? accent : context.textMuted.withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  label,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: context.textMuted,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                Text(
                                  hint,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5,
                                    color: context.textMuted.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    selectedItemBuilder: (ctx) => items
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Row(
                              children: [
                                Icon(prefixIcon, size: 18, color: accent),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        label,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: context.textMuted,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      Text(
                                        item,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13.5,
                                          color: context.textMain,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    items: items
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item,
                            child: Text(
                              item,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                color: context.textMain,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: enabled && onChanged != null
                        ? (val) {
                            onChanged(val);
                            fieldState.didChange(val);
                          }
                        : null,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  ),
                ),
              ),
            ),
            if (hasError)
              Padding(
                padding: const EdgeInsets.only(left: 14, top: 4),
                child: Text(
                  fieldState.errorText ?? '',
                  style: TextStyle(
                    color: Colors.red.shade400,
                    fontSize: 11.5,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
