import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/network/sportal_api_config.dart';
import '../../../core/localization/app_localizations.dart';
import '../../auth/providers/auth_session_provider.dart';
import '../../../ui/sportal_colors.dart';
import '../../../ui/widgets/sportal_avatar.dart';
import '../models/stream_api_exception.dart';
import '../models/stream_models.dart';
import '../providers/stream_providers.dart';

class WatchStreamPage extends ConsumerStatefulWidget {
  const WatchStreamPage({
    super.key,
    required this.streamId,
    required this.streamTitle,
    this.isObs = false,
  });

  final String streamId;
  final String streamTitle;
  final bool isObs;

  @override
  ConsumerState<WatchStreamPage> createState() => _WatchStreamPageState();
}

class _WatchStreamPageState extends ConsumerState<WatchStreamPage>
    with WidgetsBindingObserver {
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _commentsScrollController = ScrollController();

  RTCPeerConnection? _peerConnection;
  Timer? _commentsPollTimer;
  Timer? _likesPollTimer;
  Timer? _viewerCountPollTimer;
  Timer? _hlsHealthTimer;
  Timer? _sseReconnectTimer;
  Timer? _errorDismissTimer;

  // SSE
  http.Client? _sseClient;
  StreamSubscription<String>? _sseSub;
  bool _isMuted = false;

  bool _rendererReady = false;
  bool _isStarting = true;
  bool _isSendingComment = false;
  bool _showComments = true;
  bool _isLiked = false;
  int _likesCount = 0;
  bool _isLiking = false;
  int _likePulse = 0;
  bool _isLandscape = false;
  String? _errorText;
  List<StreamCommentModel> _comments = const <StreamCommentModel>[];

  // Avatar cache — backend doesn't always include `author_avatar` on every
  // comment, so we keep a per-author lookup populated from any source that
  // does have it (SSE init payload, the current user, server responses).
  final Map<String, String> _authorAvatarCache = <String, String>{};

  // HLS player state
  // Default to WebRTC-only playback per product direction (no HLS/FLV).
  bool _hlsMode = false;
  VideoPlayerController? _hlsController;
  StreamPlaybackUrls? _watchUrls;
  String _activeQuality = 'Auto';
  bool _isQualitySwitching = false;
  bool _hasTriggeredPlaybackFallback = false;
  String? _activeHlsUrl;
  Duration _lastHlsPosition = Duration.zero;
  int _hlsStallTicks = 0;
  bool _hlsRecovering = false;
  bool _isReloading = false;
  double _pullDownAccum = 0;

  // Viewer count — placeholder until a public endpoint exists
  int _viewerCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_enterFullscreen());
    // OBS/broadcast streams → HLS; mobile camera streams → WebRTC (WHEP).
    if (widget.isObs) {
      unawaited(_startHls());
    } else {
      unawaited(_initAndStart());
    }
    // SSE provides real-time viewer count, comments, likes *and* registers
    // this client as a viewer (so the count increments).
    unawaited(_connectSse());
    _startLikesPolling();
    // Comment polling is a fallback — SSE comment events take precedence.
    _startCommentsPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _commentsPollTimer?.cancel();
      _likesPollTimer?.cancel();
      _viewerCountPollTimer?.cancel();
      _hlsHealthTimer?.cancel();
      _sseReconnectTimer?.cancel();
      _disconnectSse();
      // Tear down WebRTC peer connection when backgrounded so we can
      // establish a fresh one on resume without stale ICE/connection state.
      if (!_hlsMode) {
        unawaited(_cleanup());
      }
    } else if (state == AppLifecycleState.resumed) {
      _startCommentsPolling();
      _startLikesPolling();
      unawaited(_connectSse());
      if (_hlsMode) {
        if (_hlsController != null) _startHlsHealthMonitor();
      } else {
        // WebRTC stream — reconnect after backgrounding.
        if (_rendererReady) {
          unawaited(_startWatching());
        } else {
          unawaited(_initAndStart());
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _commentsPollTimer?.cancel();
    _likesPollTimer?.cancel();
    _viewerCountPollTimer?.cancel();
    _hlsHealthTimer?.cancel();
    _sseReconnectTimer?.cancel();
    _errorDismissTimer?.cancel();
    _disconnectSse();
    _commentController.dispose();
    _commentsScrollController.dispose();
    unawaited(_cleanup());
    unawaited(_remoteRenderer.dispose());
    unawaited(_exitFullscreen());
    super.dispose();
  }

  Future<void> _enterFullscreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Start locked in portrait. The rotation button is the only way to
    // switch orientation — physical device rotation is intentionally ignored.
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
  }

  Future<void> _exitFullscreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Restore portrait-only on the rest of the app.
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
  }

  Future<void> _toggleOrientation() async {
    final next = !_isLandscape;
    // Lock to exactly one orientation family so the physical sensor cannot
    // override the user's choice.
    if (next) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
    }
    if (mounted) {
      setState(() => _isLandscape = next);
    }
  }

  Future<void> _initAndStart() async {
    try {
      await _remoteRenderer.initialize();
      if (!mounted) return;
      setState(() {
        _rendererReady = true;
      });
      await _startWatching();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isStarting = false;
        _errorText = context.l10n.t('watchPlayerInitFailed');
      });
      _scheduleErrorDismiss();
    }
  }

  /// Prefetches the watch endpoint metadata (qualities, viewer count) so
  /// the quality picker can be presented even when WebRTC is the active
  /// transport. Failures are silent — the picker simply has no items.
  // ignore: unused_element
  Future<void> _prefetchWatchUrls() async {
    try {
      final api = ref.read(streamApiClientProvider);
      final session = ref.read(streamSessionContextProvider);
      final urls = _normalizeWatchUrls(
        await api.fetchStreamWatchUrls(
          accessToken: session.accessToken,
          streamId: widget.streamId,
        ),
      );
      if (mounted && urls != null) {
        setState(() => _watchUrls = urls);
      }
    } catch (_) {
      // Silent: WebRTC playback continues without quality options.
    }
  }

  Future<void> _startWatching() async {
    final api = ref.read(streamApiClientProvider);
    final session = ref.read(streamSessionContextProvider);

    setState(() {
      _isStarting = true;
      _errorText = null;
    });

    try {
      final grant = await api.requestPlaybackGrant(
        accessToken: session.accessToken,
        streamId: widget.streamId,
        viewerId: session.viewerId,
      );
      final watchUrls = _normalizeWatchUrls(
        await api.fetchStreamWatchUrls(
          accessToken: session.accessToken,
          streamId: widget.streamId,
        ),
      );
      final playbackUrls = _normalizeWatchUrls(grant.playback) ?? watchUrls;
      if (mounted && watchUrls != null) {
        setState(() => _watchUrls = watchUrls);
      }

      final iceServers =
          (playbackUrls?.iceServers.isNotEmpty == true
                  ? playbackUrls!.iceServers
                  : watchUrls?.iceServers ?? const <StreamIceServer>[])
              .map((server) => server.toPeerConnectionJson())
              .toList();

      final pc = await createPeerConnection(<String, dynamic>{
        if (iceServers.isNotEmpty) 'iceServers': iceServers,
        'bundlePolicy': 'max-bundle',
        'rtcpMuxPolicy': 'require',
        'iceCandidatePoolSize': 4,
        'sdpSemantics': 'unified-plan',
      });

      // Only treat hard `Failed` as fatal. WebRTC routinely flaps to
      // `Disconnected` for a few seconds and recovers on its own; tearing
      // the peer connection down here forces a full re-handshake and is
      // perceived as a long freeze. We also no longer fall back to HLS —
      // playback is WebRTC-only per product direction.
      pc.onConnectionState = (state) {
        if (!mounted || _hasTriggeredPlaybackFallback) return;
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          _hasTriggeredPlaybackFallback = true;
        }
      };

      pc.onIceConnectionState = (state) {
        if (!mounted || _hasTriggeredPlaybackFallback) return;
        if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          _hasTriggeredPlaybackFallback = true;
        }
      };

      pc.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          _remoteRenderer.srcObject = event.streams.first;
        }
      };

      await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
      await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );

      final offer = await pc.createOffer(<String, dynamic>{
        'mandatory': <String, dynamic>{
          'OfferToReceiveAudio': true,
          'OfferToReceiveVideo': true,
        },
        'optional': <dynamic>[],
      });
      await pc.setLocalDescription(offer);

      final whepUri = _resolveWhepUri(
        fallbackBase: api.defaultSrsWhepBaseUrl,
        streamId: widget.streamId,
        grantWebrtcUrl: grant.webrtcUrl.isEmpty ? null : grant.webrtcUrl,
        watchWebrtcUrl: playbackUrls?.webrtc,
      );
      final answerSdp = await _exchangeSdp(
        url: whepUri,
        offerSdp: offer.sdp ?? '',
      );
      await pc.setRemoteDescription(RTCSessionDescription(answerSdp, 'answer'));

      _peerConnection = pc;
      _hasTriggeredPlaybackFallback = false;
      await WakelockPlus.enable();

      if (!mounted) return;
      setState(() {
        _isStarting = false;
      });
    } on StreamApiException catch (error) {
      await _cleanup();
      if (!mounted) return;
      setState(() {
        _isStarting = false;
        _errorText = error.message;
      });
      _scheduleErrorDismiss();
    } catch (_) {
      await _cleanup();
      if (!mounted) return;
      setState(() {
        _isStarting = false;
        _errorText = context.l10n.t('watchFailed');
      });
      _scheduleErrorDismiss();
    }
  }

  Future<String> _exchangeSdp({
    required Uri url,
    required String offerSdp,
  }) async {
    final response = await _postSdpWithRedirects(url: url, offerSdp: offerSdp);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StreamApiException(
        error: 'SDP_EXCHANGE_FAILED',
        message: 'Video handshake failed (${response.statusCode}).',
      );
    }

    return response.body;
  }

  Future<http.Response> _postSdpWithRedirects({
    required Uri url,
    required String offerSdp,
  }) async {
    Uri current = url;
    for (var i = 0; i < 4; i++) {
      final response = await http
          .post(
            current,
            headers: const <String, String>{'Content-Type': 'application/sdp'},
            body: offerSdp,
          )
          .timeout(const Duration(seconds: 20));

      if (!_isRedirectStatus(response.statusCode)) {
        return response;
      }

      final location = response.headers['location'];
      if (location == null || location.trim().isEmpty) {
        return response;
      }
      current = current.resolve(location.trim());
    }

    throw const StreamApiException(
      error: 'SDP_REDIRECT_LOOP',
      message: 'Video handshake redirected too many times.',
    );
  }

  bool _isRedirectStatus(int statusCode) {
    return statusCode == 301 ||
        statusCode == 302 ||
        statusCode == 307 ||
        statusCode == 308;
  }

  Uri _buildWhepUri(String baseUrl, String streamId) {
    final uri = Uri.parse(baseUrl.trim());
    if (_looksLikeWhepEndpoint(uri)) {
      return uri;
    }
    // Use string concatenation rather than Uri.resolve so the base path
    // (e.g. /sport) is preserved. Uri.resolve('/rtc/…') would strip it.
    final base = baseUrl.trim().replaceFirst(RegExp(r'/$'), '');
    return Uri.parse('$base/rtc/v1/whep/?app=live&stream=$streamId');
  }

  Uri _resolveWhepUri({
    required String fallbackBase,
    required String streamId,
    String? grantWebrtcUrl,
    String? watchWebrtcUrl,
  }) {
    final candidates = <String>[
      if (watchWebrtcUrl != null) watchWebrtcUrl.trim(),
      if (grantWebrtcUrl != null) grantWebrtcUrl.trim(),
    ];

    for (final candidate in candidates) {
      if (candidate.isEmpty) continue;
      if (candidate.startsWith('http://') || candidate.startsWith('https://')) {
        return Uri.parse(candidate);
      }

      // Relative absolute-path returned by the API (e.g. /sport/rtc/v1/whep/?…)
      // — prepend the host so we get the correct full URL.
      if (candidate.startsWith('/')) {
        final base = SportalApiConfig.current.uploadBaseUrl;
        return Uri.parse('$base$candidate');
      }

      if (candidate.startsWith('webrtc://')) {
        final uri = Uri.tryParse(candidate);
        if (uri == null || uri.host.isEmpty) {
          continue;
        }
        final streamFromPath = uri.pathSegments.isEmpty
            ? streamId
            : uri.pathSegments.last;
        final apiBase = SportalApiConfig.current.apiBaseUrl.replaceFirst(
          RegExp(r'/api/v1/?$'),
          '',
        );
        final apiUri = Uri.parse(apiBase);
        final scheme = apiUri.scheme.isEmpty ? 'http' : apiUri.scheme;
        final authority = apiUri.hasPort
            ? '${uri.host}:${apiUri.port}'
            : uri.host;
        return Uri.parse(
          '$scheme://$authority/rtc/v1/whep/?app=live&stream=$streamFromPath',
        );
      }
    }

    return _buildWhepUri(fallbackBase, streamId);
  }

  bool _looksLikeWhepEndpoint(Uri uri) {
    final path = uri.path.toLowerCase();
    return path.contains('/rtc/v1/whep');
  }

  void _startCommentsPolling() {
    _commentsPollTimer?.cancel();
    unawaited(_fetchComments());
    // Slower polling to keep the UI isolate free for video rendering.
    _commentsPollTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => unawaited(_fetchComments()),
    );
  }

  void _startLikesPolling() {
    _likesPollTimer?.cancel();
    unawaited(_loadLikes());
    _likesPollTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => unawaited(_loadLikes()),
    );
  }

  // ── SSE ──────────────────────────────────────────────────────────────────

  void _disconnectSse() {
    _sseSub?.cancel();
    _sseSub = null;
    _sseClient?.close();
    _sseClient = null;
  }

  Future<void> _connectSse() async {
    _disconnectSse();
    final session = ref.read(streamSessionContextProvider);
    final accessToken = session.accessToken;
    if (accessToken.isEmpty) return;

    final baseUrl = SportalApiConfig.current.apiBaseUrl;
    final uri = Uri.parse(
      '$baseUrl/streams/subscribe'
      '?streamId=${Uri.encodeComponent(widget.streamId)}'
      '&token=${Uri.encodeComponent(accessToken)}',
    );

    final client = http.Client();
    _sseClient = client;

    try {
      final request = http.Request('GET', uri);
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';
      request.headers['X-Client-Platform'] = 'mobile';

      final response = await client.send(request);
      if (response.statusCode != 200) {
        client.close();
        _sseClient = null;
        return;
      }

      String buffer = '';
      String? eventName;

      _sseSub = response.stream
          .transform(const Utf8Decoder())
          .listen(
            (chunk) {
              buffer += chunk;
              // SSE lines are separated by '\n'; double '\n\n' ends an event.
              // We process line-by-line and reset context on blank lines.
              while (buffer.contains('\n')) {
                final idx = buffer.indexOf('\n');
                final line = buffer.substring(0, idx).trim();
                buffer = buffer.substring(idx + 1);

                if (line.startsWith('event:')) {
                  eventName = line.substring(6).trim();
                } else if (line.startsWith('data:')) {
                  final dataStr = line.substring(5).trim();
                  _handleSseEvent(eventName ?? 'message', dataStr);
                  eventName = null;
                } else if (line.isEmpty) {
                  eventName = null;
                }
              }
            },
            onError: (_) {
              if (!mounted) return;
              _sseReconnectTimer = Timer(const Duration(seconds: 5), () {
                if (mounted) unawaited(_connectSse());
              });
            },
            onDone: () {
              if (!mounted) return;
              _sseReconnectTimer = Timer(const Duration(seconds: 5), () {
                if (mounted) unawaited(_connectSse());
              });
            },
            cancelOnError: true,
          );
    } catch (_) {
      client.close();
      _sseClient = null;
      if (mounted) {
        _sseReconnectTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) unawaited(_connectSse());
        });
      }
    }
  }

  void _handleSseEvent(String event, String data) {
    if (!mounted) return;
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      switch (event) {
        case 'init':
          final rawViewers = json['viewers_count'] ?? json['viewersCount'];
          final rawLikes = json['likes'];
          final rawComments = json['comments'];
          setState(() {
            if (rawViewers != null) {
              _viewerCount =
                  int.tryParse(rawViewers.toString()) ?? _viewerCount;
            }
            if (rawLikes != null) {
              _likesCount = int.tryParse(rawLikes.toString()) ?? _likesCount;
            }
            if (rawComments is List) {
              final parsed = rawComments
                  .whereType<Map<String, dynamic>>()
                  .map(StreamCommentModel.fromJson)
                  .toList();
              _comments = parsed;
              _ingestAuthorAvatars(parsed);
            }
          });

        case 'viewer_count':
          final raw = json['viewers_count'] ?? json['viewersCount'];
          if (raw != null) {
            setState(() {
              _viewerCount = int.tryParse(raw.toString()) ?? _viewerCount;
            });
          }

        case 'likes':
          final raw = json['likes'];
          if (raw != null) {
            setState(() {
              _likesCount = int.tryParse(raw.toString()) ?? _likesCount;
            });
          }

        case 'comment':
          final comment = StreamCommentModel.fromJson(json);
          setState(() {
            _ingestAuthorAvatars([comment]);
            if (!_comments.any((c) => c.id == comment.id)) {
              _comments = [..._comments, comment];
            }
          });
          if (_showComments) _scrollCommentsToBottom();

        case 'status':
          final status = json['status'] as String?;
          if (status == 'ended' && mounted) {
            Navigator.of(context).pop();
          }

        case 'mute':
          setState(() => _isMuted = true);

        case 'kick':
          if (mounted) Navigator.of(context).pop();
      }
    } catch (_) {
      // Ignore parse errors — may be a keep-alive ping.
    }
  }

  Future<void> _fetchComments() async {
    final api = ref.read(streamApiClientProvider);
    final session = ref.read(streamSessionContextProvider);

    try {
      final items = await api.fetchStreamComments(
        accessToken: session.accessToken,
        streamId: widget.streamId,
      );
      if (!mounted) return;
      setState(() {
        _comments = items;
        _ingestAuthorAvatars(items);
      });
      if (_showComments) _scrollCommentsToBottom();
    } catch (_) {
      // Ignore polling errors.
    }
  }

  void _scheduleErrorDismiss() {
    _errorDismissTimer?.cancel();
    _errorDismissTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _errorText = null);
    });
  }

  /// Records any non-empty avatar URLs from [comments] in the per-author
  /// cache so we can render avatars even on later comments where the
  /// backend omits `author_avatar`.
  void _ingestAuthorAvatars(Iterable<StreamCommentModel> comments) {
    for (final c in comments) {
      final a = c.authorAvatar?.trim();
      if (a != null && a.isNotEmpty && c.authorId.isNotEmpty) {
        _authorAvatarCache[c.authorId] = a;
      }
    }
  }

  void _scrollCommentsToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_commentsScrollController.hasClients) return;
      _commentsScrollController.animateTo(
        _commentsScrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _loadLikes() async {
    try {
      final api = ref.read(streamApiClientProvider);
      final session = ref.read(streamSessionContextProvider);
      final result = await api.getStreamLikes(
        accessToken: session.accessToken,
        streamId: widget.streamId,
      );
      if (mounted &&
          (_isLiked != result.liked || _likesCount != result.likes)) {
        setState(() {
          _isLiked = result.liked;
          _likesCount = result.likes;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    if (_isLiking) return;
    setState(() {
      _isLiking = true;
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
      if (_isLiked) _likePulse++;
    });
    try {
      final api = ref.read(streamApiClientProvider);
      final session = ref.read(streamSessionContextProvider);
      final result = await api.likeStream(
        accessToken: session.accessToken,
        streamId: widget.streamId,
      );
      if (mounted) {
        setState(() {
          _isLiked = result.liked;
          _likesCount = result.likes;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likesCount += _isLiked ? 1 : -1;
        });
      }
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSendingComment || _isMuted) return;

    final api = ref.read(streamApiClientProvider);
    final session = ref.read(streamSessionContextProvider);

    setState(() {
      _isSendingComment = true;
    });

    try {
      await api.postStreamComment(
        accessToken: session.accessToken,
        streamId: widget.streamId,
        text: text,
      );
      _commentController.clear();
      await _fetchComments();
    } on StreamApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.message;
      });
      _scheduleErrorDismiss();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = context.l10n.t('watchCommentFailed');
      });
      _scheduleErrorDismiss();
    } finally {
      if (mounted) {
        setState(() {
          _isSendingComment = false;
        });
      }
    }
  }

  Future<void> _cleanup() async {
    _hlsHealthTimer?.cancel();
    // HLS cleanup
    final hlsCtrl = _hlsController;
    _hlsController = null;
    await hlsCtrl?.dispose();

    // WebRTC cleanup
    final pc = _peerConnection;
    _peerConnection = null;
    if (pc != null) {
      await pc.close();
      await pc.dispose();
    }

    _remoteRenderer.srcObject = null;
    await WakelockPlus.disable();
  }

  StreamPlaybackUrls? _normalizeWatchUrls(StreamPlaybackUrls? urls) {
    if (urls == null) return null;
    final qualities = _mergeGeneratedHlsQualities(urls);
    return StreamPlaybackUrls(
      hls: urls.hls,
      masterHls: urls.masterHls,
      flv: urls.flv,
      webrtc: urls.webrtc,
      qualities: qualities,
      iceServers: urls.iceServers,
    );
  }

  List<StreamQuality> get _qualityOptions {
    final urls = _watchUrls;
    if (urls == null) return const <StreamQuality>[];
    return _mergeGeneratedHlsQualities(urls);
  }

  List<StreamQuality> _mergeGeneratedHlsQualities(StreamPlaybackUrls urls) {
    final baseHls = (urls.hls.isNotEmpty ? urls.hls : urls.masterHls).trim();
    final generated = baseHls.isNotEmpty
        ? _buildObsQualities(baseHls)
        : const <StreamQuality>[];
    if (generated.isEmpty) return urls.qualities;
    final merged = <String, StreamQuality>{
      for (final quality in urls.qualities) quality.name: quality,
    };
    for (final quality in generated) {
      merged.putIfAbsent(quality.name, () => quality);
    }
    final ordered = merged.values.toList();
    ordered.sort((a, b) {
      final ah = a.height ?? 0;
      final bh = b.height ?? 0;
      return bh.compareTo(ah);
    });
    return ordered;
  }

  // ── HLS / Media3 methods ────────────────────────────────────────────────

  Future<void> _startHls() async {
    setState(() {
      _isStarting = true;
      _hlsMode = true;
      _errorText = null;
    });
    try {
      final api = ref.read(streamApiClientProvider);
      final session = ref.read(streamSessionContextProvider);
      final watchUrls = _normalizeWatchUrls(
        await api.fetchStreamWatchUrls(
          accessToken: session.accessToken,
          streamId: widget.streamId,
        ),
      );
      if (!mounted) return;
      _watchUrls = watchUrls;

      final hlsUrl = (watchUrls?.masterHls.isNotEmpty == true)
          ? watchUrls!.masterHls
          : (watchUrls?.hls.isNotEmpty == true)
          ? watchUrls!.hls
          : null;

      if (hlsUrl == null || hlsUrl.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isStarting = false;
          _errorText = context.l10n.t('watchFailed');
        });
        _scheduleErrorDismiss();
        return;
      }

      // Retry HLS initialization a few times. When a stream was just
      // created (especially mobile camera streams), SRS needs ~5-10 s
      // to produce the first .m3u8 segments. Without retry, viewers see
      // "Could not watch stream" the moment they open the page.
      const maxAttempts = 8;
      const retryDelay = Duration(seconds: 2);
      Object? lastError;
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        if (!mounted) return;
        try {
          await _initHlsController(hlsUrl);
          lastError = null;
          break;
        } catch (e) {
          lastError = e;
          if (attempt < maxAttempts) {
            await Future<void>.delayed(retryDelay);
          }
        }
      }
      if (lastError != null) {
        throw lastError;
      }
      if (!mounted) return;
      setState(() {
        _activeQuality = 'Auto';
        _isStarting = false;
      });
    } on StreamApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isStarting = false;
        _errorText = error.message;
      });
      _scheduleErrorDismiss();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isStarting = false;
        _errorText = context.l10n.t('watchFailed');
      });
      _scheduleErrorDismiss();
    }
  }

  Future<void> _initHlsController(String url) async {
    final old = _hlsController;
    _hlsController = null;
    await old?.dispose();

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );
    await controller.initialize();
    controller.addListener(_onHlsUpdate);

    // Live-edge offset: stay behind the latest segment so brief network
    // hiccups can be absorbed by the local buffer instead of causing a
    // visible freeze. OBS/sport-channel streams use a larger buffer (10 s)
    // for a smoother broadcast feel; social streams use a tighter offset (6 s).
    final liveEdge = widget.isObs
        ? const Duration(seconds: 10)
        : const Duration(seconds: 6);
    final dur = controller.value.duration;
    if (dur > liveEdge + const Duration(seconds: 2)) {
      await controller.seekTo(dur - liveEdge);
    }

    await controller.play();
    await WakelockPlus.enable();

    if (mounted) {
      _hlsController = controller;
      _activeHlsUrl = url;
      _lastHlsPosition = controller.value.position;
      _hlsStallTicks = 0;
      _startHlsHealthMonitor();
    } else {
      await controller.dispose();
    }
  }

  void _startHlsHealthMonitor() {
    _hlsHealthTimer?.cancel();
    // Poll every 2s. If the position has not advanced for ~8s while we
    // expect to be playing, treat the stream as stalled and reload.
    _hlsHealthTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final ctrl = _hlsController;
      if (ctrl == null || !ctrl.value.isInitialized) return;
      if (_hlsRecovering) return;

      // Hard error \u2192 immediate reload
      if (ctrl.value.hasError) {
        unawaited(_recoverHls());
        return;
      }

      // Detect a stall: position did not move while we are supposed to play.
      final pos = ctrl.value.position;
      final shouldBePlaying = ctrl.value.isPlaying || ctrl.value.isBuffering;
      if (shouldBePlaying && pos == _lastHlsPosition) {
        _hlsStallTicks += 1;
      } else {
        _hlsStallTicks = 0;
      }
      _lastHlsPosition = pos;

      // ~8 seconds of no progress \u2192 reload to live edge.
      if (_hlsStallTicks >= 4) {
        _hlsStallTicks = 0;
        unawaited(_recoverHls());
      }
    });
  }

  Future<void> _recoverHls() async {
    if (_hlsRecovering) return;
    final url = _activeHlsUrl;
    if (url == null || url.isEmpty) return;
    _hlsRecovering = true;
    try {
      await _initHlsController(url);
    } catch (_) {
      // Best effort \u2014 if it fails the health monitor will try again.
    } finally {
      _hlsRecovering = false;
    }
  }

  Future<void> _reloadStream() async {
    if (_isReloading) return;
    setState(() => _isReloading = true);
    try {
      if (widget.isObs || _hlsMode) {
        await _recoverHls();
      } else {
        // WebRTC stream — tear down and reconnect.
        await _cleanup();
        if (mounted) await _startWatching();
      }
    } finally {
      if (mounted) setState(() => _isReloading = false);
    }
  }

  void _onHlsUpdate() {
    if (!mounted) return;
    final ctrl = _hlsController;
    if (ctrl == null) return;
    // VideoPlayer renders frames internally — only rebuild for error transitions
    // to avoid a full-page setState on every video frame (~30-60x per second).
    if (ctrl.value.hasError) {
      setState(() {});
      // The health monitor will pick this up and reload, but kick a recovery
      // immediately for a faster bounce-back.
      unawaited(_recoverHls());
    }
  }

  Future<void> _switchQuality(String qualityName, String url) async {
    if (_isQualitySwitching) return;
    setState(() => _isQualitySwitching = true);
    try {
      if (!_hlsMode) {
        await _switchToHls(preferredUrl: url, preferredQuality: qualityName);
        if (mounted) {
          setState(() => _isQualitySwitching = false);
        }
        return;
      }

      final pos = _hlsController?.value.position ?? Duration.zero;
      final wasPlaying = _hlsController?.value.isPlaying ?? true;

      final old = _hlsController;
      _hlsController = null;
      await old?.dispose();

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      await controller.initialize();
      await controller.seekTo(pos);
      controller.addListener(_onHlsUpdate);
      if (wasPlaying) await controller.play();

      if (mounted) {
        _hlsController = controller;
        setState(() {
          _activeQuality = qualityName;
          _isQualitySwitching = false;
        });
      } else {
        await controller.dispose();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isQualitySwitching = false);
      // On failure revert to Auto / master_hls
      final masterUrl = _watchUrls?.masterHls.isNotEmpty == true
          ? _watchUrls!.masterHls
          : _watchUrls?.hls;
      if (masterUrl != null && masterUrl.isNotEmpty && qualityName != 'Auto') {
        await _initHlsController(masterUrl);
        if (mounted) setState(() => _activeQuality = 'Auto');
      }
    }
  }

  // ignore: unused_element
  Future<void> _switchToWebrtc({String? reason}) async {
    final oldCtrl = _hlsController;
    _hlsController = null;
    await oldCtrl?.dispose();
    if (!mounted) return;
    setState(() {
      _hlsMode = false;
      _isStarting = true;
      _errorText = reason;
    });
    await _initAndStart();
  }

  Future<void> _switchToHls({
    String? preferredUrl,
    String? preferredQuality,
  }) async {
    // Clean up WebRTC resources
    final pc = _peerConnection;
    _peerConnection = null;
    if (pc != null) {
      await pc.close();
      await pc.dispose();
    }
    _remoteRenderer.srcObject = null;
    if (!mounted) return;
    setState(() {
      _hlsMode = true;
      _isStarting = true;
    });
    if (preferredUrl != null && preferredUrl.isNotEmpty) {
      await _initHlsController(preferredUrl);
      if (mounted) {
        setState(() {
          _activeQuality = preferredQuality ?? 'Auto';
          _isStarting = false;
        });
      }
      return;
    }
    await _startHls();
  }

  /// Derives per-rendition HLS URLs from the base `.m3u8` URL.
  /// Pattern: `<base_without_ext>_<res>p.m3u8`
  List<StreamQuality> _buildObsQualities(String baseHlsUrl) {
    // Strip query params and fragment for base URL manipulation
    final uri = Uri.tryParse(baseHlsUrl);
    if (uri == null) return const [];
    final path = uri.path;
    if (!path.endsWith('.m3u8')) return const [];
    final stem = path.substring(0, path.length - 5); // remove .m3u8
    const resolutions = [
      (name: '1080p', label: '1080p', height: 1080, bandwidth: 4000000),
      (name: '720p', label: '720p', height: 720, bandwidth: 2000000),
      (name: '480p', label: '480p', height: 480, bandwidth: 900000),
      (name: '360p', label: '360p', height: 360, bandwidth: 500000),
      (name: '240p', label: '240p', height: 240, bandwidth: 420000),
      (name: '144p', label: '144p', height: 144, bandwidth: 220000),
    ];
    return resolutions.map((r) {
      final qualityPath = '${stem}_${r.name}.m3u8';
      final qualityUri = uri.replace(path: qualityPath, query: '');
      return StreamQuality(
        name: r.name,
        label: r.label,
        url: qualityUri.toString(),
        height: r.height,
        bandwidth: r.bandwidth,
      );
    }).toList();
  }

  // Kept for future re-enable of the quality picker.
  // ignore: unused_element
  void _openQualitySheet() {
    final urls = _watchUrls;
    final masterUrl = urls != null
        ? (urls.masterHls.isNotEmpty ? urls.masterHls : urls.hls)
        : null;
    final qualities = _qualityOptions;
    final options = <(String, String)>[
      if (masterUrl != null && masterUrl.isNotEmpty) ('Auto', masterUrl),
      ...qualities.map((q) => (q.label, q.url)),
    ];
    if (options.isEmpty) return;

    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) {
        return CupertinoTheme(
          data: const CupertinoThemeData(brightness: Brightness.dark),
          child: CupertinoAlertDialog(
            title: const Text('Quality'),
            actions: options.map((opt) {
              final isActive = _activeQuality == opt.$1;
              return CupertinoDialogAction(
                onPressed: () {
                  Navigator.pop(ctx);
                  unawaited(_switchQuality(opt.$1, opt.$2));
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      child: isActive
                          ? const Icon(
                              CupertinoIcons.check_mark,
                              size: 18,
                              color: Color(0xFF4B90FF),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      opt.$1,
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Urbanist',
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────────────────

  Future<void> _leave() async {
    if (!mounted) return;
    // Pop immediately so the screen closes right away.
    // dispose() already calls _cleanup() via unawaited().
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final maxCommentsHeight = MediaQuery.of(context).size.height * 0.35;
    final currentUser = ref.read(authSessionProvider).user;
    final orderedComments = _comments.toList()
      ..sort((a, b) {
        final aDate = DateTime.tryParse(a.createdAt);
        final bDate = DateTime.tryParse(b.createdAt);
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragUpdate: widget.isObs
                    ? (details) {
                        // OBS/sport-channel streams: swipe-down from the top
                        // area reloads to the live edge (useful for broadcast
                        // streams where a bigger buffer may drift).
                        if (_isReloading || _isStarting) return;
                        if (details.localPosition.dy > 220) return;
                        _pullDownAccum += details.delta.dy;
                        if (_pullDownAccum > 80) {
                          _pullDownAccum = 0;
                          unawaited(_reloadStream());
                        }
                      }
                    : null,
                onVerticalDragEnd: widget.isObs
                    ? (_) => _pullDownAccum = 0
                    : null,
                onVerticalDragCancel: widget.isObs
                    ? () => _pullDownAccum = 0
                    : null,
                child: _hlsMode
                    ? _buildHlsView()
                    : (_rendererReady && _remoteRenderer.srcObject != null
                          ? RepaintBoundary(
                              child: RTCVideoView(
                                _remoteRenderer,
                                objectFit: RTCVideoViewObjectFit
                                    .RTCVideoViewObjectFitContain,
                              ),
                            )
                          : const Center(child: CircularProgressIndicator())),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.34),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.66),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_isReloading)
              const Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: topInset + 14,
              left: 14,
              right: 90,
              child: Text(
                widget.streamTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Urbanist',
                ),
              ),
            ),
            Positioned(
              top: topInset + 10,
              right: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Row 1: LIVE pill — viewer count — close
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _LiveWatchPill(),
                      const SizedBox(width: 8),
                      // Viewer count (UI placeholder — no endpoint yet)
                      _ViewerCountBadge(count: _viewerCount),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _isStarting ? null : _leave,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 28,
                          shadows: [
                            Shadow(blurRadius: 6, color: Colors.black54),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Rotation
                  IconButton(
                    onPressed: _toggleOrientation,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    icon: Icon(
                      _isLandscape
                          ? Icons.stay_current_portrait_rounded
                          : Icons.screen_rotation_rounded,
                      color: Colors.white,
                      size: 22,
                      shadows: const [
                        Shadow(blurRadius: 6, color: Colors.black54),
                      ],
                    ),
                  ),
                  // Manual reload \u2014 useful when the stream stalls and the
                  // automatic recovery has not kicked in yet.
                  IconButton(
                    onPressed: _isReloading || _isStarting
                        ? null
                        : () => unawaited(_reloadStream()),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                      size: 22,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                    ),
                  ),
                  // Quality picker hidden for now — WebRTC playback only.
                  // const SizedBox(height: 6),
                  // if (_qualityOptions.isNotEmpty ||
                  //     ((_watchUrls?.masterHls.isNotEmpty == true) ||
                  //         (_watchUrls?.hls.isNotEmpty == true)))
                  //   _isQualitySwitching
                  //       ? const SizedBox(
                  //           width: 36,
                  //           height: 36,
                  //           child: Center(
                  //             child: SizedBox(
                  //               width: 18,
                  //               height: 18,
                  //               child: CircularProgressIndicator(
                  //                 strokeWidth: 2,
                  //                 color: Colors.white,
                  //               ),
                  //             ),
                  //           ),
                  //         )
                  //       : IconButton(
                  //           onPressed: _openQualitySheet,
                  //           padding: EdgeInsets.zero,
                  //           constraints: const BoxConstraints(
                  //             minWidth: 36,
                  //             minHeight: 36,
                  //           ),
                  //           icon: const Icon(
                  //             CupertinoIcons.slider_horizontal_3,
                  //             color: Colors.white,
                  //             size: 22,
                  //             shadows: [
                  //               Shadow(blurRadius: 6, color: Colors.black54),
                  //             ],
                  //           ),
                  //         ),
                ],
              ),
            ),
            // Like button (right side, vertical centre)
            if (_errorText != null)
              Positioned(
                top: topInset + 58,
                left: 16,
                right: 16,
                child: Text(
                  _errorText!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFDA4AF),
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Urbanist',
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_showComments)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: maxCommentsHeight,
                        ),
                        child: _comments.isEmpty
                            ? const SizedBox.shrink()
                            : ShaderMask(
                                shaderCallback: (rect) {
                                  return const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black,
                                      Colors.black,
                                    ],
                                    stops: [0.0, 0.25, 1.0],
                                  ).createShader(rect);
                                },
                                blendMode: BlendMode.dstIn,
                                child: ListView.builder(
                                  controller: _commentsScrollController,
                                  reverse: true,
                                  padding: const EdgeInsets.only(
                                    top: 28,
                                    bottom: 6,
                                  ),
                                  itemCount: orderedComments.length,
                                  itemBuilder: (context, index) {
                                    final comment = orderedComments[index];
                                    final author = comment.authorName?.trim();
                                    final display =
                                        (author != null && author.isNotEmpty)
                                        ? author
                                        : context.l10n.t('fallbackUser');
                                    // Show the user's own avatar for their
                                    // own comments; for other users we read
                                    // the per-author cache (populated from
                                    // SSE init / any comment that included
                                    // an avatar) and fall back to whatever
                                    // is on the comment itself.
                                    final commentAvatar =
                                        comment.authorId == currentUser.id
                                        ? currentUser.avatar
                                        : (comment.authorAvatar ??
                                              _authorAvatarCache[comment
                                                  .authorId]);
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 8,
                                              top: 2,
                                            ),
                                            child: SportalAvatar(
                                              name: display,
                                              avatar: commentAvatar,
                                              size: 30,
                                            ),
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  display,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                    fontFamily: 'Urbanist',
                                                    fontSize: 13,
                                                    height: 1.2,
                                                    shadows: [
                                                      Shadow(
                                                        blurRadius: 4,
                                                        color: Colors.black54,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 1),
                                                Text(
                                                  comment.text,
                                                  style: const TextStyle(
                                                    color: Color(0xFFE8EEFA),
                                                    fontWeight: FontWeight.w500,
                                                    fontFamily: 'Urbanist',
                                                    fontSize: 13,
                                                    height: 1.3,
                                                    shadows: [
                                                      Shadow(
                                                        blurRadius: 4,
                                                        color: Colors.black54,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                    // Like sits ABOVE the input row in a fixed-size slot —
                    // heart on top, count below, right-aligned. Slot height
                    // is fixed so the input never shifts when likes change.
                    SizedBox(
                      height: 61,
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6, bottom: 7),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: _toggleLike,
                                behavior: HitTestBehavior.opaque,
                                child: TweenAnimationBuilder<double>(
                                  key: ValueKey(_likePulse),
                                  tween: Tween<double>(begin: 1.24, end: 1),
                                  duration: const Duration(milliseconds: 170),
                                  curve: Curves.easeOutBack,
                                  builder: (context, scale, child) {
                                    return Transform.scale(
                                      scale: scale,
                                      child: child,
                                    );
                                  },
                                  child: Icon(
                                    _isLiked
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    size: 34,
                                    color: _isLiked
                                        ? const Color(0xFFFF5B7E)
                                        : Colors.white,
                                    shadows: const [
                                      Shadow(
                                        blurRadius: 6,
                                        color: Colors.black54,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_likesCount > 0)
                                SizedBox(
                                  height: 16,
                                  child: Text(
                                    '$_likesCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Urbanist',
                                      shadows: [
                                        Shadow(
                                          blurRadius: 4,
                                          color: Colors.black54,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => unawaited(_sendComment()),
                            decoration: InputDecoration(
                              hintText: context.l10n.t('commentsHint'),
                              hintStyle: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Urbanist',
                              ),
                              filled: true,
                              fillColor: Colors.transparent,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  width: 0.8,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.38),
                                  width: 1,
                                ),
                              ),
                              suffixIcon: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value != 'toggle_comments') return;
                                  setState(() {
                                    _showComments = !_showComments;
                                  });
                                },
                                icon: Icon(
                                  Icons.more_horiz_rounded,
                                  color: _showComments
                                      ? const Color(0xFFD1DDF6)
                                      : SportalColors.primaryBlue,
                                ),
                                itemBuilder: (context) => [
                                  PopupMenuItem<String>(
                                    value: 'toggle_comments',
                                    child: Text(
                                      _showComments
                                          ? context.l10n.t('commentsHide')
                                          : context.l10n.t('commentsShow'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                SportalColors.primaryBlue,
                                SportalColors.primaryBlue.withValues(
                                  alpha: 0.78,
                                ),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: SportalColors.primaryBlue.withValues(
                                  alpha: 0.45,
                                ),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: _isSendingComment
                                ? null
                                : () => unawaited(_sendComment()),
                            icon: _isSendingComment
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHlsView() {
    if (_isStarting) {
      return const Center(child: CircularProgressIndicator());
    }
    final ctrl = _hlsController;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    if (ctrl.value.hasError) {
      return Center(
        child: Text(
          ctrl.value.errorDescription ?? 'Playback error',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFFDA4AF),
            fontFamily: 'Urbanist',
          ),
        ),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: ctrl.value.aspectRatio > 0
            ? ctrl.value.aspectRatio
            : 16 / 9,
        // RepaintBoundary isolates the video surface so unrelated UI work
        // (like animations, comment polling, gradient overlay) does not
        // trigger video repaints and cause visible stutter / freeze.
        child: RepaintBoundary(child: VideoPlayer(ctrl)),
      ),
    );
  }
}

class _LiveWatchPill extends StatelessWidget {
  const _LiveWatchPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.l10n.t('commonLive').toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          fontFamily: 'Urbanist',
        ),
      ),
    );
  }
}

class _ViewerCountBadge extends StatelessWidget {
  const _ViewerCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xAA1A2440),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.remove_red_eye_outlined,
            color: Colors.white,
            size: 14,
            shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
          ),
          const SizedBox(width: 5),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'Urbanist',
              shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
            ),
          ),
        ],
      ),
    );
  }
}
