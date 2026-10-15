import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api_error.dart';
import '../models/reservation.dart';
import '../services/reservation_service.dart';
import '../utils/formatters.dart';
import '../widgets/club_app_bar.dart';
import '../widgets/future_view.dart';
import '../widgets/reservation_card.dart';
import 'venues_screen.dart';

/// Pantalla 9: mis reservas vigentes, con cancelación previa confirmación.
///
/// Al cancelar se recarga la lista y el horario vuelve a quedar libre en el
/// backend, así que en la próxima consulta de disponibilidad aparece
/// disponible.
class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  final GlobalKey<FutureViewState<List<Reservation>>> _futureKey =
      GlobalKey<FutureViewState<List<Reservation>>>();

  Future<void> _reload() async {
    final FutureViewState<List<Reservation>>? state = _futureKey.currentState;
    if (state != null) {
      await state.reload();
    }
  }

  Future<void> _cancel(Reservation reservation) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('¿Cancelar la reserva?'),
        content: Text(
          'Vas a liberar ${reservation.spaceName} en ${reservation.venueName} '
          'el ${Formatters.longDate(reservation.date)} de '
          '${Formatters.timeRange(reservation.startTime, reservation.endTime)}.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await context.read<ReservationService>().cancel(reservation.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reserva cancelada. El horario quedó libre.'),
        ),
      );
      await _reload();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.userMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ClubAppBar(title: 'Mis reservas'),
      body: FutureView<List<Reservation>>(
        key: _futureKey,
        load: () => context.read<ReservationService>().current(),
        loadingMessage: 'Cargando tus reservas...',
        isEmpty: (List<Reservation> reservations) => reservations.isEmpty,
        emptyMessage: 'No tenés reservas vigentes.',
        emptyIcon: Icons.event_busy_outlined,
        builder: (
          BuildContext context,
          List<Reservation> reservations,
          Future<void> Function() reload,
        ) {
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: reservations
                  .map(
                    (Reservation reservation) => ReservationCard(
                      reservation: reservation,
                      onCancel: () => _cancel(reservation),
                    ),
                  )
                  .toList(growable: false),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (BuildContext _) => const VenuesScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Reservar'),
      ),
    );
  }
}
