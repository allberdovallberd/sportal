import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/sportal_api_client.dart';
import '../../../core/network/sportal_api_providers.dart';
import '../models/federation_model.dart';

class FederationApiClient {
  const FederationApiClient({required SportalApiClient api}) : _api = api;

  final SportalApiClient _api;

  Future<List<FederationModel>> fetchFederations() async {
    final response = await _api.get('/federations');
    final data = _extractItems(response['data']);

    return data
        .whereType<Map<String, dynamic>>()
        .map(FederationModel.fromJson)
        .toList();
  }

  Future<FederationModel?> fetchFederationById(String id) async {
    if (id.trim().isEmpty) {
      return null;
    }

    final response = await _api.get('/federations/${id.trim()}');
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      return null;
    }

    return FederationModel.fromJson(data);
  }

  List<dynamic> _extractItems(dynamic data) {
    if (data is List) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      final items = data['items'];
      if (items is List) {
        return items;
      }
    }
    return const <dynamic>[];
  }
}

final federationApiClientProvider = Provider<FederationApiClient>((ref) {
  final api = ref.watch(sportalApiClientProvider);
  return FederationApiClient(api: api);
});
