import 'package:flutter/material.dart';

enum EventStatus {
  upcoming,
  inProgress,
  paymentDue,
  completed,
  cancelled;

  String get label {
    switch (this) {
      case EventStatus.upcoming:
        return 'Upcoming';
      case EventStatus.inProgress:
        return 'In Progress';
      case EventStatus.paymentDue:
        return 'Payment Due';
      case EventStatus.completed:
        return 'Completed';
      case EventStatus.cancelled:
        return 'Cancelled';
    }
  }
}

enum PaymentMethod {
  cash,
  upi,
  bankTransfer,
  card,
  other;

  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case PaymentMethod.cash:
        return Icons.payments_outlined;
      case PaymentMethod.upi:
        return Icons.qr_code_2_rounded;
      case PaymentMethod.bankTransfer:
        return Icons.account_balance_outlined;
      case PaymentMethod.card:
        return Icons.credit_card_outlined;
      case PaymentMethod.other:
        return Icons.receipt_outlined;
    }
  }

  static PaymentMethod fromString(String? value) {
    if (value == null) return PaymentMethod.upi;
    for (final method in PaymentMethod.values) {
      if (method.name.toLowerCase() == value.toLowerCase() ||
          method.label.toLowerCase() == value.toLowerCase()) {
        return method;
      }
    }
    return PaymentMethod.upi;
  }
}

@immutable
class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.title,
    required this.amount,
    required this.paidAt,
    this.method = PaymentMethod.upi,
    this.reference,
    this.proof,
  });

  final String id;
  final String title;
  final double amount;
  final DateTime paidAt;
  final PaymentMethod method;
  final String? reference;
  final String? proof;

  bool get hasProof => proof != null && proof!.trim().isNotEmpty;

  PaymentRecord copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? paidAt,
    PaymentMethod? method,
    String? reference,
    String? proof,
  }) {
    return PaymentRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      paidAt: paidAt ?? this.paidAt,
      method: method ?? this.method,
      reference: reference ?? this.reference,
      proof: proof ?? this.proof,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'paidAt': paidAt.toIso8601String(),
        'method': method.name,
        'reference': reference,
        'proof': proof,
      };

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      paidAt: DateTime.parse(json['paidAt'] as String),
      method: PaymentMethod.fromString(json['method'] as String?),
      reference: json['reference'] as String?,
      proof: json['proof'] as String?,
    );
  }
}

@immutable
class ExpenseRecord {
  const ExpenseRecord({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.incurredAt,
  });

  final String id;
  final String title;
  final double amount;
  final String category;
  final DateTime incurredAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'category': category,
        'incurredAt': incurredAt.toIso8601String(),
      };

  factory ExpenseRecord.fromJson(Map<String, dynamic> json) {
    return ExpenseRecord(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String? ?? 'General',
      incurredAt: DateTime.parse(json['incurredAt'] as String),
    );
  }
}

@immutable
class DeliverableTask {
  const DeliverableTask({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  final String id;
  final String title;
  final bool isCompleted;

  DeliverableTask copyWith({bool? isCompleted}) {
    return DeliverableTask(
      id: id,
      title: title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
      };

  factory DeliverableTask.fromJson(Map<String, dynamic> json) {
    return DeliverableTask(
      id: json['id'] as String,
      title: json['title'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}

@immutable
class StudioEvent {
  const StudioEvent({
    required this.id,
    this.clientId,
    required this.title,
    required this.clientName,
    required this.eventType,
    required this.startsAt,
    this.startTime = '10:00 AM',
    this.endTime = '04:00 PM',
    required this.location,
    required this.status,
    required this.totalAmount,
    double? amountReceived,
    this.payments = const [],
    this.expenses = const [],
    this.deliverables = const [],
    this.notes = '',
  }) : _customAmountReceived = amountReceived;

  final String id;
  final String? clientId;
  final String title;
  final String clientName;
  final String eventType; // Wedding, Maternity, Commercial, Newborn, Portrait, etc.
  final DateTime startsAt;
  final String startTime;
  final String endTime;
  final String location;
  final EventStatus status;
  final double totalAmount;
  final double? _customAmountReceived;
  final List<PaymentRecord> payments;
  final List<ExpenseRecord> expenses;
  final List<DeliverableTask> deliverables;
  final String notes;

  /// Amount received is calculated dynamically from payments if present,
  /// otherwise falling back to explicit amountReceived or 0.
  double get amountReceived {
    if (payments.isNotEmpty) {
      return payments.fold(0.0, (acc, item) => acc + item.amount);
    }
    return _customAmountReceived ?? 0.0;
  }

  /// Remaining amount = Total agreed - Amount received
  double get remainingAmount =>
      (totalAmount - amountReceived).clamp(0.0, double.infinity);

  /// Total expenses = Sum of all recorded expenses
  double get totalExpenses =>
      expenses.fold(0.0, (acc, item) => acc + item.amount);

  /// Net Profit = Amount Received - Total Expenses
  double get netProfit => amountReceived - totalExpenses;

  /// Deliverables count
  int get completedTasksCount =>
      deliverables.where((task) => task.isCompleted).length;

  int get totalTasksCount => deliverables.length;

  double get progressRatio =>
      totalTasksCount == 0 ? 0.0 : (completedTasksCount / totalTasksCount);

  /// Calculates exact target start DateTime by parsing startTime (e.g. 10:00 AM or 02:30 PM)
  DateTime get fullStartDateTime {
    int hour = 10;
    int minute = 0;
    try {
      final clean = startTime.trim().toUpperCase();
      final isPm = clean.contains('PM');
      final isAm = clean.contains('AM');
      final parts = clean.replaceAll(RegExp(r'[^\d:]'), '').split(':');
      if (parts.isNotEmpty) {
        hour = int.tryParse(parts[0]) ?? 10;
        if (parts.length > 1) {
          minute = int.tryParse(parts[1]) ?? 0;
        }
        if (isPm && hour < 12) hour += 12;
        if (isAm && hour == 12) hour = 0;
      }
    } catch (_) {}
    return DateTime(startsAt.year, startsAt.month, startsAt.day, hour, minute);
  }

  /// Live duration until event begins
  Duration get timeUntilStart => fullStartDateTime.difference(DateTime.now());

  /// True if scheduled to start in <= 7 days and has not completed/ended
  bool get isWithin7Days {
    if (status == EventStatus.completed || status == EventStatus.cancelled) {
      return false;
    }
    final remaining = timeUntilStart;
    return remaining.inSeconds > -86400 && remaining <= const Duration(days: 7);
  }

  bool get isImminent => isWithin7Days && timeUntilStart.inHours <= 24;

  int get daysUntilStart => timeUntilStart.inDays;
  int get hoursUntilStart => timeUntilStart.inHours % 24;
  int get minutesUntilStart => timeUntilStart.inMinutes % 60;

  /// Formatted notification copy: "2 days and 14 hours left" or "18 hours left"
  String get countdownFormatted {
    final remaining = timeUntilStart;
    if (remaining.inSeconds <= 0) {
      return 'Today / Ongoing';
    }
    final days = daysUntilStart;
    final hours = hoursUntilStart;
    if (days >= 1) {
      final dayStr = days == 1 ? 'day' : 'days';
      final hourStr = hours == 1 ? 'hour' : 'hours';
      return '$days $dayStr, $hours $hourStr left';
    } else if (hours >= 1) {
      final hourStr = hours == 1 ? 'hour' : 'hours';
      return '$hours $hourStr left';
    } else {
      return '$minutesUntilStart mins left';
    }
  }

  /// Compact chip copy: "⏳ 2d 14h left"
  String get countdownChip {
    final remaining = timeUntilStart;
    if (remaining.inSeconds <= 0) return '🔥 Today';
    final days = daysUntilStart;
    final hours = hoursUntilStart;
    if (days >= 1) {
      return '⏳ ${days}d ${hours}h left';
    } else if (hours >= 1) {
      return '🚨 ${hours}h left';
    } else {
      return '🚨 ${minutesUntilStart}m left';
    }
  }

  bool get isPast =>
      status == EventStatus.completed ||
      startsAt.isBefore(DateTime.now().subtract(const Duration(days: 1)));

  StudioEvent copyWith({
    String? id,
    String? clientId,
    String? title,
    String? clientName,
    String? eventType,
    DateTime? startsAt,
    String? startTime,
    String? endTime,
    String? location,
    EventStatus? status,
    double? totalAmount,
    double? amountReceived,
    List<PaymentRecord>? payments,
    List<ExpenseRecord>? expenses,
    List<DeliverableTask>? deliverables,
    String? notes,
  }) {
    return StudioEvent(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      title: title ?? this.title,
      clientName: clientName ?? this.clientName,
      eventType: eventType ?? this.eventType,
      startsAt: startsAt ?? this.startsAt,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      amountReceived: amountReceived ?? this.amountReceived,
      payments: payments ?? this.payments,
      expenses: expenses ?? this.expenses,
      deliverables: deliverables ?? this.deliverables,
      notes: notes ?? this.notes,
    );
  }
}
