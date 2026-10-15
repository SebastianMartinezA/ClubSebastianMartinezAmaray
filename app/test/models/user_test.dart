import 'package:club_sebastian_martinez_amaray/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('User.fromJson', () {
    test('parses the user returned by /auth/login', () {
      final User user = User.fromJson(<String, dynamic>{
        'id': 2,
        'email': 'maria@club.com',
        'first_name': 'María',
        'last_name': 'Lopez',
        'birth_date': '1996-03-08',
        'created_at': '2026-10-14T22:12:52.123456Z',
      });

      expect(user.id, 2);
      expect(user.email, 'maria@club.com');
      expect(user.firstName, 'María');
      expect(user.lastName, 'Lopez');
      expect(user.fullName, 'María Lopez');
      expect(user.displayName, 'María');
      expect(user.birthDate?.year, 1996);
      expect(user.birthDate?.month, 3);
      expect(user.birthDate?.day, 8);
      expect(user.createdAt?.isUtc, isTrue);
    });

    test('accepts a null birth_date (the field is nullable in the API)', () {
      final User user = User.fromJson(<String, dynamic>{
        'id': 7,
        'email': 'sin.fecha@club.com',
        'first_name': 'Ana',
        'last_name': 'Perez',
        'birth_date': null,
        'created_at': '2026-10-14T22:12:52.123456Z',
      });

      expect(user.birthDate, isNull);
      expect(user.fullName, 'Ana Perez');
    });
  });

  group('User.toJson', () {
    test('keeps the exact field names of the API', () {
      final User user = User.fromJson(<String, dynamic>{
        'id': 2,
        'email': 'maria@club.com',
        'first_name': 'María',
        'last_name': 'Lopez',
        'birth_date': '1996-03-08',
        'created_at': '2026-10-14T22:12:52.123456Z',
      });
      final Map<String, dynamic> json = user.toJson();

      expect(json.keys, contains('first_name'));
      expect(json.keys, contains('last_name'));
      expect(json.keys, contains('birth_date'));
      expect(json.keys, contains('created_at'));
      expect(json['birth_date'], '1996-03-08');
      expect(json['email'], 'maria@club.com');
    });

    test('copyWith replaces only the given fields', () {
      final User user = User.fromJson(<String, dynamic>{
        'id': 2,
        'email': 'maria@club.com',
        'first_name': 'María',
        'last_name': 'Lopez',
        'birth_date': '1996-03-08',
      });
      final User updated = user.copyWith(firstName: 'Mariana');

      expect(updated.firstName, 'Mariana');
      expect(updated.lastName, 'Lopez');
      expect(updated.email, 'maria@club.com');
      expect(updated.birthDate?.year, 1996);
    });
  });
}
