import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/studio_event.dart';
import '../models/studio_notification.dart';
import 'events_provider.dart';

class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider() {
    _startTicker();
  }

  Timer? _ticker;
  final Set<String> _readIds = <String>{};
  final Set<String> _dismissedIds = <String>{};
  List<StudioNotification> _cachedNotifications = [];

  List<StudioNotification> get allNotifications =>
      List.unmodifiable(_cachedNotifications);

  /// Only notifications related to upcoming shoots within 7 days
  List<StudioNotification> get upcomingShootNotifications =>
      _cachedNotifications
          .where((n) =>
              n.urgency != NotificationUrgency.payment &&
              !_dismissedIds.contains(n.id))
          .toList();

  /// Closest shoot starting within 7 days
  StudioNotification? get nearestShootNotification {
    final list = upcomingShootNotifications;
    if (list.isEmpty) return null;
    return list.first;
  }

  /// Total unread alerts count
  int get unreadCount => _cachedNotifications
      .where((n) => !_readIds.contains(n.id) && !_dismissedIds.contains(n.id))
      .length;

  bool get hasUrgentAlert => _cachedNotifications.any((n) =>
      !_dismissedIds.contains(n.id) &&
      (n.urgency == NotificationUrgency.critical ||
          n.urgency == NotificationUrgency.warning));

  /// Regenerates notifications based on current events
  void syncEvents(EventsProvider eventsProvider) {
    final now = DateTime.now();
    final events = eventsProvider.events;
    final List<StudioNotification> generated = [];

    for (final event in events) {
      if (event.status == EventStatus.completed ||
          event.status == EventStatus.cancelled) {
        continue;
      }

      // Check if event is within 7 days
      if (event.isWithin7Days) {
        final diff = event.timeUntilStart;
        final notifId = 'evt-notif-${event.id}';

        if (_dismissedIds.contains(notifId)) continue;

        NotificationUrgency urgency;
        String message;

        if (diff.inHours <= 24 && diff.inSeconds > 0) {
          urgency = NotificationUrgency.critical;
          final hours = event.hoursUntilStart;
          final mins = event.minutesUntilStart;
          final timeStr = hours > 0 ? '$hours hours and $mins mins' : '$mins minutes';
          message =
              '${event.title} with ${event.clientName} starts in $timeStr at ${event.location}. Verify gear & battery charges.';
        } else if (diff.inDays <= 3 && diff.inSeconds > 0) {
          urgency = NotificationUrgency.warning;
          message =
              '${event.title} starts in ${event.daysUntilStart} days and ${event.hoursUntilStart} hours. Confirm venue timing and crew availability.';
        } else if (diff.inSeconds <= 0) {
          urgency = NotificationUrgency.critical;
          message = '${event.title} is scheduled for today at ${event.startTime}.';
        } else {
          urgency = NotificationUrgency.notice;
          message =
              'Upcoming session in ${event.daysUntilStart} days and ${event.hoursUntilStart} hours (${event.eventType} shoot for ${event.clientName}).';
        }

        generated.add(
          StudioNotification(
            id: notifId,
            eventId: event.id,
            title: event.title,
            message: message,
            startsAt: event.fullStartDateTime,
            createdAt: now,
            urgency: urgency,
            isRead: _readIds.contains(notifId),
            eventType: event.eventType,
            clientName: event.clientName,
            location: event.location,
          ),
        );
      }

      // Check for pending payment notifications
      if (event.status == EventStatus.paymentDue && event.remainingAmount > 0) {
        final payNotifId = 'pay-due-${event.id}';
        if (!_dismissedIds.contains(payNotifId)) {
          generated.add(
            StudioNotification(
              id: payNotifId,
              eventId: event.id,
              title: 'Payment Due: ${event.title}',
              message:
                  '${event.clientName} has a balance of ₹${event.remainingAmount.toStringAsFixed(0)} pending.',
              startsAt: event.fullStartDateTime,
              createdAt: now,
              urgency: NotificationUrgency.payment,
              isRead: _readIds.contains(payNotifId),
              eventType: event.eventType,
              clientName: event.clientName,
              location: event.location,
            ),
          );
        }
      }
    }

    // Sort by startsAt ascending (most imminent shoots first)
    generated.sort((a, b) {
      if (a.urgency == NotificationUrgency.critical &&
          b.urgency != NotificationUrgency.critical) {
        return -1;
      }
      if (b.urgency == NotificationUrgency.critical &&
          a.urgency != NotificationUrgency.critical) {
        return 1;
      }
      return a.startsAt.compareTo(b.startsAt);
    });

    _cachedNotifications = generated;
    notifyListeners();
  }

  void markAsRead(String id) {
    _readIds.add(id);
    _cachedNotifications = _cachedNotifications.map((n) {
      if (n.id == id) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();
    notifyListeners();
  }

  void markAllAsRead() {
    for (final n in _cachedNotifications) {
      _readIds.add(n.id);
    }
    _cachedNotifications =
        _cachedNotifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
  }

  void dismiss(String id) {
    _dismissedIds.add(id);
    _cachedNotifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  void _startTicker() {
    // Ticker fires every 60 seconds to update relative countdowns in real-time
    _ticker = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_cachedNotifications.isNotEmpty) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
