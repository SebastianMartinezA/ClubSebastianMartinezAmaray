import 'package:club_sebastian_martinez_amaray/screens/reservations_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../helpers/test_helpers.dart';

void main() {
  testWidgets('lista las reservas vigentes con su horario', (
    WidgetTester tester,
  ) async {
    final TestApp app = TestApp((http.Request request) async {
      if (request.url.path == '/auth/login') {
        return jsonResponse(tokenResponseJson());
      }
      if (request.url.path == '/reservations') {
        return jsonResponse(<Object>[
          reservationJson(
            spaceName: 'Moron_Rivadavia_19850_Futbol_1',
            startTime: '10:00:00',
            endTime: '11:00:00',
          ),
        ]);
      }
      return jsonResponse(<String, dynamic>{});
    });
    await app.signIn();

    await tester.pumpWidget(app.wrap(const ReservationsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Moron_Rivadavia_19850_Futbol_1'), findsOneWidget);
    expect(find.text('Moron'), findsOneWidget);
    expect(find.text('10:00 a 11:00'), findsOneWidget);
    expect(find.text('Activa'), findsOneWidget);
  });

  testWidgets('cancelar pide confirmación y recarga la lista', (
    WidgetTester tester,
  ) async {
    bool cancelled = false;
    final TestApp app = TestApp((http.Request request) async {
      if (request.url.path == '/auth/login') {
        return jsonResponse(tokenResponseJson());
      }
      if (request.url.path == '/reservations/1/cancel') {
        cancelled = true;
        return jsonResponse(
          reservationJson(
            status: 'cancelled',
            cancelledAt: '2026-10-15T10:00:00Z',
          ),
        );
      }
      if (request.url.path == '/reservations') {
        return jsonResponse(
          cancelled ? <Object>[] : <Object>[reservationJson()],
        );
      }
      return jsonResponse(<String, dynamic>{});
    });
    await app.signIn();

    await tester.pumpWidget(app.wrap(const ReservationsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Cancelar reserva'), findsOneWidget);

    await tester.tap(find.text('Cancelar reserva'));
    await tester.pumpAndSettle();

    expect(find.text('¿Cancelar la reserva?'), findsOneWidget);

    await tester.tap(find.text('Sí, cancelar'));
    await tester.pumpAndSettle();

    expect(cancelled, isTrue);
    expect(find.text('No tenés reservas vigentes.'), findsOneWidget);
  });

  testWidgets('si el usuario no confirma, la reserva no se cancela', (
    WidgetTester tester,
  ) async {
    final TestApp app = TestApp((http.Request request) async {
      if (request.url.path == '/auth/login') {
        return jsonResponse(tokenResponseJson());
      }
      if (request.url.path == '/reservations') {
        return jsonResponse(<Object>[reservationJson()]);
      }
      return jsonResponse(<String, dynamic>{});
    });
    await app.signIn();

    await tester.pumpWidget(app.wrap(const ReservationsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar reserva'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();

    expect(app.backend.requestsFor('/reservations/1/cancel'), isEmpty);
    expect(find.text('Moron_Rivadavia_19850_Futbol_1'), findsOneWidget);
  });

  testWidgets('muestra el estado vacío', (WidgetTester tester) async {
    final TestApp app = TestApp((http.Request request) async {
      if (request.url.path == '/auth/login') {
        return jsonResponse(tokenResponseJson());
      }
      return jsonResponse(<Object>[]);
    });
    await app.signIn();

    await tester.pumpWidget(app.wrap(const ReservationsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('No tenés reservas vigentes.'), findsOneWidget);
  });
}
