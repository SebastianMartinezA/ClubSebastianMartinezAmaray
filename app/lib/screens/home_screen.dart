import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_navigator.dart';
import '../models/reservation.dart';
import '../models/user.dart';
import '../services/reservation_service.dart';
import '../state/session.dart';
import '../widgets/club_app_bar.dart';
import '../widgets/future_view.dart';
import '../widgets/reservation_card.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'reservations_screen.dart';
import 'venues_screen.dart';

/// Pantalla 5: inicio. Saludo al usuario, próximas reservas y accesos a Sedes,
/// Mis reservas e Historial.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<FutureViewState<List<Reservation>>> _futureKey =
      GlobalKey<FutureViewState<List<Reservation>>>();

  Future<void> _reload() async {
    final FutureViewState<List<Reservation>>? state = _futureKey.currentState;
    if (state != null) {
      await state.reload();
    }
  }

  Future<void> _confirmSignOut() async {
    final Session session = context.read<Session>();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Vas a tener que ingresar de nuevo para reservar.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await session.signOut();
    if (!mounted) {
      return;
    }
    // Mismo camino que la sesión vencida (navigatorKey global): así el logout manual
    // y el 401 comparten la deduplicación y no se apilan dos pantallas de login.
    goToLogin();
  }

  void _open(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext _) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = context.watch<Session>().user;
    return Scaffold(
      appBar: ClubAppBar(
        title: 'Hola, ${user?.displayName ?? ''}',
        automaticallyImplyLeading: false,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Mi perfil',
            onPressed: () => _open(const ProfileScreen()),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: _confirmSignOut,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureView<List<Reservation>>(
          key: _futureKey,
          load: () => context.read<ReservationService>().current(),
          loadingMessage: 'Buscando tus reservas...',
          builder: (
            BuildContext context,
            List<Reservation> reservations,
            Future<void> Function() reload,
          ) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _UpcomingCard(
                  reservations: reservations,
                  onSeeAll: reservations.isEmpty
                      ? null
                      : () => _open(const ReservationsScreen()),
                ),
                const SizedBox(height: 24),
                Text('¿Qué querés hacer?',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _AccessTile(
                  icon: Icons.stadium_outlined,
                  title: 'Sedes',
                  subtitle: 'Mirá las sedes, sus canchas y la disponibilidad',
                  onTap: () => _open(const VenuesScreen()),
                ),
                _AccessTile(
                  icon: Icons.event_available_outlined,
                  title: 'Mis reservas',
                  subtitle: 'Tus reservas vigentes y cancelarlas si hace falta',
                  onTap: () => _open(const ReservationsScreen()),
                ),
                _AccessTile(
                  icon: Icons.history,
                  title: 'Historial',
                  subtitle: 'Reservas terminadas y canceladas',
                  onTap: () => _open(const HistoryScreen()),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Card with the next reservations of the user.
class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.reservations, this.onSeeAll});

  final List<Reservation> reservations;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Reservation> shown = reservations.take(3).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text('Próximas reservas', style: theme.textTheme.titleMedium),
            ),
            if (onSeeAll != null)
              TextButton(onPressed: onSeeAll, child: const Text('Ver todas')),
          ],
        ),
        const SizedBox(height: 8),
        if (shown.isEmpty)
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Icon(Icons.event_busy_outlined,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No tenés reservas próximas. Elegí una sede para reservar '
                      'tu espacio.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...shown.map(
            (Reservation reservation) => ReservationCard(
              reservation: reservation,
            ),
          ),
      ],
    );
  }
}

class _AccessTile extends StatelessWidget {
  const _AccessTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
        ),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
