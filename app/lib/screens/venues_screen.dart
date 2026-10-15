import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/venue.dart';
import '../services/catalog_service.dart';
import '../widgets/club_app_bar.dart';
import '../widgets/future_view.dart';
import '../widgets/venue_card.dart';
import 'venue_detail_screen.dart';

/// Pantalla 6: listado de sedes.
class VenuesScreen extends StatelessWidget {
  const VenuesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ClubAppBar(title: 'Sedes'),
      body: FutureView<List<Venue>>(
        load: () => context.read<CatalogService>().venues(),
        loadingMessage: 'Cargando sedes...',
        isEmpty: (List<Venue> venues) => venues.isEmpty,
        emptyMessage: 'Todavía no hay sedes cargadas.',
        emptyIcon: Icons.stadium_outlined,
        builder: (
          BuildContext context,
          List<Venue> venues,
          Future<void> Function() reload,
        ) {
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: venues
                  .map(
                    (Venue venue) => VenueCard(
                      venue: venue,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (BuildContext _) =>
                              VenueDetailScreen(venue: venue),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          );
        },
      ),
    );
  }
}
