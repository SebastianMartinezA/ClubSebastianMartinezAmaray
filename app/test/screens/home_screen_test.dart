import 'package:club_sebastian_martinez_amaray/screens/home_screen.dart';
import 'package:club_sebastian_martinez_amaray/screens/reservations_screen.dart';
import 'package:club_sebastian_martinez_amaray/screens/venues_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../helpers/test_helpers.dart';

void main() {
  testWidgets('saluda al usuario y muestra sus próximas reservas', (
    WidgetTester tester,
  ) async {
    final TestApp app = TestApp((http.Request request) async {
      if (request.url.path == '/auth/login') {
        return jsonResponse(tokenResponseJson());
      }
      if (request.url.path == '/reservations') {
        return jsonResponse(<Object>[
          reservationJson(spaceName: 'Moron_Rivadavia_19850_Paddle_1'),
        ]);
      }
      return jsonResponse(<String, dynamic>{});
    });
    await app.signIn();

    await tester.pumpWidget(app.wrap(const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Hola, María'), findsOneWidget);
    expect(find.text('Próximas reservas'), findsOneWidget);
    expect(find.text('Moron_Rivadavia_19850_Paddle_1'), findsOneWidget);
    expect(find.text('Sedes'), findsOneWidget);
    expect(find.text('Mis reservas'), findsOneWidget);
    expect(find.text('Historial'), findsOneWidget);
  });

  testWidgets('muestra un mensaje cuando no hay reservas próximas', (
    WidgetTester tester,
  ) async {
    final TestApp app = TestApp((http.Request request) async {
      if (request.url.path == '/auth/login') {
        return jsonResponse(tokenResponseJson());
      }
      return jsonResponse(<Object>[]);
    });
    await app.signIn();

    await tester.pumpWidget(app.wrap(const HomeScreen()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('No tenés reservas próximas'),
      findsOneWidget,
    );
  });

  testWidgets('muestra el error de conexión y permite reintentar', (
    WidgetTester tester,
  ) async {
    bool online = false;
    final TestApp app = TestApp((http.Request request) async {
      if (request.url.path == '/auth/login') {
        return jsonResponse(tokenResponseJson());
      }
      if (request.url.path == '/reservations') {
        if (!online) {
          throw http.ClientException('Connection refused');
        }
        return jsonResponse(<Object>[reservationJson()]);
      }
      return jsonResponse(<String, dynamic>{});
    });
    await app.signIn();

    await tester.pumpWidget(app.wrap(const HomeScreen()));
    await tester.pumpAndSettle();

    expect(
      find.text('No pudimos conectarnos con el servidor. Revisá tu conexión.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);

    // The server comes back: the retry button reloads the screen.
    online = true;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Moron_Rivadavia_19850_Futbol_1'), findsOneWidget);
  });

  testWidgets('navega a la pantalla de sedes', (WidgetTester tester) async {
    final TestApp app = TestApp((http.Request request) async {
      if (request.url.path == '/auth/login') {
        return jsonResponse(tokenResponseJson());
      }
      if (request.url.path == '/reservations') {
        return jsonResponse(<Object>[]);
      }
      if (request.url.path == '/venues') {
        return jsonResponse(<Object>[venueJson()]);
      }
      return jsonResponse(<String, dynamic>{});
    });
    await app.signIn();

    await tester.pumpWidget(app.wrap(const HomeScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sedes'));
    await tester.pumpAndSettle();

    expect(find.byType(VenuesScreen), findsOneWidget);
    expect(find.text('Moron'), findsOneWidget);
    expect(find.text('Rivadavia 19850'), findsOneWidget);
    expect(find.textContaining('Abierta de 08:00 a 22:00'), findsOneWidget);
  });

  testWidgets('navega a mis reservas', (WidgetTester tester) async {
    final TestApp app = TestApp((http.Request request) async {
      if (request.url.path == '/auth/login') {
        return jsonResponse(tokenResponseJson());
      }
      return jsonResponse(<Object>[reservationJson()]);
    });
    await app.signIn();

    await tester.pumpWidget(app.wrap(const HomeScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mis reservas'));
    await tester.pumpAndSettle();

    expect(find.byType(ReservationsScreen), findsOneWidget);
    expect(find.text('Cancelar reserva'), findsOneWidget);
  });
}
