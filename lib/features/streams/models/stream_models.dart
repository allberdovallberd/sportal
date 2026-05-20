import 'stream_api_exception.dart';

class StreamSessionModel {
  const StreamSessionModel({
    required this.id,
    required this.streamerId,
    required this.title,
    required this.sport,
    required this.status,
    required this.isObs,
    required this.likesCount,
    required this.commentsCount,
    this.startedAt,
    this.endedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String streamerId;
  final String title;
  final String sport;
  final String status;
  final bool isObs;
  final int likesCount;
  final int commentsCount;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isLive => status.trim().toLowerCase() == 'live';

  factory StreamSessionModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    return StreamSessionModel(
      id: (json['id'] ?? '').toString(),
      streamerId: (json['streamer_id'] ?? json['streamerId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      sport: (json['sport'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      isObs: json['is_obs'] == true || json['isObs'] == true,
      likesCount:
          int.tryParse(
            (json['likes_count'] ?? json['likesCount'] ?? 0).toString(),
          ) ??
          0,
      commentsCount:
          int.tryParse(
            (json['comments_count'] ?? json['commentsCount'] ?? 0).toString(),
          ) ??
          0,
      startedAt: parseDate(json['started_at'] ?? json['startedAt']),
      endedAt: parseDate(json['ended_at'] ?? json['endedAt']),
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
      updatedAt: parseDate(json['updated_at'] ?? json['updatedAt']),
    );
  }
}

class CreateStreamResponse {
  const CreateStreamResponse({required this.session, this.publish});

  final StreamSessionModel session;
  final PublishInfo? publish;

  factory CreateStreamResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final source = data is Map<String, dynamic> ? data : json;

    final sessionJson = source['session'];
    final sessionMap = sessionJson is Map<String, dynamic>
        ? sessionJson
        : source;

    if (sessionMap['id'] == null) {
      throw const StreamApiException(
        error: 'INVALID_PAYLOAD',
        message: 'Yaylym maglumaty nadogry.',
      );
    }

    final publishJson = source['publish'] ?? source['publish_info'];
    return CreateStreamResponse(
      session: StreamSessionModel.fromJson(sessionMap),
      publish: publishJson is Map<String, dynamic>
          ? PublishInfo.fromJson(publishJson)
          : null,
    );
  }
}

class PublishInfo {
  const PublishInfo({
    required this.token,
    required this.protocol,
    required this.srsApi,
    required this.whipPath,
    required this.rtmpUrl,
    this.whipUrl = '',
    this.rtmpServer = '',
    this.obsStreamKey = '',
    this.streamId = '',
    this.secret = '',
  });

  final String token;
  final String protocol;
  final String srsApi;
  final String whipPath;
  final String rtmpUrl;

  /// Full WHIP endpoint URL returned by the backend for camera streams (see
  /// API_ENDPOINTS.md §4.1). Mobile clients POST the SDP offer here.
  final String whipUrl;

  /// RTMP server portion for OBS streams (see §5.1). Pasted into OBS
  /// Settings → Stream → Server.
  final String rtmpServer;

  /// OBS stream key (see §5.1). Pasted into OBS Settings → Stream → Stream Key.
  final String obsStreamKey;

  /// Stream UUID returned alongside the publish info.
  final String streamId;

  /// Publish secret token. Returned only once; treat as sensitive.
  final String secret;

  factory PublishInfo.fromJson(Map<String, dynamic> json) {
    return PublishInfo(
      token: (json['token'] ?? '').toString(),
      protocol: (json['protocol'] ?? '').toString(),
      srsApi: (json['srsApi'] ?? json['srs_api'] ?? '').toString(),
      whipPath: (json['whipPath'] ?? json['whip_path'] ?? '').toString(),
      rtmpUrl: (json['rtmpUrl'] ?? json['rtmp_url'] ?? '').toString(),
      whipUrl: (json['whipUrl'] ?? json['whip_url'] ?? '').toString(),
      rtmpServer: (json['rtmpServer'] ?? json['rtmp_server'] ?? '').toString(),
      obsStreamKey: (json['obsStreamKey'] ?? json['obs_stream_key'] ?? '')
          .toString(),
      streamId: (json['streamId'] ?? json['stream_id'] ?? '').toString(),
      secret: (json['secret'] ?? '').toString(),
    );
  }
}

class ViewerPlaybackGrant {
  const ViewerPlaybackGrant({
    required this.streamId,
    required this.viewerId,
    required this.playbackToken,
    required this.expiresAt,
    required this.webrtcUrl,
    this.playback,
  });

  final String streamId;
  final String viewerId;
  final String playbackToken;
  final String expiresAt;
  final String webrtcUrl;
  final StreamPlaybackUrls? playback;

  factory ViewerPlaybackGrant.fromJson(Map<String, dynamic> json) {
    final playbackJson = json['playback'];
    return ViewerPlaybackGrant(
      streamId: (json['stream_id'] ?? json['streamId'] ?? '').toString(),
      viewerId: (json['viewer_id'] ?? json['viewerId'] ?? '').toString(),
      playbackToken: (json['playback_token'] ?? json['playbackToken'] ?? '')
          .toString(),
      expiresAt: (json['expires_at'] ?? json['expiresAt'] ?? '').toString(),
      webrtcUrl: (json['webrtc_url'] ?? json['webrtcUrl'] ?? '').toString(),
      playback: playbackJson is Map<String, dynamic>
          ? StreamPlaybackUrls.fromJson(playbackJson)
          : null,
    );
  }
}

class StreamQuality {
  const StreamQuality({
    required this.name,
    required this.label,
    required this.url,
    this.width,
    this.height,
    this.bandwidth,
  });

  final String name;
  final String label;
  final String url;
  final int? width;
  final int? height;
  final int? bandwidth;

  factory StreamQuality.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic v) =>
        v is int ? v : int.tryParse((v ?? '').toString());
    return StreamQuality(
      name: (json['name'] ?? '').toString(),
      label: (json['label'] ?? json['name'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      width: parseInt(json['width']),
      height: parseInt(json['height']),
      bandwidth: parseInt(json['bandwidth']),
    );
  }
}

class StreamIceServer {
  const StreamIceServer({required this.urls, this.username, this.credential});

  final List<String> urls;
  final String? username;
  final String? credential;

  factory StreamIceServer.fromJson(Map<String, dynamic> json) {
    final rawUrls = json['urls'];
    final urls = rawUrls is List
        ? rawUrls
              .map((item) => item.toString())
              .where((u) => u.isNotEmpty)
              .toList()
        : <String>[];
    return StreamIceServer(
      urls: urls,
      username: json['username']?.toString(),
      credential: json['credential']?.toString(),
    );
  }

  Map<String, dynamic> toPeerConnectionJson() {
    return <String, dynamic>{
      'urls': urls,
      if (username != null && username!.isNotEmpty) 'username': username,
      if (credential != null && credential!.isNotEmpty)
        'credential': credential,
    };
  }
}

class StreamPlaybackUrls {
  const StreamPlaybackUrls({
    required this.hls,
    required this.masterHls,
    required this.flv,
    required this.webrtc,
    this.qualities = const [],
    this.iceServers = const [],
  });

  final String hls;

  /// Adaptive HLS master playlist URL. Use as default playback URL when
  /// non-empty; otherwise fall back to [hls].
  final String masterHls;

  final String flv;
  final String webrtc;

  /// Backend-provided quality renditions for the quality selector.
  /// Empty when the backend returns no adaptive tracks.
  final List<StreamQuality> qualities;

  /// TURN/STUN configuration provided by the backend for WHEP/WebRTC viewing.
  final List<StreamIceServer> iceServers;

  factory StreamPlaybackUrls.fromJson(Map<String, dynamic> json) {
    final qualitiesJson = json['qualities'];
    final iceServersJson = json['ice_servers'] ?? json['iceServers'];
    final List<StreamQuality> qualities = qualitiesJson is List
        ? qualitiesJson
              .whereType<Map<String, dynamic>>()
              .map(StreamQuality.fromJson)
              .where((q) => q.url.isNotEmpty)
              .toList()
        : const [];
    final List<StreamIceServer> iceServers = iceServersJson is List
        ? iceServersJson
              .whereType<Map<String, dynamic>>()
              .map(StreamIceServer.fromJson)
              .where((server) => server.urls.isNotEmpty)
              .toList()
        : const [];
    return StreamPlaybackUrls(
      hls: (json['hls'] ?? '').toString(),
      masterHls: (json['master_hls'] ?? json['masterHls'] ?? '').toString(),
      flv: (json['flv'] ?? '').toString(),
      webrtc: (json['webrtc'] ?? '').toString(),
      qualities: qualities,
      iceServers: iceServers,
    );
  }
}

class StreamCommentModel {
  const StreamCommentModel({
    required this.id,
    required this.streamId,
    required this.authorId,
    this.authorName,
    this.authorAvatar,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String streamId;
  final String authorId;
  final String? authorName;
  final String? authorAvatar;
  final String text;
  final String createdAt;

  factory StreamCommentModel.fromJson(Map<String, dynamic> json) {
    // Some backend versions wrap the author info in a nested `author` map
    // (mirroring the news payload), others put `author_name` / `author_avatar`
    // directly on the comment. Read from both shapes so the client works
    // regardless of which the server is currently emitting.
    final nestedAuthor = json['author'];
    final authorMap = nestedAuthor is Map<String, dynamic>
        ? nestedAuthor
        : const <String, dynamic>{};

    String? pickString(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    return StreamCommentModel(
      id: (json['id'] ?? '').toString(),
      streamId: (json['stream_id'] ?? json['streamId'] ?? '').toString(),
      authorId: (json['author_id'] ?? json['authorId'] ?? authorMap['id'] ?? '')
          .toString(),
      authorName: pickString(
        json['author_name'] ??
            json['authorName'] ??
            authorMap['username'] ??
            authorMap['name'],
      ),
      authorAvatar: pickString(
        json['author_avatar'] ?? json['authorAvatar'] ?? authorMap['avatar'],
      ),
      text: (json['text'] ?? '').toString(),
      createdAt: (json['created_at'] ?? json['createdAt'] ?? '').toString(),
    );
  }
}
