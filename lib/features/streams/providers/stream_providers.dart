import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/sportal_api_providers.dart';
import '../../auth/providers/auth_session_provider.dart';
import '../models/stream_models.dart';
import '../services/stream_api_client.dart';

class StreamSessionContext {
  const StreamSessionContext({
    required this.accessToken,
    required this.viewerId,
    required this.streamerId,
    required this.displayName,
    required this.isAdmin,
  });

  final String accessToken;
  final String viewerId;
  final String streamerId;
  final String displayName;
  final bool isAdmin;
}

final streamApiClientProvider = Provider<StreamApiClient>((ref) {
  final api = ref.watch(sportalApiClientProvider);
  return StreamApiClient(api: api, config: api.config);
});

final streamSessionContextProvider = Provider<StreamSessionContext>((ref) {
  final auth = ref.watch(authSessionProvider);
  return StreamSessionContext(
    accessToken: auth.accessToken,
    viewerId: auth.user.id.isEmpty
        ? const String.fromEnvironment(
            'STREAMS_VIEWER_ID',
            defaultValue: 'sportal-viewer',
          )
        : auth.user.id,
    streamerId: auth.user.id.isEmpty
        ? const String.fromEnvironment(
            'STREAMS_STREAMER_ID',
            defaultValue: 'sportal-streamer',
          )
        : auth.user.id,
    displayName: auth.user.email.isEmpty ? 'Sportal User' : auth.user.email,
    isAdmin: auth.isAdmin,
  );
});

final streamCategoryFilterProvider = StateProvider<String>((ref) => 'all');

final streamRefreshKeyProvider = StateProvider<int>((ref) => 0);

final streamSessionsProvider = FutureProvider<List<StreamSessionModel>>((
  ref,
) async {
  ref.watch(streamRefreshKeyProvider);
  final selectedFilter = ref.watch(streamCategoryFilterProvider);
  final api = ref.watch(streamApiClientProvider);
  final session = ref.watch(streamSessionContextProvider);

  final items = await api.fetchStreamSessions(accessToken: session.accessToken);
  items.sort((a, b) {
    if (a.isLive && !b.isLive) return -1;
    if (!a.isLive && b.isLive) return 1;

    final aTime = a.startedAt ?? a.createdAt;
    final bTime = b.startedAt ?? b.createdAt;
    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    return bTime.compareTo(aTime);
  });

  if (selectedFilter == 'all') {
    return items;
  }

  return items
      .where((item) => item.sport.toLowerCase() == selectedFilter)
      .toList();
});
