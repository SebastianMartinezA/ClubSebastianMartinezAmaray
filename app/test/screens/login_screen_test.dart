import 'dart:async';

import 'package:club_sebastian_martinez_amaray/screens/home_screen.dart';
import 'package:club_sebastian_martinez_amaray/screens/login_screen.dart';
import 'package:club_sebastian_martinez_amaray/screens/register_screen.dart';
import 'package:club_sebastian_martinez_amaray/services/auth_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../helpers/test_helpers.dart';

void main() {
  /// Backend falso: la API contesta el perfil del usuario y las reservas del home.
  /// La credencial la resuelve el `FakeAuthBackend` que arma `TestApp`.
  FutureOr<http.Response> Function(http.Request) backendWithLogin() {
    return (http.Request request) async {
      if (request.url.path == '/users/me') {
        return jsonResponse(userJson());
      }
      if (request.url.path == '/reservations') {
        return jsonResponse(<Object>[]);
      }
      return jsonResponse(<String, dynamic>{});
    };
  }

  testWidgets('muestra los campos de correo y contraseña', (
    WidgetTester tester,
  ) async {
    final TestApp app = TestApp(backendWithLogin());

    await tester.pumpWidget(app.wrap(const LoginScreen()));

    expect(find.text('Ingresá para reservar tu espacio'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Ingresar'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('Olvidé mi contraseña'), findsOneWidget);
  });

  testWidgets('valida que el correo y la contraseña no estén vacíos', (
    WidgetTester tester,
  ) async {
    final TestApp app = TestApp(backendWithLogin());

    await tester.pumpWidget(app.wrap(const LoginScreen()));
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresá tu correo electrónico.'), findsOneWidget);
    expect(find.text('Ingresá tu contraseña.'), findsOneWidget);
    // No request was sent: the form was not valid.
    expect(app.backend.requests.isEmpty, isTrue);
  });

  testWidgets('muestra el error cuando las credenciales son incorrectas', (
    WidgetTester tester,
  ) async {
    // La credencial la rechaza el proveedor de autenticación, no la API.
    final TestApp app = TestApp(
      backendWithLogin(),
      authBackend: FakeAuthBackend(
        loginError: const AuthBackendException('wrong-password'),
      ),
    );

    await tester.pumpWidget(app.wrap(const LoginScreen()));
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'maria@club.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'malaClave');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(
      find.text('El correo o la contraseña son incorrectos.'),
      findsOneWidget,
    );
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('muestra el error de conexión cuando el servidor no responde', (
    WidgetTester tester,
  ) async {
    // Simulates a server that is down: the request itself fails.
    final TestApp offline = TestApp((http.Request request) {
      throw http.ClientException('Connection refused');
    });

    await tester.pumpWidget(offline.wrap(const LoginScreen()));
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'maria@club.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Secreta123');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(
      find.text('No pudimos conectarnos con el servidor. Revisá tu conexión.'),
      findsOneWidget,
    );
  });

  testWidgets('entra al inicio cuando el login es correcto', (
    WidgetTester tester,
  ) async {
    final TestApp app = TestApp(backendWithLogin());

    await tester.pumpWidget(app.wrap(const LoginScreen()));
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'maria@club.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Secreta123');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Hola, María'), findsOneWidget);
    expect(app.session.isAuthenticated, isTrue);
  });

  testWidgets('abre la pantalla de registro', (WidgetTester tester) async {
    final TestApp app = TestApp(backendWithLogin());

    await tester.pumpWidget(app.wrap(const LoginScreen()));
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.text('Crear mi cuenta'), findsOneWidget);
  });
}
