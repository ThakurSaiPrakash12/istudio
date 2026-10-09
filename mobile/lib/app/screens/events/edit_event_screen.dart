import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/client.dart';
import '../../models/studio_event.dart';
import '../../providers/auth_provider.dart';
import '../../providers/events_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/geo_distance_utils.dart';
import '../../widgets/location_search_field.dart';
import '../../widgets/studio_app_bar.dart';
import '../../widgets/studio_button.dart';
import '../../widgets/studio_text_field.dart';

class EditEventScreen extends StatefulWidget {
  const EditEventScreen({super.key, required this.event});

  final StudioEvent event;

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  static const _eventTypes = [
    'Wedding',
    'Maternity',
    'Commercial',
    'Newborn',
    'Pre-wedding',
    'Portrait',
    'Fashion',
    'Event',
    'Others',
  ];

  static final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  late final TextEditingController _customTypeController;

  late String _eventType;
  late DateTime _date;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late EventStatus _status;
  String? _clientId;
  late String _clientName;
  double? _eventLatitude;
  double? _eventLongitude;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _titleController = TextEditingController(text: e.title);
    _locationController = TextEditingController(text: e.location);
    _amountController = TextEditingController(
      text: e.totalAmount == e.totalAmount.roundToDouble()
          ? e.totalAmount.toInt().toString()
          : e.totalAmount.toString(),
    );
    _notesController = TextEditingController(text: e.notes);

    final knownType = _eventTypes.firstWhere(
      (t) => t.toLowerCase() == e.eventType.toLowerCase(),
      orElse: () => 'Others',
    );
    _eventType = knownType;
    _customTypeController = TextEditingController(
      text: knownType == 'Others' && e.eventType.toLowerCase() != 'others'
          ? e.eventType
          : '',
    );

    _date = DateTime(e.startsAt.year, e.startsAt.month, e.startsAt.day);
    _startTime = _parseTime(e.startTime, const TimeOfDay(hour: 10, minute: 0));
    _endTime = _parseTime(e.endTime, const TimeOfDay(hour: 16, minute: 0));
    _status = e.status;
    _clientId = e.clientId;
    _clientName = e.clientName;
    _eventLatitude = e.latitude;
    _eventLongitude = e.longitude;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _customTypeController.dispose();
    super.dispose();
  }

  TimeOfDay _parseTime(String raw, TimeOfDay fallback) {
    final clean = raw.trim().toUpperCase();
    final match = RegExp(r'(\d{1,2})(?::(\d{2}))?').firstMatch(clean);
    if (match == null) return fallback;
    var hour = int.tryParse(match.group(1)!) ?? fallback.hour;
    final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
    if (clean.contains('PM') && hour < 12) hour += 12;
    if (clean.contains('AM') && hour == 12) hour = 0;
    if (hour > 23 || minute > 59) return fallback;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Widget _pickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: context.accentColor,
          surface: context.cardBg,
          onSurface: context.textMain,
        ),
      ),
      child: child!,
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 5);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(first) ? first : _date,
      firstDate: first,
      lastDate: DateTime(now.year + 5),
      builder: _pickerTheme,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _startTime : _endTime,
      builder: _pickerTheme,
    );
    if (picked == null) return;
    setState(() => start ? _startTime = picked : _endTime = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.heavyImpact();
      AppSnackBar.error(context, 'Please fix the highlighted fields.');
      return;
    }

    final eventType = _eventType == 'Others' &&
            _customTypeController.text.trim().isNotEmpty
        ? _customTypeController.text.trim()
        : _eventType;

    final updated = widget.event.copyWith(
      title: _titleController.text.trim(),
      eventType: eventType,
      clientId: _clientId,
      clientName: _clientName,
      startsAt: DateTime(
        _date.year,
        _date.month,
        _date.day,
        _startTime.hour,
        _startTime.minute,
      ),
      startTime: _startTime.format(context),
      endTime: _endTime.format(context),
      location: _locationController.text.trim(),
      latitude: _eventLatitude,
      longitude: _eventLongitude,
      clearLocationCoordinates:
          _eventLatitude == null || _eventLongitude == null,
      totalAmount: double.parse(_amountController.text.trim()),
      status: _status,
      notes: _notesController.text.trim(),
    );

    setState(() => _saving = true);
    try {
      await context.read<EventsProvider>().updateEvent(updated);
      if (!mounted) return;
      AppSnackBar.success(context, 'Event updated.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(
        context,
        e is ApiException ? e.message : 'Could not update event.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final received = widget.event.amountReceived;
    AuthProvider? auth;
    try {
      auth = context.watch<AuthProvider>();
    } catch (_) {
      auth = null;
    }
    final currentUser = auth?.user;
    final studioLat = currentUser?.latitude;
    final studioLng = currentUser?.longitude;
    final studioName = (currentUser?.studioName.trim().isNotEmpty == true)
        ? currentUser!.studioName.trim()
        : ((currentUser?.city.trim().isNotEmpty == true)
            ? currentUser!.city.trim()
            : 'Studio');

    double? distanceKm;
    if (studioLat != null &&
        studioLng != null &&
        _eventLatitude != null &&
        _eventLongitude != null &&
        !studioLat.isNaN &&
        !studioLng.isNaN &&
        !_eventLatitude!.isNaN &&
        !_eventLongitude!.isNaN) {
      distanceKm = GeoDistanceUtils.calculateHaversineKm(
        studioLat,
        studioLng,
        _eventLatitude!,
        _eventLongitude!,
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            StudioAppBar(
              title: 'Edit Event',
              subtitle: widget.event.title,
              showNotificationBell: false,
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
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    _sectionHeader('Event Information'),
                    const SizedBox(height: 12),
                    StudioTextField(
                      label: 'Event Name',
                      controller: _titleController,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter an event name'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    _label('Event Category'),
                    const SizedBox(height: 10),
                    _buildTypeChips(),
                    if (_eventType == 'Others') ...[
                      const SizedBox(height: 10),
                      StudioTextField(
                        label: 'Specify Event Type',
                        controller: _customTypeController,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please specify the event type'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 22),
                    _sectionHeader('Client'),
                    const SizedBox(height: 12),
                    _buildClientTile(),
                    const SizedBox(height: 22),
                    _sectionHeader('Schedule & Venue'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _pickerTile(
                            icon: Icons.calendar_month_outlined,
                            title: 'Date',
                            value: DateFormat('d MMM yyyy').format(_date),
                            onTap: _pickDate,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _pickerTile(
                            icon: Icons.access_time_rounded,
                            title: 'Start',
                            value: _startTime.format(context),
                            onTap: () => _pickTime(start: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _pickerTile(
                            icon: Icons.access_time_filled_rounded,
                            title: 'End',
                            value: _endTime.format(context),
                            onTap: () => _pickTime(start: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    LocationSearchField(
                      label: 'Location / Venue',
                      controller: _locationController,
                      initialLatitude: _eventLatitude,
                      initialLongitude: _eventLongitude,
                      referenceLatitude: studioLat,
                      referenceLongitude: studioLng,
                      referenceLabel: studioName,
                      onLocationSelected: (place) {
                        setState(() {
                          _eventLatitude = place.latitude;
                          _eventLongitude = place.longitude;
                        });
                      },
                      onCoordinatesCleared: () {
                        setState(() {
                          _eventLatitude = null;
                          _eventLongitude = null;
                        });
                      },
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter a location'
                          : null,
                    ),
                    if (_eventLatitude != null && _eventLongitude != null)
                      _buildLocationDistanceCard(
                        context,
                        distanceKm: distanceKm,
                        studioName: studioName,
                        hasStudioCoords: studioLat != null && studioLng != null,
                      ),
                    const SizedBox(height: 22),
                    _sectionHeader('Financials'),
                    const SizedBox(height: 12),
                    StudioTextField(
                      label: 'Total Package (₹)',
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (v) {
                        final amount = double.tryParse(v?.trim() ?? '');
                        if (amount == null || amount < 0) {
                          return 'Enter a valid amount';
                        }
                        if (amount < received) {
                          return 'Cannot be less than ${_currency.format(received)} already received';
                        }
                        return null;
                      },
                    ),
                    if (received > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${_currency.format(received)} already received from payments.',
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    _sectionHeader('Status'),
                    const SizedBox(height: 12),
                    _buildStatusChips(),
                    const SizedBox(height: 22),
                    _sectionHeader('Notes'),
                    const SizedBox(height: 12),
                    StudioTextField(
                      label: 'Notes & Instructions',
                      hint: 'Shoot notes, client requirements...',
                      controller: _notesController,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 28),
                    StudioButton(
                      label: 'Save Changes',
                      onPressed: _saving ? null : _save,
                      isLoading: _saving,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: context.textMain,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Divider(
            color: context.cardBorder.withValues(alpha: 0.3),
            thickness: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: TextStyle(
        color: context.textMuted,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final accent = context.accentColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: context.isDark ? 0.24 : 0.14)
                : context.innerBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? accent : context.cardBorder,
              width: selected ? 1.6 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? (context.isDark ? Colors.white : accent)
                  : context.textMain,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final type in _eventTypes)
          _chip(
            label: type,
            selected: _eventType == type,
            onTap: () => setState(() => _eventType = type),
          ),
      ],
    );
  }

  Widget _buildStatusChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final status in EventStatus.values)
          _chip(
            label: status.label,
            selected: _status == status,
            onTap: () => setState(() => _status = status),
          ),
      ],
    );
  }

  Widget _pickerTile({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: context.accentColor, size: 14),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(color: context.textMuted, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.textMain,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientTile() {
    final accent = context.accentColor;
    final isDark = context.isDark;
    final name = _clientName.trim().isEmpty ? 'No client' : _clientName;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.35 : 0.25),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: accent.withValues(alpha: 0.2),
            child: Text(
              name[0].toUpperCase(),
              style: TextStyle(color: accent, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.textMain,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: _openClientPicker,
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _openClientPicker() {
    final clients = context.read<EventsProvider>().clients;
    showModalBottomSheet<Client>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var query = '';
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final q = query.trim().toLowerCase();
            final filtered = q.isEmpty
                ? clients
                : clients
                    .where((c) =>
                        c.name.toLowerCase().contains(q) || c.phone.contains(q))
                    .toList();
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: context.isDark ? const Color(0xFF16161E) : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.textMuted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: TextField(
                      onChanged: (v) => setSheetState(() => query = v),
                      decoration: InputDecoration(
                        hintText: 'Search by client name or phone...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: context.innerBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No clients found',
                              style: TextStyle(color: context.textMuted),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final client = filtered[i];
                              final selected = client.id == _clientId;
                              return ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                tileColor: context.innerBg,
                                leading: CircleAvatar(
                                  backgroundColor: context.accentColor
                                      .withValues(alpha: 0.2),
                                  child: Text(
                                    client.name.isNotEmpty
                                        ? client.name[0].toUpperCase()
                                        : 'C',
                                    style: TextStyle(
                                      color: context.accentColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  client.name,
                                  style: TextStyle(
                                    color: context.textMain,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  client.phone,
                                  style: TextStyle(color: context.textMuted),
                                ),
                                trailing: selected
                                    ? Icon(
                                        Icons.check_circle_rounded,
                                        color: context.accentColor,
                                      )
                                    : null,
                                onTap: () =>
                                    Navigator.of(sheetContext).pop(client),
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
    ).then((client) {
      if (client == null || !mounted) return;
      setState(() {
        _clientId = client.id;
        _clientName = client.name;
      });
    });
  }

  Widget _buildLocationDistanceCard(
    BuildContext context, {
    required double? distanceKm,
    required String studioName,
    required bool hasStudioCoords,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasCoords = _eventLatitude != null && _eventLongitude != null;
    if (!hasCoords && _locationController.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    String tierLabel;
    Color tierColor;
    IconData tierIcon;
    String estTime;

    if (distanceKm != null) {
      if (distanceKm < 0.5) {
        tierLabel = 'At Studio';
        tierColor = AppColors.pastelMint;
        tierIcon = Icons.home_work_rounded;
        estTime = 'Zero travel required';
      } else if (distanceKm < 2.5) {
        tierLabel = 'Same Locality (< 2.5 km)';
        tierColor = AppColors.pastelMint;
        tierIcon = Icons.directions_walk_rounded;
        estTime = '~5–10 mins travel';
      } else if (distanceKm < 25.0) {
        tierLabel = 'Local Coverage (< 25 km)';
        tierColor = AppColors.sky;
        tierIcon = Icons.directions_car_rounded;
        estTime = '~${(distanceKm * 2.2).clamp(10, 60).round()} mins drive';
      } else if (distanceKm < 60.0) {
        tierLabel = 'Extended Metro (< 60 km)';
        tierColor = Colors.orangeAccent;
        tierIcon = Icons.commute_rounded;
        estTime = '~${(distanceKm * 1.8).clamp(30, 120).round()} mins drive';
      } else {
        tierLabel = 'Outstation Shoot (> 60 km)';
        tierColor = Colors.purpleAccent;
        tierIcon = Icons.flight_takeoff_rounded;
        estTime = 'Outstation travel charges apply';
      }
    } else {
      tierLabel = hasCoords ? 'Location Locked' : 'Custom Location';
      tierColor = AppColors.sky;
      tierIcon = Icons.place_rounded;
      estTime = '';
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (distanceKm != null && distanceKm < 25
                  ? AppColors.pastelMint
                  : AppColors.sky)
              .withValues(alpha: isDark ? 0.35 : 0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(tierIcon, size: 18, color: tierColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (distanceKm != null) ...[
                      Row(
                        children: [
                          Text(
                            distanceKm < 0.5
                                ? 'In-Studio Shoot'
                                : '${distanceKm.toStringAsFixed(1)} km',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: context.textMain,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: tierColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tierLabel,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: tierColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        distanceKm < 0.5
                            ? 'Location matches your studio coordinates'
                            : 'Distance from $studioName • $estTime',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: context.textMuted,
                        ),
                      ),
                    ] else if (!hasStudioCoords) ...[
                      Text(
                        'Coordinates Locked',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.textMain,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Set your Studio address in Profile to calculate distance from studio.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: context.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (hasCoords) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (isDark ? Colors.black : Colors.grey.shade100)
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 13,
                    color: AppColors.pastelMint,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'GPS: ${_eventLatitude!.toStringAsFixed(4)}°, ${_eventLongitude!.toStringAsFixed(4)}° • Auto-synced for nearby photographer calculations',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        color: context.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
