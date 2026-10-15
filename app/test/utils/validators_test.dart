import 'package:club_sebastian_martinez_amaray/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.email', () {
    test('accepts a well formed address', () {
      expect(Validators.email('maria@club.com'), isNull);
      expect(Validators.email('maria.lopez+reserva@club.com.ar'), isNull);
    });

    test('rejects an empty value', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email(null), isNotNull);
    });

    test('rejects a malformed address', () {
      expect(Validators.email('maria'), isNotNull);
      expect(Validators.email('maria@'), isNotNull);
      expect(Validators.email('@club.com'), isNotNull);
    });
  });

  group('Validators.newPassword', () {
    test('accepts 8 characters or more (the API minimum)', () {
      expect(Validators.minPasswordLength, 8);
      expect(Validators.newPassword('Secreta123'), isNull);
    });

    test('rejects a short password', () {
      expect(Validators.newPassword('Secreta'), isNotNull);
      expect(Validators.newPassword(''), isNotNull);
    });
  });

  group('Validators.password', () {
    test('only requires a value (login)', () {
      expect(Validators.password('abc'), isNull);
      expect(Validators.password(''), isNotNull);
    });
  });

  group('Validators.matches', () {
    test('checks the repeated password', () {
      expect(Validators.matches('Secreta123', 'Secreta123', 'x'), isNull);
      expect(
        Validators.matches('Secreta123', 'Secreta124', 'x'),
        'Las contraseñas no coinciden.',
      );
    });
  });

  group('Validators.resetToken', () {
    test('accepts the token of the API', () {
      expect(
        Validators.resetToken('6fNa8JxywwKY-F-FHGRO5Bx6emx0Wd21dfNDMapUnXI'),
        isNull,
      );
    });

    test('rejects an empty or too short token', () {
      expect(Validators.resetToken(''), isNotNull);
      expect(Validators.resetToken('abc'), isNotNull);
    });
  });

  group('Validators.required', () {
    test('names the missing field in the message', () {
      expect(Validators.required('', 'tu nombre'), 'Completá tu nombre.');
      expect(Validators.required('María', 'tu nombre'), isNull);
    });
  });
}
