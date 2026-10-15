import 'package:flutter/material.dart';

import '../models/availability.dart';
import '../utils/formatters.dart';
import 'slot_chip.dart';

/// Grid of one-hour slots of a space on a given date.
class SlotGrid extends StatelessWidget {
  const SlotGrid({
    super.key,
    required this.slots,
    this.selectedStartTime,
    this.onSlotTap,
  });

  final List<AvailabilitySlot> slots;

  /// `HH:MM:SS` of the selected start, to highlight it.
  final String? selectedStartTime;

  final void Function(AvailabilitySlot slot)? onSlotTap;

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const Text('No hay turnos para este día.');
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((AvailabilitySlot slot) {
        return SlotChip(
          label: Formatters.time(slot.startTime),
          available: slot.available,
          selected: selectedStartTime == slot.startTime,
          onTap: onSlotTap == null ? null : () => onSlotTap!(slot),
        );
      }).toList(growable: false),
    );
  }
}
