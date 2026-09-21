import '../models/client.dart';
import '../models/studio_event.dart';
import 'api_service.dart';

class BusinessService {
  BusinessService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  Future<List<Client>> listClients(String token) async {
    final payload = await _api.get('/clients', token: token);
    return _list(payload['clients']).map(Client.fromJson).toList();
  }

  Future<Client> createClient(String token, Client client) async {
    final payload = await _api.post('/clients', client.toJson(), token: token);
    return Client.fromJson(_map(payload['client']));
  }

  Future<Client> updateClient(String token, Client client) async {
    final payload = await _api.put(
      '/clients/${client.id}',
      client.toJson(),
      token: token,
    );
    return Client.fromJson(_map(payload['client']));
  }

  Future<void> deleteClient(String token, String id) async {
    await _api.delete('/clients/$id', token: token);
  }

  Future<List<StudioEvent>> listEvents(String token) async {
    final payload = await _api.get('/events', token: token);
    return _list(payload['events']).map(_eventFromJson).toList();
  }

  Future<StudioEvent> createEvent(String token, StudioEvent event) async {
    final payload = await _api.post(
      '/events',
      _eventPayload(event),
      token: token,
      idempotencyKey: event.id,
    );
    return _eventFromJson(_map(payload['event']));
  }

  Future<StudioEvent> updateEvent(String token, StudioEvent event) async {
    final payload = await _api.put(
      '/events/${event.id}',
      _eventPayload(event),
      token: token,
    );
    return _eventFromJson(_map(payload['event']));
  }

  Future<void> deleteEvent(String token, String id) async {
    await _api.delete('/events/$id', token: token);
  }

  Future<PaymentRecord> addPayment(
    String token,
    String eventId,
    PaymentRecord payment,
  ) async {
    final payload = await _api.post(
      '/events/$eventId/payments',
      _paymentPayload(payment),
      token: token,
      idempotencyKey: payment.id,
    );
    return PaymentRecord.fromJson(_map(payload['payment']));
  }

  Future<void> deletePayment(String token, String id) async {
    await _api.delete('/payments/$id', token: token);
  }

  Future<PaymentRecord> uploadPaymentProof(
    String token,
    String paymentId,
    List<int> bytes,
    String filename,
  ) async {
    final payload = await _api.postMultipart(
      '/payments/$paymentId/proof',
      fieldName: 'proof',
      bytes: bytes,
      filename: filename,
      token: token,
    );
    return PaymentRecord.fromJson(_map(payload['payment']));
  }

  Future<ExpenseRecord> addExpense(
    String token,
    String eventId,
    ExpenseRecord expense,
  ) async {
    final payload = await _api.post(
      '/events/$eventId/expenses',
      _expensePayload(expense),
      token: token,
      idempotencyKey: expense.id,
    );
    return ExpenseRecord.fromJson(_map(payload['expense']));
  }

  Future<void> deleteExpense(String token, String id) async {
    await _api.delete('/expenses/$id', token: token);
  }

  Future<DeliverableTask> updateDeliverable(
    String token,
    String id,
    bool completed,
  ) async {
    final payload = await _api.put('/deliverables/$id', {
      'isCompleted': completed,
    }, token: token);
    return DeliverableTask.fromJson(_map(payload['deliverable']));
  }

  Future<DeliverableTask> createDeliverable(
    String token,
    String eventId,
    DeliverableTask task,
  ) async {
    final payload = await _api.post(
      '/events/$eventId/deliverables',
      {
        'title': task.title,
        'stage': 'General',
        'isCompleted': task.isCompleted,
      },
      token: token,
      idempotencyKey: task.id,
    );
    return DeliverableTask.fromJson(_map(payload['deliverable']));
  }

  Map<String, dynamic> _eventPayload(StudioEvent event) => {
    'clientId': event.clientId,
    'title': event.title,
    'eventType': event.eventType,
    'startsAt': event.startsAt.toIso8601String(),
    'startTime': event.startTime,
    'endTime': event.endTime,
    'location': event.location,
    'status': event.status.name,
    'totalAmount': event.totalAmount,
    'notes': event.notes,
  };

  Map<String, dynamic> _paymentPayload(PaymentRecord payment) => {
    'title': payment.title,
    'amount': payment.amount,
    'paidAt': payment.paidAt.toIso8601String(),
    'method': payment.method.name,
    if (payment.reference != null && payment.reference!.isNotEmpty)
      'reference': payment.reference,
    if (payment.proof != null && payment.proof!.isNotEmpty)
      'proofUrl': payment.proof,
  };

  Map<String, dynamic> _expensePayload(ExpenseRecord expense) => {
    'title': expense.title,
    'amount': expense.amount,
    'category': expense.category,
    'incurredAt': expense.incurredAt.toIso8601String(),
  };

  StudioEvent _eventFromJson(Map<String, dynamic> json) {
    final payments = _list(
      json['payments'],
    ).map(PaymentRecord.fromJson).toList();
    final expenses = _list(
      json['expenses'],
    ).map(ExpenseRecord.fromJson).toList();
    final deliverables = _list(
      json['deliverables'],
    ).map(DeliverableTask.fromJson).toList();
    return StudioEvent(
      id: json['id'] as String? ?? '',
      clientId: json['clientId'] as String?,
      title: json['title'] as String? ?? '',
      clientName: json['clientName'] as String? ?? '',
      eventType: json['eventType'] as String? ?? '',
      startsAt:
          DateTime.tryParse(json['startsAt'] as String? ?? '') ??
          DateTime.now(),
      startTime: json['startTime'] as String? ?? '10:00 AM',
      endTime: json['endTime'] as String? ?? '04:00 PM',
      location: json['location'] as String? ?? '',
      status: EventStatus.values.firstWhere(
        (item) => item.name == json['status'],
        orElse: () => EventStatus.upcoming,
      ),
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      amountReceived: (json['amountReceived'] as num?)?.toDouble(),
      payments: payments,
      expenses: expenses,
      deliverables: deliverables,
      notes: json['notes'] as String? ?? '',
    );
  }

  List<Map<String, dynamic>> _list(dynamic value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
      : const [];

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const ApiException('The studio returned an invalid record.');
  }
}
