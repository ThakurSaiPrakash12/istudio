import '../models/photographer_profile.dart';
import 'api_service.dart';

class PhotographerService {
  PhotographerService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  Future<List<PhotographerProfile>> searchNearby({
    required String token,
    String? location,
    String? query,
    String? category,
    double? latitude,
    double? longitude,
  }) async {
    final params = <String, String>{};
    if (location != null && location.trim().isNotEmpty) {
      params['location'] = location.trim();
    }
    if (query != null && query.trim().isNotEmpty) {
      params['query'] = query.trim();
    }
    if (category != null && category.trim().isNotEmpty) {
      params['category'] = category.trim();
    }
    if (latitude != null && !latitude.isNaN) {
      params['lat'] = latitude.toString();
    }
    if (longitude != null && !longitude.isNaN) {
      params['lng'] = longitude.toString();
    }

    final queryParams = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final endpoint = queryParams.isEmpty
        ? '/photographers/nearby'
        : '/photographers/nearby?$queryParams';

    final payload = await _api.get(endpoint, token: token);
    final raw = payload['photographers'];
    if (raw is! List) return const [];
    final list = raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(PhotographerProfile.fromJson)
        .toList();

    list.sort((a, b) {
      if (a.distanceKm != null && b.distanceKm != null) {
        return a.distanceKm!.compareTo(b.distanceKm!);
      }
      if (a.distanceKm != null) return -1;
      if (b.distanceKm != null) return 1;
      return 0;
    });

    return list;
  }
}
