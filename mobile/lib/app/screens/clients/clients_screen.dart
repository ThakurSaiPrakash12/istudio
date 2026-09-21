import 'package:flutter/material.dart';
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
import 'client_details_screen.dart';
import '../../routes/smooth_page_route.dart';

enum ClientFilter {
  all,
  upcoming,
  active,
  past,
  paymentDue;

  String get label {
    switch (this) {
      case ClientFilter.all:
        return 'All';
      case ClientFilter.upcoming:
        return 'Coming Up';
      case ClientFilter.active:
        return 'Active';
      case ClientFilter.past:
        return 'Done';
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
        case ClientFilter.upcoming:
          return clientEvents.any((e) =>
              e.status == EventStatus.upcoming &&
              !e.startsAt
                  .isBefore(DateTime.now().subtract(const Duration(days: 1))));
        case ClientFilter.active:
          return clientEvents.any((e) => e.status == EventStatus.inProgress);
        case ClientFilter.past:
          return clientEvents.isNotEmpty &&
              clientEvents.every((e) =>
                  e.status == EventStatus.completed ||
                  e.startsAt.isBefore(
                      DateTime.now().subtract(const Duration(days: 1))));
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

              // Search Bar
              FadeTransition(
                opacity: _staggered(0.0, 0.30),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: context.cardBorder.withValues(alpha: 0.30),
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: textMain, fontSize: 14),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search by name or phone...',
                        hintStyle: TextStyle(
                          color: textMuted.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(Icons.search_rounded,
                            color: accent, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear,
                                    color: textMuted, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                    ),
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
                          padding:
                              const EdgeInsets.fromLTRB(16, 4, 16, 110),
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
                                          Text(
                                            client.name,
                                            style: TextStyle(
                                              color: textMain,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            client.phone.isNotEmpty
                                                ? client.phone
                                                : (client
                                                        .email.isNotEmpty
                                                    ? client.email
                                                    : 'No contact details'),
                                            style: TextStyle(
                                              color: textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: textMuted,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Pill-shaped stats row
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: sheetContext.textMuted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'New Client Profile',
                      style: GoogleFonts.plusJakartaSans(
                        color: sheetContext.textMain,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon:
                          Icon(Icons.close, color: sheetContext.textMuted),
                      onPressed: () =>
                          Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                StudioTextField(
                  label: 'Full Name *',
                  hint: 'e.g. Aanya Sharma',
                  controller: nameController,
                ),
                const SizedBox(height: 14),
                StudioTextField(
                  label: 'Phone Number *',
                  hint: 'e.g. 9876543210',
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                StudioTextField(
                  label: 'Email Address',
                  hint: 'e.g. aanya@example.com',
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                StudioTextField(
                  label: 'Address / Location',
                  hint: 'e.g. Flat 402, Lotus Residency',
                  controller: addressController,
                ),
                const SizedBox(height: 14),
                StudioTextField(
                  label: 'Notes & Preferences',
                  hint:
                      'Special lighting, themes, delivery requests...',
                  controller: notesController,
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                StudioButton(
                  label: 'Create Client',
                  onPressed: () {
                    final name = nameController.text.trim();
                    final phone = phoneController.text.trim();
                    final digitsOnly =
                        phone.replaceAll(RegExp(r'\D'), '');

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Please enter client full name'),
                        ),
                      );
                      return;
                    }

                    if (phone.isEmpty) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter phone number'),
                        ),
                      );
                      return;
                    }

                    if (digitsOnly.length < 10) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Phone number must be at least 10 digits'),
                        ),
                      );
                      return;
                    }

                    final newClient = Client(
                      id: 'cli-${DateTime.now().millisecondsSinceEpoch}',
                      name: name,
                      phone: phone,
                      email: emailController.text.trim(),
                      address: addressController.text.trim(),
                      notes: notesController.text.trim(),
                      createdAt: DateTime.now(),
                    );

                    context.read<EventsProvider>().addClient(newClient);
                    Navigator.of(sheetContext).pop();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Client "${newClient.name}" created.'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
