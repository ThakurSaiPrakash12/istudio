import 'package:flutter/foundation.dart';

/// Status of a client profile in iStudio.
///
/// Options:
/// - [information]: Client visited / came for information & inquiry (active in Home screen box for 3 days).
/// - [comingUp]: Client with an upcoming shoot / scheduled booking.
/// - [completed]: Client whose events are completed / past shoot client.
enum ClientStatus {
  information,
  comingUp,
  completed,
  notResponded;

  String get label {
    switch (this) {
      case ClientStatus.information:
        return 'Information';
      case ClientStatus.comingUp:
        return 'Coming Up';
      case ClientStatus.completed:
        return 'Completed';
      case ClientStatus.notResponded:
        return 'Not Responded';
    }
  }

  static ClientStatus fromString(String? value) {
    if (value == null) return ClientStatus.information;
    final lower = value.trim().toLowerCase();
    switch (lower) {
      case 'notresponded':
      case 'not_responded':
      case 'unresponsive':
        return ClientStatus.notResponded;
      case 'comingup':
      case 'coming_up':
      case 'upcoming':
        return ClientStatus.comingUp;
      case 'completed':
      case 'past':
      case 'done':
        return ClientStatus.completed;
      case 'information':
      case 'info':
      case 'inquiry':
      default:
        return ClientStatus.information;
    }
  }
}

@immutable
class Client {
  const Client({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    this.address = '',
    this.notes = '',
    this.status = ClientStatus.information,
    this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String notes;
  final ClientStatus status;
  final DateTime? createdAt;

  Client copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? notes,
    ClientStatus? status,
    DateTime? createdAt,
  }) {
    return Client(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'notes': notes,
        'status': status.name,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      address: json['address'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      status: ClientStatus.fromString(json['status'] as String?),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}
