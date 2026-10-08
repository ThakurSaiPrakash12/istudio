import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/photographer_profile.dart';
import '../../models/studio_event.dart';
import '../../providers/auth_provider.dart';
import '../../services/photographer_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/launcher_utils.dart';
import '../../utils/photographer_categories.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/studio_app_bar.dart';
import '../../widgets/studio_button.dart';

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
      );

      if (!mounted) return;
      setState(() {
        _photographers = results;
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
    sb.writeln('📸 *Event Details & Collaboration Opportunity*');
    sb.writeln('━━━━━━━━━━━━━━━━━━━━');
    if (myUser?.displayStudioName.isNotEmpty == true) {
      sb.writeln('*From Studio:* ${myUser!.displayStudioName}');
    }
    sb.writeln('*Event:* ${event.title} (${event.eventType})');
    sb.writeln('*Date:* $dateStr');
    sb.writeln('*Time:* ${event.startTime} - ${event.endTime}');
    sb.writeln('*Location:* ${event.location}');

    if (event.deliverables.isNotEmpty) {
      sb.writeln('*Requirements:*');
      for (final d in event.deliverables) {
        sb.writeln('  • ${d.title}');
      }
    }

    if (event.notes.trim().isNotEmpty) {
      sb.writeln('*Notes:* ${event.notes.trim()}');
    }

    sb.writeln('━━━━━━━━━━━━━━━━━━━━');
    if (myUser != null) {
      sb.writeln('*Contact:* ${myUser.displayOwner} (${myUser.phone})');
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

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: ctx.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: ctx.cardBorder),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: ctx.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Text(
                'Share Event with ${photographer.displayName}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: ctx.textMain,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Send event schedule, deliverables, and location details directly.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: ctx.textMuted,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: StudioButton(
                      label: 'Send via WhatsApp',
                      icon: Icons.chat_bubble_outline_rounded,
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
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(color: ctx.cardBorder),
                      ),
                      icon: Icon(Icons.share_outlined, color: ctx.textMain, size: 18),
                      label: Text(
                        'Other Share Options',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          color: ctx.textMain,
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        // ignore: deprecated_member_use
                        Share.share(
                          message,
                          subject: 'Event Collaboration: ${event.title}',
                        );
                      },
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
                  ? 'Find collaborators for "${event.title}"'
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

            // Search Header Box
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
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
                              hintText: 'Enter event city or location...',
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
                  const SizedBox(height: 12),

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
                                StudioButton(
                                  label: 'Retry',
                                  icon: Icons.refresh_rounded,
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
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                                itemCount: _photographers.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 14),
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

  Widget _buildPhotographerCard(PhotographerProfile photographer) {
    final isDark = context.isDark;
    final hasEvent = widget.event != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Studio Name, Owner Name, Location
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.sky, Color(0xFF6366F1)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  photographer.displayName.isNotEmpty
                      ? photographer.displayName[0].toUpperCase()
                      : 'P',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title and details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      photographer.displayName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.textMain,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (photographer.displayOwner != photographer.displayName)
                      Text(
                        photographer.displayOwner,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: context.textMuted,
                        ),
                      ),
                    const SizedBox(height: 4),
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
                        if (photographer.displayDistance != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              photographer.displayDistance!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF059669),
                              ),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(width: 6),
                          Text(
                            '• Distance unavailable',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              color: context.textMuted.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Categories & Roles chips
          if (photographer.categories.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: photographer.categories.take(4).map((c) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.sky.withValues(alpha: isDark ? 0.2 : 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.sky.withValues(alpha: 0.25),
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

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Action Buttons: Call, WhatsApp, and Share Event Details
          Row(
            children: [
              // Call Button
              if (photographer.phone.isNotEmpty)
                IconButton.filledTonal(
                  tooltip: 'Call Photographer',
                  style: IconButton.styleFrom(
                    backgroundColor: context.innerBg,
                    foregroundColor: context.textMain,
                  ),
                  icon: const Icon(Icons.call_rounded, size: 18),
                  onPressed: () => LauncherUtils.makePhoneCall(
                    context,
                    photographer.phone,
                  ),
                ),
              const SizedBox(width: 8),

              // WhatsApp Button
              if (photographer.phone.isNotEmpty)
                IconButton.filledTonal(
                  tooltip: 'Chat on WhatsApp',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.15),
                    foregroundColor: const Color(0xFF25D366),
                  ),
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  onPressed: () {
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

              // Share Event Details Button
              Expanded(
                child: StudioButton(
                  label: hasEvent ? 'Share Event Details' : 'Contact / Details',
                  icon: hasEvent ? Icons.share_rounded : Icons.info_outline_rounded,
                  height: 42,
                  onPressed: () {
                    if (hasEvent) {
                      _shareEventDetails(photographer);
                    } else if (photographer.phone.isNotEmpty) {
                      LauncherUtils.openWhatsApp(context, photographer.phone);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
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
              'Try adjusting your search location, clearing filters, or searching for other nearby cities.',
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
