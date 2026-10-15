import '../models/device_token.dart';
import 'api_client.dart';

/// Registration of the push notifications token of this device.
///
/// Endpoints used: `POST /devices` (idempotent: sending the same token again
/// reassigns it to the current user) and `GET /devices`.
class DeviceService {
  DeviceService(this._api);

  final ApiClient _api;

  Future<DeviceToken> register({
    required String token,
    String platform = 'android',
  }) async {
    final Map<String, dynamic> json = await _api.postMap(
      '/devices',
      body: <String, dynamic>{'token': token, 'platform': platform},
    );
    return DeviceToken.fromJson(json);
  }

  Future<List<DeviceToken>> list() async {
    final List<Map<String, dynamic>> items = await _api.getItems('/devices');
    return items.map(DeviceToken.fromJson).toList(growable: false);
  }
}
