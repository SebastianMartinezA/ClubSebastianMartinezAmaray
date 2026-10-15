import 'package:flutter/material.dart';

/// Error state with a retry button.
///
/// Shown whenever a request fails, including the two cases the assignment
/// cares about: no connectivity and server timeout (in both cases the message
/// is "No pudimos conectarnos con el servidor. Revisá tu conexión.").
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.isConnectivityProblem = false,
    this.details,
  });

  final String message;
  final Future<void> Function() onRetry;
  final bool isConnectivityProblem;
  final String? details;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              isConnectivityProblem ? Icons.wifi_off : Icons.error_outline,
              size: 56,
              color: scheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (details != null && details!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                details!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
