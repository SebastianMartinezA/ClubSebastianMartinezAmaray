import '../models/availability.dart';
import '../models/sport_space.dart';
import '../models/venue.dart';
import '../utils/formatters.dart';
import 'api_client.dart';

/// Catalog: venues, spaces and availability.
///
/// Endpoints used: `GET /venues`, `GET /venues/{id}`, `GET /venues/{id}/spaces`,
/// `GET /venues/{id}/availability?date=YYYY-MM-DD`, `GET /spaces`,
/// `GET /spaces/{id}`.
class CatalogService {
  CatalogService(this._api);

  final ApiClient _api;

  Future<List<Venue>> venues() async {
    final List<Map<String, dynamic>> items = await _api.getItems('/venues');
    return items.map(Venue.fromJson).toList(growable: false);
  }

  Future<Venue> venue(int venueId) async {
    return Venue.fromJson(await _api.getMap('/venues/$venueId'));
  }

  Future<List<SportSpace>> venueSpaces(int venueId) async {
    final List<Map<String, dynamic>> items =
        await _api.getItems('/venues/$venueId/spaces');
    return items.map(SportSpace.fromJson).toList(growable: false);
  }

  /// `GET /spaces` with the optional filters of the API.
  ///
  /// `type` is case insensitive and partial on the backend; `venueId` filters
  /// by venue.
  Future<List<SportSpace>> spaces({String? type, int? venueId}) async {
    final Map<String, String> query = <String, String>{};
    if (type != null && type.isNotEmpty) {
      query['type'] = type;
    }
    if (venueId != null) {
      query['venue_id'] = '$venueId';
    }
    final List<Map<String, dynamic>> items =
        await _api.getItems('/spaces', query: query);
    return items.map(SportSpace.fromJson).toList(growable: false);
  }

  Future<SportSpace> space(int spaceId) async {
    return SportSpace.fromJson(await _api.getMap('/spaces/$spaceId'));
  }

  /// Availability grid (one-hour slots) of every active space of a venue.
  Future<VenueAvailability> availability({
    required int venueId,
    required DateTime date,
  }) async {
    final Map<String, dynamic> json = await _api.getMap(
      '/venues/$venueId/availability',
      query: <String, String>{'date': Formatters.toIsoDate(date)},
    );
    return VenueAvailability.fromJson(json);
  }
}
