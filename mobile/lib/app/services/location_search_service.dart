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
  });

  final String name;
  final String displayName;
  final double latitude;
  final double longitude;
  final String? city;

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
    );
  }

  factory PlaceLocation.fromNominatim(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? '';
    final displayName = json['display_name'] as String? ?? '';
    final lat = double.tryParse(json['lat']?.toString() ?? '') ?? 0.0;
    final lon = double.tryParse(json['lon']?.toString() ?? '') ?? 0.0;

    return PlaceLocation(
      name: name.isNotEmpty ? name : displayName.split(',').first.trim(),
      displayName: displayName,
      latitude: lat,
      longitude: lon,
    );
  }
}

class LocationSearchService {
  LocationSearchService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// Searches for venues / addresses by text query using OpenStreetMap geocoding.
  Future<List<PlaceLocation>> searchPlaces(String query) async {
    final clean = query.trim();
    if (clean.length < 2) return [];

    // 1. Try Photon first (instant search-as-you-type OSM index)
    try {
      final uri = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(clean)}&limit=5',
      );
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
  Future<PlaceLocation?> geocodeLocation(String query) async {
    final results = await searchPlaces(query);
    if (results.isNotEmpty) return results.first;
    return null;
  }
}
