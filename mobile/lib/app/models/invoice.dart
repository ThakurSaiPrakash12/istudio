import 'package:flutter/foundation.dart';

enum InvoiceStatus { paid, pending, partial, overdue }

enum InvoiceFilter {
  all,
  paid,
  pending,
  partial,
  overdue;

  String get label => switch (this) {
    InvoiceFilter.all => 'All',
    InvoiceFilter.paid => 'Paid',
    InvoiceFilter.pending => 'Pending',
    InvoiceFilter.partial => 'Part Paid',
    InvoiceFilter.overdue => 'Late',
  };
}

@immutable
class InvoiceDeliverable {
  const InvoiceDeliverable({
    required this.id,
    required this.name,
    required this.cost,
  });

  final String id;
  final String name;
  final double cost;

  InvoiceDeliverable copyWith({String? name, double? cost}) {
    return InvoiceDeliverable(
      id: id,
      name: name ?? this.name,
      cost: cost ?? this.cost,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'cost': cost};

  factory InvoiceDeliverable.fromJson(Map<String, dynamic> json) {
    return InvoiceDeliverable(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      cost: (json['cost'] as num?)?.toDouble() ?? 0,
    );
  }
}

@immutable
class Invoice {
  const Invoice({
    required this.id,
    required this.number,
    required this.eventName,
    required this.contactName,
    required this.phone,
    required this.address,
    required this.issuedOn,
    required this.dueDate,
    required this.deliverables,
    this.upiId = '',
    this.amountReceived = 0,
  });

  final String id;
  final String number;
  final String eventName;
  final String contactName;
  final String phone;
  final String address;
  final DateTime issuedOn;
  final DateTime dueDate;
  final List<InvoiceDeliverable> deliverables;
  final String upiId;
  final double amountReceived;

  double get total =>
      deliverables.fold(0, (sum, item) => sum + item.cost);

  double get pendingAmount {
    final value = total - amountReceived;
    return value < 0.01 ? 0 : value;
  }

  bool get isPaid => pendingAmount <= 0;

  bool get isPartiallyPaid => amountReceived > 0.009 && pendingAmount > 0;

  bool get isOverdue {
    if (isPaid) return false;
    final dueEnd = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
      23,
      59,
      59,
    );
    return DateTime.now().isAfter(dueEnd);
  }

  InvoiceStatus get status {
    if (isPaid) return InvoiceStatus.paid;
    if (isOverdue) return InvoiceStatus.overdue;
    if (isPartiallyPaid) return InvoiceStatus.partial;
    return InvoiceStatus.pending;
  }

  String get statusLabel => switch (status) {
    InvoiceStatus.paid => 'Paid ✓',
    InvoiceStatus.pending => 'Pending',
    InvoiceStatus.partial => 'Part Paid',
    InvoiceStatus.overdue => 'Late',
  };

  Invoice copyWith({
    String? id,
    String? number,
    String? eventName,
    String? contactName,
    String? phone,
    String? address,
    DateTime? issuedOn,
    DateTime? dueDate,
    List<InvoiceDeliverable>? deliverables,
    String? upiId,
    double? amountReceived,
  }) {
    return Invoice(
      id: id ?? this.id,
      number: number ?? this.number,
      eventName: eventName ?? this.eventName,
      contactName: contactName ?? this.contactName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      issuedOn: issuedOn ?? this.issuedOn,
      dueDate: dueDate ?? this.dueDate,
      deliverables: deliverables ?? this.deliverables,
      upiId: upiId ?? this.upiId,
      amountReceived: amountReceived ?? this.amountReceived,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'eventName': eventName,
    'contactName': contactName,
    'phone': phone,
    'address': address,
    'issuedOn': issuedOn.toIso8601String(),
    'dueDate': dueDate.toIso8601String(),
    'deliverables': deliverables.map((item) => item.toJson()).toList(),
    'upiId': upiId,
    'amountReceived': amountReceived,
  };

  factory Invoice.fromJson(Map<String, dynamic> json) {
    final items = (json['deliverables'] as List<dynamic>? ?? []).map((item) {
      return InvoiceDeliverable.fromJson(
        Map<String, dynamic>.from(item as Map),
      );
    }).toList();
    return Invoice(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      number: json['number'] as String? ?? '',
      eventName: json['eventName'] as String? ?? '',
      contactName: json['contactName'] as String? ?? json['clientName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      address: json['address'] as String? ?? '',
      issuedOn: DateTime.tryParse(json['issuedOn'] as String? ?? '') ?? DateTime.now(),
      dueDate: DateTime.tryParse(json['dueDate'] as String? ?? '') ?? DateTime.now(),
      deliverables: items,
      upiId: json['upiId'] as String? ?? '',
      amountReceived: (json['amountReceived'] as num?)?.toDouble() ?? 0,
    );
  }
}

class InvoiceOverview {
  const InvoiceOverview({
    required this.total,
    required this.received,
    required this.pending,
  });

  final double total;
  final double received;
  final double pending;
}
