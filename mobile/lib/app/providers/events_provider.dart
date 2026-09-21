import 'package:flutter/foundation.dart';
import '../models/client.dart';
import '../models/studio_event.dart';
import '../services/business_service.dart';
import 'auth_provider.dart';

class EventsProvider extends ChangeNotifier {
  String? _userId;
  bool _loading = false;
  String? _token;
  bool _creatingEvent = false;
  bool _addingPayment = false;
  final BusinessService _service;

  EventsProvider({BusinessService? service})
    : _service = service ?? BusinessService();

  final List<Client> _clients = [];
  final List<StudioEvent> _events = [];

  List<Client> get clients => List.unmodifiable(_clients);
  List<StudioEvent> get events => List.unmodifiable(_events);
  bool get isLoading => _loading;

  void syncAuth(AuthProvider auth) {
    if (auth.isBootstrapping) return;
    final userId = auth.user?.id;
    final token = auth.token;
    if (userId == _userId && token == _token) return;
    _userId = userId;
    _token = token;
    _clients.clear();
    _events.clear();
    _loading = userId != null;
    notifyListeners();
    if (userId != null && token != null) _loadFromServer(token);
  }

  List<StudioEvent> get upcomingEvents {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _events
        .where(
          (e) =>
              e.status != EventStatus.completed &&
              e.status != EventStatus.cancelled &&
              !e.startsAt.isBefore(today),
        )
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  List<StudioEvent> get pastEvents {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _events
        .where(
          (e) =>
              e.status == EventStatus.completed || e.startsAt.isBefore(today),
        )
        .toList()
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
  }

  // ================= Event & Client Methods =================

  StudioEvent? findById(String id) {
    try {
      return _events.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  StudioEvent? getEventById(String id) => findById(id);

  Client? getClientById(String id) {
    try {
      return _clients.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  List<StudioEvent> getEventsForClient(String clientId, {String? clientName}) {
    return _events.where((e) {
      if (e.clientId != null && e.clientId == clientId) {
        return true;
      }
      if (clientName != null &&
          e.clientName.trim().toLowerCase() ==
              clientName.trim().toLowerCase()) {
        return true;
      }
      return false;
    }).toList()..sort((a, b) => b.startsAt.compareTo(a.startsAt));
  }

  List<PaymentRecord> getPaymentsForClient(
    String clientId, {
    String? clientName,
  }) {
    final clientEvents = getEventsForClient(clientId, clientName: clientName);
    final allPayments = <PaymentRecord>[];
    for (final event in clientEvents) {
      allPayments.addAll(event.payments);
    }
    allPayments.sort((a, b) => b.paidAt.compareTo(a.paidAt));
    return allPayments;
  }

  double getClientTotalValue(String clientId, {String? clientName}) {
    final clientEvents = getEventsForClient(clientId, clientName: clientName);
    return clientEvents.fold(0.0, (acc, e) => acc + e.totalAmount);
  }

  double getClientTotalReceived(String clientId, {String? clientName}) {
    final clientEvents = getEventsForClient(clientId, clientName: clientName);
    return clientEvents.fold(0.0, (acc, e) => acc + e.amountReceived);
  }

  double getClientTotalRemaining(String clientId, {String? clientName}) {
    final clientEvents = getEventsForClient(clientId, clientName: clientName);
    return clientEvents.fold(0.0, (acc, e) => acc + e.remainingAmount);
  }

  Future<Client> addClient(Client client) async {
    if (_token == null) {
      _clients.insert(0, client);
      notifyListeners();
      return client;
    }
    final created = await _service.createClient(_token!, client);
    _clients.insert(0, created);
    notifyListeners();
    return created;
  }

  Future<void> updateClient(Client client) async {
    final index = _clients.indexWhere((c) => c.id == client.id);
    if (index != -1) {
      final previousClient = _clients[index];
      final previousEvents = List<StudioEvent>.from(_events);
      _clients[index] = client;
      // Also update clientName in associated events if name changed
      for (int i = 0; i < _events.length; i++) {
        if (_events[i].clientId == client.id &&
            _events[i].clientName != client.name) {
          _events[i] = _events[i].copyWith(clientName: client.name);
        }
      }
      try {
        if (_token != null) {
          _clients[index] = await _service.updateClient(_token!, client);
        }
      } catch (_) {
        _clients[index] = previousClient;
        _events
          ..clear()
          ..addAll(previousEvents);
        notifyListeners();
        rethrow;
      }
      notifyListeners();
    }
  }

  Future<void> deleteClient(String id) async {
    if (_token != null) await _service.deleteClient(_token!, id);
    _clients.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  // ================= Event Methods =================

  StudioEvent? getById(String id) {
    try {
      return _events.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addEvent(StudioEvent event) async {
    if (_creatingEvent) return;
    _creatingEvent = true;
    try {
      if (_token == null) {
        _events.insert(0, event);
        notifyListeners();
        return;
      }
      final created = await _service.createEvent(_token!, event);
      _events.insert(0, created);
      try {
        for (final payment in event.payments) {
          await _service.addPayment(_token!, created.id, payment);
        }
        for (final task in event.deliverables) {
          await _service.createDeliverable(_token!, created.id, task);
        }
        final refreshed = (await _service.listEvents(
          _token!,
        )).firstWhere((item) => item.id == created.id, orElse: () => created);
        _events[_events.indexWhere((item) => item.id == created.id)] =
            refreshed;
        notifyListeners();
      } catch (_) {
        try {
          await _service.deleteEvent(_token!, created.id);
        } catch (_) {}
        _events.removeWhere((item) => item.id == created.id);
        notifyListeners();
        rethrow;
      }
    } finally {
      _creatingEvent = false;
    }
  }

  Future<void> updateEvent(StudioEvent event) async {
    final index = _events.indexWhere((e) => e.id == event.id);
    if (index != -1) {
      final previous = _events[index];
      _events[index] = event;
      try {
        if (_token != null) {
          _events[index] = await _service.updateEvent(_token!, event);
        }
      } catch (_) {
        _events[index] = previous;
        notifyListeners();
        rethrow;
      }
      notifyListeners();
    }
  }

  Future<void> deleteEvent(String id) async {
    if (_token != null) await _service.deleteEvent(_token!, id);
    _events.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  Future<void> addExpense(String eventId, ExpenseRecord expense) async {
    final index = _events.indexWhere((e) => e.id == eventId);
    if (index != -1) {
      final current = _events[index];
      final previous = current;
      final updatedExpenses = [...current.expenses, expense];
      _events[index] = current.copyWith(expenses: updatedExpenses);
      try {
        if (_token != null) {
          final saved = await _service.addExpense(_token!, eventId, expense);
          _events[index] = _events[index].copyWith(
            expenses: [
              ..._events[index].expenses.where((item) => item.id != expense.id),
              saved,
            ],
          );
        }
      } catch (_) {
        _events[index] = previous;
        notifyListeners();
        rethrow;
      }
      notifyListeners();
    }
  }

  Future<void> deleteExpense(String eventId, String expenseId) async {
    final index = _events.indexWhere((e) => e.id == eventId);
    if (index != -1) {
      final current = _events[index];
      final previous = current;
      final updatedExpenses = current.expenses
          .where((ex) => ex.id != expenseId)
          .toList();
      _events[index] = current.copyWith(expenses: updatedExpenses);
      try {
        if (_token != null) {
          await _service.deleteExpense(_token!, expenseId);
        }
      } catch (_) {
        _events[index] = previous;
        notifyListeners();
        rethrow;
      }
      notifyListeners();
    }
  }

  Future<PaymentRecord?> addPayment(
    String eventId,
    PaymentRecord payment,
  ) async {
    if (_addingPayment) return null;
    final index = _events.indexWhere((e) => e.id == eventId);
    if (index == -1) return null;

    _addingPayment = true;
    try {
      if (_token == null) {
        final current = _events[index];
        _events[index] = current.copyWith(
          payments: [...current.payments, payment],
        );
        notifyListeners();
        return payment;
      }

      final saved = await _service.addPayment(_token!, eventId, payment);
      final refreshed = (await _service.listEvents(_token!)).firstWhere(
        (item) => item.id == eventId,
        orElse: () => _events[index].copyWith(
          payments: [..._events[index].payments, saved],
        ),
      );
      _events[index] = refreshed;
      notifyListeners();
      return saved;
    } finally {
      _addingPayment = false;
    }
  }

  Future<void> uploadPaymentProof(
    String eventId,
    String paymentId,
    List<int> bytes,
    String filename,
  ) async {
    final index = _events.indexWhere((item) => item.id == eventId);
    if (index == -1 || _token == null) return;
    final saved = await _service.uploadPaymentProof(
      _token!,
      paymentId,
      bytes,
      filename,
    );
    _events[index] = _events[index].copyWith(
      payments: _events[index].payments
          .map((item) => item.id == paymentId ? saved : item)
          .toList(),
    );
    notifyListeners();
  }

  Future<void> toggleDeliverable(String eventId, String taskId) async {
    final index = _events.indexWhere((e) => e.id == eventId);
    if (index != -1) {
      final current = _events[index];
      final previous = current;
      final updatedDeliverables = current.deliverables.map((task) {
        if (task.id == taskId) {
          return task.copyWith(isCompleted: !task.isCompleted);
        }
        return task;
      }).toList();
      _events[index] = current.copyWith(deliverables: updatedDeliverables);
      try {
        if (_token != null) {
          final saved = await _service.updateDeliverable(
            _token!,
            taskId,
            updatedDeliverables
                .firstWhere((item) => item.id == taskId)
                .isCompleted,
          );
          _events[index] = _events[index].copyWith(
            deliverables: _events[index].deliverables
                .map((item) => item.id == taskId ? saved : item)
                .toList(),
          );
        }
      } catch (_) {
        _events[index] = previous;
        notifyListeners();
        rethrow;
      }
      notifyListeners();
    }
  }

  Future<void> _loadFromServer(String token) async {
    try {
      final clients = await _service.listClients(token);
      final events = await _service.listEvents(token);
      if (token != _token) return;
      _clients.addAll(clients);
      _events.addAll(events);
    } catch (_) {
      _clients.clear();
      _events.clear();
    } finally {
      if (token == _token) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /* Legacy seed data is intentionally disabled. Records must come from the
      authenticated user's user-scoped local store or backend. */
  /*

  void _initDefaultClients() {
    _clients.addAll([
      const Client(
        id: 'cli-1',
        name: 'Aanya Sharma',
        phone: '+91 98765 43210',
        email: 'aanya.sharma@example.com',
        address: 'Flat 402, Lotus Residency, Mumbai',
        notes:
            'Bride requested golden hour lawn portrait session. Drone clearance obtained.',
      ),
      const Client(
        id: 'cli-2',
        name: 'Meera Kapoor',
        phone: '+91 98234 56789',
        email: 'meera.kapoor@example.com',
        address: 'Villa 12, Green Meadows, Bengaluru',
        notes:
            'Maternity and lifestyle portrait client. Husband joins for studio sessions.',
      ),
      const Client(
        id: 'cli-3',
        name: 'Northwind Atelier',
        phone: '+91 91234 56780',
        email: 'campaigns@northwindatelier.com',
        address: '5th Floor, Trade Tower, Indiranagar, Bengaluru',
        notes:
            'Commercial luxury collection brand shoot. High-res TIFFs & color profiles required.',
      ),
      const Client(
        id: 'cli-4',
        name: 'The Iyer Family',
        phone: '+91 99887 76655',
        email: 'arjun.iyer@example.com',
        address: '18, Orchid Gardens, Pune',
        notes:
            'Family portraits and newborn photography. Requested handcrafted wooden album box.',
      ),
      const Client(
        id: 'cli-5',
        name: 'Aarav & Priya',
        phone: '+91 98111 22334',
        email: 'aarav.priya@example.com',
        address: '24 Palm Avenue, New Delhi',
        notes:
            'Wedding coverage delivered with 500 edited shots and Italian leather album.',
      ),
    ]);
  }

  void _initDefaultEvents() {
    final now = DateTime.now();

    _events.addAll([
      // 1. Upcoming Wedding (Client: Aanya Sharma / Aanya & Rohan)
      StudioEvent(
        id: 'evt-up-1',
        clientId: 'cli-1',
        title: 'Wedding — Aanya & Rohan',
        clientName: 'Aanya Sharma',
        eventType: 'Wedding',
        startsAt: DateTime(
          now.year,
          now.month,
          now.day,
        ).add(const Duration(days: 2)),
        startTime: '09:00 AM',
        endTime: '10:00 PM',
        location: 'Lotus Pavilion',
        status: EventStatus.upcoming,
        totalAmount: 110000,
        payments: [
          PaymentRecord(
            id: 'p-101',
            title: 'Advance Booking',
            amount: 50000,
            paidAt: now.subtract(const Duration(days: 20)),
            method: PaymentMethod.upi,
            reference: 'UPI/2026/LUMEN9042',
            proof: 'receipt_advance_aanya.jpg',
          ),
          PaymentRecord(
            id: 'p-102',
            title: 'Mid-term Milestone',
            amount: 30000,
            paidAt: now.subtract(const Duration(days: 5)),
            method: PaymentMethod.bankTransfer,
            reference: 'NEFT-HDFC-99382104',
            proof: 'neft_bank_slip_30k.pdf',
          ),
        ],
        expenses: [
          ExpenseRecord(
            id: 'ex-101',
            title: 'Second Shooter Advance',
            amount: 8000,
            category: 'Crew',
            incurredAt: now.subtract(const Duration(days: 4)),
          ),
          ExpenseRecord(
            id: 'ex-102',
            title: 'Memory Cards & Battery Rental',
            amount: 4500,
            category: 'Equipment',
            incurredAt: now.subtract(const Duration(days: 2)),
          ),
        ],
        deliverables: const [
          DeliverableTask(
            id: 't-1',
            title: 'Pre-event Consultation',
            isCompleted: true,
          ),
          DeliverableTask(
            id: 't-2',
            title: 'Gear Checklist & Crew Briefing',
            isCompleted: true,
          ),
          DeliverableTask(
            id: 't-3',
            title: 'Main Wedding Coverage',
            isCompleted: false,
          ),
          DeliverableTask(
            id: 't-4',
            title: 'Raw Files Dual Backup',
            isCompleted: false,
          ),
          DeliverableTask(
            id: 't-5',
            title: 'Client Selection Gallery',
            isCompleted: false,
          ),
          DeliverableTask(
            id: 't-6',
            title: 'High-Res Retouching',
            isCompleted: false,
          ),
          DeliverableTask(
            id: 't-7',
            title: 'Cinematic Highlights Reel',
            isCompleted: false,
          ),
          DeliverableTask(
            id: 't-8',
            title: 'Hardcover Album Delivery',
            isCompleted: false,
          ),
        ],
        notes:
            'Bride requested golden hour lawn portrait session. Drone clearance obtained for venue.',
      ),

      // 2. Upcoming Maternity Session (Client: Meera Kapoor)
      StudioEvent(
        id: 'evt-up-2',
        clientId: 'cli-2',
        title: 'Maternity Session — Meera',
        clientName: 'Meera Kapoor',
        eventType: 'Maternity',
        startsAt: DateTime(
          now.year,
          now.month,
          now.day,
        ).add(const Duration(days: 5)),
        startTime: '02:00 PM',
        endTime: '05:30 PM',
        location: 'Studio Floor B',
        status: EventStatus.upcoming,
        totalAmount: 40000,
        payments: [
          PaymentRecord(
            id: 'p-103',
            title: 'Advance Deposit',
            amount: 25000,
            paidAt: now.subtract(const Duration(days: 10)),
            method: PaymentMethod.upi,
            reference: 'UPI/MEERA/782103',
            proof: 'gpay_receipt_25000.png',
          ),
        ],
        expenses: [
          ExpenseRecord(
            id: 'ex-103',
            title: 'Studio Lighting Setup & Gaffer',
            amount: 3500,
            category: 'Studio',
            incurredAt: now.subtract(const Duration(days: 1)),
          ),
        ],
        deliverables: const [
          DeliverableTask(
            id: 't-201',
            title: 'Moodboard & Wardrobe Check',
            isCompleted: true,
          ),
          DeliverableTask(
            id: 't-202',
            title: 'Studio Session Execution',
            isCompleted: false,
          ),
          DeliverableTask(
            id: 't-203',
            title: 'Color Grading & Retouching',
            isCompleted: false,
          ),
          DeliverableTask(
            id: 't-204',
            title: 'Fine Art Prints Packaging',
            isCompleted: false,
          ),
        ],
        notes:
            'Requested neutral tones and soft fabric drapes. Husband will join for second half.',
      ),

      // 3. Upcoming Commercial Brand Campaign (Client: Northwind Atelier)
      StudioEvent(
        id: 'evt-up-3',
        clientId: 'cli-3',
        title: 'Brand Campaign — Northwind',
        clientName: 'Northwind Atelier',
        eventType: 'Commercial',
        startsAt: DateTime(
          now.year,
          now.month,
          now.day,
        ).add(const Duration(days: 8)),
        startTime: '11:00 AM',
        endTime: '07:00 PM',
        location: 'City Terrace & Studio',
        status: EventStatus.inProgress,
        totalAmount: 85000,
        payments: [
          PaymentRecord(
            id: 'p-104',
            title: 'Full Advance Agreement',
            amount: 85000,
            paidAt: now.subtract(const Duration(days: 14)),
            method: PaymentMethod.bankTransfer,
            reference: 'RTGS/NW/CORP/102938',
            proof: 'rtgs_transfer_northwind.pdf',
          ),
        ],
        expenses: [
          ExpenseRecord(
            id: 'ex-104',
            title: 'Stylist & Assistant',
            amount: 14000,
            category: 'Crew',
            incurredAt: now.subtract(const Duration(days: 3)),
          ),
          ExpenseRecord(
            id: 'ex-105',
            title: 'Location Permission Fee',
            amount: 6000,
            category: 'Location',
            incurredAt: now.subtract(const Duration(days: 2)),
          ),
        ],
        deliverables: const [
          DeliverableTask(
            id: 't-301',
            title: 'Lookbook Planning',
            isCompleted: true,
          ),
          DeliverableTask(
            id: 't-302',
            title: 'Model Casting & Fitting',
            isCompleted: true,
          ),
          DeliverableTask(
            id: 't-303',
            title: 'Lookbook Shoot',
            isCompleted: false,
          ),
          DeliverableTask(
            id: 't-304',
            title: 'Commercial Retouching & Delivery',
            isCompleted: false,
          ),
        ],
        notes:
            'Autumn luxury collection. Deliver deliverables on flash drive & private cloud.',
      ),

      // 4. Past Wedding (Client: Aarav & Priya)
      StudioEvent(
        id: 'evt-past-1',
        clientId: 'cli-5',
        title: 'Aarav & Priya — Wedding',
        clientName: 'Aarav & Priya',
        eventType: 'Wedding',
        startsAt: DateTime(2026, 8, 12, 10, 0),
        startTime: '10:00 AM',
        endTime: '11:30 PM',
        location: 'Lotus Pavilion',
        status: EventStatus.completed,
        totalAmount: 120000,
        payments: [
          PaymentRecord(
            id: 'p-201',
            title: 'Advance',
            amount: 50000,
            paidAt: DateTime(2026, 8, 1),
            method: PaymentMethod.upi,
            reference: 'UPI/AARAV/50K',
            proof: 'wedding_advance_slip.jpg',
          ),
          PaymentRecord(
            id: 'p-202',
            title: 'Second Payment',
            amount: 30000,
            paidAt: DateTime(2026, 8, 10),
            method: PaymentMethod.card,
            reference: 'POS-TXN-88471',
            proof: 'card_swipe_pos_30k.pdf',
          ),
          PaymentRecord(
            id: 'p-203',
            title: 'Final Payment',
            amount: 40000,
            paidAt: DateTime(2026, 8, 12),
            method: PaymentMethod.cash,
            reference: 'CASH-REC-1049',
          ),
        ],
        expenses: [
          ExpenseRecord(
            id: 'ex-201',
            title: 'Freelancer Photographer',
            amount: 15000,
            category: 'Crew',
            incurredAt: DateTime(2026, 8, 12),
          ),
          ExpenseRecord(
            id: 'ex-202',
            title: 'Travel',
            amount: 5000,
            category: 'Travel',
            incurredAt: DateTime(2026, 8, 12),
          ),
          ExpenseRecord(
            id: 'ex-203',
            title: 'Album Printing',
            amount: 12000,
            category: 'Printing',
            incurredAt: DateTime(2026, 8, 20),
          ),
          ExpenseRecord(
            id: 'ex-204',
            title: 'Equipment Rental',
            amount: 10000,
            category: 'Equipment',
            incurredAt: DateTime(2026, 8, 11),
          ),
        ],
        deliverables: const [
          DeliverableTask(
            id: 't-401',
            title: 'Event Photography',
            isCompleted: true,
          ),
          DeliverableTask(
            id: 't-402',
            title: 'Raw Files Backup',
            isCompleted: true,
          ),
          DeliverableTask(
            id: 't-403',
            title: 'Client Selection',
            isCompleted: true,
          ),
          DeliverableTask(
            id: 't-404',
            title: 'Photo Editing',
            isCompleted: true,
          ),
          DeliverableTask(
            id: 't-405',
            title: 'Video Editing',
            isCompleted: true,
          ),
          DeliverableTask(
            id: 't-406',
            title: 'Album Design',
            isCompleted: true,
          ),
          DeliverableTask(
            id: 't-407',
            title: 'Album Printing',
            isCompleted: true,
          ),
          DeliverableTask(
            id: 't-408',
            title: 'Final Delivery',
            isCompleted: true,
          ),
        ],
        notes:
            'Complete wedding coverage completed with 500 edited shots and a premium Italian leather album.',
      ),

      // 5. Past Maternity (Client: Meera Kapoor -> Second event for Meera Kapoor!)
      StudioEvent(
        id: 'evt-past-2',
        clientId: 'cli-2',
        title: 'Meera — Maternity Studio Shoot',
        clientName: 'Meera Kapoor',
        eventType: 'Maternity',
        startsAt: DateTime(2026, 8, 5, 14, 0),
        startTime: '02:00 PM',
        endTime: '05:00 PM',
        location: 'Studio Floor B',
        status: EventStatus.completed,
        totalAmount: 35000,
        payments: [
          PaymentRecord(
            id: 'p-301',
            title: 'Booking Deposit',
            amount: 15000,
            paidAt: DateTime(2026, 7, 20),
            method: PaymentMethod.upi,
            reference: 'UPI/MEERA/15000',
            proof: 'maternity_booking_receipt.png',
          ),
          PaymentRecord(
            id: 'p-302',
            title: 'Final Settlement',
            amount: 20000,
            paidAt: DateTime(2026, 8, 5),
            method: PaymentMethod.card,
            reference: 'POS-REC-77382',
            proof: 'card_receipt_20000.pdf',
          ),
        ],
        expenses: [
          ExpenseRecord(
            id: 'ex-301',
            title: 'Studio Rental & Props',
            amount: 5000,
            category: 'Studio',
            incurredAt: DateTime(2026, 8, 5),
          ),
        ],
        deliverables: const [
          DeliverableTask(
            id: 't-501',
            title: 'Studio Setup',
            isCompleted: true,
          ),
          DeliverableTask(
            id: 't-502',
            title: 'Portrait Session',
            isCompleted: true,
          ),
          DeliverableTask(
            id: 't-503',
            title: 'Editing & Retouching',
            isCompleted: true,
          ),
          DeliverableTask(
            id: 't-504',
            title: 'High-Res Digital Album Delivered',
            isCompleted: true,
          ),
        ],
        notes: 'Delivered 35 hand-retouched photos. Client gave 5-star review.',
      ),

      // 6. Past Newborn Session (Client: The Iyer Family)
      StudioEvent(
        id: 'evt-past-3',
        clientId: 'cli-4',
        title: 'Iyer Family — Newborn',
        clientName: 'The Iyer Family',
        eventType: 'Newborn',
        startsAt: DateTime(2026, 7, 22, 11, 0),
        startTime: '11:00 AM',
        endTime: '03:00 PM',
        location: 'Softbox Suite',
        status: EventStatus.completed,
        totalAmount: 30000,
        payments: [
          PaymentRecord(
            id: 'p-401',
            title: 'Advance Payment',
            amount: 15000,
            paidAt: DateTime(2026, 7, 10),
            method: PaymentMethod.upi,
            reference: 'UPI/IYER/ADV15K',
            proof: 'iyer_adv_receipt.jpg',
          ),
          PaymentRecord(
            id: 'p-402',
            title: 'Balance Payment',
            amount: 15000,
            paidAt: DateTime(2026, 7, 22),
            method: PaymentMethod.cash,
            reference: 'CASH-SETTLE-301',
          ),
        ],
        expenses: [
          ExpenseRecord(
            id: 'ex-401',
            title: 'Baby Wrap Props & Sanitization',
            amount: 2500,
            category: 'Props',
            incurredAt: DateTime(2026, 7, 21),
          ),
          ExpenseRecord(
            id: 'ex-402',
            title: 'Studio Heating Assistant',
            amount: 2000,
            category: 'Crew',
            incurredAt: DateTime(2026, 7, 22),
          ),
        ],
        deliverables: const [
          DeliverableTask(
            id: 't-601',
            title: 'Baby-safe Studio Setup',
            isCompleted: true,
          ),
          DeliverableTask(
            id: 't-602',
            title: 'Newborn Shoot Execution',
            isCompleted: true,
          ),
          DeliverableTask(
            id: 't-603',
            title: 'Photo Retouching',
            isCompleted: true,
          ),
          DeliverableTask(
            id: 't-604',
            title: 'Keepsake Box Handed Over',
            isCompleted: true,
          ),
        ],
        notes: 'Smooth shoot with 2-week-old baby. Client loved wooden prints.',
      ),
    ]);
  }
  */
}
