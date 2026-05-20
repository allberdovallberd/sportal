import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/federation_model.dart';
import '../services/federation_api_client.dart';

final federationRefreshKeyProvider = StateProvider<int>((ref) => 0);

final federationListProvider = FutureProvider<List<FederationModel>>((
  ref,
) async {
  ref.watch(federationRefreshKeyProvider);
  final api = ref.watch(federationApiClientProvider);
  return api.fetchFederations();
});

final federationDetailProvider = FutureProvider.family<FederationModel, String>(
  (ref, federationId) async {
    final api = ref.watch(federationApiClientProvider);
    final detail = await api.fetchFederationById(federationId);
    if (detail == null) {
      throw StateError('Federation not found');
    }
    return detail;
  },
);
