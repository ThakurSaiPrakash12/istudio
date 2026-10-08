import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_studio/app/models/studio_event.dart';

void main() {
  group('StudioEvent Status and Date Classification', () {
    final referenceToday = DateTime(2026, 10, 8, 14, 30); // 8 Oct 2026

    test('1. Future event date -> Upcoming', () {
      final futureEvent = StudioEvent(
        id: 'evt-future-1',
        title: 'Diwali Corporate Shoot',
        clientName: 'Tata Group',
        eventType: 'Commercial',
        startsAt: DateTime(2026, 10, 20),
        location: 'Mumbai',
        status: EventStatus.upcoming,
        totalAmount: 35000,
      );

      expect(futureEvent.effectiveStatusLabel(referenceToday), 'Upcoming');
      expect(futureEvent.effectiveStatusLabel(referenceToday), isNot('Past'));
    });

    test('2. Today event date -> Today', () {
      final todayEvent = StudioEvent(
        id: 'evt-today-1',
        title: 'Same-day Birthday Shoot',
        clientName: 'Aarav Patel',
        eventType: 'Portrait',
        startsAt: DateTime(2026, 10, 8, 10, 0),
        location: 'Hyderabad Studio',
        status: EventStatus.upcoming,
        totalAmount: 12000,
      );

      expect(todayEvent.effectiveStatusLabel(referenceToday), 'Today');
      expect(todayEvent.effectiveStatusLabel(referenceToday), isNot('Upcoming'));
    });

    test('3. Past date + Completed -> Completed', () {
      final completedEvent = StudioEvent(
        id: 'evt-past-completed',
        title: 'Mehta Family Portraits',
        clientName: 'Mehta Family',
        eventType: 'Portrait',
        startsAt: DateTime(2026, 9, 25),
        location: 'Bandra West',
        status: EventStatus.completed,
        totalAmount: 18000,
      );

      expect(completedEvent.effectiveStatusLabel(referenceToday), 'Completed');
    });

    test('4. Past date + In Progress -> Past · In Progress', () {
      final inProgressEvent = StudioEvent(
        id: 'evt-past-inprogress',
        title: 'Aurora Brand Campaign',
        clientName: 'Aurora Corp',
        eventType: 'Brand Campaign',
        startsAt: DateTime(2026, 10, 5),
        location: 'Film City',
        status: EventStatus.inProgress,
        totalAmount: 48000,
      );

      expect(
        inProgressEvent.effectiveStatusLabel(referenceToday),
        'Past · In Progress',
      );
    });

    test('5. Past date + stale Upcoming -> never Upcoming (shows Past / Needs Update)', () {
      final staleUpcomingEvent = StudioEvent(
        id: 'evt-past-stale',
        title: 'Rahul and Riya',
        clientName: 'Rahul & Riya',
        eventType: 'Wedding',
        startsAt: DateTime(2026, 10, 5),
        location: 'Taj Falaknuma Palace',
        status: EventStatus.upcoming,
        totalAmount: 10000,
      );

      final label = staleUpcomingEvent.effectiveStatusLabel(referenceToday);
      expect(label, isNot('Upcoming'));
      expect(label, 'Past / Needs Update');
    });

    test('Cancelled status always returns Cancelled regardless of date', () {
      final cancelledEvent = StudioEvent(
        id: 'evt-cancelled',
        title: 'Cancelled Shoot',
        clientName: 'Kunal Roy',
        eventType: 'Pre-wedding',
        startsAt: DateTime(2026, 10, 1),
        location: 'Goa',
        status: EventStatus.cancelled,
        totalAmount: 25000,
      );

      expect(cancelledEvent.effectiveStatusLabel(referenceToday), 'Cancelled');
    });
  });
}
