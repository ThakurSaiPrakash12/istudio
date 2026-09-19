import 'package:flutter/foundation.dart';
import '../models/client.dart';
import '../models/studio_event.dart';

class EventsProvider extends ChangeNotifier {
  EventsProvider() {
    _initDefaultClients();
    _initDefaultEvents();
  }

  final List<Client> _clients = [];
  final List<StudioEvent> _events = [];

  List<Client> get clients => List.unmodifiable(_clients);
  List<StudioEvent> get events => List.unmodifiable(_events);

  List<StudioEvent> get upcomingEvents {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _events
        .where((e) =>
            e.status != EventStatus.completed &&
            e.status != EventStatus.cancelled &&
            !e.startsAt.isBefore(today))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  List<StudioEvent> get pastEvents {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _events
        .where((e) =>
            e.status == EventStatus.completed ||
            e.startsAt.isBefore(today))
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
          e.clientName.trim().toLowerCase() == clientName.trim().toLowerCase()) {
        return true;
      }
      return false;
    }).toList()
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
  }

  List<PaymentRecord> getPaymentsForClient(String clientId, {String? clientName}) {
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

  void addClient(Client client) {
    _clients.insert(0, client);
    notifyListeners();
  }

  void updateClient(Client client) {
    final index = _clients.indexWhere((c) => c.id == client.id);
    if (index != -1) {
      _clients[index] = client;
      // Also update clientName in associated events if name changed
      for (int i = 0; i < _events.length; i++) {
        if (_events[i].clientId == client.id &&
            _events[i].clientName != client.name) {
          _events[i] = _events[i].copyWith(clientName: client.name);
        }
      }
      notifyListeners();
    }
  }

  void deleteClient(String id) {
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

  void addEvent(StudioEvent event) {
    _events.insert(0, event);
    notifyListeners();
  }

  void updateEvent(StudioEvent event) {
    final index = _events.indexWhere((e) => e.id == event.id);
    if (index != -1) {
      _events[index] = event;
      notifyListeners();
    }
  }

  void deleteEvent(String id) {
    _events.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  void addExpense(String eventId, ExpenseRecord expense) {
    final index = _events.indexWhere((e) => e.id == eventId);
    if (index != -1) {
      final current = _events[index];
      final updatedExpenses = [...current.expenses, expense];
      _events[index] = current.copyWith(expenses: updatedExpenses);
      notifyListeners();
    }
  }

  void deleteExpense(String eventId, String expenseId) {
    final index = _events.indexWhere((e) => e.id == eventId);
    if (index != -1) {
      final current = _events[index];
      final updatedExpenses =
          current.expenses.where((ex) => ex.id != expenseId).toList();
      _events[index] = current.copyWith(expenses: updatedExpenses);
      notifyListeners();
    }
  }

  void addPayment(String eventId, PaymentRecord payment) {
    final index = _events.indexWhere((e) => e.id == eventId);
    if (index != -1) {
      final current = _events[index];
      final updatedPayments = [...current.payments, payment];
      final newAmountReceived =
          updatedPayments.fold(0.0, (acc, p) => acc + p.amount);
      final newStatus = newAmountReceived >= current.totalAmount
          ? (current.status == EventStatus.paymentDue
              ? EventStatus.upcoming
              : current.status)
          : current.status;

      _events[index] = current.copyWith(
        payments: updatedPayments,
        amountReceived: newAmountReceived,
        status: newStatus,
      );
      notifyListeners();
    }
  }

  void toggleDeliverable(String eventId, String taskId) {
    final index = _events.indexWhere((e) => e.id == eventId);
    if (index != -1) {
      final current = _events[index];
      final updatedDeliverables = current.deliverables.map((task) {
        if (task.id == taskId) {
          return task.copyWith(isCompleted: !task.isCompleted);
        }
        return task;
      }).toList();
      _events[index] = current.copyWith(deliverables: updatedDeliverables);
      notifyListeners();
    }
  }

  // ================= Seed Data =================

  void _initDefaultClients() {
    _clients.addAll([
      const Client(
        id: 'cli-1',
        name: 'Aanya Sharma',
        phone: '+91 98765 43210',
        email: 'aanya.sharma@example.com',
        address: 'Flat 402, Lotus Residency, Mumbai',
        notes: 'Bride requested golden hour lawn portrait session. Drone clearance obtained.',
      ),
      const Client(
        id: 'cli-2',
        name: 'Meera Kapoor',
        phone: '+91 98234 56789',
        email: 'meera.kapoor@example.com',
        address: 'Villa 12, Green Meadows, Bengaluru',
        notes: 'Maternity and lifestyle portrait client. Husband joins for studio sessions.',
      ),
      const Client(
        id: 'cli-3',
        name: 'Northwind Atelier',
        phone: '+91 91234 56780',
        email: 'campaigns@northwindatelier.com',
        address: '5th Floor, Trade Tower, Indiranagar, Bengaluru',
        notes: 'Commercial luxury collection brand shoot. High-res TIFFs & color profiles required.',
      ),
      const Client(
        id: 'cli-4',
        name: 'The Iyer Family',
        phone: '+91 99887 76655',
        email: 'arjun.iyer@example.com',
        address: '18, Orchid Gardens, Pune',
        notes: 'Family portraits and newborn photography. Requested handcrafted wooden album box.',
      ),
      const Client(
        id: 'cli-5',
        name: 'Aarav & Priya',
        phone: '+91 98111 22334',
        email: 'aarav.priya@example.com',
        address: '24 Palm Avenue, New Delhi',
        notes: 'Wedding coverage delivered with 500 edited shots and Italian leather album.',
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
        startsAt: DateTime(now.year, now.month, now.day).add(const Duration(days: 2)),
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
          DeliverableTask(id: 't-1', title: 'Pre-event Consultation', isCompleted: true),
          DeliverableTask(id: 't-2', title: 'Gear Checklist & Crew Briefing', isCompleted: true),
          DeliverableTask(id: 't-3', title: 'Main Wedding Coverage', isCompleted: false),
          DeliverableTask(id: 't-4', title: 'Raw Files Dual Backup', isCompleted: false),
          DeliverableTask(id: 't-5', title: 'Client Selection Gallery', isCompleted: false),
          DeliverableTask(id: 't-6', title: 'High-Res Retouching', isCompleted: false),
          DeliverableTask(id: 't-7', title: 'Cinematic Highlights Reel', isCompleted: false),
          DeliverableTask(id: 't-8', title: 'Hardcover Album Delivery', isCompleted: false),
        ],
        notes: 'Bride requested golden hour lawn portrait session. Drone clearance obtained for venue.',
      ),

      // 2. Upcoming Maternity Session (Client: Meera Kapoor)
      StudioEvent(
        id: 'evt-up-2',
        clientId: 'cli-2',
        title: 'Maternity Session — Meera',
        clientName: 'Meera Kapoor',
        eventType: 'Maternity',
        startsAt: DateTime(now.year, now.month, now.day).add(const Duration(days: 5)),
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
          DeliverableTask(id: 't-201', title: 'Moodboard & Wardrobe Check', isCompleted: true),
          DeliverableTask(id: 't-202', title: 'Studio Session Execution', isCompleted: false),
          DeliverableTask(id: 't-203', title: 'Color Grading & Retouching', isCompleted: false),
          DeliverableTask(id: 't-204', title: 'Fine Art Prints Packaging', isCompleted: false),
        ],
        notes: 'Requested neutral tones and soft fabric drapes. Husband will join for second half.',
      ),

      // 3. Upcoming Commercial Brand Campaign (Client: Northwind Atelier)
      StudioEvent(
        id: 'evt-up-3',
        clientId: 'cli-3',
        title: 'Brand Campaign — Northwind',
        clientName: 'Northwind Atelier',
        eventType: 'Commercial',
        startsAt: DateTime(now.year, now.month, now.day).add(const Duration(days: 8)),
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
          DeliverableTask(id: 't-301', title: 'Lookbook Planning', isCompleted: true),
          DeliverableTask(id: 't-302', title: 'Model Casting & Fitting', isCompleted: true),
          DeliverableTask(id: 't-303', title: 'Lookbook Shoot', isCompleted: false),
          DeliverableTask(id: 't-304', title: 'Commercial Retouching & Delivery', isCompleted: false),
        ],
        notes: 'Autumn luxury collection. Deliver deliverables on flash drive & private cloud.',
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
          DeliverableTask(id: 't-401', title: 'Event Photography', isCompleted: true),
          DeliverableTask(id: 't-402', title: 'Raw Files Backup', isCompleted: true),
          DeliverableTask(id: 't-403', title: 'Client Selection', isCompleted: true),
          DeliverableTask(id: 't-404', title: 'Photo Editing', isCompleted: true),
          DeliverableTask(id: 't-405', title: 'Video Editing', isCompleted: true),
          DeliverableTask(id: 't-406', title: 'Album Design', isCompleted: true),
          DeliverableTask(id: 't-407', title: 'Album Printing', isCompleted: true),
          DeliverableTask(id: 't-408', title: 'Final Delivery', isCompleted: true),
        ],
        notes: 'Complete wedding coverage completed with 500 edited shots and a premium Italian leather album.',
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
          DeliverableTask(id: 't-501', title: 'Studio Setup', isCompleted: true),
          DeliverableTask(id: 't-502', title: 'Portrait Session', isCompleted: true),
          DeliverableTask(id: 't-503', title: 'Editing & Retouching', isCompleted: true),
          DeliverableTask(id: 't-504', title: 'High-Res Digital Album Delivered', isCompleted: true),
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
          DeliverableTask(id: 't-601', title: 'Baby-safe Studio Setup', isCompleted: true),
          DeliverableTask(id: 't-602', title: 'Newborn Shoot Execution', isCompleted: true),
          DeliverableTask(id: 't-603', title: 'Photo Retouching', isCompleted: true),
          DeliverableTask(id: 't-604', title: 'Keepsake Box Handed Over', isCompleted: true),
        ],
        notes: 'Smooth shoot with 2-week-old baby. Client loved wooden prints.',
      ),
    ]);
  }
}
