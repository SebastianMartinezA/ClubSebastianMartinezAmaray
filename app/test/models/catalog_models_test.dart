import 'package:club_sebastian_martinez_amaray/models/availability.dart';
import 'package:club_sebastian_martinez_amaray/models/sport_space.dart';
import 'package:club_sebastian_martinez_amaray/models/venue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Venue.fromJson', () {
    test('parses the venue with its opening hours', () {
      final Venue venue = Venue.fromJson(<String, dynamic>{
        'id': 1,
        'name': 'Moron',
        'address': 'Rivadavia 19850',
        'opening_time': '08:00:00',
        'closing_time': '22:00:00',
      });

      expect(venue.id, 1);
      expect(venue.name, 'Moron');
      expect(venue.address, 'Rivadavia 19850');
      expect(venue.openingTime, '08:00:00');
      expect(venue.closingTime, '22:00:00');
      expect(venue.toJson()['opening_time'], '08:00:00');
    });
  });

  group('SportSpace.fromJson', () {
    test('parses the space of GET /venues/1/spaces', () {
      final SportSpace space = SportSpace.fromJson(<String, dynamic>{
        'id': 1,
        'venue_id': 1,
        'venue_name': 'Moron',
        'name': 'Moron_Rivadavia_19850_Paddle_1',
        'space_type': 'Paddle',
        'number': 1,
      });

      expect(space.id, 1);
      expect(space.venueId, 1);
      expect(space.venueName, 'Moron');
      expect(space.name, 'Moron_Rivadavia_19850_Paddle_1');
      expect(space.spaceType, SpaceTypes.paddle);
      expect(space.number, 1);
      expect(space.displayName, 'Paddle 1');
    });
  });

  group('VenueAvailability.fromJson', () {
    test('parses the slots of every space and their available flag', () {
      final VenueAvailability availability =
          VenueAvailability.fromJson(<String, dynamic>{
        'venue': <String, dynamic>{
          'id': 1,
          'name': 'Moron',
          'address': 'Rivadavia 19850',
          'opening_time': '08:00:00',
          'closing_time': '22:00:00',
        },
        'date': '2026-10-17',
        'spaces': <Map<String, dynamic>>[
          <String, dynamic>{
            'space': <String, dynamic>{
              'id': 3,
              'venue_id': 1,
              'venue_name': 'Moron',
              'name': 'Moron_Rivadavia_19850_Futbol_1',
              'space_type': 'Futbol',
              'number': 1,
            },
            'slots': <Map<String, dynamic>>[
              <String, dynamic>{
                'start_time': '08:00:00',
                'end_time': '09:00:00',
                'available': true,
              },
              <String, dynamic>{
                'start_time': '10:00:00',
                'end_time': '11:00:00',
                'available': false,
              },
              <String, dynamic>{
                'start_time': '21:00:00',
                'end_time': '22:00:00',
                'available': true,
              },
            ],
          },
        ],
      });

      expect(availability.date, '2026-10-17');
      expect(availability.venue.name, 'Moron');
      expect(availability.spaces.length, 1);

      final SpaceAvailability space = availability.spaces.first;
      expect(space.space.id, 3);
      expect(space.slots.length, 3);
      expect(space.slots.first.startTime, '08:00:00');
      expect(space.slots.first.available, isTrue);
      expect(space.slots[1].available, isFalse);
      expect(space.availableSlots.length, 2);
      expect(space.hasFreeSlots, isTrue);
      expect(availability.slotsOf(3).length, 3);
      expect(availability.slotsOf(99), isEmpty);
    });

    test('survives a space without slots and a missing list', () {
      final VenueAvailability availability =
          VenueAvailability.fromJson(<String, dynamic>{
        'venue': <String, dynamic>{
          'id': 1,
          'name': 'Moron',
          'address': 'Rivadavia 19850',
          'opening_time': '08:00:00',
          'closing_time': '22:00:00',
        },
        'date': '2026-10-17',
      });

      expect(availability.spaces, isEmpty);
    });

    test('hasFreeSlots is false when every slot is taken', () {
      final SpaceAvailability space =
          SpaceAvailability.fromJson(<String, dynamic>{
        'space': <String, dynamic>{
          'id': 3,
          'venue_id': 1,
          'venue_name': 'Moron',
          'name': 'Moron_Rivadavia_19850_Futbol_1',
          'space_type': 'Futbol',
          'number': 1,
        },
        'slots': <Map<String, dynamic>>[
          <String, dynamic>{
            'start_time': '08:00:00',
            'end_time': '09:00:00',
            'available': false,
          },
        ],
      });

      expect(space.hasFreeSlots, isFalse);
      expect(space.availableSlots, isEmpty);
    });
  });
}
