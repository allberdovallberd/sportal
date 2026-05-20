import '../../../core/network/sportal_api_client.dart';
import '../../../core/network/sportal_api_config.dart';
import '../../../core/network/sportal_api_exception.dart';
import '../models/stream_api_exception.dart';
import '../models/stream_models.dart';

class StreamApiClient {
  StreamApiClient({SportalApiClient? api, SportalApiConfig? config})
    : _api = api ?? SportalApiClient(),
      _config = config ?? SportalApiConfig.current;

  final SportalApiClient _api;
  final SportalApiConfig _config;

  String get defaultSrsWhipBaseUrl => _config.srsWhipBaseUrl;
  String get defaultSrsWhepBaseUrl => _config.srsWhepBaseUrl;

  Future<List<StreamSessionModel>> fetchStreamSessions({
    String? accessToken,
    bool liveOnly = false,
  }) async {
    final payload = await _send(
      () => _api.get(
        liveOnly ? '/streams/live' : '/streams',
        accessToken: accessToken,
      ),
    );

    final data = payload['data'];
    final items = _extractItems(data);

    return items
        .whereType<Map<String, dynamic>>()
        .map(StreamSessionModel.fromJson)
        .toList();
  }

  Future<CreateStreamResponse> createStreamSession({
    String? accessToken,
    required String title,
    String? sport,
    bool isObs = false,
  }) async {
    final requestBody = <String, dynamic>{
      'title': title,
      'is_obs': isObs,
      if (sport != null && sport.trim().isNotEmpty) 'sport': sport.trim(),
    };

    final payload = await _send(() async {
      try {
        return await _api.post(
          '/admin/streams',
          accessToken: accessToken,
          body: requestBody,
        );
      } on SportalApiException catch (error) {
        if (error.statusCode == 404) {
          throw const StreamApiException(
            error: 'ENDPOINT_NOT_FOUND',
            message:
                'API_ENDPOINTS.md boyuncha stream doretmek endpointi mobile ucin yok.',
            statusCode: 404,
          );
        }
        rethrow;
      }
    });
    return CreateStreamResponse.fromJson(payload);
  }

  Future<void> deleteAllStreamSessions({String? accessToken}) async {
    try {
      await _send(
        () => _api.delete('/admin/streams', accessToken: accessToken),
      );
    } on StreamApiException catch (error) {
      if (error.statusCode == 404) return;
      rethrow;
    }
  }

  Future<void> deleteStreamSession({
    String? accessToken,
    required String streamId,
  }) async {
    try {
      await _send(
        () => _api.delete('/admin/streams/$streamId', accessToken: accessToken),
      );
    } on StreamApiException catch (error) {
      if (error.statusCode == 404) return;
      rethrow;
    }
  }

  Future<ViewerPlaybackGrant> requestPlaybackGrant({
    String? accessToken,
    required String streamId,
    String? viewerId,
  }) async {
    final payload = await _send(
      () => _api.post(
        '/streams/playback',
        accessToken: accessToken,
        body: <String, dynamic>{'stream_id': streamId},
      ),
    );

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const StreamApiException(
        error: 'INVALID_PAYLOAD',
        message: 'Playback grant payload is invalid.',
      );
    }

    return ViewerPlaybackGrant.fromJson(data);
  }

  Future<StreamPlaybackUrls?> fetchStreamWatchUrls({
    String? accessToken,
    required String streamId,
  }) async {
    final payload = await _send(
      () => _api.get('/streams/$streamId/watch', accessToken: accessToken),
    );

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final playback = data['playback'];
    if (playback is! Map<String, dynamic>) {
      return null;
    }

    final urls = StreamPlaybackUrls.fromJson(playback);
    return StreamPlaybackUrls(
      hls: _resolvePlaybackUrl(urls.hls),
      masterHls: _resolvePlaybackUrl(urls.masterHls),
      flv: _resolvePlaybackUrl(urls.flv),
      webrtc: _resolvePlaybackUrl(urls.webrtc),
      qualities: urls.qualities
          .map(
            (q) => StreamQuality(
              name: q.name,
              label: q.label,
              url: _resolvePlaybackUrl(q.url),
              width: q.width,
              height: q.height,
              bandwidth: q.bandwidth,
            ),
          )
          .toList(),
      iceServers: urls.iceServers,
    );
  }

  /// Fetches the current viewer count for [streamId] from the watch endpoint.
  /// Returns 0 when the API doesn't include the field.
  Future<int> fetchViewerCount({
    String? accessToken,
    required String streamId,
  }) async {
    try {
      final payload = await _send(
        () => _api.get('/streams/$streamId/watch', accessToken: accessToken),
      );
      final data = payload['data'];
      if (data is Map<String, dynamic>) {
        final stream = data['stream'];
        if (stream is Map<String, dynamic>) {
          final v = stream['viewers_count'] ?? stream['viewersCount'];
          return int.tryParse((v ?? 0).toString()) ?? 0;
        }
      }
    } on StreamApiException {
      // Silently ignore — counter remains at last known value.
    }
    return 0;
  }

  Future<void> markStreamLive({
    String? accessToken,
    required String streamId,
  }) async {
    try {
      await _send(
        () => _api.post(
          '/streams/srs-webhook',
          accessToken: accessToken,
          body: {
            'action': 'on_publish',
            'app': 'live',
            'stream': streamId,
            'stream_id': streamId,
          },
        ),
      );
    } on StreamApiException catch (error) {
      if (error.statusCode == 404) return;
      rethrow;
    }
  }

  Future<void> markStreamEnded({
    String? accessToken,
    required String streamId,
  }) async {
    try {
      await _send(
        () => _api.post(
          '/streams/srs-webhook',
          accessToken: accessToken,
          body: {
            'action': 'on_unpublish',
            'app': 'live',
            'stream': streamId,
            'stream_id': streamId,
          },
        ),
      );
    } on StreamApiException catch (error) {
      if (error.statusCode == 404) return;
      rethrow;
    }
  }

  Future<List<StreamCommentModel>> fetchStreamComments({
    String? accessToken,
    required String streamId,
  }) async {
    final payload = await _send(
      () => _api.post(
        '/streams/comments',
        accessToken: accessToken,
        body: {'stream_id': streamId},
      ),
    );

    final items = _extractItems(payload['data']);

    return items
        .whereType<Map<String, dynamic>>()
        .map(StreamCommentModel.fromJson)
        .toList();
  }

  Future<StreamCommentModel> postStreamComment({
    String? accessToken,
    required String streamId,
    required String text,
  }) async {
    final payload = await _send(
      () => _api.post(
        '/streams/comment',
        accessToken: accessToken,
        body: {'stream_id': streamId, 'text': text},
      ),
    );

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const StreamApiException(
        error: 'INVALID_PAYLOAD',
        message: 'Comment payload is invalid.',
      );
    }

    return StreamCommentModel.fromJson(data);
  }

  /// Toggles like on a stream. Returns `{liked, likes}`.
  Future<({bool liked, int likes})> likeStream({
    String? accessToken,
    required String streamId,
  }) async {
    final payload = await _send(
      () => _api.post(
        '/streams/like',
        accessToken: accessToken,
        body: {'stream_id': streamId},
      ),
    );
    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      return (
        liked: data['liked'] == true,
        likes: int.tryParse((data['likes'] ?? 0).toString()) ?? 0,
      );
    }
    return (liked: false, likes: 0);
  }

  /// Adds [delta] to the stream like counter (for rapid-tap animations).
  Future<int> incrementLikes({
    String? accessToken,
    required String streamId,
    required int delta,
  }) async {
    final payload = await _send(
      () => _api.post(
        '/streams/like-inc',
        accessToken: accessToken,
        body: {'stream_id': streamId, 'delta': delta},
      ),
    );
    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      return int.tryParse((data['likes'] ?? 0).toString()) ?? 0;
    }
    return 0;
  }

  /// Fetches current like count + liked state for a stream.
  Future<({bool liked, int likes})> getStreamLikes({
    String? accessToken,
    required String streamId,
  }) async {
    final payload = await _send(
      () => _api.post(
        '/streams/likes',
        accessToken: accessToken,
        body: {'stream_id': streamId},
      ),
    );
    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      return (
        liked: data['liked'] == true,
        likes: int.tryParse((data['likes'] ?? 0).toString()) ?? 0,
      );
    }
    return (liked: false, likes: 0);
  }

  Future<Map<String, dynamic>> _send(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    try {
      return await request();
    } on SportalApiException catch (error) {
      throw StreamApiException(
        error: error.code ?? 'REQUEST_FAILED',
        message: error.message,
        statusCode: error.statusCode,
      );
    }
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

  String _resolvePlaybackUrl(String value) {
    final raw = value.trim();
    if (raw.isEmpty) {
      return '';
    }

    if (raw.startsWith('webrtc://')) {
      return raw;
    }

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      final uri = Uri.tryParse(raw);
      if (uri != null) {
        final baseUri = Uri.parse(_config.apiBaseUrl);
        final path = uri.path.isNotEmpty ? uri.path : '/';
        return Uri(
          scheme: baseUri.scheme,
          host: baseUri.host,
          port: baseUri.hasPort ? baseUri.port : null,
          path: path,
          query: uri.hasQuery ? uri.query : null,
          fragment: uri.fragment.isEmpty ? null : uri.fragment,
        ).toString();
      }
    }

    final base = _config.uploadBaseUrl.replaceFirst(RegExp(r'/$'), '');
    if (raw.startsWith('/')) {
      return '$base$raw';
    }
    return '$base/$raw';
  }
}
