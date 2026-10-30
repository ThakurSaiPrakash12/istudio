import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PlaceLocation {
  const PlaceLocation({
    required this.name,
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.city,
    this.state,
    this.district,
    this.country,
  });

  final String name;
  final String displayName;
  final double latitude;
  final double longitude;
  final String? city;
  final String? state;
  final String? district;
  final String? country;

  factory PlaceLocation.fromPhoton(Map<String, dynamic> feature) {
    final properties = feature['properties'] as Map<String, dynamic>? ?? {};
    final geometry = feature['geometry'] as Map<String, dynamic>? ?? {};
    final coordinates = geometry['coordinates'] as List<dynamic>? ?? [0.0, 0.0];

    final lon = (coordinates[0] as num).toDouble();
    final lat = (coordinates[1] as num).toDouble();

    final name = properties['name'] as String? ?? '';
    final street = properties['street'] as String? ?? '';
    final locality = properties['locality'] as String? ??
        properties['district'] as String? ??
        '';
    final city = properties['city'] as String? ??
        properties['county'] as String? ??
        properties['state'] as String? ??
        '';
    final state = properties['state'] as String?;
    final district = properties['district'] as String? ?? properties['county'] as String?;
    final country = properties['country'] as String?;

    final parts = [name, street, locality, city]
        .where((p) => p.trim().isNotEmpty)
        .toSet()
        .toList();
    final displayName = parts.join(', ');

    return PlaceLocation(
      name: name.isNotEmpty ? name : displayName,
      displayName: displayName.isNotEmpty ? displayName : name,
      latitude: lat,
      longitude: lon,
      city: city.isNotEmpty ? city : null,
      state: state,
      district: district,
      country: country,
    );
  }

  factory PlaceLocation.fromNominatim(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? '';
    final displayName = json['display_name'] as String? ?? '';
    final lat = double.tryParse(json['lat']?.toString() ?? '') ?? 0.0;
    final lon = double.tryParse(json['lon']?.toString() ?? '') ?? 0.0;
    final addr = json['address'] as Map<String, dynamic>? ?? {};

    final country = addr['country'] as String?;
    final state = addr['state'] as String? ??
        addr['province'] as String? ??
        addr['region'] as String?;
    final district = addr['district'] as String? ??
        addr['county'] as String? ??
        addr['state_district'] as String?;
    final city = addr['city'] as String? ??
        addr['town'] as String? ??
        addr['village'] as String? ??
        addr['suburb'] as String?;

    return PlaceLocation(
      name: name.isNotEmpty ? name : displayName.split(',').first.trim(),
      displayName: displayName,
      latitude: lat,
      longitude: lon,
      city: city,
      state: state,
      district: district,
      country: country,
    );
  }
}

class LocationSearchService {
  LocationSearchService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// Searches for venues / addresses by text query using OpenStreetMap geocoding.
  /// Optionally biases results around [latitude] and [longitude] if provided.
  Future<List<PlaceLocation>> searchPlaces(
    String query, {
    double? latitude,
    double? longitude,
  }) async {
    final clean = query.trim();
    if (clean.length < 2) return [];

    // 1. Try Photon first (instant search-as-you-type OSM index)
    try {
      var url =
          'https://photon.komoot.io/api/?q=${Uri.encodeComponent(clean)}&limit=6';
      if (latitude != null &&
          longitude != null &&
          !latitude.isNaN &&
          !longitude.isNaN) {
        url += '&lat=$latitude&lon=$longitude';
      }
      final uri = Uri.parse(url);
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>? ?? [];
        if (features.isNotEmpty) {
          final places = features
              .map((f) => PlaceLocation.fromPhoton(f as Map<String, dynamic>))
              .where((p) => p.latitude != 0.0 && p.longitude != 0.0)
              .toList();
          if (places.isNotEmpty) return places;
        }
      }
    } catch (_) {}

    // 2. Fallback to OpenStreetMap Nominatim
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(clean)}&format=json&limit=5',
      );
      final response = await _client.get(uri, headers: {
        'User-Agent': 'LumenStudioApp/1.0',
      }).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>? ?? [];
        final places = list
            .map((item) =>
                PlaceLocation.fromNominatim(item as Map<String, dynamic>))
            .where((p) => p.latitude != 0.0 && p.longitude != 0.0)
            .toList();
        if (places.isNotEmpty) return places;
      }
    } catch (_) {}

    return [];
  }

  /// Geocodes a location text into coordinates.
  /// If the full query with commas fails, automatically tries candidate sub-queries
  /// (e.g. stripping pillar/flat/plot numbers, trying venue + locality + city).
  Future<PlaceLocation?> geocodeLocation(
    String query, {
    double? latitude,
    double? longitude,
  }) async {
    final clean = query.trim();
    if (clean.isEmpty) return null;

    final results = await searchPlaces(
      clean,
      latitude: latitude,
      longitude: longitude,
    );
    if (results.isNotEmpty) return results.first;

    // Fallback: If full address failed, try candidate sub-parts (e.g. Venue, Locality, City)
    final parts = clean
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length > 1) {
      // Filter out room / pillar / flat / floor / plot / h.no prefixes
      final meaningfulParts = parts.where((p) {
        final lower = p.toLowerCase();
        return !lower.startsWith('pillar') &&
            !lower.startsWith('flat') &&
            !lower.startsWith('plot') &&
            !lower.startsWith('h.no') &&
            !lower.startsWith('d.no') &&
            !lower.startsWith('door') &&
            !lower.startsWith('beside') &&
            !lower.startsWith('opposite') &&
            !lower.startsWith('near') &&
            !lower.startsWith('room');
      }).toList();

      if (meaningfulParts.isNotEmpty && meaningfulParts.length != parts.length) {
        final subResults = await searchPlaces(
          meaningfulParts.join(', '),
          latitude: latitude,
          longitude: longitude,
        );
        if (subResults.isNotEmpty) return subResults.first;
      }

      // Try venue name + last 2 parts (usually locality + city)
      if (meaningfulParts.length >= 3) {
        final venueAndCity = [
          meaningfulParts.first,
          meaningfulParts[meaningfulParts.length - 2],
          meaningfulParts.last,
        ].join(', ');
        final subResults = await searchPlaces(
          venueAndCity,
          latitude: latitude,
          longitude: longitude,
        );
        if (subResults.isNotEmpty) return subResults.first;
      }

      // Try just venue name
      if (meaningfulParts.isNotEmpty) {
        final subResults = await searchPlaces(
          meaningfulParts.first,
          latitude: latitude,
          longitude: longitude,
        );
        if (subResults.isNotEmpty) return subResults.first;
      }
    }

    return null;
  }
}
