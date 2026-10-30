import '../models/photographer_profile.dart';
import 'api_service.dart';

class PhotographerService {
  PhotographerService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  /// Global in-memory cache of discovered photographers for instant live preloaded search
  static List<PhotographerProfile> preloadedPhotographers = [];

  /// Asynchronously preloads photographers into memory so Discover tab opens instantly
  static Future<void> preloadIfEmpty(String token) async {
    if (preloadedPhotographers.isNotEmpty || token.isEmpty) return;
    try {
      final service = PhotographerService();
      final list = await service.searchNearby(token: token);
      if (list.isNotEmpty) {
        preloadedPhotographers = list;
      }
    } catch (_) {}
  }

  Future<List<PhotographerProfile>> searchNearby({
    required String token,
    String? location,
    String? query,
    String? state,
    String? district,
    /// Pass one or more categories to filter. Empty list means no filter.
    List<String> categories = const [],
    double? latitude,
    double? longitude,
    bool includeSelf = false,
  }) async {
    final params = <String, String>{};
    if (location != null && location.trim().isNotEmpty) {
      params['location'] = location.trim();
    }
    if (query != null && query.trim().isNotEmpty) {
      params['query'] = query.trim();
    }
    if (state != null && state.trim().isNotEmpty) params['state'] = state.trim();
    if (district != null && district.trim().isNotEmpty) params['district'] = district.trim();
    if (categories.isNotEmpty) {
      params['category'] = categories.map((c) => c.trim()).join(',');
    }
    if (latitude != null && !latitude.isNaN) {
      params['lat'] = latitude.toString();
    }
    if (longitude != null && !longitude.isNaN) {
      params['lng'] = longitude.toString();
    }
    if (includeSelf) {
      params['includeSelf'] = 'true';
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
