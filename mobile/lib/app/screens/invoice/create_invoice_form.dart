import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/invoice.dart';
import '../../models/studio_event.dart';
import '../../providers/events_provider.dart';
import '../../providers/invoices_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/validators.dart';
import '../../widgets/studio_button.dart';
import '../../widgets/studio_card.dart';
import '../../widgets/studio_text_field.dart';
import 'invoice_preview_screen.dart';
import 'invoice_sheets.dart';

class CreateInvoiceForm extends StatefulWidget {
  const CreateInvoiceForm({super.key, required this.onSaved});

  final ValueChanged<Invoice> onSaved;

  @override
  State<CreateInvoiceForm> createState() => CreateInvoiceFormState();
}

class CreateInvoiceFormState extends State<CreateInvoiceForm> {
  final _formKey = GlobalKey<FormState>();
  final _eventController = TextEditingController();
  final _contactController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _upiController = TextEditingController();

  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  final List<InvoiceDeliverable> _deliverables = [];
  bool _saving = false;

  static final _money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  double get _total =>
      _deliverables.fold(0, (sum, item) => sum + item.cost);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final lastUpi = context.read<InvoicesProvider>().lastUpiId;
      if (lastUpi.isNotEmpty && _upiController.text.isEmpty) {
        _upiController.text = lastUpi;
      }
    });
  }

  @override
  void dispose() {
    _eventController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  void resetForm() {
    _formKey.currentState?.reset();
    _eventController.clear();
    _contactController.clear();
    _phoneController.clear();
    _addressController.clear();
    setState(() {
      _deliverables.clear();
      _dueDate = DateTime.now().add(const Duration(days: 7));
    });
  }

  Invoice _buildInvoice() {
    final provider = context.read<InvoicesProvider>();
    return Invoice(
      id: 'inv-${DateTime.now().millisecondsSinceEpoch}',
      number: provider.nextNumber(),
      eventName: _eventController.text.trim(),
      contactName: _contactController.text.trim(),
      phone: Validators.normalizePhone(_phoneController.text),
      address: _addressController.text.trim(),
      issuedOn: DateTime.now(),
      dueDate: _dueDate,
      deliverables: List.unmodifiable(_deliverables),
      upiId: _upiController.text.trim(),
    );
  }

  bool _validate() {
    if (!_formKey.currentState!.validate()) return false;
    if (_deliverables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one item before continuing.'),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _preview() async {
    if (!_validate()) return;
    final saved = await InvoicePreviewScreen.open(
      context,
      invoice: _buildInvoice(),
      isDraft: true,
    );
    if (saved != null && mounted) {
      resetForm();
      widget.onSaved(saved);
    }
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _saving = true);
    try {
      final invoice = _buildInvoice();
      final provider = context.read<InvoicesProvider>();
      final saved = await provider.addInvoice(invoice);
      await provider.rememberUpi(saved.upiId);
      if (!mounted) return;
      resetForm();
      widget.onSaved(saved);
      await InvoicePreviewScreen.open(context, invoice: saved);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save receipt.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addOrEditDeliverable([InvoiceDeliverable? existing]) async {
    final result = await AddDeliverableSheet.show(
      context,
      existing: existing,
    );
    if (result == null) return;
    setState(() {
      final index = _deliverables.indexWhere((item) => item.id == result.id);
      if (index >= 0) {
        _deliverables[index] = result;
      } else {
        _deliverables.add(result);
      }
    });
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
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
      setState(() => _dueDate = picked);
    }
  }

  void _fillFromEvent(StudioEvent event) {
    final client = context.read<EventsProvider>().getClientById(
      event.clientId ?? '',
    );
    setState(() {
      _eventController.text = event.title;
      _contactController.text = event.clientName;
      if ((client?.phone ?? '').isNotEmpty) {
        _phoneController.text = client!.phone;
      }
      if ((client?.address ?? '').isNotEmpty) {
        _addressController.text = client!.address;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final events = context.watch<EventsProvider>().events;
    final textMain = context.textMain;
    final textMuted = context.textMuted;
    final accent = context.accentColor;

    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          130 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _sectionTitle(context, 'Client Details'),
          const SizedBox(height: 12),
          if (events.isNotEmpty) ...[
            Text(
              'From shoot',
              style: TextStyle(color: textMuted, fontSize: 13),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: events.length > 8 ? 8 : events.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final event = events[index];
                  return ActionChip(
                    label: Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => _fillFromEvent(event),
                    backgroundColor: context.cardBg,
                    side: BorderSide(color: context.cardBorder),
                    labelStyle: TextStyle(color: textMain, fontSize: 12),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
          ],
          StudioTextField(
            label: 'Shoot name',
            hint: 'e.g. Wedding — Aanya & Rohan',
            controller: _eventController,
            validator: (value) =>
                (value == null || value.trim().isEmpty)
                    ? 'Enter the shoot name'
                    : null,
          ),
          const SizedBox(height: 14),
          StudioTextField(
            label: 'Client name',
            hint: 'e.g. Aanya Sharma',
            controller: _contactController,
            validator: (value) =>
                (value == null || value.trim().isEmpty)
                    ? 'Enter the client name'
                    : null,
          ),
          const SizedBox(height: 14),
          StudioTextField(
            label: 'Phone number',
            hint: 'e.g. 9876543210',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            validator: Validators.phone,
          ),
          const SizedBox(height: 14),
          StudioTextField(
            label: 'Address',
            hint: 'Studio, venue, or billing address',
            controller: _addressController,
            maxLines: 3,
            textInputAction: TextInputAction.newline,
            validator: (value) =>
                (value == null || value.trim().isEmpty)
                    ? 'Enter a billing address'
                    : null,
          ),
          const SizedBox(height: 14),
          Text(
            'Due date',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: textMuted,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _pickDueDate,
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_rounded, color: accent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        DateFormat('EEEE, d MMM yyyy').format(_dueDate),
                        style: TextStyle(
                          color: textMain,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.expand_more_rounded, color: textMuted),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _sectionTitle(context, 'Items / Work')),
              Semantics(
                button: true,
                label: 'Add item',
                child: IconButton.filled(
                  tooltip: 'Add item',
                  onPressed: _addOrEditDeliverable,
                  style: IconButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.add_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_deliverables.isEmpty)
            StudioCard(
              child: Column(
                children: [
                  Icon(
                    Icons.photo_album_outlined,
                    color: textMuted.withValues(alpha: 0.7),
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No items added',
                    style: TextStyle(
                      color: textMain,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap + to add photo items or packages.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textMuted, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ..._deliverables.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: StudioCard(
                  padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                  onTap: () => _addOrEditDeliverable(item),
                  child: Row(
                    children: [
                      Icon(Icons.collections_outlined, color: accent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textMain,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _money.format(item.cost),
                        style: TextStyle(
                          color: textMain,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove ${item.name}',
                        onPressed: () {
                          setState(() {
                            _deliverables.removeWhere((d) => d.id == item.id);
                          });
                        },
                        icon: Icon(
                          Icons.close_rounded,
                          color: textMuted,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 16),
          _sectionTitle(context, 'Bill Summary'),
          const SizedBox(height: 12),
          StudioCard(
            child: Column(
              children: [
                _summaryRow(context, 'Items', '${_deliverables.length}'),
                const SizedBox(height: 10),
                _summaryRow(
                  context,
                  'Total Amount',
                  _money.format(_total),
                  emphasize: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Payment (UPI)'),
          const SizedBox(height: 12),
          StudioTextField(
            label: 'UPI ID',
            hint: 'e.g. lumenstudio@okaxis',
            controller: _upiController,
            prefixIcon: Icons.qr_code_2_rounded,
            textInputAction: TextInputAction.done,
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) return null;
              if (!trimmed.contains('@') || trimmed.length < 5) {
                return 'Enter a valid UPI ID';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _saving ? null : _preview,
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Check Receipt'),
            style: OutlinedButton.styleFrom(
              foregroundColor: textMain,
              side: BorderSide(color: context.cardBorder),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          StudioButton(
            label: 'Save & Share Receipt',
            isLoading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
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
            color: context.cardBorder.withValues(alpha: 0.35),
            thickness: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(
    BuildContext context,
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: emphasize ? context.textMain : context.textMuted,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: emphasize ? context.accentColor : context.textMain,
            fontWeight: FontWeight.w700,
            fontSize: emphasize ? 18 : 14,
          ),
        ),
      ],
    );
  }
}
