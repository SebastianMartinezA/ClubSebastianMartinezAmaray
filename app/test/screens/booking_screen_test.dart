import 'package:club_sebastian_martinez_amaray/models/availability.dart';
import 'package:club_sebastian_martinez_amaray/models/sport_space.dart';
import 'package:club_sebastian_martinez_amaray/models/venue.dart';
import 'package:club_sebastian_martinez_amaray/screens/booking_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../helpers/test_helpers.dart';

void main() {
  const Venue venue = Venue(
    id: 1,
    name: 'Moron',
    address: 'Rivadavia 19850',
    openingTime: '08:00:00',
    closingTime: '22:00:00',
  );
  const SportSpace space = SportSpace(
    id: 3,
    venueId: 1,
    venueName: 'Moron',
    name: 'Moron_Rivadavia_19850_Futbol_1',
    spaceType: 'Futbol',
    number: 1,
  );
  final List<AvailabilitySlot> slots = <AvailabilitySlot>[
    const AvailabilitySlot(
      startTime: '08:00:00',
      endTime: '09:00:00',
      available: true,
    ),
    const AvailabilitySlot(
      startTime: '10:00:00',
      endTime: '11:00:00',
      available: true,
    ),
    const AvailabilitySlot(
      startTime: '11:00:00',
      endTime: '12:00:00',
      available: true,
    ),
    const AvailabilitySlot(
      startTime: '12:00:00',
      endTime: '13:00:00',
      available: false,
    ),
  ];

  Widget bookingScreen() {
    return BookingScreen(
      venue: venue,
      space: space,
      date: DateTime(2999, 10, 17),
      slots: slots,
      initialStartTime: '10:00:00',
    );
  }

  testWidgets('confirma la reserva y manda el cuerpo que espera la API', (
    WidgetTester tester,
  ) async {
    final TestApp app = TestApp((http.Request request) async {
      if (request.url.path == '/reservations') {
        return jsonResponse(reservationJson(), statusCode: 201);
      }
      return jsonResponse(<String, dynamic>{});
    });

    await tester.pumpWidget(app.wrap(bookingScreen()));
    await tester.pumpAndSettle();

    // The start time chosen in the availability grid is preselected.
    expect(find.textContaining('10:00 a 11:00'), findsOneWidget);

    await tester.tap(find.text('Confirmar reserva'));
    await tester.pumpAndSettle();

    expect(find.text('¡Reserva confirmada!'), findsOneWidget);

    final http.Request request =
        app.backend.requestsFor('/reservations').single;
    final Map<String, dynamic> body = app.backend.bodyOf(request);
    expect(body['sport_space_id'], 3);
    expect(body['date'], '2999-10-17');
    expect(body['start_time'], '10:00:00');
    expect(body['end_time'], '11:00:00');
  });

  testWidgets('deja elegir un rango de dos horas', (
    WidgetTester tester,
  ) async {
    final TestApp app = TestApp((http.Request request) async {
      return jsonResponse(reservationJson(), statusCode: 201);
    });

    await tester.pumpWidget(app.wrap(bookingScreen()));
    await tester.pumpAndSettle();

    // 10:00 -> 11:00 (1 h) or 10:00 -> 12:00 (2 h): the next slot is taken.
    await tester.tap(find.textContaining('Hasta 12:00'));
    await tester.pumpAndSettle();
    expect(find.textContaining('10:00 a 12:00'), findsWidgets);

    await tester.tap(find.text('Confirmar reserva'));
    await tester.pumpAndSettle();

    final Map<String, dynamic> body =
        app.backend.bodyOf(app.backend.requestsFor('/reservations').single);
    expect(body['start_time'], '10:00:00');
    expect(body['end_time'], '12:00:00');
  });

  testWidgets('muestra el mensaje exacto cuando el horario se ocupó', (
    WidgetTester tester,
  ) async {
    final TestApp app = TestApp((http.Request request) async {
      return errorResponse(
        409,
        'El espacio ya está reservado en ese horario.',
        'space_not_available',
      );
    });

    await tester.pumpWidget(app.wrap(bookingScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar reserva'));
    await tester.pumpAndSettle();

    expect(find.text('Ese horario se acaba de ocupar. Elegí otro.'), findsOneWidget);
  });

  testWidgets('muestra el detalle del error de validación del backend', (
    WidgetTester tester,
  ) async {
    final TestApp app = TestApp((http.Request request) async {
      return errorResponse(
        400,
        'El horario está fuera del horario de la sede (08:00 a 22:00).',
        'outside_venue_hours',
      );
    });

    await tester.pumpWidget(app.wrap(bookingScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar reserva'));
    await tester.pumpAndSettle();

    expect(
      find.text('El horario está fuera del horario de la sede (08:00 a 22:00).'),
      findsOneWidget,
    );
  });

  testWidgets('no deja confirmar si el espacio no tiene turnos libres', (
    WidgetTester tester,
  ) async {
    final TestApp app = TestApp((http.Request request) async {
      return jsonResponse(<String, dynamic>{});
    });

    await tester.pumpWidget(
      app.wrap(
        BookingScreen(
          venue: venue,
          space: space,
          date: DateTime(2999, 10, 17),
          slots: <AvailabilitySlot>[
            const AvailabilitySlot(
              startTime: '10:00:00',
              endTime: '11:00:00',
              available: false,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No quedan turnos libres para este espacio ese día.'),
      findsOneWidget,
    );
    expect(app.backend.requests, isEmpty);
  });
}
