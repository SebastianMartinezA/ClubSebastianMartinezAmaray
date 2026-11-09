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
    test('accepts a six digit code from the API', () {
      expect(Validators.resetToken('123456'), isNull);
      expect(Validators.resetToken(' 000001 '), isNull);
    });

    test('rejects anything that is not six digits', () {
      expect(Validators.resetToken(''), isNotNull);
      expect(Validators.resetToken('12345'), isNotNull);
      expect(Validators.resetToken('1234567'), isNotNull);
      expect(Validators.resetToken('abc123'), isNotNull);
    });
  });

  group('Validators.required', () {
    test('names the missing field in the message', () {
      expect(Validators.required('', 'tu nombre'), 'Completá tu nombre.');
      expect(Validators.required('María', 'tu nombre'), isNull);
    });
  });
}
