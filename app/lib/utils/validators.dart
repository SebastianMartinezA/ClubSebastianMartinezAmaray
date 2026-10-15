/// Form validation helpers (pure Dart, unit tested in `test/utils/`).
class Validators {
  Validators._();

  static final RegExp _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

  /// Minimum password length accepted by `POST /auth/register`
  /// (`minLength: 8` in the OpenAPI schema).
  static const int minPasswordLength = 8;

  static String? email(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Ingresá tu correo electrónico.';
    }
    if (!_emailPattern.hasMatch(text)) {
      return 'Ingresá un correo válido (por ejemplo nombre@dominio.com).';
    }
    return null;
  }

  static String? required(String? value, String label) {
    if ((value ?? '').trim().isEmpty) {
      return 'Completá $label.';
    }
    return null;
  }

  /// Registration / reset password rule: at least [minPasswordLength].
  static String? newPassword(String? value) {
    final String text = value ?? '';
    if (text.isEmpty) {
      return 'Ingresá una contraseña.';
    }
    if (text.length < minPasswordLength) {
      return 'La contraseña tiene que tener al menos $minPasswordLength caracteres.';
    }
    return null;
  }

  /// Login rule: only non-empty is required (the API decides the rest).
  static String? password(String? value) {
    if ((value ?? '').isEmpty) {
      return 'Ingresá tu contraseña.';
    }
    return null;
  }

  static String? matches(String? value, String other, String label) {
    if ((value ?? '') != other) {
      return 'Las contraseñas no coinciden.';
    }
    return null;
  }

  /// Reset token sent by `POST /auth/forgot-password` (`minLength: 8`).
  static String? resetToken(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Pegá el código que te llegó por correo.';
    }
    if (text.length < 8) {
      return 'El código no es válido.';
    }
    return null;
  }
}
