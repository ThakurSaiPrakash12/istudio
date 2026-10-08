import 'dart:math' as math;

class DistanceResult {
  const DistanceResult({
    this.distanceKm,
    required this.badgeText,
    this.isNearby = false,
    this.isSameLocality = false,
    this.isSameCity = false,
    this.hasKnownDistance = false,
    this.isExact = true,
  });

  final double? distanceKm;
  final String badgeText;
  final bool isNearby; // distanceKm < 25 km
  final bool isSameLocality; // distanceKm < 2.5 km
  final bool isSameCity;
  final bool hasKnownDistance;
  final bool isExact;
}

class GeoDistanceUtils {
  GeoDistanceUtils._();

  /// Haversine distance in km.
  static double calculateHaversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return (earthRadiusKm * c * 10).round() / 10;
  }

  /// Computes the display distance between an event and a photographer using real coordinates.
  ///
  /// Flow: Event lat/lng + Photographer lat/lng → Haversine → distance from event.
  /// If coordinates are missing, returns [DistanceResult] with
  /// [hasKnownDistance] = false and [badgeText] = 'Distance unavailable'.
  static DistanceResult computeEventDistance({
    String? eventLocation,
    double? eventLat,
    double? eventLng,
    String? photographerCity,
    String? photographerAddress,
    double? photographerLat,
    double? photographerLng,
    double? precomputedDistanceKm,
  }) {
    // 1. Server precomputed distance from real GPS coordinates
    if (precomputedDistanceKm != null &&
        !precomputedDistanceKm.isNaN &&
        precomputedDistanceKm >= 0) {
      return _buildResult(
        distanceKm: precomputedDistanceKm,
        eventLocation: eventLocation,
      );
    }

    // 2. Real event coords + Real photographer coords → Haversine
    if (eventLat != null &&
        eventLng != null &&
        photographerLat != null &&
        photographerLng != null &&
        !eventLat.isNaN &&
        !eventLng.isNaN &&
        !photographerLat.isNaN &&
        !photographerLng.isNaN) {
      final distanceKm = calculateHaversineKm(
        eventLat,
        eventLng,
        photographerLat,
        photographerLng,
      );
      return _buildResult(
        distanceKm: distanceKm,
        eventLocation: eventLocation,
      );
    }

    // 3. Missing coordinates → Distance unavailable (no hardcoded fallback)
    return const DistanceResult(
      badgeText: 'Distance unavailable',
      hasKnownDistance: false,
    );
  }

  static double _toRad(double deg) => deg * (math.pi / 180.0);

  static DistanceResult _buildResult({
    required double distanceKm,
    required String? eventLocation,
  }) {
    final hasEvent =
        eventLocation != null && eventLocation.trim().isNotEmpty;
    final suffix = hasEvent ? 'from event' : 'away';

    String badgeText;
    if (distanceKm < 0.5) {
      badgeText = '< 500m $suffix';
    } else if (distanceKm < 1.0) {
      badgeText = '< 1 km $suffix';
    } else if (distanceKm < 25.0) {
      badgeText = '${distanceKm.toStringAsFixed(1)} km $suffix';
    } else if (distanceKm < 100.0) {
      badgeText = '${distanceKm.toStringAsFixed(0)} km $suffix';
    } else {
      badgeText = '${distanceKm.toStringAsFixed(0)} km away';
    }

    return DistanceResult(
      distanceKm: distanceKm,
      badgeText: badgeText,
      isNearby: distanceKm < 25.0,
      isSameLocality: distanceKm < 2.5,
      hasKnownDistance: true,
      isExact: true,
    );
  }
}
