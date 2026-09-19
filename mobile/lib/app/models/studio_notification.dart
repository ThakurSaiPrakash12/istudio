import 'package:flutter/material.dart';

enum NotificationUrgency {
  critical, // < 24 hours
  warning, // < 72 hours (3 days)
  notice, // 4-7 days
  payment, // payment balance pending
  info, // general studio notification
}

@immutable
class StudioNotification {
  const StudioNotification({
    required this.id,
    this.eventId,
    required this.title,
    required this.message,
    required this.startsAt,
    required this.createdAt,
    this.urgency = NotificationUrgency.notice,
    this.isRead = false,
    this.eventType = 'Session',
    this.clientName = '',
    this.location = '',
  });

  final String id;
  final String? eventId;
  final String title;
  final String message;
  final DateTime startsAt;
  final DateTime createdAt;
  final NotificationUrgency urgency;
  final bool isRead;
  final String eventType;
  final String clientName;
  final String location;

  Duration get timeRemaining => startsAt.difference(DateTime.now());

  int get daysRemaining => timeRemaining.inDays;
  int get hoursRemaining => timeRemaining.inHours % 24;
  int get minutesRemaining => timeRemaining.inMinutes % 60;

  bool get isPast => timeRemaining.inMinutes < -30;
  bool get isOngoing => timeRemaining.inMinutes >= -30 && timeRemaining.inSeconds <= 0;

  /// Compact chip format: e.g. "⏳ 2d 14h left", "🚨 18h left", "🔥 Today"
  String get countdownBadge {
    if (isPast) return 'Passed';
    if (isOngoing) return '🔥 In Progress';
    if (timeRemaining.inSeconds <= 0) return '🔥 Today';

    if (daysRemaining >= 1) {
      return '⏳ ${daysRemaining}d ${hoursRemaining}h left';
    } else if (hoursRemaining >= 1) {
      return '🚨 ${hoursRemaining}h ${minutesRemaining}m left';
    } else if (minutesRemaining > 0) {
      return '🚨 ${minutesRemaining}m left';
    } else {
      return '🚨 Starting now';
    }
  }

  /// Full descriptive notification breakdown:
  /// e.g. "Starts in 2 days and 14 hours"
  String get countdownSentence {
    if (isPast) return 'Shoot has completed';
    if (isOngoing) return 'Shoot is currently underway today';
    if (timeRemaining.inSeconds <= 0) return 'Shoot starts today!';

    if (daysRemaining >= 1) {
      final dayLabel = daysRemaining == 1 ? 'day' : 'days';
      final hourLabel = hoursRemaining == 1 ? 'hour' : 'hours';
      return 'Starts in $daysRemaining $dayLabel and $hoursRemaining $hourLabel';
    } else if (hoursRemaining >= 1) {
      final hourLabel = hoursRemaining == 1 ? 'hour' : 'hours';
      return 'Starts in $hoursRemaining $hourLabel and $minutesRemaining mins';
    } else {
      return 'Starts in $minutesRemaining minutes';
    }
  }

  StudioNotification copyWith({
    String? id,
    String? eventId,
    String? title,
    String? message,
    DateTime? startsAt,
    DateTime? createdAt,
    NotificationUrgency? urgency,
    bool? isRead,
    String? eventType,
    String? clientName,
    String? location,
  }) {
    return StudioNotification(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      title: title ?? this.title,
      message: message ?? this.message,
      startsAt: startsAt ?? this.startsAt,
      createdAt: createdAt ?? this.createdAt,
      urgency: urgency ?? this.urgency,
      isRead: isRead ?? this.isRead,
      eventType: eventType ?? this.eventType,
      clientName: clientName ?? this.clientName,
      location: location ?? this.location,
    );
  }
}
