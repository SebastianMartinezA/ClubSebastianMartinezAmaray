import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/reservation.dart';
import '../services/reservation_service.dart';
import '../widgets/club_app_bar.dart';
import '../widgets/future_view.dart';
import '../widgets/reservation_card.dart';

/// Pantalla 10: historial de reservas terminadas y canceladas, distinguidas por
/// estado (`Terminada` / `Cancelada`).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'Todas';

  static const List<String> _filters = <String>[
    'Todas',
    'Terminadas',
    'Canceladas',
  ];

  List<Reservation> _applyFilter(List<Reservation> reservations) {
    switch (_filter) {
      case 'Terminadas':
        return reservations
            .where((Reservation item) => !item.isCancelled)
            .toList(growable: false);
      case 'Canceladas':
        return reservations
            .where((Reservation item) => item.isCancelled)
            .toList(growable: false);
      default:
        return reservations;
    }
  }

  String _emptyForFilter() {
    switch (_filter) {
      case 'Terminadas':
        return 'No hay reservas terminadas en tu historial.';
      case 'Canceladas':
        return 'No hay reservas canceladas en tu historial.';
      default:
        return 'Todavía no hay reservas en tu historial.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ClubAppBar(title: 'Historial'),
      body: FutureView<List<Reservation>>(
        load: () => context.read<ReservationService>().history(),
        loadingMessage: 'Cargando tu historial...',
        isEmpty: (List<Reservation> reservations) => reservations.isEmpty,
        emptyMessage: 'Todavía no hay reservas en tu historial.',
        emptyIcon: Icons.history_toggle_off,
        builder: (
          BuildContext context,
          List<Reservation> reservations,
          Future<void> Function() reload,
        ) {
          final List<Reservation> visible = _applyFilter(reservations);
          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: _filters
                      .map(
                        (String filter) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(filter),
                            selected: _filter == filter,
                            onSelected: (bool _) =>
                                setState(() => _filter = filter),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: reload,
                  child: visible.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          children: <Widget>[
                            Text(
                              _emptyForFilter(),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          children: visible
                              .map(
                                (Reservation reservation) => ReservationCard(
                                  reservation: reservation,
                                ),
                              )
                              .toList(growable: false),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
