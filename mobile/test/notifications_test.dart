import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_studio/app/models/studio_event.dart';
import 'package:lumen_studio/app/providers/events_provider.dart';
import 'package:lumen_studio/app/providers/notifications_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('7-Day Event Countdown & Parsing Tests', () {
    test('Parses startTime AM/PM into fullStartDateTime accurately', () {
      final baseDate = DateTime(2026, 9, 25);
      final eventAm = StudioEvent(
        id: 'ev-am',
        title: 'Morning Session',
        clientName: 'Test Client',
        eventType: 'Portrait',
        startsAt: baseDate,
        startTime: '09:15 AM',
        location: 'Studio A',
        status: EventStatus.upcoming,
        totalAmount: 10000,
      );

      expect(eventAm.fullStartDateTime.year, 2026);
      expect(eventAm.fullStartDateTime.month, 9);
      expect(eventAm.fullStartDateTime.day, 25);
      expect(eventAm.fullStartDateTime.hour, 9);
      expect(eventAm.fullStartDateTime.minute, 15);

      final eventPm = StudioEvent(
        id: 'ev-pm',
        title: 'Evening Shoot',
        clientName: 'Test Client',
        eventType: 'Wedding',
        startsAt: baseDate,
        startTime: '04:45 PM',
        location: 'Beach Lawn',
        status: EventStatus.upcoming,
        totalAmount: 50000,
      );

      expect(eventPm.fullStartDateTime.hour, 16);
      expect(eventPm.fullStartDateTime.minute, 45);
    });

    test('Identifies events within 7 days vs beyond 7 days', () {
      final now = DateTime.now();

      final within2Days = StudioEvent(
        id: 'ev-2d',
        title: 'Shoot in 2 days',
        clientName: 'Client 2d',
        eventType: 'Wedding',
        startsAt: now.add(const Duration(days: 2)),
        startTime: '10:00 AM',
        location: 'Studio',
        status: EventStatus.upcoming,
        totalAmount: 20000,
      );

      final beyond7Days = StudioEvent(
        id: 'ev-8d',
        title: 'Shoot in 8 days',
        clientName: 'Client 8d',
        eventType: 'Commercial',
        startsAt: now.add(const Duration(days: 9)),
        startTime: '10:00 AM',
        location: 'Studio',
        status: EventStatus.upcoming,
        totalAmount: 30000,
      );

      final completedEvent = StudioEvent(
        id: 'ev-done',
        title: 'Completed Shoot',
        clientName: 'Client Done',
        eventType: 'Portrait',
        startsAt: now.add(const Duration(days: 2)),
        startTime: '10:00 AM',
        location: 'Studio',
        status: EventStatus.completed,
        totalAmount: 15000,
      );

      expect(within2Days.isWithin7Days, isTrue);
      expect(beyond7Days.isWithin7Days, isFalse);
      expect(completedEvent.isWithin7Days, isFalse);
    });

    test('Formats countdown sentences with days and hours', () {
      final now = DateTime.now();
      final event = StudioEvent(
        id: 'ev-cd',
        title: 'Wedding Shoot',
        clientName: 'Aanya',
        eventType: 'Wedding',
        startsAt: now.add(const Duration(days: 3)),
        startTime: '11:59 PM',
        location: 'Lotus',
        status: EventStatus.upcoming,
        totalAmount: 45000,
      );

      expect(event.daysUntilStart, greaterThanOrEqualTo(2));
      expect(event.countdownFormatted, contains('day'));
      expect(event.countdownFormatted, contains('left'));
      expect(event.countdownChip, contains('d'));
      expect(event.countdownChip, contains('h'));
    });
  });

  group('NotificationsProvider Unit Tests', () {
    test('Generates notifications for events within 7 days', () {
      final eventsProvider = EventsProvider();
      final now = DateTime.now();
      eventsProvider.addEvent(
        StudioEvent(
          id: 'test-notification-1',
          title: 'Wedding Shoot',
          clientName: 'Aanya',
          eventType: 'Wedding',
          startsAt: now.add(const Duration(days: 2)),
          location: 'Lotus Pavilion',
          status: EventStatus.upcoming,
          totalAmount: 45000,
        ),
      );
      eventsProvider.addEvent(
        StudioEvent(
          id: 'test-notification-2',
          title: 'Maternity Shoot',
          clientName: 'Meera',
          eventType: 'Maternity',
          startsAt: now.add(const Duration(days: 5)),
          location: 'Studio',
          status: EventStatus.upcoming,
          totalAmount: 30000,
        ),
      );
      final notifsProvider = NotificationsProvider();

      notifsProvider.syncEvents(eventsProvider);

      final upcomingNotifs = notifsProvider.upcomingShootNotifications;
      expect(upcomingNotifs.length, greaterThanOrEqualTo(2));

      final firstNotif = notifsProvider.nearestShootNotification;
      expect(firstNotif, isNotNull);
      expect(firstNotif!.daysRemaining, lessThanOrEqualTo(7));
      expect(firstNotif.countdownSentence, contains('Starts in'));

      // Test mark as read
      final initialUnread = notifsProvider.unreadCount;
      expect(initialUnread, greaterThan(0));

      notifsProvider.markAsRead(firstNotif.id);
      expect(notifsProvider.unreadCount, equals(initialUnread - 1));

      // Test dismiss
      notifsProvider.dismiss(firstNotif.id);
      expect(
        notifsProvider.upcomingShootNotifications.any(
          (n) => n.id == firstNotif.id,
        ),
        isFalse,
      );
    });
  });
}
