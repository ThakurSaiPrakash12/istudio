import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/photographer_profile.dart';
import '../../models/studio_event.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/photographer_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/fuzzy_search_utils.dart';
import '../../utils/geo_distance_utils.dart';
import '../../utils/india_locations.dart';
import '../../utils/launcher_utils.dart';
import '../../utils/photographer_categories.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/studio_app_bar.dart';

class NearbyPhotographersScreen extends StatefulWidget {
  const NearbyPhotographersScreen({
    super.key,
    this.event,
    this.initialLocation,
    this.service,
  });

  final StudioEvent? event;
  final String? initialLocation;
  final PhotographerService? service;

  @override
  State<NearbyPhotographersScreen> createState() =>
      _NearbyPhotographersScreenState();
}

class _NearbyPhotographersScreenState extends State<NearbyPhotographersScreen> {
  late final PhotographerService _service;
  late final TextEditingController _searchController;
  late final TextEditingController _locationSearchController;
  final Set<String> _selectedCategories = {};
  bool _loading = false;
  bool _isBackgroundSyncing = false;
  List<PhotographerProfile> _photographers = [];
  List<PhotographerProfile> _allPhotographers = [];
  String? _errorMessage;
  String? _selectedState;
  String? _selectedDistrict;
  bool _isBrowsingIndiaLocations = false;
  Timer? _debounceTimer;
  /// Monotonically increasing counter used to discard stale async responses.
  int _fetchSeq = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? PhotographerService();
    final defaultLoc = widget.initialLocation ?? '';
    _searchController = TextEditingController(text: defaultLoc);
    _locationSearchController = TextEditingController();

    // Use preloaded cache if already available in memory for instantaneous rendering
    if (PhotographerService.preloadedPhotographers.isNotEmpty) {
      _allPhotographers = List.from(PhotographerService.preloadedPhotographers);
      _photographers = List.from(_allPhotographers);
      _loading = false;
      if (defaultLoc.isNotEmpty) {
        _applyLocalFilter();
      }
    }

    _fetchPhotographers(isBackgroundSync: _allPhotographers.isNotEmpty);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _locationSearchController.dispose();
    super.dispose();
  }

  /// Instantly filters the preloaded photographers in memory as the user types (0ms latency).
  void _applyLocalFilter() {
    final queryText = _searchController.text.trim();
    if (_allPhotographers.isEmpty) return;

    List<PhotographerProfile> filtered = List.from(_allPhotographers);

    // Apply category filters
    if (_selectedCategories.isNotEmpty) {
      filtered = filtered.where((p) {
        return _selectedCategories.any((cat) =>
            p.categories.any((c) => c.toLowerCase().contains(cat.toLowerCase())) ||
            p.specialties.toLowerCase().contains(cat.toLowerCase()));
      }).toList();
    }

    // Apply state & district filters
    if (_selectedState != null && _selectedState!.isNotEmpty) {
      final s = _selectedState!.toLowerCase();
      filtered = filtered.where((p) => p.state.toLowerCase() == s).toList();
    }
    if (_selectedDistrict != null && _selectedDistrict!.isNotEmpty) {
      final d = _selectedDistrict!.toLowerCase();
      filtered = filtered.where((p) => p.district.toLowerCase() == d || p.city.toLowerCase() == d).toList();
    }

    // If query text is present, rank and filter by fuzzy/prefix relevance
    if (queryText.isNotEmpty) {
      final scored = <MapEntry<PhotographerProfile, double>>[];
      for (final p in filtered) {
        final score = FuzzySearchUtils.scorePhotographer(p, queryText);
        if (score > 0) {
          scored.add(MapEntry(p, score));
        }
      }
      scored.sort((a, b) {
        final cmp = b.value.compareTo(a.value);
        if (cmp != 0) return cmp;
        return a.key.displayName.toLowerCase().compareTo(b.key.displayName.toLowerCase());
      });
      filtered = scored.map((e) => e.key).toList();
    }

    setState(() {
      _photographers = filtered;
    });
  }

  void _onSearchChanged(String text) {
    // 1. Instant keystroke update from preloaded cache
    _applyLocalFilter();

    // 2. Debounced background sync with backend
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        _fetchPhotographers(isBackgroundSync: true);
      }
    });
  }

  String get _referenceLocation {
    final queryLoc = _searchController.text.trim();
    if (queryLoc.isNotEmpty) return queryLoc;
    if (widget.event?.location.isNotEmpty == true) {
      return widget.event!.location;
    }
    return '';
  }

  Future<void> _fetchPhotographers({bool isBackgroundSync = false}) async {
    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) return;

    // Capture the current sequence number before any await.
    // If a newer call starts before this one resolves, we discard stale results.
    final seq = ++_fetchSeq;

    if (!isBackgroundSync && _allPhotographers.isEmpty) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _isBackgroundSyncing = true;
        _errorMessage = null;
      });
    }

    try {
      final queryLoc = _searchController.text.trim();

      final results = await _service.searchNearby(
        token: token,
        location: queryLoc.isNotEmpty ? queryLoc : null,
        query: queryLoc.isNotEmpty ? queryLoc : null,
        state: widget.event == null ? _selectedState : null,
        district: widget.event == null ? _selectedDistrict : null,
        categories: _selectedCategories.toList(),
        latitude: widget.event?.latitude,
        longitude: widget.event?.longitude,
        includeSelf: false,
      );

      // Discard this response if a newer query has already been dispatched.
      if (seq != _fetchSeq || !mounted) return;

      final currentUser = context.read<AuthProvider>().user;
      final sortedResults = results.where((p) {
        if (currentUser == null) return true;
        final myId = currentUser.id;
        final myUser = currentUser.username.trim().toLowerCase();
        if (myId.isNotEmpty && p.id == myId) return false;
        if (myUser.isNotEmpty && p.username.trim().toLowerCase() == myUser) return false;
        return true;
      }).toList();
      if (widget.event != null) {
        final refLoc = _referenceLocation;
        sortedResults.sort((a, b) {
          final distA = GeoDistanceUtils.computeEventDistance(
            eventLocation: refLoc,
            eventLat: widget.event?.latitude,
            eventLng: widget.event?.longitude,
            photographerCity: a.city,
            photographerAddress: a.address,
            photographerLat: a.latitude,
            photographerLng: a.longitude,
            precomputedDistanceKm: a.distanceKm,
          );
          final distB = GeoDistanceUtils.computeEventDistance(
            eventLocation: refLoc,
            eventLat: widget.event?.latitude,
            eventLng: widget.event?.longitude,
            photographerCity: b.city,
            photographerAddress: b.address,
            photographerLat: b.latitude,
            photographerLng: b.longitude,
            precomputedDistanceKm: b.distanceKm,
          );

          if (distA.distanceKm != null && distB.distanceKm != null) {
            return distA.distanceKm!.compareTo(distB.distanceKm!);
          }
          if (distA.distanceKm != null) return -1;
          if (distB.distanceKm != null) return 1;
          return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
        });
      } else if (queryLoc.isNotEmpty) {
        sortedResults.sort((a, b) {
          final scoreA = FuzzySearchUtils.scorePhotographer(a, queryLoc);
          final scoreB = FuzzySearchUtils.scorePhotographer(b, queryLoc);
          if (scoreA != scoreB) {
            return scoreB.compareTo(scoreA); // Highest fuzzy relevance first
          }
          return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
        });
      }

      // Maintain master in-memory cache for instant preloading
      if (queryLoc.isEmpty && _selectedCategories.isEmpty && _selectedDistrict == null) {
        _allPhotographers = List.from(sortedResults);
        PhotographerService.preloadedPhotographers = List.from(sortedResults);
      } else {
        final existingIds = _allPhotographers.map((p) => p.id).toSet();
        for (final p in sortedResults) {
          if (!existingIds.contains(p.id)) {
            _allPhotographers.add(p);
          }
        }
        PhotographerService.preloadedPhotographers = List.from(_allPhotographers);
      }

      setState(() {
        _photographers = sortedResults;
        _loading = false;
        _isBackgroundSyncing = false;
      });
    } catch (e) {
      if (seq != _fetchSeq || !mounted) return;
      setState(() {
        _loading = false;
        _isBackgroundSyncing = false;
        if (_photographers.isEmpty) {
          _errorMessage = 'Unable to load photographers near this location.';
        }
      });
    }
  }

  String _formatEventShareText(StudioEvent event, PhotographerProfile photographer) {
    final auth = context.read<AuthProvider>();
    final myUser = auth.user;
    final dateStr = DateFormat('EEE, dd MMM yyyy').format(event.startsAt);

    final sb = StringBuffer();
    sb.writeln('📸 *Collaboration Opportunity & Event Details*');
    sb.writeln('━━━━━━━━━━━━━━━━━━━━');
    if (myUser?.displayStudioName.isNotEmpty == true) {
      sb.writeln('*From Studio:* ${myUser!.displayStudioName}');
    }
    sb.writeln('*Event:* ${event.title} (${event.eventType})');
    sb.writeln('*Date:* $dateStr');
    sb.writeln('*Time:* ${event.startTime} - ${event.endTime}');
    sb.writeln('*Venue / Location:* ${event.location}');

    if (event.deliverables.isNotEmpty) {
      sb.writeln('*Deliverables Required:*');
      for (final d in event.deliverables) {
        sb.writeln('  • ${d.title}');
      }
    }

    if (event.notes.trim().isNotEmpty) {
      sb.writeln('*Special Notes:* ${event.notes.trim()}');
    }

    sb.writeln('━━━━━━━━━━━━━━━━━━━━');
    if (myUser != null) {
      sb.writeln('*Contact Person:* ${myUser.displayOwner} (${myUser.phone})');
    }
    sb.writeln('Looking forward to collaborating with you!');

    return sb.toString();
  }

  void _shareEventDetails(PhotographerProfile photographer) {
    final event = widget.event;
    if (event == null) {
      AppSnackBar.info(context, 'No event selected to share.');
      return;
    }

    final message = _formatEventShareText(event, photographer);
    final isDark = context.isDark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: ctx.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: ctx.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: ctx.textMuted.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.sky.withValues(alpha: 0.25),
                          const Color(0xFF6366F1).withValues(alpha: 0.2),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.sky.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.share_rounded,
                      color: AppColors.sky,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share Event with ${photographer.displayName}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: ctx.textMain,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Invite to collaborate on "${event.title}"',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: ctx.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Preview container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ctx.innerBg.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: ctx.cardBorder.withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.event_note_rounded, size: 16, color: AppColors.sky),
                        const SizedBox(width: 6),
                        Text(
                          ctx.tr('Event Summary'),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.sky,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${event.title} • ${DateFormat('dd MMM yyyy').format(event.startsAt)}\n'
                      '📍 ${event.location.isNotEmpty ? event.location : 'Location TBD'} (${event.startTime} - ${event.endTime})',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: ctx.textMain,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // WhatsApp Primary Action
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.chat_rounded, size: 20),
                  label: Text(
                    ctx.tr('Send via WhatsApp'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    LauncherUtils.openWhatsApp(
                      context,
                      photographer.phone,
                      prefilledMessage: message,
                    );
                  },
                ),
              ),

              const SizedBox(height: 10),

              // Other Share Options
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(color: ctx.cardBorder),
                  ),
                  icon: Icon(Icons.share_outlined, color: ctx.textMain, size: 18),
                  label: Text(
                    ctx.tr('More Sharing Options'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ctx.textMain,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    // ignore: deprecated_member_use
                    Share.share(
                      message,
                      subject: 'Collaboration: ${event.title}',
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPhotographerDetailsSheet(
    PhotographerProfile photographer,
    DistanceResult distanceInfo,
  ) {
    final isDark = context.isDark;
    final hasEvent = widget.event != null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: ctx.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: ctx.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: ctx.textMuted.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  _buildAvatar(photographer, size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          photographer.displayName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: ctx.textMain,
                          ),
                        ),
                        if (photographer.displayOwner != photographer.displayName)
                          Text(
                            photographer.displayOwner,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: ctx.textMuted,
                            ),
                          ),
                        const SizedBox(height: 4),
                        _buildDistanceBadge(distanceInfo, isCompact: false),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Location Detail
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_rounded, size: 18, color: AppColors.sky),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      photographer.displayLocation,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: ctx.textMain,
                      ),
                    ),
                  ),
                ],
              ),

              if (photographer.about.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  ctx.tr('About'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ctx.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  photographer.about.trim(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: ctx.textMain,
                    height: 1.4,
                  ),
                ),
              ],

              if (photographer.categories.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  ctx.tr('Categories & Services'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ctx.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: photographer.categories.map((c) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.sky.withValues(alpha: isDark ? 0.2 : 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.sky.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        c,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.sky,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  if (photographer.phone.isNotEmpty) ...[
                    _buildQuickContactButton(
                      icon: Icons.call_rounded,
                      tooltip: 'Call',
                      color: AppColors.sky,
                      onTap: () => LauncherUtils.makePhoneCall(context, photographer.phone),
                    ),
                    const SizedBox(width: 10),
                    _buildQuickContactButton(
                      icon: Icons.chat_rounded,
                      tooltip: 'WhatsApp',
                      color: const Color(0xFF25D366),
                      onTap: () {
                        final greeting = hasEvent
                            ? 'Hi ${photographer.displayName}, inquiring about an upcoming event: "${widget.event!.title}".'
                            : 'Hi ${photographer.displayName}, inquiring about photography collaboration.';
                        LauncherUtils.openWhatsApp(
                          context,
                          photographer.phone,
                          prefilledMessage: greeting,
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: _buildShareEventActionButton(
                      hasEvent: hasEvent,
                      photographer: photographer,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;

    // View modes:
    // If event != null: Event Collaborators mode (proximity search around event)
    // If event == null:
    //    • Default: Global discovery listing with worldwide search & location filter toolbar
    //    • _isBrowsingIndiaLocations: State / District drill-down picker
    final bool isStateSelector = event == null && _isBrowsingIndiaLocations && _selectedState == null;
    final bool isDistrictSelector = event == null && _isBrowsingIndiaLocations && _selectedState != null && _selectedDistrict == null;

    final String appBarSubtitle;
    if (event != null) {
      appBarSubtitle = 'Collaborators for "${event.title}"';
    } else if (isDistrictSelector) {
      appBarSubtitle = 'Select district in $_selectedState';
    } else if (isStateSelector) {
      appBarSubtitle = 'Select Indian State / UT';
    } else if (_selectedDistrict != null) {
      appBarSubtitle = '$_selectedDistrict, $_selectedState';
    } else {
      appBarSubtitle = 'Explore photographers worldwide';
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            StudioAppBar(
              title: event == null ? context.tr('Discover Photographers') : context.tr('Nearby Photographers'),
              subtitle: appBarSubtitle,
              leading: (event != null || Navigator.of(context).canPop() || _isBrowsingIndiaLocations)
                  ? IconButton(
                      tooltip: 'Back',
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: context.textMain,
                        size: 20,
                      ),
                      onPressed: () {
                        if (isDistrictSelector) {
                          setState(() {
                            _selectedState = null;
                            _locationSearchController.clear();
                          });
                        } else if (isStateSelector) {
                          setState(() {
                            _isBrowsingIndiaLocations = false;
                            _locationSearchController.clear();
                          });
                        } else if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                    )
                  : null,
              actions: [
                if (event == null && _isBrowsingIndiaLocations)
                  IconButton(
                    tooltip: 'Close Location Filter',
                    icon: Icon(Icons.close_rounded, color: context.textMuted),
                    onPressed: () {
                      setState(() {
                        _isBrowsingIndiaLocations = false;
                        _locationSearchController.clear();
                      });
                    },
                  ),
              ],
            ),

            if (event != null) _buildEventContextBanner(event),

            Expanded(
              child: isStateSelector
                  ? _buildStateSelectorView()
                  : isDistrictSelector
                      ? _buildDistrictSelectorView()
                      : _buildPhotographersListingView(),
            ),
          ],
        ),
      ),
    );
  }

  /// 1. State Selector View (Searchable Indian States & Union Territories)
  Widget _buildStateSelectorView() {
    final query = _locationSearchController.text.trim().toLowerCase();
    final allStates = IndiaLocations.states;
    final filteredStates = query.isEmpty
        ? allStates
        : allStates.where((s) => FuzzySearchUtils.matchesLocation(s, query)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Explore Photographers in India'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.textMain,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('Select a state or union territory to discover verified local studios and operators.'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: context.textMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        // Search Bar for States
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _locationSearchController,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: context.textMain,
              ),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.sky, size: 20),
                hintText: context.tr('Search 36 states & union territories...'),
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: context.textMuted,
                ),
                suffixIcon: _locationSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, size: 18, color: context.textMuted),
                        onPressed: () {
                          _locationSearchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),

        // States List
        Expanded(
          child: filteredStates.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: context.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'No states found matching "${_locationSearchController.text}"',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.textMuted),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                  itemCount: filteredStates.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (ctx, index) {
                    final stateName = filteredStates[index];
                    final districtCount = IndiaLocations.districtsByState[stateName]?.length ?? 0;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedState = stateName;
                            _selectedDistrict = null;
                            _locationSearchController.clear();
                            _photographers = [];
                            _selectedCategories.clear();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          decoration: BoxDecoration(
                            color: context.cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.cardBorder),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.sky.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.location_on_rounded, size: 16, color: AppColors.sky),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  stateName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: context.textMain,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: context.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$districtCount ${context.tr('districts')}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: context.textMuted,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right_rounded, size: 18, color: context.textMuted),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// 2. District Selector View (Searchable Districts for Selected State)
  Widget _buildDistrictSelectorView() {
    final state = _selectedState!;
    final query = _locationSearchController.text.trim().toLowerCase();
    final allDistricts = IndiaLocations.districtsByState[state] ?? const <String>[];
    final filteredDistricts = query.isEmpty
        ? allDistricts
        : allDistricts.where((d) => FuzzySearchUtils.matchesLocation(d, query)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top breadcrumb / State banner
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.sky.withValues(alpha: context.isDark ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.sky.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.map_rounded, size: 18, color: AppColors.sky),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      text: '${context.tr('State')}: ',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: context.textMuted),
                      children: [
                        TextSpan(
                          text: state,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.textMain,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: AppColors.sky,
                  ),
                  icon: const Icon(Icons.edit_location_alt_rounded, size: 14),
                  label: Text(context.tr('Change State'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedState = null;
                      _selectedDistrict = null;
                      _locationSearchController.clear();
                    });
                  },
                ),
              ],
            ),
          ),
        ),

        // Subheading
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 6),
          child: Text(
            '${context.tr('Select District in')} $state',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.textMain,
            ),
          ),
        ),

        // Search Bar for Districts
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Container(
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _locationSearchController,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: context.textMain,
              ),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.sky, size: 20),
                hintText: 'Search districts in $state...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: context.textMuted,
                ),
                suffixIcon: _locationSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, size: 18, color: context.textMuted),
                        onPressed: () {
                          _locationSearchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),

        // Districts List
        Expanded(
          child: filteredDistricts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: context.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'No districts found matching "${_locationSearchController.text}"',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.textMuted),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                  itemCount: filteredDistricts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (ctx, index) {
                    final districtName = filteredDistricts[index];

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedDistrict = districtName;
                            _isBrowsingIndiaLocations = false;
                            _selectedCategories.clear();
                            _searchController.clear();
                            _locationSearchController.clear();
                          });
                          _fetchPhotographers();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          decoration: BoxDecoration(
                            color: context.cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.cardBorder),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.location_city_rounded, size: 16, color: Color(0xFF818CF8)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  districtName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: context.textMain,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.sky),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// 3. Photographer Listing & Filter View (Shows Photographers for Selected District / Event / Worldwide)
  Widget _buildPhotographersListingView() {
    final isDark = context.isDark;
    final event = widget.event;

    return Column(
      children: [
        // Location filter toolbar for Discover mode (Worldwide vs District Filter)
        if (event == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: Row(
              children: [
                if (_selectedDistrict != null) ...[
                  // Active district pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.sky.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.sky.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.place_rounded, size: 15, color: AppColors.sky),
                        const SizedBox(width: 4),
                        Text(
                          '$_selectedDistrict, $_selectedState',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.sky,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedState = null;
                              _selectedDistrict = null;
                            });
                            _fetchPhotographers();
                          },
                          child: const Icon(Icons.close_rounded, size: 16, color: AppColors.sky),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      foregroundColor: AppColors.sky,
                    ),
                    icon: const Icon(Icons.tune_rounded, size: 14),
                    label: const Text('Change Location', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isBrowsingIndiaLocations = true;
                      });
                    },
                  ),
                ] else ...[
                  // Worldwide badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.cardBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.public_rounded, size: 14, color: AppColors.sky),
                        const SizedBox(width: 5),
                        Text(
                          'Worldwide',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      side: BorderSide(color: context.cardBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.map_outlined, size: 14, color: AppColors.sky),
                    label: Text(
                      'Filter by State & District',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.textMain,
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isBrowsingIndiaLocations = true;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),

        // Search Header Box
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          const Icon(
                            Icons.search_rounded,
                            color: AppColors.sky,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: context.textMain,
                              ),
                              decoration: InputDecoration(
                                hintText: event != null && event.location.isNotEmpty
                                    ? 'Search around "${event.location}"...'
                                    : (_selectedDistrict != null
                                        ? 'Search studios in $_selectedDistrict...'
                                        : 'Search city, area, category, or studio...'),
                                hintStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: context.textMuted,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onSubmitted: (_) {
                                _debounceTimer?.cancel();
                                _applyLocalFilter();
                                _fetchPhotographers(isBackgroundSync: _photographers.isNotEmpty);
                              },
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.clear_rounded, size: 18, color: context.textMuted),
                              onPressed: () {
                                _debounceTimer?.cancel();
                                _searchController.clear();
                                if (_allPhotographers.isNotEmpty) {
                                  _applyLocalFilter();
                                }
                                _fetchPhotographers(isBackgroundSync: true);
                              },
                            ),
                          IconButton(
                            tooltip: 'Search',
                            icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.sky),
                            onPressed: () {
                              _debounceTimer?.cancel();
                              _applyLocalFilter();
                              _fetchPhotographers(isBackgroundSync: _photographers.isNotEmpty);
                            },
                          ),
                          const SizedBox(width: 2),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Hamburger / Category Filter button
                  _buildCategoryFilterButton(),
                ],
              ),

              // Active category filters row (only displayed when filters are selected)
              if (_selectedCategories.isNotEmpty) ...[
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Text(
                          'Filtered by:',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: context.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      ..._selectedCategories.map((cat) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() => _selectedCategories.remove(cat));
                            _fetchPhotographers();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.sky.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.sky.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  cat,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.sky,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.close_rounded, size: 13, color: AppColors.sky),
                              ],
                            ),
                          ),
                        ),
                      )),
                      TextButton(
                        onPressed: () {
                          setState(() => _selectedCategories.clear());
                          _fetchPhotographers();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Clear all',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.sky,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Result count indicator bar
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _selectedCategories.isEmpty
                      ? (_selectedDistrict != null
                          ? '${_photographers.length} photographer${_photographers.length == 1 ? '' : 's'} found in $_selectedDistrict'
                          : (_searchController.text.trim().isNotEmpty
                              ? '${_photographers.length} photographer${_photographers.length == 1 ? '' : 's'} matching "${_searchController.text.trim()}"'
                              : '${_photographers.length} photographer${_photographers.length == 1 ? '' : 's'} discovered worldwide'))
                      : '${_photographers.length} photographer${_photographers.length == 1 ? '' : 's'} matching ${_selectedCategories.length} selected categor${_selectedCategories.length == 1 ? 'y' : 'ies'}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_selectedCategories.isNotEmpty || _selectedDistrict != null || _searchController.text.trim().isNotEmpty)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedCategories.clear();
                      _selectedState = null;
                      _selectedDistrict = null;
                      _searchController.clear();
                    });
                    _fetchPhotographers();
                  },
                  child: Text(
                    'Clear filters',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.sky,
                    ),
                  ),
                ),
            ],
          ),
        ),

        if (_isBackgroundSyncing)
          const LinearProgressIndicator(
            minHeight: 2,
            color: AppColors.sky,
            backgroundColor: Colors.transparent,
          ),

        // List / Loading / Error / Empty Content
        Expanded(
          child: _loading
              ? ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 4,
                  itemBuilder: (_, _) => const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: ShimmerBox(
                      height: 140,
                      borderRadius: 18,
                    ),
                  ),
                )
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline_rounded, size: 48, color: context.textMuted),
                            const SizedBox(height: 12),
                            Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: context.textMain)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.sky,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Retry'),
                              onPressed: _fetchPhotographers,
                            ),
                          ],
                        ),
                      ),
                    )
                  : _photographers.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _fetchPhotographers,
                          color: AppColors.sky,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                            itemCount: _photographers.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (ctx, index) => _buildPhotographerCard(_photographers[index]),
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildEventContextBanner(StudioEvent event) {
    final isDark = context.isDark;
    final dateStr = DateFormat('EEE, dd MMM').format(event.startsAt);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.sky.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.sky.withValues(alpha: 0.25),
          width: 0.9,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.sky.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt_outlined,
              size: 16,
              color: AppColors.sky,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        event.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.textMain,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.sky.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        event.eventType,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.sky,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  event.location.isNotEmpty
                      ? 'Venue: ${event.location} • $dateStr'
                      : 'Date: $dateStr (${event.startTime})',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: context.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterButton() {
    final hasActive = _selectedCategories.isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: 'Filter by Category',
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _openCategoryFilterSheet,
          child: Ink(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: hasActive
                  ? AppColors.sky.withValues(alpha: context.isDark ? 0.22 : 0.12)
                  : context.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasActive ? AppColors.sky : context.cardBorder,
                width: hasActive ? 1.5 : 1,
              ),
              boxShadow: hasActive
                  ? [
                      BoxShadow(
                        color: AppColors.skyGlow,
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 22,
                  color: hasActive ? AppColors.sky : context.textMain,
                ),
                if (hasActive)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3.5),
                      decoration: const BoxDecoration(
                        color: AppColors.sky,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Center(
                        child: Text(
                          '${_selectedCategories.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCategoryFilterSheet() async {
    HapticFeedback.lightImpact();
    final tempSelected = Set<String>.from(_selectedCategories);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.78,
              ),
              decoration: BoxDecoration(
                color: ctx.cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(color: ctx.cardBorder, width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 30,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ctx.textMuted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.sky.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: AppColors.sky,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Filter by Role & Category',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: ctx.textMain,
                                ),
                              ),
                              Text(
                                tempSelected.isEmpty
                                    ? 'Showing all roles worldwide'
                                    : '${tempSelected.length} role${tempSelected.length == 1 ? '' : 's'} selected',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: ctx.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (tempSelected.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setSheetState(() => tempSelected.clear());
                            },
                            child: Text(
                              'Reset',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.sky,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                      shrinkWrap: true,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              selected: tempSelected.isEmpty,
                              label: const Text('All Roles'),
                              labelStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: tempSelected.isEmpty
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: tempSelected.isEmpty
                                    ? Colors.white
                                    : ctx.textMain,
                              ),
                              selectedColor: AppColors.sky,
                              backgroundColor: ctx.innerBg,
                              side: BorderSide(
                                color: tempSelected.isEmpty
                                    ? AppColors.sky
                                    : ctx.cardBorder,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              onSelected: (_) {
                                setSheetState(() => tempSelected.clear());
                              },
                            ),
                            ...PhotographerCategories.all.map((cat) {
                              final isSelected = tempSelected.contains(cat);
                              return FilterChip(
                                selected: isSelected,
                                label: Text(cat),
                                labelStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : ctx.textMain,
                                ),
                                selectedColor: AppColors.sky,
                                backgroundColor: ctx.innerBg,
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.sky
                                      : ctx.cardBorder,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                onSelected: (_) {
                                  setSheetState(() {
                                    if (isSelected) {
                                      tempSelected.remove(cat);
                                    } else {
                                      tempSelected.add(cat);
                                    }
                                  });
                                },
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      18,
                      12,
                      18,
                      12 + MediaQuery.paddingOf(context).bottom,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: ctx.textMuted,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: ctx.ctaGradient,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.sky.withValues(alpha: 0.28),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                setState(() {
                                  _selectedCategories.clear();
                                  _selectedCategories.addAll(tempSelected);
                                });
                                _fetchPhotographers();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                tempSelected.isEmpty
                                    ? 'Show All Photographers'
                                    : 'Apply Filters (${tempSelected.length})',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAvatar(PhotographerProfile photographer, {double size = 48}) {
    if (photographer.logoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.3),
        child: Image.network(
          photographer.logoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildInitialsAvatar(photographer, size),
        ),
      );
    }
    return _buildInitialsAvatar(photographer, size);
  }

  Widget _buildInitialsAvatar(PhotographerProfile photographer, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF818CF8),
            Color(0xFF6366F1),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        photographer.displayName.isNotEmpty
            ? photographer.displayName[0].toUpperCase()
            : 'P',
        style: GoogleFonts.plusJakartaSans(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDistanceBadge(DistanceResult distanceInfo, {bool isCompact = true}) {
    // Rule 4: no reliable coordinates → show "Distance unavailable" in muted text
    if (!distanceInfo.hasKnownDistance) {
      return Text(
        'Distance unavailable',
        style: GoogleFonts.plusJakartaSans(
          fontSize: isCompact ? 11 : 12,
          color: context.textMuted.withValues(alpha: 0.6),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    // Colour logic:
    //  • Exact & very close (< 5 km) → emerald
    //  • Same city (no km) or approx close → sky blue
    //  • Approx far or exact far → indigo
    final isVeryClose = distanceInfo.isSameLocality ||
        (distanceInfo.distanceKm != null && distanceInfo.distanceKm! < 5.0);
    final isSameCity = distanceInfo.isSameCity;

    final Color bgColor;
    final Color borderColor;
    final Color textColor;

    if (isVeryClose && distanceInfo.isExact) {
      // Exact GPS, very close → emerald
      bgColor     = const Color(0xFF10B981).withValues(alpha: 0.14);
      borderColor = const Color(0xFF10B981).withValues(alpha: 0.35);
      textColor   = const Color(0xFF10B981);
    } else if (isSameCity || (isVeryClose && !distanceInfo.isExact)) {
      // Same city or approx-close → sky blue
      bgColor     = AppColors.sky.withValues(alpha: 0.14);
      borderColor = AppColors.sky.withValues(alpha: 0.35);
      textColor   = AppColors.sky;
    } else {
      // Approx far or exact far → indigo
      bgColor     = const Color(0xFF6366F1).withValues(alpha: 0.14);
      borderColor = const Color(0xFF6366F1).withValues(alpha: 0.35);
      textColor   = const Color(0xFF818CF8);
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 10,
        vertical: isCompact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Text(
        distanceInfo.badgeText,
        style: GoogleFonts.plusJakartaSans(
          fontSize: isCompact ? 11 : 12,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildPhotographerCard(PhotographerProfile photographer) {
    final isDark = context.isDark;
    final hasEvent = widget.event != null;
    final refLoc = _referenceLocation;

    // Compute distance from event venue / reference location
    final distanceInfo = GeoDistanceUtils.computeEventDistance(
      eventLocation: refLoc,
      eventLat: widget.event?.latitude,
      eventLng: widget.event?.longitude,
      photographerCity: photographer.city,
      photographerAddress: photographer.address,
      photographerLat: photographer.latitude,
      photographerLng: photographer.longitude,
      precomputedDistanceKm: photographer.distanceKm,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showPhotographerDetailsSheet(photographer, distanceInfo),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Avatar, Studio Name, Owner Name, and Proximity Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvatar(photographer, size: 48),
                  const SizedBox(width: 12),

                  // Title and details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                photographer.displayName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: context.textMain,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (photographer.displayOwner != photographer.displayName)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(
                              photographer.displayOwner,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: context.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        const SizedBox(height: 4),

                        // Location row
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: AppColors.sky,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                photographer.displayLocation,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: context.textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Distance badge: only shown if an event reference exists or actual coordinates exist
              if (hasEvent || distanceInfo.hasKnownDistance) ...[
                const SizedBox(height: 10),
                _buildDistanceBadge(distanceInfo, isCompact: true),
              ],

              // Categories & Roles chips
              if (photographer.categories.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: photographer.categories.take(3).map((c) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.sky.withValues(alpha: isDark ? 0.16 : 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.sky.withValues(alpha: 0.22),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        c,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.sky,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 14),
              Divider(
                height: 1,
                color: context.cardBorder.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),

              // Action Buttons Row: Call, WhatsApp, and Share Event Details
              Row(
                children: [
                  // Call Button
                  if (photographer.phone.isNotEmpty) ...[
                    _buildQuickContactButton(
                      icon: Icons.call_rounded,
                      tooltip: 'Call Photographer',
                      color: context.textMain,
                      onTap: () => LauncherUtils.makePhoneCall(
                        context,
                        photographer.phone,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // WhatsApp Button
                  if (photographer.phone.isNotEmpty) ...[
                    _buildQuickContactButton(
                      icon: Icons.chat_rounded,
                      tooltip: 'Chat on WhatsApp',
                      color: const Color(0xFF25D366),
                      bgColor: const Color(0xFF25D366).withValues(alpha: 0.15),
                      borderColor: const Color(0xFF25D366).withValues(alpha: 0.35),
                      onTap: () {
                        final greeting = hasEvent
                            ? 'Hi ${photographer.displayName}, inquiring about an upcoming event: "${widget.event!.title}".'
                            : 'Hi ${photographer.displayName}, inquiring about photography collaboration.';
                        LauncherUtils.openWhatsApp(
                          context,
                          photographer.phone,
                          prefilledMessage: greeting,
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Share Event Details Button (Primary Action)
                  Expanded(
                    child: _buildShareEventActionButton(
                      hasEvent: hasEvent,
                      photographer: photographer,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickContactButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    Color? bgColor,
    Color? borderColor,
    required VoidCallback onTap,
  }) {
    final isDark = context.isDark;

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor ??
                    (isDark
                        ? const Color(0xFF1E2538)
                        : const Color(0xFFEEF2F8)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: borderColor ?? context.cardBorder,
                  width: 1.0,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 19),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShareEventActionButton({
    required bool hasEvent,
    required PhotographerProfile photographer,
  }) {
    return _PressableActionButton(
      label: hasEvent ? 'Share Event' : 'Contact Studio',
      icon: hasEvent ? Icons.share_rounded : Icons.info_outline_rounded,
      onTap: () {
        if (hasEvent) {
          _shareEventDetails(photographer);
        } else if (photographer.phone.isNotEmpty) {
          LauncherUtils.openWhatsApp(context, photographer.phone);
        } else {
          AppSnackBar.info(
            context,
            'No contact number available for ${photographer.displayName}.',
          );
        }
      },
    );
  }

  Widget _buildEmptyState() {
    final isDiscoverMode = widget.event == null && _selectedDistrict != null;

    if (isDiscoverMode) {
      final hasCategoryFilter = _selectedCategories.isNotEmpty;
      final title = hasCategoryFilter
          ? 'No Photographers Matching Filter'
          : 'No Studios in $_selectedDistrict Yet';
      final message = hasCategoryFilter
          ? 'No photographers registered in $_selectedDistrict match the selected categories (${_selectedCategories.join(', ')}).'
          : 'We could not find any registered photographers in $_selectedDistrict, $_selectedState. Try exploring an adjacent district or change state.';

      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.sky.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_search_rounded,
                  size: 40,
                  color: AppColors.sky,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: context.textMain,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: context.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  if (hasCategoryFilter)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sky,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.clear_all_rounded, size: 18),
                      label: const Text('Clear Filters'),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        _searchController.clear();
                        setState(() => _selectedCategories.clear());
                        _fetchPhotographers();
                      },
                    ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: context.cardBorder),
                    ),
                    icon: const Icon(Icons.location_city_rounded, size: 18),
                    label: const Text('Change District'),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedDistrict = null;
                        _isBrowsingIndiaLocations = true;
                        _locationSearchController.clear();
                      });
                    },
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: context.cardBorder),
                    ),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Change State'),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedState = null;
                        _selectedDistrict = null;
                        _isBrowsingIndiaLocations = true;
                        _locationSearchController.clear();
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final hasCategoryFilter = _selectedCategories.isNotEmpty;
    final queryText = _searchController.text.trim();
    final hasQuery = queryText.isNotEmpty;

    final String title;
    final String message;

    if (hasQuery) {
      title = 'No Photographers Matching "$queryText"';
      message = 'We could not find any studios matching your search. Try searching for another city, country, or studio name.';
    } else if (hasCategoryFilter) {
      title = 'No Photographers Matching Selected Roles';
      message = 'No registered photographers match the selected categories (${_selectedCategories.join(', ')}).';
    } else if (widget.event != null) {
      title = 'No Photographers Found Nearby';
      message = 'Try adjusting your search location, clearing category filters, or searching for nearby cities.';
    } else {
      title = 'No Photographers Discovered Yet';
      message = 'Registered photographers from around the world will appear here.';
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.sky.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_search_rounded,
                size: 40,
                color: AppColors.sky,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: context.textMain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: context.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                if (hasQuery || hasCategoryFilter)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sky,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.clear_all_rounded, size: 18),
                    label: const Text('Clear Filters'),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _selectedCategories.clear();
                        _selectedState = null;
                        _selectedDistrict = null;
                      });
                      _fetchPhotographers();
                    },
                  ),
                if (widget.event == null)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: context.cardBorder),
                    ),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Filter by State & District'),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isBrowsingIndiaLocations = true;
                      });
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dedicated, premium card action button with tactile press feedback and zero text clipping
class _PressableActionButton extends StatefulWidget {
  const _PressableActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_PressableActionButton> createState() => _PressableActionButtonState();
}

class _PressableActionButtonState extends State<_PressableActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        setState(() => _pressed = true);
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.spring,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF00C6FF),
                Color(0xFF6366F1),
                Color(0xFF8B5CF6),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.35 : 0.25),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.35 : 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 17),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.label,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
