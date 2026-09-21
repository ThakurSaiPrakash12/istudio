import '../models/invoice.dart';
import 'api_service.dart';

class InvoiceService {
  InvoiceService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  Future<List<Invoice>> list({required String token}) async {
    final payload = await _api.get('/invoices', token: token);
    final raw = payload['invoices'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Invoice.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Invoice> create({
    required String token,
    required Invoice invoice,
  }) async {
    final payload = await _api.post(
      '/invoices',
      {
        'eventName': invoice.eventName,
        'contactName': invoice.contactName,
        'phone': invoice.phone,
        'address': invoice.address,
        'issuedOn': invoice.issuedOn.toIso8601String(),
        'dueDate': invoice.dueDate.toIso8601String(),
        'deliverables': invoice.deliverables
            .map((item) => item.toJson())
            .toList(),
        'upiId': invoice.upiId,
        'amountReceived': invoice.amountReceived,
      },
      token: token,
      idempotencyKey: invoice.id,
    );
    return _readInvoice(payload);
  }

  Future<Invoice> markPaid({required String token, required String id}) async {
    final payload = await _api.post(
      '/invoices/$id/paid',
      const {},
      token: token,
      idempotencyKey: 'invoice:$id:paid',
    );
    return _readInvoice(payload);
  }

  Future<Invoice> markPartial({
    required String token,
    required String id,
    required double amount,
  }) async {
    final payload = await _api.post(
      '/invoices/$id/partial',
      {'amount': amount},
      token: token,
      idempotencyKey: 'invoice:$id:partial:$amount',
    );
    return _readInvoice(payload);
  }

  Future<Invoice> extendDueDate({
    required String token,
    required String id,
    required DateTime dueDate,
  }) async {
    final payload = await _api.patch('/invoices/$id/due-date', {
      'dueDate': dueDate.toIso8601String(),
    }, token: token);
    return _readInvoice(payload);
  }

  Future<void> delete({required String token, required String id}) async {
    await _api.delete('/invoices/$id', token: token);
  }

  Future<Invoice> update({
    required String token,
    required Invoice invoice,
  }) async {
    final payload = await _api.patch('/invoices/${invoice.id}', {
      'eventName': invoice.eventName,
      'contactName': invoice.contactName,
      'phone': invoice.phone,
      'address': invoice.address,
      'issuedOn': invoice.issuedOn.toIso8601String(),
      'dueDate': invoice.dueDate.toIso8601String(),
      'deliverables': invoice.deliverables
          .map((item) => item.toJson())
          .toList(),
      'upiId': invoice.upiId,
      'amountReceived': invoice.amountReceived,
    }, token: token);
    return _readInvoice(payload);
  }

  Invoice _readInvoice(Map<String, dynamic> payload) {
    final raw = payload['invoice'];
    if (raw is! Map) {
      throw const ApiException('Invoice could not be loaded.');
    }
    return Invoice.fromJson(Map<String, dynamic>.from(raw));
  }
}
