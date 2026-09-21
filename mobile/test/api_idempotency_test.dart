import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lumen_studio/app/models/invoice.dart';
import 'package:lumen_studio/app/models/studio_event.dart';
import 'package:lumen_studio/app/services/api_service.dart';
import 'package:lumen_studio/app/services/business_service.dart';
import 'package:lumen_studio/app/services/invoice_service.dart';

class _RecordingClient extends http.BaseClient {
  final requests = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final response = request.url.path.endsWith('/invoices')
        ? {'invoice': _invoiceJson()}
        : request.url.path.contains('/invoices/')
        ? {'invoice': _invoiceJson()}
        : request.url.path.endsWith('/events')
        ? {'event': _eventJson()}
        : request.url.path.contains('/payments')
        ? {'payment': _paymentJson()}
        : request.url.path.contains('/expenses')
        ? {'expense': _expenseJson()}
        : {'deliverable': _deliverableJson()};
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(response))),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }

  static Map<String, dynamic> _invoiceJson() => {
    'id': 'invoice-1',
    'number': 'INV-1001',
    'eventName': 'Event',
    'contactName': 'Client',
    'phone': '9000000000',
    'address': 'Address',
    'issuedOn': '2030-01-01T00:00:00Z',
    'dueDate': '2030-02-01T00:00:00Z',
    'deliverables': [
      {'id': 'd-1', 'name': 'Coverage', 'cost': 100},
    ],
  };

  static Map<String, dynamic> _eventJson() => {
    'id': 'event-1',
    'title': 'Event',
    'eventType': 'Wedding',
    'startsAt': '2030-01-01T10:00:00Z',
    'location': 'Studio',
    'status': 'upcoming',
    'totalAmount': 100,
    'payments': [],
    'expenses': [],
    'deliverables': [],
  };

  static Map<String, dynamic> _paymentJson() => {
    'id': 'payment-1',
    'title': 'Payment',
    'amount': 10,
    'paidAt': '2030-01-01T10:00:00Z',
    'method': 'upi',
  };

  static Map<String, dynamic> _expenseJson() => {
    'id': 'expense-1',
    'title': 'Expense',
    'amount': 1,
    'category': 'Travel',
    'incurredAt': '2030-01-01T10:00:00Z',
  };

  static Map<String, dynamic> _deliverableJson() => {
    'id': 'deliverable-1',
    'title': 'Edit',
    'isCompleted': false,
  };
}

void main() {
  test('all dangerous mutation calls send stable idempotency keys', () async {
    final client = _RecordingClient();
    final api = ApiService(client: client);
    final business = BusinessService(api: api);
    final invoices = InvoiceService(api: api);
    final event = StudioEvent(
      id: 'event-key',
      title: 'Event',
      eventType: 'Wedding',
      clientName: 'Client',
      startsAt: DateTime(2030, 1, 1),
      location: 'Studio',
      status: EventStatus.upcoming,
      totalAmount: 100,
    );
    final payment = PaymentRecord(
      id: 'payment-key',
      title: 'Payment',
      amount: 10,
      paidAt: DateTime(2030, 1, 1),
    );
    final expense = ExpenseRecord(
      id: 'expense-key',
      title: 'Expense',
      amount: 1,
      category: 'Travel',
      incurredAt: DateTime(2030, 1, 1),
    );
    const deliverable = DeliverableTask(id: 'deliverable-key', title: 'Edit');
    final invoice = Invoice(
      id: 'invoice-key',
      number: '',
      eventName: 'Event',
      contactName: 'Client',
      phone: '9000000000',
      address: 'Address',
      issuedOn: DateTime(2030, 1, 1),
      dueDate: DateTime(2030, 2, 1),
      deliverables: [
        InvoiceDeliverable(id: 'd-1', name: 'Coverage', cost: 100),
      ],
    );

    await business.createEvent('token', event);
    await business.createEvent('token', event);
    await business.addPayment('token', 'event-1', payment);
    await business.addPayment('token', 'event-1', payment);
    await business.addExpense('token', 'event-1', expense);
    await business.createDeliverable('token', 'event-1', deliverable);
    await invoices.create(token: 'token', invoice: invoice);
    await invoices.markPartial(token: 'token', id: 'invoice-1', amount: 10);
    await invoices.markPartial(token: 'token', id: 'invoice-1', amount: 10);
    await invoices.markPaid(token: 'token', id: 'invoice-1');
    await invoices.markPaid(token: 'token', id: 'invoice-1');

    final keys = client.requests
        .map((request) => request.headers['Idempotency-Key'])
        .toList();
    expect(
      keys,
      containsAllInOrder([
        'event-key',
        'event-key',
        'payment-key',
        'payment-key',
        'expense-key',
        'deliverable-key',
        'invoice-key',
        'invoice:invoice-1:partial:10.0',
        'invoice:invoice-1:partial:10.0',
        'invoice:invoice-1:paid',
        'invoice:invoice-1:paid',
      ]),
    );
  });
}

Matcher containsAllInOrder(List<String> expected) =>
    _ContainsAllInOrder(expected);

class _ContainsAllInOrder extends Matcher {
  _ContainsAllInOrder(this.expected);
  final List<String> expected;

  @override
  bool matches(dynamic item, Map matchState) {
    if (item is! Iterable) return false;
    final values = item.whereType<String>().toList();
    var offset = 0;
    for (final value in expected) {
      final index = values.indexOf(value, offset);
      if (index == -1) return false;
      offset = index + 1;
    }
    return true;
  }

  @override
  Description describe(Description description) =>
      description.add('contains expected keys in order');

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) => mismatchDescription.add('keys were $item');
}
