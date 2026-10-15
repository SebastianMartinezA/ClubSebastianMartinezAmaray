import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Chip that shows the state of a reservation: `Activa`, `Terminada` or
/// `Cancelada`.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final Color color = AppTheme.statusColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        // withAlpha instead of withValues/withOpacity: it works on every
        // Flutter version (the other two changed/were deprecated at some point).
        color: color.withAlpha(31),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(102)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
