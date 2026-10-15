import 'package:club_sebastian_martinez_amaray/models/availability.dart';
import 'package:club_sebastian_martinez_amaray/models/sport_space.dart';
import 'package:club_sebastian_martinez_amaray/models/venue.dart';
import 'package:club_sebastian_martinez_amaray/services/api_client.dart';
import 'package:club_sebastian_martinez_amaray/services/catalog_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../helpers/test_helpers.dart';

void main() {
  CatalogService buildCatalog(FakeBackend backend) {
    return CatalogService(
      ApiClient(baseUrl: 'http://test.local', client: backend.client),
    );
  }

  group('venues', () {
    test('GET /venues', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(<Object>[
          venueJson(),
          venueJson(
            id: 2,
            name: 'Castelar',
            address: 'Av. Yrigoyen 1234',
            openingTime: '09:00:00',
            closingTime: '23:00:00',
          ),
        ]),
      );
      final CatalogService catalog = buildCatalog(backend);

      final List<Venue> venues = await catalog.venues();

      expect(backend.lastRequest.url.path, '/venues');
      expect(venues.length, 2);
      expect(venues.first.name, 'Moron');
      expect(venues.last.address, 'Av. Yrigoyen 1234');
      expect(venues.last.closingTime, '23:00:00');
    });

    test('GET /venues/{id}', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(venueJson()),
      );
      final CatalogService catalog = buildCatalog(backend);

      final Venue venue = await catalog.venue(1);

      expect(backend.lastRequest.url.path, '/venues/1');
      expect(venue.openingTime, '08:00:00');
    });
  });

  group('spaces', () {
    test('GET /venues/{id}/spaces', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(<Object>[spaceJson()]),
      );
      final CatalogService catalog = buildCatalog(backend);

      final List<SportSpace> spaces = await catalog.venueSpaces(1);

      expect(backend.lastRequest.url.path, '/venues/1/spaces');
      expect(spaces.single.name, 'Moron_Rivadavia_19850_Futbol_1');
    });

    test('GET /spaces sends the type filter', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(<Object>[
          spaceJson(spaceType: 'Paddle', name: 'Moron_Rivadavia_19850_Paddle_1'),
        ]),
      );
      final CatalogService catalog = buildCatalog(backend);

      final List<SportSpace> spaces = await catalog.spaces(type: 'Paddle');

      expect(backend.lastRequest.url.path, '/spaces');
      expect(backend.lastRequest.url.queryParameters['type'], 'Paddle');
      expect(spaces.single.spaceType, 'Paddle');
    });

    test('GET /spaces sends the venue_id filter too', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(<Object>[spaceJson()]),
      );
      final CatalogService catalog = buildCatalog(backend);

      await catalog.spaces(type: 'Futbol', venueId: 1);

      expect(backend.lastRequest.url.queryParameters['venue_id'], '1');
      expect(backend.lastRequest.url.queryParameters['type'], 'Futbol');
    });

    test('GET /spaces without filters sends no query', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(<Object>[spaceJson()]),
      );
      final CatalogService catalog = buildCatalog(backend);

      await catalog.spaces();

      expect(backend.lastRequest.url.queryParameters, isEmpty);
    });

    test('GET /spaces/{id}', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(spaceJson()),
      );
      final CatalogService catalog = buildCatalog(backend);

      final SportSpace space = await catalog.space(3);

      expect(backend.lastRequest.url.path, '/spaces/3');
      expect(space.venueId, 1);
    });
  });

  group('availability', () {
    test('GET /venues/{id}/availability sends the date as YYYY-MM-DD', () async {
      final FakeBackend backend = FakeBackend(
        (http.Request request) async => jsonResponse(availabilityJson()),
      );
      final CatalogService catalog = buildCatalog(backend);

      final VenueAvailability availability = await catalog.availability(
        venueId: 1,
        date: DateTime(2026, 10, 17),
      );

      expect(backend.lastRequest.url.path, '/venues/1/availability');
      expect(backend.lastRequest.url.queryParameters['date'], '2026-10-17');
      expect(availability.date, '2026-10-17');
      expect(availability.spaces.single.slots.length, 3);
      expect(availability.spaces.single.availableSlots.length, 2);
    });
  });
}
