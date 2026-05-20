import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_session_provider.dart';
import 'sportal_api_client.dart';

final sportalApiClientProvider = Provider<SportalApiClient>((ref) {
  return SportalApiClient(
    getRefreshToken: () => ref.read(authSessionProvider).refreshToken,
    onTokensRefreshed: (accessToken, refreshToken) {
      ref
          .read(authSessionProvider.notifier)
          .setTokens(accessToken: accessToken, refreshToken: refreshToken);
    },
  );
});
