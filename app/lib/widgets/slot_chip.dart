import 'package:flutter/material.dart';

/// One hour of the availability grid: free (tappable), taken or selected.
class SlotChip extends StatelessWidget {
  const SlotChip({
    super.key,
    required this.label,
    required this.available,
    this.selected = false,
    this.onTap,
  });

  /// `20:00`.
  final String label;
  final bool available;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final Color background;
    final Color foreground;
    if (!available) {
      // Taken slot: muted text/icon on the card surface. `onSurfaceVariant`
      // (#6C6C6E) is the measured secondary text colour; `outline` (#2A2A2D)
      // is a border colour and would be almost invisible here (1.1:1).
      background = scheme.surfaceContainerHighest;
      foreground = scheme.onSurfaceVariant;
    } else if (selected) {
      background = scheme.primary;
      foreground = scheme.onPrimary;
    } else {
      background = scheme.primaryContainer;
      foreground = scheme.onPrimaryContainer;
    }

    return Semantics(
      button: available,
      enabled: available,
      label: available ? 'Turno $label libre' : 'Turno $label ocupado',
      child: InkWell(
        onTap: available ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? scheme.primary : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: foreground,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              decoration: available ? null : TextDecoration.lineThrough,
            ),
          ),
        ),
      ),
    );
  }
}
