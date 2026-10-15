import 'package:club_sebastian_martinez_amaray/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toIsoDate', () {
    test('formats with the YYYY-MM-DD the API expects', () {
      expect(Formatters.toIsoDate(DateTime(2026, 10, 17)), '2026-10-17');
    });

    test('pads month and day with a leading zero', () {
      expect(Formatters.toIsoDate(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('parseIsoDate round trips', () {
      final DateTime? parsed = Formatters.parseIsoDate('2026-10-17');

      expect(parsed, isNotNull);
      expect(parsed!.year, 2026);
      expect(Formatters.toIsoDate(parsed), '2026-10-17');
      expect(Formatters.parseIsoDate(null), isNull);
      expect(Formatters.parseIsoDate(''), isNull);
    });
  });

  group('date', () {
    test('formats as dd/MM/yyyy', () {
      expect(Formatters.date(DateTime(2026, 10, 17)), '17/10/2026');
    });

    test('longDate spells the day in Spanish', () {
      // 2026-10-17 is a Saturday.
      expect(
        Formatters.longDate(DateTime(2026, 10, 17)),
        'sábado 17 de octubre de 2026',
      );
    });

    test('longDate for the demo date of the API', () {
      expect(
        Formatters.longDate(DateTime(2026, 1, 1)),
        'jueves 1 de enero de 2026',
      );
    });
  });

  group('time', () {
    test('turns 20:00:00 into 20:00', () {
      expect(Formatters.time('20:00:00'), '20:00');
      expect(Formatters.time('08:00:00'), '08:00');
    });

    test('tolerates a value without seconds', () {
      expect(Formatters.time('09:30'), '09:30');
    });

    test('timeRange builds the label of a booking', () {
      expect(
        Formatters.timeRange('10:00:00', '11:00:00'),
        '10:00 a 11:00',
      );
    });
  });

  group('durations', () {
    test('hoursBetween returns whole hours', () {
      expect(Formatters.hoursBetween('10:00:00', '11:00:00'), 1);
      expect(Formatters.hoursBetween('10:00:00', '13:00:00'), 3);
    });

    test('hoursBetween never returns less than one hour', () {
      expect(Formatters.hoursBetween('10:00:00', '10:30:00'), 1);
    });

    test('addHours walks the one-hour grid', () {
      expect(Formatters.addHours('10:00:00', 1), '11:00:00');
      expect(Formatters.addHours('21:00:00', 1), '22:00:00');
    });
  });
}
