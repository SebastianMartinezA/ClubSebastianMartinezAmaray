import 'package:flutter/material.dart';

import '../models/reservation.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'status_chip.dart';

/// Card of a reservation, used by "Mis reservas" and by "Historial".
class ReservationCard extends StatelessWidget {
  const ReservationCard({
    super.key,
    required this.reservation,
    this.onCancel,
  });

  final Reservation reservation;

  /// When present, a "Cancelar" button is shown.
  final Future<void> Function()? onCancel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadius),
      margin: const EdgeInsets.only(bottom: AppTheme.gap),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    reservation.venueName,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                StatusChip(label: reservation.statusLabel),
              ],
            ),
            const SizedBox(height: 8),
            _Line(
              icon: Icons.sports_tennis_outlined,
              text: reservation.spaceName,
            ),
            _Line(
              icon: Icons.event_outlined,
              text: Formatters.longDate(reservation.date),
            ),
            _Line(
              icon: Icons.access_time_outlined,
              text: Formatters.timeRange(
                reservation.startTime,
                reservation.endTime,
              ),
            ),
            if (reservation.isCancelled && reservation.cancelledAt != null)
              _Line(
                icon: Icons.cancel_outlined,
                text: 'Cancelada el '
                    '${Formatters.date(reservation.cancelledAt!.toLocal())}',
              ),
            if (onCancel != null && reservation.canBeCancelled) ...<Widget>[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => onCancel!(),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Cancelar reserva'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: theme.colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
