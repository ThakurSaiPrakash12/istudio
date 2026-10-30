import 'dart:convert';
import 'package:http/http.dart' as http;

class ParsedCoordinates {
  const ParsedCoordinates({
    required this.latitude,
    required this.longitude,
    this.placeName,
    this.source = 'coordinates',
  });

  final double latitude;
  final double longitude;
  final String? placeName;
  final String source;

  @override
  String toString() => '$latitude, $longitude';
}

class ReverseGeocodeResult {
  const ReverseGeocodeResult({
    required this.displayName,
    this.city,
    this.state,
    this.district,
    this.country,
    this.countryCode,
  });

  final String displayName;
  final String? city;
  final String? state;
  final String? district;
  final String? country;
  final String? countryCode;

  @override
  String toString() =>
      'ReverseGeocodeResult(displayName: $displayName, city: $city, state: $state, district: $district, country: $country)';
}

class GoogleMapsLocationParser {
  GoogleMapsLocationParser({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// Regex for raw decimal coordinates: "17.372605, 78.459720" or "17.372605 78.459720"
  static final _rawCoordsRegex = RegExp(
    r'([-+]?\d{1,2}(?:\.\d+)?)[,\s]+([-+]?\d{1,3}(?:\.\d+)?)',
  );

  /// Regex for Degrees Minutes Seconds (DMS): 17°22'21.4"N 78°27'35.0"E
  static final _dmsRegex = RegExp(
    r'''(\d+)[°\s]+(\d+)['\s]+([\d.]+)"?\s*([NSns])[,\s]+(\d+)[°\s]+(\d+)['\s]+([\d.]+)"?\s*([EWew])''',
  );

  /// Exact place pin in Google Maps URLs (Protobuf): !3d(lat)!4d(lng) or !3d(lat)!2d(lng)
  static final _pbLatThenLng4d = RegExp(
    r'!3d([-+]?\d{1,2}\.\d+)!4d([-+]?\d{1,3}\.\d+)',
  );
  static final _pbLatThenLng2d = RegExp(
    r'!3d([-+]?\d{1,2}\.\d+)!2d([-+]?\d{1,3}\.\d+)',
  );
  static final _pbLngThenLat4d = RegExp(
    r'!4d([-+]?\d{1,3}\.\d+)!3d([-+]?\d{1,2}\.\d+)',
  );
  static final _pbLngThenLat2d = RegExp(
    r'!2d([-+]?\d{1,3}\.\d+)!3d([-+]?\d{1,2}\.\d+)',
  );

  /// Regex for ?q=lat,lng or &q=lat,lng or &ll=lat,lng or destination=lat,lng
  static final _queryCoordsRegex = RegExp(
    r'[?&](?:q|ll|query|saddr|daddr|destination)=([-+]?\d{1,2}\.\d+)[,+ ]([-+]?\d{1,3}\.\d+)',
  );

  /// Regex for /search/lat,lng
  static final _searchCoordsRegex = RegExp(
    r'/search/([-+]?\d{1,2}\.\d+)[,+ ]([-+]?\d{1,3}\.\d+)',
  );

  /// Regex for @lat,lng in Google Maps URLs: .../@17.372605,78.459720,17z...
  /// Note: @lat,lng is camera viewport, so exact pin (!3d!4d or ?q=) is prioritized first.
  static final _atCoordsRegex = RegExp(
    r'@([-+]?\d{1,2}\.\d+),([-+]?\d{1,3}\.\d+)',
  );

  /// Regex for staticmap / metadata: center=lat%2Clng or center=lat,lng
  static final _centerCoordsRegex = RegExp(
    r'center=([-+]?\d{1,2}\.\d+)(?:%2C|%2c|,)([-+]?\d{1,3}\.\d+)',
  );

  /// Regex for /place/Place+Name/...
  static final _placeNameRegex = RegExp(
    r'/place/([^/@?#]+)',
  );

  /// Checks if the input string contains or represents a Google Maps URL.
  static bool isGoogleMapsUrl(String input) {
    final text = input.trim().toLowerCase();
    if (text.isEmpty) return false;
    return text.contains('maps.app.goo.gl') ||
        text.contains('goo.gl/maps') ||
        text.contains('google.com/maps') ||
        text.contains('maps.google.com');
  }

  /// Checks if input is either a Google Maps URL OR raw decimal/DMS coordinates.
  static bool isGoogleMapsUrlOrCoords(String input) {
    final text = input.trim();
    if (text.isEmpty) return false;
    if (isGoogleMapsUrl(text)) return true;
    final parsed = parseSync(text);
    return parsed != null;
  }

  /// Normalizes user input (handles missing https://, trims spaces, extracts URL or coords)
  static String normalizeInput(String input) {
    var text = input.trim();
    if (text.isEmpty) return '';

    // If text contains a URL (e.g. "Check out this place: https://maps.app.goo.gl/xxx"), extract it
    final urlMatch = RegExp(r'(https?://[^\s]+)').firstMatch(text);
    if (urlMatch != null) {
      return urlMatch.group(1)!;
    }

    // If starts with maps.app.goo.gl, goo.gl, or google.com/maps without https://
    if (text.startsWith('maps.app.goo.gl/') ||
        text.startsWith('goo.gl/maps/') ||
        text.startsWith('www.google.com/maps') ||
        text.startsWith('maps.google.com')) {
      return 'https://$text';
    }

    return text;
  }

  /// Tries to parse coordinates synchronously without network calls.
  /// Prioritizes EXACT place pins (!3d!4d, ?q=) over generic viewport (@lat,lng).
  static ParsedCoordinates? parseSync(String input) {
    final text = normalizeInput(input);
    if (text.isEmpty) return null;

    final placeName = _extractPlaceName(text);

    // 1. Exact Pin Protobuf: !3d(lat)!4d(lng) (Primary place coordinates in Google Maps)
    final pbMatch = _pbLatThenLng4d.firstMatch(text) ?? _pbLatThenLng2d.firstMatch(text);
    if (pbMatch != null) {
      final lat = double.tryParse(pbMatch.group(1)!);
      final lng = double.tryParse(pbMatch.group(2)!);
      if (lat != null && lng != null && _isValidLat(lat) && _isValidLng(lng)) {
        return ParsedCoordinates(
          latitude: lat,
          longitude: lng,
          placeName: placeName,
          source: 'google_pin_protobuf',
        );
      }
    }

    final pbRev = _pbLngThenLat4d.firstMatch(text) ?? _pbLngThenLat2d.firstMatch(text);
    if (pbRev != null) {
      final lng = double.tryParse(pbRev.group(1)!);
      final lat = double.tryParse(pbRev.group(2)!);
      if (lat != null && lng != null && _isValidLat(lat) && _isValidLng(lng)) {
        return ParsedCoordinates(
          latitude: lat,
          longitude: lng,
          placeName: placeName,
          source: 'google_pin_protobuf',
        );
      }
    }

    // 2. Exact Query Coordinates: ?q=lat,lng or &ll=lat,lng
    final queryMatch = _queryCoordsRegex.firstMatch(text);
    if (queryMatch != null) {
      final lat = double.tryParse(queryMatch.group(1)!);
      final lng = double.tryParse(queryMatch.group(2)!);
      if (lat != null && lng != null && _isValidLat(lat) && _isValidLng(lng)) {
        return ParsedCoordinates(
          latitude: lat,
          longitude: lng,
          placeName: placeName,
          source: 'google_maps_query',
        );
      }
    }

    // 3. Plain decimal coordinates (e.g. 17.372605, 78.459720 or 17.372605 78.459720)
    if (!text.startsWith('http://') && !text.startsWith('https://')) {
      final rawMatch = _rawCoordsRegex.firstMatch(text);
      if (rawMatch != null) {
        final lat = double.tryParse(rawMatch.group(1)!);
        final lng = double.tryParse(rawMatch.group(2)!);
        if (lat != null &&
            lng != null &&
            _isValidLat(lat) &&
            _isValidLng(lng)) {
          return ParsedCoordinates(
            latitude: lat,
            longitude: lng,
            source: 'raw_coordinates',
          );
        }
      }
    }

    // 4. DMS coordinates: 17°22'21.4"N 78°27'35.0"E
    final dmsMatch = _dmsRegex.firstMatch(text);
    if (dmsMatch != null) {
      final latDeg = double.tryParse(dmsMatch.group(1)!) ?? 0;
      final latMin = double.tryParse(dmsMatch.group(2)!) ?? 0;
      final latSec = double.tryParse(dmsMatch.group(3)!) ?? 0;
      final latHem = dmsMatch.group(4)!.toUpperCase();

      final lngDeg = double.tryParse(dmsMatch.group(5)!) ?? 0;
      final lngMin = double.tryParse(dmsMatch.group(6)!) ?? 0;
      final lngSec = double.tryParse(dmsMatch.group(7)!) ?? 0;
      final lngHem = dmsMatch.group(8)!.toUpperCase();

      var lat = latDeg + (latMin / 60) + (latSec / 3600);
      if (latHem == 'S') lat = -lat;

      var lng = lngDeg + (lngMin / 60) + (lngSec / 3600);
      if (lngHem == 'W') lng = -lng;

      if (_isValidLat(lat) && _isValidLng(lng)) {
        return ParsedCoordinates(
          latitude: lat,
          longitude: lng,
          source: 'dms',
        );
      }
    }

    // 5. Search path: /search/lat,lng
    final searchMatch = _searchCoordsRegex.firstMatch(text);
    if (searchMatch != null) {
      final lat = double.tryParse(searchMatch.group(1)!);
      final lng = double.tryParse(searchMatch.group(2)!);
      if (lat != null && lng != null && _isValidLat(lat) && _isValidLng(lng)) {
        return ParsedCoordinates(
          latitude: lat,
          longitude: lng,
          placeName: placeName,
          source: 'google_maps_url',
        );
      }
    }

    // 6. Viewport Coordinates (@lat,lng) — used as fallback when no exact pin is present
    final atMatch = _atCoordsRegex.firstMatch(text);
    if (atMatch != null) {
      final lat = double.tryParse(atMatch.group(1)!);
      final lng = double.tryParse(atMatch.group(2)!);
      if (lat != null && lng != null && _isValidLat(lat) && _isValidLng(lng)) {
        return ParsedCoordinates(
          latitude: lat,
          longitude: lng,
          placeName: placeName,
          source: 'google_maps_viewport',
        );
      }
    }

    return null;
  }

  /// Parses coordinates from string or resolves shortened Google Maps links (maps.app.goo.gl, goo.gl).
  Future<ParsedCoordinates?> parseAsync(String input) async {
    final clean = normalizeInput(input);
    if (clean.isEmpty) return null;

    // 1. Try sync parse first (direct coords or URL with embedded coords)
    final syncResult = parseSync(clean);
    if (syncResult != null) return syncResult;

    // 2. If it's a URL, resolve redirects and extract coordinates
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      try {
        final resolved = await _resolveGoogleMapsUrl(clean);
        if (resolved != null) return resolved;
      } catch (_) {}
    }

    return null;
  }

  /// Resolves shortened Google Maps links and parses coordinates from redirect Location or HTML body.
  Future<ParsedCoordinates?> _resolveGoogleMapsUrl(String initialUrl) async {
    try {
      final uri = Uri.parse(initialUrl);

      var currentUri = uri;
      String? destinationUrl;
      String? placeNameFromUrl;

      for (int i = 0; i < 4; i++) {
        final req = http.Request('GET', currentUri)..followRedirects = false;
        req.headers['User-Agent'] =
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

        final streamed = await _client.send(req).timeout(const Duration(seconds: 6));
        final loc = streamed.headers['location'];

        if (streamed.statusCode >= 300 && streamed.statusCode < 400 && loc != null) {
          destinationUrl = loc;
          final syncCheck = parseSync(loc);
          if (syncCheck != null) return syncCheck;

          placeNameFromUrl ??= _extractPlaceName(loc);
          currentUri = Uri.parse(loc);
          continue;
        }

        // Final destination page (200 OK)
        destinationUrl = currentUri.toString();
        final syncCheck = parseSync(destinationUrl);
        if (syncCheck != null) return syncCheck;

        placeNameFromUrl ??= _extractPlaceName(destinationUrl);

        final response = await http.Response.fromStream(streamed);
        final body = response.body;

        // 1. Check exact pin protobuf in HTML body: !3d(lat)!4d(lng)
        final pb1 = _pbLatThenLng4d.firstMatch(body) ?? _pbLatThenLng2d.firstMatch(body);
        if (pb1 != null) {
          final lat = double.tryParse(pb1.group(1)!);
          final lng = double.tryParse(pb1.group(2)!);
          if (lat != null && lng != null && _isValidLat(lat) && _isValidLng(lng)) {
            return ParsedCoordinates(
              latitude: lat,
              longitude: lng,
              placeName: placeNameFromUrl,
              source: 'google_pb_coords',
            );
          }
        }

        final pb2 = _pbLngThenLat4d.firstMatch(body) ?? _pbLngThenLat2d.firstMatch(body);
        if (pb2 != null) {
          final lng = double.tryParse(pb2.group(1)!);
          final lat = double.tryParse(pb2.group(2)!);
          if (lat != null && lng != null && _isValidLat(lat) && _isValidLng(lng)) {
            return ParsedCoordinates(
              latitude: lat,
              longitude: lng,
              placeName: placeNameFromUrl,
              source: 'google_pb_coords',
            );
          }
        }

        // 2. Check canonical link in HTML
        final canonicalMatch = RegExp(r"""<link[^>]+rel=["']canonical["'][^>]+href=["']([^"']+)["']""", caseSensitive: false).firstMatch(body);
        if (canonicalMatch != null) {
          final cUrl = canonicalMatch.group(1)!;
          final cParsed = parseSync(cUrl);
          if (cParsed != null) return cParsed;
        }

        // 3. Check @lat,lng in body (e.g. within embedded script links)
        final atMatch = _atCoordsRegex.firstMatch(body);
        if (atMatch != null) {
          final lat = double.tryParse(atMatch.group(1)!);
          final lng = double.tryParse(atMatch.group(2)!);
          if (lat != null && lng != null && _isValidLat(lat) && _isValidLng(lng)) {
            return ParsedCoordinates(
              latitude: lat,
              longitude: lng,
              placeName: placeNameFromUrl,
              source: 'google_body_at_coords',
            );
          }
        }

        // 4. Check staticmap center in body as fallback
        final bodyCenter = _centerCoordsRegex.firstMatch(body);
        if (bodyCenter != null) {
          final lat = double.tryParse(bodyCenter.group(1)!);
          final lng = double.tryParse(bodyCenter.group(2)!);
          if (lat != null && lng != null && _isValidLat(lat) && _isValidLng(lng)) {
            return ParsedCoordinates(
              latitude: lat,
              longitude: lng,
              placeName: placeNameFromUrl,
              source: 'google_staticmap_center',
            );
          }
        }

        break;
      }

      // 4. Fallback: Geocode place name from URL
      if (placeNameFromUrl != null && placeNameFromUrl.isNotEmpty) {
        final geocoded = await _geocodePlaceName(placeNameFromUrl);
        if (geocoded != null) return geocoded;
      }

      // 5. Ultimate fallback: staticmap center in body
      final centerMatch = _centerCoordsRegex.firstMatch(destinationUrl ?? '') ?? _centerCoordsRegex.firstMatch(currentUri.toString());
      if (centerMatch != null) {
        final lat = double.tryParse(centerMatch.group(1)!);
        final lng = double.tryParse(centerMatch.group(2)!);
        if (lat != null && lng != null && _isValidLat(lat) && _isValidLng(lng)) {
          return ParsedCoordinates(
            latitude: lat,
            longitude: lng,
            placeName: placeNameFromUrl,
            source: 'google_staticmap_center',
          );
        }
      }
    } catch (_) {}

    return null;
  }

  /// Fallback: Geocode place name extracted from `/place/Place+Name/` URL path
  Future<ParsedCoordinates?> _geocodePlaceName(String placeName) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(placeName)}&format=json&limit=1',
      );
      final res = await _client.get(
        uri,
        headers: {'User-Agent': 'iStudio-Photography-App/1.0'},
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final list = json.decode(res.body) as List<dynamic>;
        if (list.isNotEmpty) {
          final first = list.first as Map<String, dynamic>;
          final lat = double.tryParse(first['lat']?.toString() ?? '');
          final lng = double.tryParse(first['lon']?.toString() ?? '');
          if (lat != null && lng != null && _isValidLat(lat) && _isValidLng(lng)) {
            return ParsedCoordinates(
              latitude: lat,
              longitude: lng,
              placeName: placeName,
              source: 'nominatim_fallback',
            );
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Reverse geocodes coordinates to structured address details (country, state, district, city).
  /// Works globally — supporting Indian states/districts as well as international countries.
  Future<ReverseGeocodeResult?> reverseGeocodeDetails(
    double latitude,
    double longitude,
  ) async {
    // 1. Try OpenStreetMap Nominatim with addressdetails=1
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&zoom=18&addressdetails=1',
      );
      final res = await _client.get(
        uri,
        headers: {'User-Agent': 'iStudio-Photography-App/1.0'},
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final displayName = data['display_name'] as String? ?? '';
        final addr = data['address'] as Map<String, dynamic>? ?? {};

        final country = addr['country'] as String?;
        final countryCode = addr['country_code'] as String?;
        final isIndia = (country?.toLowerCase() == 'india') ||
            (countryCode?.toLowerCase() == 'in');

        final state = addr['state'] as String? ??
            addr['province'] as String? ??
            addr['region'] as String? ??
            addr['state_district'] as String?;

        final rawDistrict = addr['district'] as String? ??
            addr['county'] as String? ??
            addr['state_district'] as String? ??
            addr['city_district'] as String? ??
            addr['city'] as String?;

        var district = rawDistrict;
        if (isIndia && district != null) {
          district = district
              .replaceAll(
                RegExp(
                  r'\s+(district|mandal|county|zone|division)$',
                  caseSensitive: false,
                ),
                '',
              )
              .trim();
        }

        final city = addr['city'] as String? ??
            addr['town'] as String? ??
            addr['village'] as String? ??
            addr['municipality'] as String? ??
            addr['suburb'] as String? ??
            district;

        String formattedName = displayName;
        if (formattedName.isNotEmpty) {
          final parts =
              formattedName.split(',').map((s) => s.trim()).toList();
          if (parts.length > 3) {
            formattedName = parts.take(3).join(', ');
          }
        }

        return ReverseGeocodeResult(
          displayName: formattedName.isNotEmpty
              ? formattedName
              : '$latitude, $longitude',
          city: city?.trim().isNotEmpty == true ? city!.trim() : null,
          state: state?.trim().isNotEmpty == true ? state!.trim() : null,
          district:
              district?.trim().isNotEmpty == true ? district!.trim() : null,
          country: country?.trim().isNotEmpty == true ? country!.trim() : null,
          countryCode: countryCode?.trim().isNotEmpty == true
              ? countryCode!.trim().toLowerCase()
              : null,
        );
      }
    } catch (_) {}

    // 2. Fallback to Photon reverse geocode
    try {
      final uri = Uri.parse(
        'https://photon.komoot.io/reverse?lat=$latitude&lon=$longitude',
      );
      final res = await _client.get(
        uri,
        headers: {'User-Agent': 'iStudio-Photography-App/1.0'},
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>?;
        if (features != null && features.isNotEmpty) {
          final props = (features.first
                  as Map<String, dynamic>)['properties']
              as Map<String, dynamic>? ??
              {};

          final name = props['name'] as String? ?? '';
          final street = props['street'] as String? ?? '';
          final city = props['city'] as String? ?? props['locality'] as String?;
          final district =
              props['district'] as String? ?? props['county'] as String?;
          final state = props['state'] as String?;
          final country = props['country'] as String?;
          final countryCode = props['countrycode'] as String?;

          final parts = [name, street, city]
              .where((p) => p != null && p.trim().isNotEmpty)
              .toList();
          final formattedName = parts.isNotEmpty
              ? parts.join(', ')
              : '$latitude, $longitude';

          return ReverseGeocodeResult(
            displayName: formattedName,
            city: city?.trim().isNotEmpty == true ? city!.trim() : null,
            state: state?.trim().isNotEmpty == true ? state!.trim() : null,
            district:
                district?.trim().isNotEmpty == true ? district!.trim() : null,
            country:
                country?.trim().isNotEmpty == true ? country!.trim() : null,
            countryCode: countryCode?.trim().isNotEmpty == true
                ? countryCode!.trim().toLowerCase()
                : null,
          );
        }
      }
    } catch (_) {}

    return null;
  }

  /// Reverse geocodes coordinates to a human-friendly address string.
  Future<String?> reverseGeocode(double latitude, double longitude) async {
    final details = await reverseGeocodeDetails(latitude, longitude);
    return details?.displayName;
  }

  static String? _extractPlaceName(String url) {
    try {
      final match = _placeNameRegex.firstMatch(url);
      if (match != null) {
        final raw = match.group(1)!;
        return Uri.decodeComponent(raw.replaceAll('+', ' ')).trim();
      }
    } catch (_) {}
    return null;
  }

  static bool _isValidLat(double lat) => lat >= -90.0 && lat <= 90.0;
  static bool _isValidLng(double lng) => lng >= -180.0 && lng <= 180.0;
}
