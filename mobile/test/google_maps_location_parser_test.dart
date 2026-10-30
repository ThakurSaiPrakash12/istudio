import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_studio/app/utils/google_maps_location_parser.dart';

void main() {
  group('GoogleMapsLocationParser Tests', () {
    test('parses raw comma-separated coordinates', () {
      final res = GoogleMapsLocationParser.parseSync('17.372605, 78.459720');
      expect(res, isNotNull);
      expect(res!.latitude, closeTo(17.372605, 0.000001));
      expect(res.longitude, closeTo(78.459720, 0.000001));
    });

    test('parses raw space-separated coordinates', () {
      final res = GoogleMapsLocationParser.parseSync('17.372605 78.459720');
      expect(res, isNotNull);
      expect(res!.latitude, closeTo(17.372605, 0.000001));
      expect(res.longitude, closeTo(78.459720, 0.000001));
    });

    test('parses Google Maps URL with @lat,lng', () {
      const url =
          'https://www.google.com/maps/place/Satyanarayan+Patang+Ghar/@17.372605,78.459720,17z/data=!3m1!4b1';
      final res = GoogleMapsLocationParser.parseSync(url);
      expect(res, isNotNull);
      expect(res!.latitude, closeTo(17.372605, 0.000001));
      expect(res.longitude, closeTo(78.459720, 0.000001));
      expect(res.placeName, equals('Satyanarayan Patang Ghar'));
    });

    test('parses Google Maps query URL with ?q=lat,lng', () {
      const url = 'https://maps.google.com/?q=17.372605,78.459720';
      final res = GoogleMapsLocationParser.parseSync(url);
      expect(res, isNotNull);
      expect(res!.latitude, closeTo(17.372605, 0.000001));
      expect(res.longitude, closeTo(78.459720, 0.000001));
    });

    test('parses Google Maps search URL', () {
      const url = 'https://www.google.com/maps/search/17.372605,+78.459720?entry=tts';
      final res = GoogleMapsLocationParser.parseSync(url);
      expect(res, isNotNull);
      expect(res!.latitude, closeTo(17.372605, 0.000001));
      expect(res.longitude, closeTo(78.459720, 0.000001));
    });

    test('parses DMS coordinates format', () {
      const dms = '''17°22'21.4"N 78°27'35.0"E''';
      final res = GoogleMapsLocationParser.parseSync(dms);
      expect(res, isNotNull);
      expect(res!.latitude, closeTo(17.372611, 0.001));
      expect(res.longitude, closeTo(78.459722, 0.001));
    });

    test('normalizes input without https prefix', () {
      const input = 'maps.app.goo.gl/ttQaX1XkSeW4pXxk7';
      final normalized = GoogleMapsLocationParser.normalizeInput(input);
      expect(normalized, equals('https://maps.app.goo.gl/ttQaX1XkSeW4pXxk7'));
    });

    test('normalizes input surrounded by text message', () {
      const input = 'Check out this venue: https://maps.app.goo.gl/ttQaX1XkSeW4pXxk7 for the shoot';
      final normalized = GoogleMapsLocationParser.normalizeInput(input);
      expect(normalized, equals('https://maps.app.goo.gl/ttQaX1XkSeW4pXxk7'));
    });

    test('validates Google Maps URLs correctly', () {
      expect(GoogleMapsLocationParser.isGoogleMapsUrl('https://maps.app.goo.gl/ttQaX1XkSeW4pXxk7'), isTrue);
      expect(GoogleMapsLocationParser.isGoogleMapsUrl('maps.app.goo.gl/ttQaX1XkSeW4pXxk7'), isTrue);
      expect(GoogleMapsLocationParser.isGoogleMapsUrl('https://goo.gl/maps/12345'), isTrue);
      expect(GoogleMapsLocationParser.isGoogleMapsUrl('https://www.google.com/maps/place/xyz'), isTrue);
      expect(GoogleMapsLocationParser.isGoogleMapsUrl('Hyderabad, India'), isFalse);
      expect(GoogleMapsLocationParser.isGoogleMapsUrl('https://example.com'), isFalse);
      expect(GoogleMapsLocationParser.isGoogleMapsUrl(''), isFalse);
    });

    test('reverseGeocodeDetails returns structured location details', () async {
      final parser = GoogleMapsLocationParser();
      // Cupertino location (outside India)
      final res = await parser.reverseGeocodeDetails(37.33182, -122.03118);
      if (res != null) {
        expect(res.displayName.isNotEmpty, isTrue);
        expect(res.country, equals('United States'));
        expect(res.state, equals('California'));
      }
    });
  });
}
