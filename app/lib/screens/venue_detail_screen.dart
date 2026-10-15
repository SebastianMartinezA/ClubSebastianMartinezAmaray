import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/availability.dart';
import '../models/sport_space.dart';
import '../models/venue.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/club_app_bar.dart';
import '../widgets/future_view.dart';
import '../widgets/slot_grid.dart';
import 'booking_screen.dart';

/// Pantalla 7: detalle de una sede.
///
/// Muestra los espacios de la sede con filtro por tipo y la disponibilidad del
/// día elegido (grilla de turnos de una hora de
/// `GET /venues/{id}/availability?date=...`).
class VenueDetailScreen extends StatefulWidget {
  const VenueDetailScreen({super.key, required this.venue});

  final Venue venue;

  @override
  State<VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends State<VenueDetailScreen> {
  final GlobalKey<FutureViewState<VenueAvailability>> _futureKey =
      GlobalKey<FutureViewState<VenueAvailability>>();

  late DateTime _date;
  String? _typeFilter;
  bool _onlyFree = false;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
  }

  Future<void> _reload() async {
    final FutureViewState<VenueAvailability>? state = _futureKey.currentState;
    if (state != null) {
      await state.reload();
    }
  }

  Future<void> _changeDate(DateTime date) async {
    setState(() => _date = date);
    await _reload();
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today,
      lastDate: today.add(const Duration(days: 60)),
      helpText: 'Elegí el día para ver la disponibilidad',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked != null) {
      await _changeDate(picked);
    }
  }

  bool get _isToday {
    final DateTime now = DateTime.now();
    return _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
  }

  Future<void> _book(SpaceAvailability item, String startTime) async {
    final bool? created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext _) => BookingScreen(
          venue: widget.venue,
          space: item.space,
          date: _date,
          slots: item.slots,
          initialStartTime: startTime,
        ),
      ),
    );
    if (created == true) {
      // The slot is taken now: refresh the grid so it shows as occupied.
      await _reload();
    }
  }

  List<String> _types(List<SpaceAvailability> spaces) {
    final Set<String> types = <String>{};
    for (final SpaceAvailability item in spaces) {
      if (item.space.spaceType.isNotEmpty) {
        types.add(item.space.spaceType);
      }
    }
    final List<String> sorted = types.toList()..sort();
    return sorted;
  }

  List<SpaceAvailability> _visible(
    List<SpaceAvailability> spaces,
  ) {
    return spaces.where((SpaceAvailability item) {
      final bool matchesType =
          _typeFilter == null || item.space.spaceType == _typeFilter;
      final bool matchesFree = !_onlyFree || item.hasFreeSlots;
      return matchesType && matchesFree;
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: ClubAppBar(title: widget.venue.name),
      body: FutureView<VenueAvailability>(
        key: _futureKey,
        load: () => context.read<CatalogService>().availability(
              venueId: widget.venue.id,
              date: _date,
            ),
        loadingMessage: 'Buscando disponibilidad...',
        builder: (
          BuildContext context,
          VenueAvailability data,
          Future<void> Function() reload,
        ) {
          final List<String> types = _types(data.spaces);
          final List<SpaceAvailability> visible = _visible(data.spaces);

          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _VenueHeader(venue: data.venue),
                const SizedBox(height: 16),
                _DateSelector(
                  date: _date,
                  canGoBack: !_isToday,
                  onPrevious: () => _changeDate(
                    _date.subtract(const Duration(days: 1)),
                  ),
                  onNext: () => _changeDate(_date.add(const Duration(days: 1))),
                  onPick: _pickDate,
                ),
                const SizedBox(height: 12),
                if (types.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      FilterChip(
                        label: const Text('Todas'),
                        selected: _typeFilter == null,
                        onSelected: (bool _) =>
                            setState(() => _typeFilter = null),
                      ),
                      ...types.map(
                        (String type) => FilterChip(
                          label: Text(type),
                          selected: _typeFilter == type,
                          onSelected: (bool _) =>
                              setState(() => _typeFilter = type),
                        ),
                      ),
                    ],
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _onlyFree,
                  onChanged: (bool value) => setState(() => _onlyFree = value),
                  title: const Text('Mostrar solo espacios con turnos libres'),
                ),
                Row(
                  children: <Widget>[
                    _Legend(color: theme.colorScheme.primaryContainer, label: 'Libre'),
                    const SizedBox(width: 12),
                    _Legend(
                      color: theme.colorScheme.surfaceContainerHighest,
                      label: 'Ocupado',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Tocá un turno libre para reservarlo.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'No hay espacios para mostrar con este filtro.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                else
                  ...visible.map(
                    (SpaceAvailability item) => _SpaceCard(
                      item: item,
                      onSlotTap: (AvailabilitySlot slot) =>
                          _book(item, slot.startTime),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _VenueHeader extends StatelessWidget {
  const _VenueHeader({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadius),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.place_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(venue.address, style: theme.textTheme.bodyLarge),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Icon(Icons.schedule_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Abierta de ${Formatters.time(venue.openingTime)} a '
                  '${Formatters.time(venue.closingTime)} hs',
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({
    required this.date,
    required this.canGoBack,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  final DateTime date;
  final bool canGoBack;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Día anterior',
              onPressed: canGoBack ? onPrevious : null,
            ),
            Expanded(
              child: InkWell(
                onTap: onPick,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: <Widget>[
                      Text(
                        Formatters.longDate(date),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        'Tocá para elegir otro día',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Día siguiente',
              onPressed: onNext,
            ),
          ],
        ),
      ),
    );
  }
}

class _SpaceCard extends StatelessWidget {
  const _SpaceCard({required this.item, required this.onSlotTap});

  final SpaceAvailability item;
  final void Function(AvailabilitySlot slot) onSlotTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SportSpace space = item.space;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadius),
      margin: const EdgeInsets.only(bottom: AppTheme.gap),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(space.displayName, style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(space.name, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            if (item.slots.isEmpty)
              const Text('Sin turnos para este día.')
            else
              SlotGrid(slots: item.slots, onSlotTap: onSlotTap),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
