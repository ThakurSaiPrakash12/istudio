import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumen_studio/app/models/studio_event.dart';
import 'package:lumen_studio/app/services/api_service.dart';
import 'package:lumen_studio/app/services/business_service.dart';

void main() {
  final event = StudioEvent(
    id: 'event-location-test',
    title: 'Location Test',
    clientName: 'Test Client',
    eventType: 'Wedding',
    startsAt: DateTime(2026, 10, 9),
    location: 'Selected venue',
    latitude: 17.385,
    longitude: 78.4867,
    status: EventStatus.upcoming,
    totalAmount: 1000,
  );

  test('create event sends selected venue coordinates and reads them back',
      () async {
    Map<String, dynamic>? sentBody;
    final api = ApiService(
      client: MockClient((request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'success': true, 'event': event.toJson()}),
          201,
        );
      }),
    );

    final created = await BusinessService(api: api).createEvent('test-token', event);

    expect(sentBody?['latitude'], event.latitude);
    expect(sentBody?['longitude'], event.longitude);
    expect(created.latitude, event.latitude);
    expect(created.longitude, event.longitude);
  });

  test('event update sends null coordinates to clear a changed venue', () async {
    Map<String, dynamic>? sentBody;
    final updatedEvent = event.copyWith(clearLocationCoordinates: true);
    final api = ApiService(
      client: MockClient((request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'success': true, 'event': updatedEvent.toJson()}),
          200,
        );
      }),
    );

    final updated =
        await BusinessService(api: api).updateEvent('test-token', updatedEvent);

    expect(sentBody, containsPair('latitude', isNull));
    expect(sentBody, containsPair('longitude', isNull));
    expect(updated.latitude, isNull);
    expect(updated.longitude, isNull);
  });
}
