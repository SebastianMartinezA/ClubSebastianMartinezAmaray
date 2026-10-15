import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api_error.dart';
import '../models/availability.dart';
import '../models/reservation.dart';
import '../models/sport_space.dart';
import '../models/venue.dart';
import '../services/reservation_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/club_app_bar.dart';
import '../widgets/error_banner.dart';
import '../widgets/primary_button.dart';
import '../widgets/slot_grid.dart';

/// Pantalla 8: reservar.
///
/// El espacio, el día y los turnos vienen de la pantalla de disponibilidad.
/// El usuario elige la hora de inicio y la de fin (rangos de una hora, en
/// punto, dentro del horario de la sede) y confirma contra `POST /reservations`.
class BookingScreen extends StatefulWidget {
  const BookingScreen({
    super.key,
    required this.venue,
    required this.space,
    required this.date,
    required this.slots,
    this.initialStartTime,
  });

  final Venue venue;
  final SportSpace space;
  final DateTime date;

  /// Turnos del día para este espacio (`AvailabilitySlot`).
  final List<AvailabilitySlot> slots;

  /// `HH:MM:SS` elegido en la grilla de la pantalla anterior.
  final String? initialStartTime;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  String? _startTime;
  String? _endTime;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final String? initial = widget.initialStartTime;
    if (initial != null) {
      _applyStart(initial);
    }
  }

  List<AvailabilitySlot> get _freeSlots => widget.slots
      .where((AvailabilitySlot slot) => slot.available)
      .toList(growable: false);

  /// Possible end times: consecutive available slots starting at the chosen
  /// one. The first option is always `inicio + 1 h`, which is the minimum
  /// duration accepted by the API.
  List<String> _endOptions(String start) {
    final List<String> options = <String>[];
    String cursor = start;
    for (final AvailabilitySlot slot in widget.slots) {
      if (slot.startTime != cursor) {
        continue;
      }
      if (!slot.available) {
        break;
      }
      options.add(slot.endTime);
      cursor = slot.endTime;
    }
    return options;
  }

  void _applyStart(String start) {
    final List<String> options = _endOptions(start);
    _startTime = start;
    _endTime = options.isEmpty ? null : options.first;
  }

  void _selectStart(String start) {
    setState(() => _applyStart(start));
  }

  Future<void> _confirm() async {
    final String? start = _startTime;
    final String? end = _endTime;
    if (start == null || end == null) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final Reservation reservation =
          await context.read<ReservationService>().create(
        sportSpaceId: widget.space.id,
        date: widget.date,
        startTime: start,
        endTime: end,
      );
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('¡Reserva confirmada!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(reservation.venueName),
              Text(reservation.spaceName),
              Text(Formatters.longDate(reservation.date)),
              Text(
                '${Formatters.timeRange(reservation.startTime, reservation.endTime)} hs',
              ),
            ],
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Listo'),
            ),
          ],
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.userMessage;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? start = _startTime;
    final List<String> endOptions = start == null ? const <String>[] : _endOptions(start);

    return Scaffold(
      appBar: const ClubAppBar(title: 'Reservar'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadius),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(widget.space.displayName,
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(widget.space.name, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Text(widget.venue.name, style: theme.textTheme.bodyLarge),
                  Text(
                    widget.venue.address,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    Formatters.longDate(widget.date),
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Elegí el horario de inicio', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_freeSlots.isEmpty)
            const Text('No quedan turnos libres para este espacio ese día.')
          else
            SlotGrid(
              slots: _freeSlots,
              selectedStartTime: _startTime,
              onSlotTap: (AvailabilitySlot slot) => _selectStart(slot.startTime),
            ),
          const SizedBox(height: 20),
          Text('Elegí el horario de fin', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (start == null)
            const Text('Primero elegí el horario de inicio.')
          else if (endOptions.isEmpty)
            const Text('No hay más turnos libres después de ese horario.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: endOptions
                  .map(
                    (String end) => ChoiceChip(
                      label: Text(
                        'Hasta ${Formatters.time(end)} '
                        '(${Formatters.hoursBetween(start, end)} h)',
                      ),
                      selected: _endTime == end,
                      onSelected: (bool selected) {
                        if (selected) {
                          setState(() => _endTime = end);
                        }
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
          const SizedBox(height: 20),
          if (start != null && _endTime != null)
            Card(
              color: theme.colorScheme.secondaryContainer,
              shape:
                  RoundedRectangleBorder(borderRadius: AppTheme.borderRadius),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Resumen', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.space.displayName} · ${widget.venue.name}',
                    ),
                    Text(Formatters.longDate(widget.date)),
                    Text(
                      '${Formatters.timeRange(start, _endTime!)} hs '
                      '(${Formatters.hoursBetween(start, _endTime!)} h)',
                    ),
                  ],
                ),
              ),
            ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 16),
            ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Confirmar reserva',
            loading: _loading,
            onPressed: (start == null || _endTime == null) ? null : _confirm,
          ),
          const SizedBox(height: 8),
          Text(
            'Los turnos son de una hora y empiezan en punto. Si el horario se '
            'ocupa mientras reservás, la API te lo va a avisar.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
