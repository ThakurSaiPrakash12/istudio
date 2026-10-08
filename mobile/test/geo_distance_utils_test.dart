import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_studio/app/utils/geo_distance_utils.dart';

void main() {
  group('GeoDistanceUtils', () {
    // ── calculateHaversineKm ─────────────────────────────────────────────────

    test('Haversine distance Miyapur ↔ Gachibowli is ~6.3 km', () {
      final d = GeoDistanceUtils.calculateHaversineKm(
        17.4968, 78.3547, // Miyapur
        17.4401, 78.3489, // Gachibowli
      );
      expect(d, inInclusiveRange(5.5, 7.5));
    });

    test('Haversine distance between same coordinates is 0.0 km', () {
      final d = GeoDistanceUtils.calculateHaversineKm(
        17.4968, 78.3547,
        17.4968, 78.3547,
      );
      expect(d, 0.0);
    });

    // ── computeEventDistance: real coordinates ───────────────────────────────

    test('real event coords + real photographer coords → Haversine distance', () {
      final result = GeoDistanceUtils.computeEventDistance(
        eventLocation: 'Grand Ballroom, Hyderabad',
        eventLat: 17.4968,
        eventLng: 78.3547,
        photographerCity: 'Hyderabad',
        photographerAddress: 'Gachibowli',
        photographerLat: 17.4401,
        photographerLng: 78.3489,
      );
      expect(result.hasKnownDistance, isTrue);
      expect(result.isExact, isTrue);
      expect(result.distanceKm, inInclusiveRange(5.5, 7.5));
      expect(result.badgeText, contains('km from event'));
      expect(result.badgeText, isNot(contains('Approx')));
    });

    test('server precomputed distance from real GPS → exact label', () {
      final result = GeoDistanceUtils.computeEventDistance(
        eventLocation: 'Royal Palace, Hyderabad',
        photographerCity: 'Hyderabad',
        photographerAddress: 'Banjara Hills',
        precomputedDistanceKm: 3.2,
      );
      expect(result.hasKnownDistance, isTrue);
      expect(result.isExact, isTrue);
      expect(result.distanceKm, 3.2);
      expect(result.badgeText, contains('3.2 km from event'));
      expect(result.badgeText, isNot(contains('Approx')));
    });

    test('close distance (< 500m) formats correctly', () {
      final result = GeoDistanceUtils.computeEventDistance(
        eventLocation: 'Studio Hall',
        eventLat: 17.4156,
        eventLng: 78.4357,
        photographerLat: 17.4160,
        photographerLng: 78.4360,
      );
      expect(result.hasKnownDistance, isTrue);
      expect(result.badgeText, contains('< 500m'));
    });

    // ── computeEventDistance: missing coordinates → unavailable ──────────────

    test('missing event coordinates → Distance unavailable (no hardcoded fallback)', () {
      final result = GeoDistanceUtils.computeEventDistance(
        eventLocation: 'Miyapur, Hyderabad', // Has named locality in text
        eventLat: null,
        eventLng: null,
        photographerCity: 'Hyderabad',
        photographerAddress: 'Gachibowli',
        photographerLat: 17.4401,
        photographerLng: 78.3489,
      );
      expect(result.hasKnownDistance, isFalse);
      expect(result.distanceKm, isNull);
      expect(result.badgeText, 'Distance unavailable');
    });

    test('missing photographer coordinates → Distance unavailable', () {
      final result = GeoDistanceUtils.computeEventDistance(
        eventLocation: 'Venue Hall',
        eventLat: 17.4968,
        eventLng: 78.3547,
        photographerCity: 'Hyderabad',
        photographerAddress: 'Banjara Hills',
        photographerLat: null,
        photographerLng: null,
      );
      expect(result.hasKnownDistance, isFalse);
      expect(result.distanceKm, isNull);
      expect(result.badgeText, 'Distance unavailable');
    });

    test('both coordinates missing → Distance unavailable even if cities match', () {
      final result = GeoDistanceUtils.computeEventDistance(
        eventLocation: 'Hyderabad',
        eventLat: null,
        eventLng: null,
        photographerCity: 'Hyderabad',
        photographerAddress: 'Hyderabad',
        photographerLat: null,
        photographerLng: null,
      );
      expect(result.hasKnownDistance, isFalse);
      expect(result.distanceKm, isNull);
      expect(result.badgeText, 'Distance unavailable');
    });
  });
}
