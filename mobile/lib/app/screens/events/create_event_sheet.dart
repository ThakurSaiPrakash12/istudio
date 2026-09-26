import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/client.dart';
import '../../models/studio_event.dart';
import '../../providers/events_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/studio_button.dart';
import '../../widgets/studio_text_field.dart';

class CreateEventSheet extends StatefulWidget {
  final Client? initialClient;

  const CreateEventSheet({
    super.key,
    this.initialClient,
  });

  static Future<void> show(BuildContext context, {Client? initialClient}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => CreateEventSheet(initialClient: initialClient),
    );
  }

  @override
  State<CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends State<CreateEventSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  Client? _selectedClient;

  final _nameController = TextEditingController();
  final _clientController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _advanceController = TextEditingController();
  final _customEventTypeController = TextEditingController();

  String _eventType = 'Wedding';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 3));
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);

  double _totalAmount = 0;
  double _advanceReceived = 0;

  static final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  final List<String> _eventTypes = [
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

  @override
  void initState() {
    super.initState();
    if (widget.initialClient != null) {
      _selectedClient = widget.initialClient;
      _clientController.text = widget.initialClient!.name;
      _phoneController.text = widget.initialClient!.phone;
    }
    _totalAmountController.addListener(_onAmountChanged);
    _advanceController.addListener(_onAmountChanged);
    _clientController.addListener(_onClientNameChanged);
  }

  @override
  void dispose() {
    _totalAmountController.removeListener(_onAmountChanged);
    _advanceController.removeListener(_onAmountChanged);
    _clientController.removeListener(_onClientNameChanged);
    _nameController.dispose();
    _clientController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _totalAmountController.dispose();
    _advanceController.dispose();
    _customEventTypeController.dispose();
    super.dispose();
  }

  void _onClientNameChanged() {
    final name = _clientController.text.trim();
    if (name.isNotEmpty) {
      final provider = context.read<EventsProvider>();
      final match = provider.clients.firstWhere(
        (c) => c.name.toLowerCase() == name.toLowerCase(),
        orElse: () => const Client(id: '', name: '', phone: '', email: ''),
      );
      if (match.id.isNotEmpty &&
          match.phone.isNotEmpty &&
          _phoneController.text.isEmpty) {
        _phoneController.text = match.phone;
      }
    }
  }

  void _onAmountChanged() {
    setState(() {
      _totalAmount = double.tryParse(_totalAmountController.text.trim()) ?? 0;
      _advanceReceived = double.tryParse(_advanceController.text.trim()) ?? 0;
    });
  }

  double get _remainingAmount =>
      (_totalAmount - _advanceReceived).clamp(0.0, double.infinity);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
      builder: (context, child) {
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
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (context, child) {
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
      },
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      builder: (context, child) {
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
      },
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final startsAt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );
      final formattedStartTime = _startTime.format(context);
      final formattedEndTime = _endTime.format(context);

      final payments = <PaymentRecord>[];
      if (_advanceReceived > 0) {
        payments.add(
          PaymentRecord(
            id: 'pay-${DateTime.now().millisecondsSinceEpoch}',
            title: 'Advance Received',
            amount: _advanceReceived,
            paidAt: DateTime.now(),
            method: PaymentMethod.upi,
          ),
        );
      }

      final provider = context.read<EventsProvider>();

      String matchedClientId = '';
      String clientName = '';

      if (_selectedClient != null) {
        matchedClientId = _selectedClient!.id;
        clientName = _selectedClient!.name;

        // If client was in 'information' stage, auto-promote to 'comingUp'
        if (_selectedClient!.status == ClientStatus.information) {
          final updated = _selectedClient!.copyWith(status: ClientStatus.comingUp);
          provider.updateClient(updated);
        }
      } else {
        clientName = _clientController.text.trim();
        final clientPhone = _phoneController.text.trim();

        final existing = provider.clients.firstWhere(
          (c) => c.name.toLowerCase() == clientName.toLowerCase(),
          orElse: () => const Client(id: '', name: '', phone: '', email: ''),
        );

        if (existing.id.isNotEmpty) {
          matchedClientId = existing.id;
          if (existing.status == ClientStatus.information) {
            provider.updateClient(existing.copyWith(status: ClientStatus.comingUp));
          }
        } else {
          final newClient = Client(
            id: 'cli-${DateTime.now().millisecondsSinceEpoch}',
            name: clientName,
            phone: clientPhone,
            email: '',
            status: ClientStatus.comingUp,
            createdAt: DateTime.now(),
          );
          final createdClient = await provider.addClient(newClient);
          matchedClientId = createdClient.id;
        }
      }

      final effectiveEventType =
          (_eventType == 'Others' &&
              _customEventTypeController.text.trim().isNotEmpty)
          ? _customEventTypeController.text.trim()
          : _eventType;

      final newEvent = StudioEvent(
        id: 'evt-${DateTime.now().millisecondsSinceEpoch}',
        title: _nameController.text.trim(),
        eventType: effectiveEventType,
        clientId: matchedClientId,
        clientName: clientName,
        status: EventStatus.upcoming,
        location: _locationController.text.trim().isEmpty
            ? 'Studio / On Location'
            : _locationController.text.trim(),
        startsAt: startsAt,
        startTime: formattedStartTime,
        endTime: formattedEndTime,
        totalAmount: _totalAmount,
        payments: payments,
        notes: _notesController.text.trim(),
        deliverables: const [
          DeliverableTask(
            id: 't-1',
            title: 'Consultation & Moodboard',
            isCompleted: true,
          ),
          DeliverableTask(
            id: 't-2',
            title: 'Shoot Execution',
            isCompleted: false,
          ),
          DeliverableTask(
            id: 't-3',
            title: 'Backup & Selection',
            isCompleted: false,
          ),
          DeliverableTask(
            id: 't-4',
            title: 'Editing & Retouching',
            isCompleted: false,
          ),
          DeliverableTask(
            id: 't-5',
            title: 'Final Delivery',
            isCompleted: false,
          ),
        ],
      );

      await provider.addEvent(newEvent);
      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Event "${newEvent.title}" added to schedule.')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
          height: MediaQuery.of(context).size.height * 0.88,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xF5121622) : const Color(0xF8FFFFFF),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: AppColors.sky.withValues(alpha: isDark ? 0.28 : 0.18),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.65 : 0.18),
                blurRadius: 36,
                offset: const Offset(0, -8),
              ),
              BoxShadow(
                color: AppColors.sky.withValues(alpha: isDark ? 0.12 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create New Event',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: textMain,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Record shoot details & package financials',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textMuted, fontSize: 13),
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
          ),
          Divider(color: context.cardBorder.withValues(alpha: 0.3), height: 1),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  // SECTION 1: Event Information
                  _buildSectionHeader(context, 'Event Information'),
                  const SizedBox(height: 12),
                  StudioTextField(
                    label: 'Event Name',
                    hint: 'e.g. Wedding — Client Name',
                    controller: _nameController,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter an event name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Event Category / Type',
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 14,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _eventTypes.map((type) {
                      final selected = _eventType == type;
                      return ChoiceChip(
                        label: Text(type),
                        selected: selected,
                        onSelected: (val) {
                          if (val) setState(() => _eventType = type);
                        },
                        selectedColor: accent.withValues(alpha: 0.28),
                        backgroundColor: context.cardBg,
                        side: BorderSide(
                          color: selected
                              ? accent
                              : context.cardBorder.withValues(alpha: 0.4),
                        ),
                        labelStyle: TextStyle(
                          color: selected ? accent : textMain,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      );
                    }).toList(),
                  ),
                  if (_eventType == 'Others') ...[
                    const SizedBox(height: 10),
                    StudioTextField(
                      label: 'Specify Event Type *',
                      hint: 'e.g. Housewarming, Anniversary, Corporate Gala',
                      controller: _customEventTypeController,
                      validator: (val) {
                        if (_eventType == 'Others' &&
                            (val == null || val.trim().isEmpty)) {
                          return 'Please specify the event type';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 18),
                  // Client Assignment Section
                  _buildSectionHeader(context, 'Client Assignment'),
                  const SizedBox(height: 12),
                  if (_selectedClient != null) ...[
                    Container(
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
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accent.withValues(alpha: 0.4),
                                  context.cardBorder,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _selectedClient!.name.isNotEmpty
                                  ? _selectedClient!.name[0].toUpperCase()
                                  : 'C',
                              style: TextStyle(
                                color: textMain,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _selectedClient!.name,
                                        style: TextStyle(
                                          color: textMain,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    _buildStatusPill(_selectedClient!.status, isDark),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedClient!.phone,
                                  style: TextStyle(
                                    color: textMuted,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => _openClientPicker(context),
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.person_search_rounded, size: 18),
                      label: const Text('Select Existing Client Profile'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => _openClientPicker(context),
                    ),
                    const SizedBox(height: 12),
                    StudioTextField(
                      label: 'Client Name *',
                      hint: 'e.g. Client Name',
                      controller: _clientController,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter the client name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    StudioTextField(
                      label: 'Client Phone Number *',
                      hint: 'e.g. 9876543210',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter client phone number';
                        }
                        final digitsOnly = val.replaceAll(RegExp(r'\D'), '');
                        if (digitsOnly.length < 10) {
                          return 'Phone number must be at least 10 digits';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 14),
                  // Date & Time selection row
                  Row(
                    children: [
                      Expanded(
                        child: _buildPickerTile(
                          context,
                          icon: Icons.calendar_month_outlined,
                          title: 'Date',
                          value: DateFormat('d MMM yyyy').format(_selectedDate),
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPickerTile(
                          context,
                          icon: Icons.access_time_rounded,
                          title: 'Start',
                          value: _startTime.format(context),
                          onTap: _pickStartTime,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPickerTile(
                          context,
                          icon: Icons.access_time_rounded,
                          title: 'End',
                          value: _endTime.format(context),
                          onTap: _pickEndTime,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  StudioTextField(
                    label: 'Location / Venue',
                    hint: 'e.g. Grand Ballroom, City Hotel',
                    controller: _locationController,
                  ),
                  const SizedBox(height: 14),
                  StudioTextField(
                    label: 'Notes / Special Requests',
                    hint: 'e.g. Golden hour preference, 2 traditional outfits',
                    controller: _notesController,
                  ),
                  const SizedBox(height: 24),

                  // SECTION 2: Financial Information
                  _buildSectionHeader(context, 'Financial Information'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: StudioTextField(
                          label: 'Total Package (₹)',
                          hint: 'e.g. 100000',
                          controller: _totalAmountController,
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Enter total package amount';
                            }
                            if (double.tryParse(val.trim()) == null) {
                              return 'Invalid amount';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StudioTextField(
                          label: 'Advance Received (₹)',
                          hint: 'e.g. 30000',
                          controller: _advanceController,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Automated Remaining Calculation Card
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _remainingAmount > 0
                            ? accent.withValues(alpha: 0.6)
                            : accent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Remaining Balance',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_currency.format(_totalAmount)} \u2212 ${_currency.format(_advanceReceived)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _currency.format(_remainingAmount),
                            style: TextStyle(
                              color: accent,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Save Button
                  StudioButton(
                    label: 'Create Event',
                    onPressed: _isSubmitting ? null : _submit,
                    isLoading: _isSubmitting,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
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

  Widget _buildPickerTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    final accent = context.accentColor;
    final textMain = context.textMain;
    final textMuted = context.textMuted;

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
                Icon(icon, color: accent, size: 14),
                const SizedBox(width: 4),
                Text(title, style: TextStyle(color: textMuted, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: textMain,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _openClientPicker(BuildContext context) {
    final provider = context.read<EventsProvider>();
    final clients = provider.clients;
    final isDark = context.isDark;
    final textMain = context.textMain;
    final textMuted = context.textMuted;
    final accent = context.accentColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (pickerContext) {
        String query = '';
        return StatefulBuilder(
          builder: (pickerContext, setModalState) {
            final filtered = query.trim().isEmpty
                ? clients
                : clients.where((c) {
                    final q = query.toLowerCase();
                    return c.name.toLowerCase().contains(q) ||
                        c.phone.contains(q);
                  }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16161E) : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: textMuted.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Select Client for Event',
                            style: GoogleFonts.plusJakartaSans(
                              color: textMain,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: textMuted),
                          onPressed: () => Navigator.of(pickerContext).pop(),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      autofocus: false,
                      onChanged: (val) => setModalState(() => query = val),
                      decoration: InputDecoration(
                        hintText: 'Search by client name or phone...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: context.innerBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              query.isEmpty
                                  ? 'No clients found'
                                  : 'No clients match "$query"',
                              style: TextStyle(color: textMuted),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final client = filtered[index];
                              final clientEvents =
                                  provider.getEventsForClient(client.id,
                                      clientName: client.name);
                              final eventCount = clientEvents.length;

                              return InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  setState(() {
                                    _selectedClient = client;
                                    _clientController.text = client.name;
                                    _phoneController.text = client.phone;
                                  });
                                  Navigator.of(pickerContext).pop();
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: context.innerBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: context.cardBorder
                                          .withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor:
                                            accent.withValues(alpha: 0.2),
                                        child: Text(
                                          client.name.isNotEmpty
                                              ? client.name[0].toUpperCase()
                                              : 'C',
                                          style: TextStyle(
                                            color: accent,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
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
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                _buildStatusPill(
                                                    client.status, isDark),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${client.phone} • $eventCount ${eventCount == 1 ? 'event' : 'events'}',
                                              style: TextStyle(
                                                color: textMuted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: const Text('Add as New Client Instead'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedClient = null;
                        });
                        Navigator.of(pickerContext).pop();
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
