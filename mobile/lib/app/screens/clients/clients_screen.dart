import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/client.dart';
import '../../models/studio_event.dart';
import '../../providers/events_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/studio_app_bar.dart';
import '../../widgets/studio_button.dart';
import '../../widgets/studio_card.dart';
import '../../widgets/studio_text_field.dart';
import '../../widgets/uiverse_search_bar.dart';
import 'client_details_screen.dart';
import '../../routes/smooth_page_route.dart';
import '../../utils/launcher_utils.dart';

enum ClientFilter {
  all,
  information,
  upcoming,
  completed,
  notResponded,
  paymentDue;

  String get label {
    switch (this) {
      case ClientFilter.all:
        return 'All';
      case ClientFilter.information:
        return 'Information';
      case ClientFilter.upcoming:
        return 'Coming Up';
      case ClientFilter.completed:
        return 'Completed';
      case ClientFilter.notResponded:
        return 'Not Responded';
      case ClientFilter.paymentDue:
        return 'Due';
    }
  }
}

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  ClientFilter _activeFilter = ClientFilter.all;
  late AnimationController _enterController;

  static final _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _enterController.dispose();
    super.dispose();
  }

  Animation<double> _staggered(double begin, double end) =>
      CurvedAnimation(
        parent: _enterController,
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
      );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventsProvider>();
    final allClients = provider.clients;
    final textMain = context.textMain;
    final textMuted = context.textMuted;
    final accent = context.accentColor;

    final query = _searchController.text.trim().toLowerCase();

    // Filter clients based on search query and filter chip
    final filteredClients = allClients.where((client) {
      final clientEvents =
          provider.getEventsForClient(client.id, clientName: client.name);

      final matchesSearch = query.isEmpty ||
          client.name.toLowerCase().contains(query) ||
          client.phone.toLowerCase().contains(query) ||
          client.email.toLowerCase().contains(query) ||
          clientEvents.any((e) =>
              e.title.toLowerCase().contains(query) ||
              e.eventType.toLowerCase().contains(query));

      if (!matchesSearch) return false;

      switch (_activeFilter) {
        case ClientFilter.all:
          return true;
        case ClientFilter.information:
          return client.status == ClientStatus.information;
        case ClientFilter.upcoming:
          return client.status == ClientStatus.comingUp ||
              clientEvents.any((e) =>
                  (e.status == EventStatus.upcoming ||
                      e.status == EventStatus.inProgress) &&
                  !e.startsAt.isBefore(
                      DateTime.now().subtract(const Duration(days: 1))));
        case ClientFilter.completed:
          return client.status == ClientStatus.completed ||
              (clientEvents.isNotEmpty &&
                  clientEvents.every((e) =>
                      e.status == EventStatus.completed ||
                      e.startsAt.isBefore(
                          DateTime.now().subtract(const Duration(days: 1)))));
        case ClientFilter.notResponded:
          return client.status == ClientStatus.notResponded;
        case ClientFilter.paymentDue:
          return clientEvents.any((e) =>
              e.remainingAmount > 0 || e.status == EventStatus.paymentDue);
      }
    }).toList();

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            children: [
              StudioAppBar(
                title: 'Clients',
                subtitle: '${allClients.length} clients',
                actions: [
                  IconButton(
                    tooltip: 'Add Client',
                    icon: Icon(Icons.person_add_alt_1_rounded,
                        color: accent, size: 22),
                    onPressed: () => _showAddClientSheet(context),
                  ),
                ],
              ),

              // Animated Uiverse Search Bar
              FadeTransition(
                opacity: _staggered(0.0, 0.30),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: UiverseSearchBar(
                    controller: _searchController,
                    hintText: 'Search by name or phone...',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),

              // Filter Chips
              FadeTransition(
                opacity: _staggered(0.10, 0.40),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: ClientFilter.values.map((filter) {
                      final isSelected = _activeFilter == filter;
                      return Padding(
                        padding:
                            const EdgeInsets.only(right: 8, bottom: 8),
                        child: FilterChip(
                          label: Text(filter.label),
                          selected: isSelected,
                          selectedColor: accent,
                          backgroundColor: context.cardBg,
                          showCheckmark: false,
                          shape: const StadiumBorder(),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : textMain,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? accent
                                : context.cardBorder
                                    .withValues(alpha: 0.4),
                          ),
                          onSelected: (_) {
                            HapticFeedback.selectionClick();
                            setState(() => _activeFilter = filter);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Client List with smooth AnimatedSwitcher
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: filteredClients.isEmpty
                      ? FadeTransition(
                          key: const ValueKey('empty_clients'),
                          opacity: _staggered(0.20, 0.55),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color:
                                          accent.withValues(alpha: 0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                        Icons.person_search_rounded,
                                        size: 40,
                                        color: textMuted.withValues(
                                            alpha: 0.6)),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'No clients found',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: textMain,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Adjust your search or clear filters',
                                    style: TextStyle(
                                        color: textMuted, fontSize: 13),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          key: const ValueKey('clients_list'),
                          padding: EdgeInsets.fromLTRB(
                            16,
                            4,
                            16,
                            130 + MediaQuery.paddingOf(context).bottom,
                          ),
                          itemCount: filteredClients.length,
                          separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final client = filteredClients[index];
                          final events = provider.getEventsForClient(
                              client.id,
                              clientName: client.name);
                          final totalValue =
                              provider.getClientTotalValue(client.id,
                                  clientName: client.name);
                          final totalRemaining =
                              provider.getClientTotalRemaining(
                                  client.id,
                                  clientName: client.name);
                          final hasRemaining = totalRemaining > 0;

                          return StudioCard(
                            borderRadius: 28,
                            padding: const EdgeInsets.all(16),
                            onTap: () {
                              Navigator.of(context).push(
                                SmoothPageRoute(
                                  builder: (_) => ClientDetailsScreen(
                                      clientId: client.id),
                                ),
                              );
                            },
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // Circular avatar
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            accent.withValues(
                                                alpha: 0.22),
                                            accent.withValues(
                                                alpha: 0.06),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: accent.withValues(
                                              alpha: 0.28),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          client.name.isNotEmpty
                                              ? client
                                                  .name.characters.first
                                                  .toUpperCase()
                                              : 'C',
                                          style: TextStyle(
                                            color: accent,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  client.name,
                                                  style: TextStyle(
                                                    color: textMain,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              _buildStatusPill(client.status, context.isDark),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          if (client.phone.isNotEmpty)
                                            InkWell(
                                              borderRadius: BorderRadius.circular(6),
                                              onTap: () => LauncherUtils.makePhoneCall(context, client.phone),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 2),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.phone_outlined,
                                                      size: 13,
                                                      color: Color(0xFF10B981),
                                                    ),
                                                    const SizedBox(width: 5),
                                                    Flexible(
                                                      child: Text(
                                                        client.phone,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          color: Color(0xFF10B981),
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                          else if (client.email.isNotEmpty)
                                            InkWell(
                                              borderRadius: BorderRadius.circular(6),
                                              onTap: () => LauncherUtils.sendEmail(context, client.email),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 2),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.mail_outline_rounded,
                                                      size: 13,
                                                      color: accent,
                                                    ),
                                                    const SizedBox(width: 5),
                                                    Flexible(
                                                      child: Text(
                                                        client.email,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                          color: accent,
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                          else
                                            Text(
                                              'No contact details',
                                              style: TextStyle(
                                                color: textMuted,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (client.phone.isNotEmpty) ...[
                                      IconButton(
                                        icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                                        color: const Color(0xFF10B981),
                                        style: IconButton.styleFrom(
                                          backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.12),
                                          padding: const EdgeInsets.all(7),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        tooltip: 'Call ${client.name}',
                                        onPressed: () => LauncherUtils.makePhoneCall(context, client.phone),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: textMuted,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Pill-shaped stats row / status alert
                                if (client.status == ClientStatus.notResponded)
                                  _buildNotRespondedCardRow(context, client)
                                else if (client.status == ClientStatus.information && events.isEmpty)
                                  _buildInquiryCardRow(context)
                                else if (events.isEmpty)
                                  _buildEmptyEventsCardRow(context)
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: context.innerBg,
                                    borderRadius:
                                        BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Icon(
                                                Icons
                                                    .event_note_outlined,
                                                size: 13,
                                                color: accent.withValues(
                                                    alpha: 0.8)),
                                            const SizedBox(width: 5),
                                            Flexible(
                                              child: Text(
                                                '${events.length} ${events.length == 1 ? 'Event' : 'Events'}'
                                                '${events.isNotEmpty ? ' · ${_currency.format(totalValue)}' : ''}',
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow
                                                        .ellipsis,
                                                style: TextStyle(
                                                  color: textMain,
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (hasRemaining)
                                        Container(
                                          padding:
                                              const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 9,
                                                  vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors
                                                    .urgencyWarning(
                                                        context)
                                                .withValues(
                                                    alpha: 0.14),
                                            borderRadius:
                                                BorderRadius.circular(
                                                    999),
                                            border: Border.all(
                                              color: AppColors
                                                      .urgencyWarning(
                                                          context)
                                                  .withValues(
                                                      alpha: 0.35),
                                            ),
                                          ),
                                          child: Text(
                                            '${_currency.format(totalRemaining)} Due',
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: AppColors
                                                  .urgencyWarning(
                                                      context),
                                              fontSize: 11,
                                              fontWeight:
                                                  FontWeight.w700,
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          padding:
                                              const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 9,
                                                  vertical: 3),
                                          decoration: BoxDecoration(
                                            color: accent.withValues(
                                                alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(
                                                    999),
                                          ),
                                          child: Text(
                                            'All Paid',
                                            style: TextStyle(
                                              color: accent,
                                              fontSize: 11,
                                              fontWeight:
                                                  FontWeight.w700,
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
                      ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddClientSheet(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();
    final notesController = TextEditingController();
    ClientStatus selectedStatus = ClientStatus.information;
    String? sheetError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardBg,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final textMain = sheetContext.textMain;
            final textMuted = sheetContext.textMuted;
            final accent = sheetContext.accentColor;

            return SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Fixed Modal Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 14, 12),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: textMuted.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Icon(
                                Icons.person_add_alt_1_rounded,
                                color: accent,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'New Client Profile',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: textMain,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Inquiry lead, upcoming shoot, or past client',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close_rounded, color: textMuted),
                              onPressed: () => Navigator.of(sheetContext).pop(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    color: sheetContext.cardBorder.withValues(alpha: 0.35),
                    height: 1,
                  ),

                  // Scrollable Body with fields
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (sheetError != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded,
                                      color: Color(0xFFEF4444), size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      sheetError!,
                                      style: const TextStyle(
                                        color: Color(0xFFEF4444),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Status Selector Section
                          Text(
                            'Client Stage / Category',
                            style: TextStyle(
                              color: textMuted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 42,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              children: [
                                _buildAddClientStatusChip(
                                  sheetContext,
                                  status: ClientStatus.information,
                                  label: 'Inquiry',
                                  icon: Icons.chat_bubble_outline_rounded,
                                  color: const Color(0xFFFBBF24),
                                  isSelected: selectedStatus == ClientStatus.information,
                                  onTap: () => setSheetState(() => selectedStatus = ClientStatus.information),
                                ),
                                const SizedBox(width: 8),
                                _buildAddClientStatusChip(
                                  sheetContext,
                                  status: ClientStatus.comingUp,
                                  label: 'Coming Up',
                                  icon: Icons.calendar_today_rounded,
                                  color: AppColors.sky,
                                  isSelected: selectedStatus == ClientStatus.comingUp,
                                  onTap: () => setSheetState(() => selectedStatus = ClientStatus.comingUp),
                                ),
                                const SizedBox(width: 8),
                                _buildAddClientStatusChip(
                                  sheetContext,
                                  status: ClientStatus.completed,
                                  label: 'Completed',
                                  icon: Icons.task_alt_rounded,
                                  color: const Color(0xFF34D399),
                                  isSelected: selectedStatus == ClientStatus.completed,
                                  onTap: () => setSheetState(() => selectedStatus = ClientStatus.completed),
                                ),
                                const SizedBox(width: 8),
                                _buildAddClientStatusChip(
                                  sheetContext,
                                  status: ClientStatus.notResponded,
                                  label: 'Not Responded',
                                  icon: Icons.schedule_send_rounded,
                                  color: const Color(0xFF64748B),
                                  isSelected: selectedStatus == ClientStatus.notResponded,
                                  onTap: () => setSheetState(() => selectedStatus = ClientStatus.notResponded),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          StudioTextField(
                            label: 'Full Name *',
                            hint: 'e.g. Aditi Sharma',
                            prefixIcon: Icons.person_outline_rounded,
                            controller: nameController,
                          ),
                          const SizedBox(height: 14),
                          StudioTextField(
                            label: 'Phone Number *',
                            hint: 'e.g. 9876543210',
                            prefixIcon: Icons.phone_outlined,
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 14),
                          StudioTextField(
                            label: 'Email Address',
                            hint: 'e.g. aditi@example.com',
                            prefixIcon: Icons.email_outlined,
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 14),
                          StudioTextField(
                            label: 'Address / Location',
                            hint: 'e.g. Jubilee Hills, Hyderabad',
                            prefixIcon: Icons.location_on_outlined,
                            controller: addressController,
                          ),
                          const SizedBox(height: 14),
                          StudioTextField(
                            label: 'Notes & Preferences',
                            hint: 'Photography preferences, package requests, budget...',
                            prefixIcon: Icons.notes_rounded,
                            controller: notesController,
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Fixed Bottom Action Button
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                    ),
                    decoration: BoxDecoration(
                      color: sheetContext.cardBg,
                      border: Border(
                        top: BorderSide(
                          color: sheetContext.cardBorder.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                    child: StudioButton(
                      label: 'Save Client Profile',
                      onPressed: () {
                        final name = nameController.text.trim();
                        final phone = phoneController.text.trim();
                        final digitsOnly =
                            phone.replaceAll(RegExp(r'\D'), '');

                        if (name.isEmpty) {
                          HapticFeedback.heavyImpact();
                          setSheetState(() => sheetError = 'Please enter client full name');
                          return;
                        }

                        if (phone.isEmpty) {
                          HapticFeedback.heavyImpact();
                          setSheetState(() => sheetError = 'Please enter phone number');
                          return;
                        }

                        if (digitsOnly.length < 10) {
                          HapticFeedback.heavyImpact();
                          setSheetState(() => sheetError = 'Phone number must be at least 10 digits');
                          return;
                        }

                        final newClient = Client(
                          id: 'cli-${DateTime.now().millisecondsSinceEpoch}',
                          name: name,
                          phone: phone,
                          email: emailController.text.trim(),
                          address: addressController.text.trim(),
                          notes: notesController.text.trim(),
                          status: selectedStatus,
                          createdAt: DateTime.now(),
                        );

                        context.read<EventsProvider>().addClient(newClient);
                        Navigator.of(sheetContext).pop();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Client "${newClient.name}" created successfully.'),
                          ),
                        );
                      },
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

  Widget _buildAddClientStatusChip(
    BuildContext context, {
    required ClientStatus status,
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = context.isDark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: isDark ? 0.25 : 0.16)
                : context.innerBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected
                  ? color
                  : context.cardBorder.withValues(alpha: 0.4),
              width: isSelected ? 1.6 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? color : context.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? (isDark ? Colors.white : color)
                      : context.textMain,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotRespondedCardRow(BuildContext context, Client client) {
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF64748B).withValues(alpha: isDark ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFF64748B).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule_send_rounded,
            size: 14,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'No response after 15 days',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
              ),
            ),
            child: const Text(
              'Follow Up',
              style: TextStyle(
                color: Color(0xFF38BDF8),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInquiryCardRow(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFBBF24).withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFFBBF24).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 13,
            color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'Inquiry lead · Event not booked yet',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFBBF24).withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Active',
              style: TextStyle(
                color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyEventsCardRow(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: context.innerBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(Icons.event_busy_outlined, size: 13, color: context.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'No events scheduled yet',
              style: TextStyle(
                color: context.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(ClientStatus status, bool isDark) {
    Color bg;
    Color fg;
    String label = status.label;

    switch (status) {
      case ClientStatus.information:
        bg = const Color(0xFFFBBF24).withValues(alpha: isDark ? 0.22 : 0.14);
        fg = isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309);
        break;
      case ClientStatus.comingUp:
        bg = AppColors.sky.withValues(alpha: isDark ? 0.22 : 0.14);
        fg = isDark ? const Color(0xFFC7D2FE) : AppColors.skyDeep;
        break;
      case ClientStatus.completed:
        bg = const Color(0xFF34D399).withValues(alpha: isDark ? 0.22 : 0.14);
        fg = isDark ? const Color(0xFFA7F3D0) : const Color(0xFF047857);
        break;
      case ClientStatus.notResponded:
        bg = const Color(0xFF64748B).withValues(alpha: isDark ? 0.22 : 0.14);
        fg = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
