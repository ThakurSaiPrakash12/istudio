import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/photographer_profile.dart';
import '../../models/studio_event.dart';
import '../../providers/auth_provider.dart';
import '../../services/photographer_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/geo_distance_utils.dart';
import '../../utils/launcher_utils.dart';
import '../../utils/photographer_categories.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/studio_app_bar.dart';

class NearbyPhotographersScreen extends StatefulWidget {
  const NearbyPhotographersScreen({
    super.key,
    this.event,
    this.initialLocation,
  });

  final StudioEvent? event;
  final String? initialLocation;

  @override
  State<NearbyPhotographersScreen> createState() =>
      _NearbyPhotographersScreenState();
}

class _NearbyPhotographersScreenState extends State<NearbyPhotographersScreen> {
  final PhotographerService _service = PhotographerService();
  late final TextEditingController _searchController;
  String _selectedCategory = 'All';
  bool _loading = false;
  List<PhotographerProfile> _photographers = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final defaultLoc = widget.initialLocation ??
        (widget.event?.location.isNotEmpty == true
            ? widget.event!.location
            : '');
    _searchController = TextEditingController(text: defaultLoc);
    _fetchPhotographers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _referenceLocation {
    final queryLoc = _searchController.text.trim();
    if (queryLoc.isNotEmpty) return queryLoc;
    if (widget.event?.location.isNotEmpty == true) {
      return widget.event!.location;
    }
    return '';
  }

  Future<void> _fetchPhotographers() async {
    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final queryLoc = _searchController.text.trim();
      final cat = _selectedCategory == 'All' ? null : _selectedCategory;

      final results = await _service.searchNearby(
        token: token,
        location: queryLoc.isNotEmpty ? queryLoc : null,
        category: cat,
        latitude: widget.event?.latitude,
        longitude: widget.event?.longitude,
      );

      // Sort by proximity to event or reference location
      final refLoc = _referenceLocation;
      final sortedResults = List<PhotographerProfile>.from(results);
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
        return 0;
      });

      if (!mounted) return;
      setState(() {
        _photographers = sortedResults;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Unable to load photographers near this location.';
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
                          'Event Summary',
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
                    'Send via WhatsApp',
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
                    'More Sharing Options',
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
                  'About',
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
                  'Categories & Services',
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
    final isDark = context.isDark;
    final event = widget.event;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            StudioAppBar(
              title: 'Nearby Photographers',
              subtitle: event != null
                  ? 'Collaborators for "${event.title}"'
                  : 'Search by location and categories',
              leading: IconButton(
                tooltip: 'Back',
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: context.textMain,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),

            // Event context banner (if viewing for a specific event)
            if (event != null) _buildEventContextBanner(event),

            // Search Header Box
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  // Search input
                  Container(
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
                          Icons.location_on_rounded,
                          color: AppColors.sky,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: context.textMain,
                            ),
                            decoration: InputDecoration(
                              hintText: event != null && event.location.isNotEmpty
                                  ? 'Search around "${event.location}"...'
                                  : 'Enter event city or location...',
                              hintStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: context.textMuted,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onSubmitted: (_) => _fetchPhotographers(),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: Icon(Icons.clear_rounded, size: 18, color: context.textMuted),
                            onPressed: () {
                              _searchController.clear();
                              _fetchPhotographers();
                            },
                          ),
                        IconButton(
                          tooltip: 'Search',
                          icon: const Icon(Icons.search_rounded, color: AppColors.sky),
                          onPressed: _fetchPhotographers,
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Horizontal category chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All'),
                        ...PhotographerCategories.primaryRoles.map(_buildFilterChip),
                        ...PhotographerCategories.operatorRoles.map(_buildFilterChip),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content List
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
                                Icon(
                                  Icons.error_outline_rounded,
                                  size: 48,
                                  color: context.textMuted,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: context.textMain),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.sky,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
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
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (ctx, index) => _buildPhotographerCard(
                                  _photographers[index],
                                ),
                              ),
                            ),
            ),
          ],
        ),
      ),
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

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedCategory == label;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? Colors.white : context.textMain,
        ),
        selectedColor: AppColors.sky,
        backgroundColor: context.cardBg,
        side: BorderSide(
          color: isSelected ? AppColors.sky : context.cardBorder,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onSelected: (_) {
          setState(() => _selectedCategory = label);
          _fetchPhotographers();
        },
      ),
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

              // Distance from event — always shown (exact / approx / same city / unavailable)
              const SizedBox(height: 10),
              _buildDistanceBadge(distanceInfo, isCompact: true),

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
        }
      },
    );
  }

  Widget _buildEmptyState() {
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
              'No Photographers Found Nearby',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: context.textMain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search location, clearing category filters, or searching for nearby cities.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: context.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: context.cardBorder),
                  ),
                  icon: const Icon(Icons.clear_all_rounded, size: 18),
                  label: const Text('Clear Filters'),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _selectedCategory = 'All');
                    _fetchPhotographers();
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
