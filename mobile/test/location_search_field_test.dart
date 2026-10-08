import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumen_studio/app/services/location_search_service.dart';
import 'package:lumen_studio/app/widgets/location_search_field.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('selecting a venue reports its geocoded coordinates', (
    tester,
  ) async {
    final controller = TextEditingController();
    PlaceLocation? selectedPlace;
    var coordinatesCleared = false;
    final service = LocationSearchService(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'features': [
              {
                'properties': {'name': 'Test Venue', 'city': 'Hyderabad'},
                'geometry': {
                  'coordinates': [78.4867, 17.385],
                },
              },
            ],
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationSearchField(
            label: 'Location / Venue',
            controller: controller,
            locationSearchService: service,
            onLocationSelected: (place) => selectedPlace = place,
            onCoordinatesCleared: () => coordinatesCleared = true,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'Test Venue');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test Venue').last);
    await tester.pumpAndSettle();

    expect(selectedPlace?.latitude, 17.385);
    expect(selectedPlace?.longitude, 78.4867);
    expect(controller.text, 'Test Venue, Hyderabad');

    await tester.enterText(find.byType(TextFormField), 'Different venue');
    expect(coordinatesCleared, isTrue);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
