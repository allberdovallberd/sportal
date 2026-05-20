import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../ui/sportal_colors.dart';
import '../../../ui/widgets/sportal_avatar.dart';
import '../../auth/providers/auth_session_provider.dart';
import '../models/stream_api_exception.dart';
import '../models/stream_models.dart';
import '../providers/stream_providers.dart';

class PublishStreamPage extends ConsumerStatefulWidget {
  const PublishStreamPage({
    super.key,
    required this.streamId,
    required this.streamTitle,
    this.whipPath,
    this.publishBaseUrl,
    this.publishToken,
    this.whipUrl,
  });

  final String streamId;
  final String streamTitle;
  final String? whipPath;
  final String? publishBaseUrl;
  final String? publishToken;

  /// Full WHIP URL returned by the API (includes secret query param). When
  /// provided this is used directly and publishBaseUrl / whipPath are ignored.
  final String? whipUrl;

  @override
  ConsumerState<PublishStreamPage> createState() => _PublishStreamPageState();
}

class _PublishStreamPageState extends ConsumerState<PublishStreamPage>
    with WidgetsBindingObserver {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _commentsScrollController = ScrollController();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  Timer? _commentsPollTimer;
  Timer? _likesPollTimer;
  Timer? _viewerCountPollTimer;

  bool _rendererReady = false;
  bool _isStarting = true;
  bool _isPublishing = false;
  bool _isMicEnabled = true;
  bool _isCameraEnabled = true;
  bool _isFrontCamera = true;
  bool _isSendingComment = false;
  bool _showComments = true;
  int _likesCount = 0;
  int _viewerCount = 0;
  bool _hasStopped = false;
  bool _hasMarkedLive = false;
  bool _isStopping = false;

  String? _errorText;
  List<StreamCommentModel> _comments = const <StreamCommentModel>[];

  // Per-author avatar cache — see watch_stream_page for rationale.
  final Map<String, String> _authorAvatarCache = <String, String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_enterFullscreen());
    unawaited(_initAndStart());
    _startCommentsPolling();
    _startLikesPolling();
    _startViewerCountPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Keep stream alive in background; only reduce non-critical polling work.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _commentsPollTimer?.cancel();
      _likesPollTimer?.cancel();
      _viewerCountPollTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      if (_isPublishing) {
        _startCommentsPolling();
        _startLikesPolling();
        _startViewerCountPolling();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _commentsPollTimer?.cancel();
    _likesPollTimer?.cancel();
    _viewerCountPollTimer?.cancel();
    _commentController.dispose();
    _commentsScrollController.dispose();
    // If user explicitly exits stream we stop in _confirmStopAndExit.
    // On app/process close, avoid heavy async network work during dispose.
    unawaited(_cleanupLocalMedia());
    unawaited(_localRenderer.dispose());
    unawaited(_exitFullscreen());
    super.dispose();
  }

  Future<void> _enterFullscreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Streamer can hold the phone in any orientation; the camera track and
    // the layout adapt naturally. Web/remote viewers receive the rotated
    // video via the WebRTC orientation extension.
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _exitFullscreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
  }

  Future<void> _initAndStart() async {
    try {
      await _localRenderer.initialize();
      if (!mounted) return;
      setState(() {
        _rendererReady = true;
      });
      await _startPublishing();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isStarting = false;
        _errorText = context.l10n.t('publishCameraInitFailed');
      });
    }
  }

  Future<void> _startPublishing() async {
    final api = ref.read(streamApiClientProvider);

    setState(() {
      _isStarting = true;
      _errorText = null;
    });

    try {
      final media = await navigator.mediaDevices.getUserMedia(<String, dynamic>{
        'audio': <String, dynamic>{
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': <String, dynamic>{
          'facingMode': _isFrontCamera ? 'user' : 'environment',
          'width': <String, dynamic>{'ideal': 720},
          'height': <String, dynamic>{'ideal': 1280},
          'frameRate': <String, dynamic>{'ideal': 24, 'max': 30},
        },
      });

      _localStream = media;
      _localRenderer.srcObject = media;

      final pc = await createPeerConnection(<String, dynamic>{
        'bundlePolicy': 'max-bundle',
        'rtcpMuxPolicy': 'require',
        'iceCandidatePoolSize': 4,
        'sdpSemantics': 'unified-plan',
      });

      for (final track in media.getTracks()) {
        await pc.addTrack(track, media);
      }

      final offer = await pc.createOffer(<String, dynamic>{
        'mandatory': <String, dynamic>{
          'OfferToReceiveAudio': false,
          'OfferToReceiveVideo': false,
        },
        'optional': <dynamic>[],
      });
      await pc.setLocalDescription(offer);

      final whipUri = widget.whipUrl?.trim().isNotEmpty == true
          ? _sanitizeWhipUrl(
              Uri.parse(widget.whipUrl!),
              fallbackBaseUrl: api.defaultSrsWhipBaseUrl,
            )
          : _buildWhipUri(
              baseUrl: widget.publishBaseUrl?.trim().isNotEmpty == true
                  ? widget.publishBaseUrl!
                  : api.defaultSrsWhipBaseUrl,
              streamId: widget.streamId,
              whipPath: widget.whipPath,
              token: widget.publishToken,
            );

      final answerSdp = await _exchangeSdp(
        url: whipUri,
        offerSdp: offer.sdp ?? '',
      );
      await pc.setRemoteDescription(RTCSessionDescription(answerSdp, 'answer'));
      _hasMarkedLive = true;

      _peerConnection = pc;
      await WakelockPlus.enable();

      if (!mounted) return;
      setState(() {
        _isPublishing = true;
        _isStarting = false;
      });
    } on StreamApiException catch (error) {
      await _cleanupLocalMedia();
      if (!mounted) return;
      setState(() {
        _isPublishing = false;
        _isStarting = false;
        _errorText = error.message;
      });
    } catch (error) {
      await _cleanupLocalMedia();
      if (!mounted) return;
      setState(() {
        _isPublishing = false;
        _isStarting = false;
        _errorText = _buildStartStreamError(error);
      });
    }
  }

  String _buildStartStreamError(Object error) {
    final raw = error.toString();
    final normalized = raw.toLowerCase();
    if (normalized.contains('notallowederror') ||
        normalized.contains('permission') ||
        normalized.contains('denied')) {
      return 'Could not start stream. Camera we mikrofon rugsatlaryny acyn.';
    }
    final l10n = context.l10n;
    if (normalized.contains('notallowederror') ||
        normalized.contains('permission') ||
        normalized.contains('denied')) {
      return l10n.t('publishStartPermission');
    }
    return l10n.format('publishStartFailed', {'error': raw});
  }

  Future<String> _exchangeSdp({
    required Uri url,
    required String offerSdp,
  }) async {
    final response = await http
        .post(
          url,
          headers: const <String, String>{'Content-Type': 'application/sdp'},
          body: offerSdp,
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StreamApiException(
        error: 'SDP_EXCHANGE_FAILED',
        message: context.l10n.format('publishVideoHandshakeFailed', {
          'code': '${response.statusCode}',
        }),
      );
    }

    return response.body;
  }

  Uri _buildWhipUri({
    required String baseUrl,
    required String streamId,
    String? whipPath,
    String? token,
  }) {
    final trimmedBase = baseUrl.trim();
    final trimmedPath = whipPath?.trim() ?? '';
    final baseUri = Uri.parse(trimmedBase);

    Uri resolvedUri;
    if (trimmedPath.isNotEmpty) {
      if (trimmedPath.startsWith('http://') ||
          trimmedPath.startsWith('https://')) {
        resolvedUri = Uri.parse(trimmedPath);
      } else {
        resolvedUri = baseUri.resolve(trimmedPath);
      }
    } else if (_looksLikeWhipEndpoint(baseUri)) {
      resolvedUri = baseUri;
    } else {
      // Build the WHIP path relative to the base URL, preserving any path
      // prefix (e.g. /sport/ from the nginx reverse proxy).
      final trimmedBaseNoSlash = trimmedBase.endsWith('/')
          ? trimmedBase.substring(0, trimmedBase.length - 1)
          : trimmedBase;
      resolvedUri = Uri.parse(
        '$trimmedBaseNoSlash/rtc/v1/whip/',
      ).replace(queryParameters: {'app': 'live', 'stream': streamId});
    }

    return _appendTokenIfNeeded(resolvedUri, token);
  }

  /// The server sometimes returns a `whip_url` without an explicit port,
  /// causing the request to go to port 80 where nothing listens (errno=111).
  /// When that happens, rewrite the URL to go through nginx at port 8000
  /// with the /sport path prefix instead.
  Uri _sanitizeWhipUrl(Uri serverUrl, {required String fallbackBaseUrl}) {
    final fallback = Uri.parse(fallbackBaseUrl.trim());

    // Server returned a relative path (no host). Resolve it against the
    // fallback base URL's host so we get a full absolute URL.
    if (serverUrl.host.isEmpty) {
      var path = serverUrl.path;
      if (!path.startsWith('/sport')) {
        path = '/sport$path';
      }
      return fallback.replace(
        path: path,
        queryParameters: serverUrl.queryParameters.isEmpty
            ? null
            : serverUrl.queryParameters,
      );
    }

    final port = serverUrl.hasPort ? serverUrl.port : 80;
    // Port 80 with plain http almost certainly means the server config is
    // missing the port. Route through nginx instead.
    if (port == 80 && serverUrl.scheme == 'http') {
      // Rebuild on the nginx host/port but keep the original path & query.
      // Ensure the path starts with /sport.
      var path = serverUrl.path;
      if (!path.startsWith('/sport')) {
        path = '/sport$path';
      }
      return fallback.replace(
        path: path,
        queryParameters: serverUrl.queryParameters.isEmpty
            ? null
            : serverUrl.queryParameters,
      );
    }
    return serverUrl;
  }

  bool _looksLikeWhipEndpoint(Uri uri) {
    final path = uri.path.toLowerCase();
    return path.contains('/rtc/v1/whip');
  }

  Uri _appendTokenIfNeeded(Uri uri, String? token) {
    final trimmedToken = token?.trim() ?? '';
    if (trimmedToken.isEmpty) {
      return uri;
    }

    final query = Map<String, String>.from(uri.queryParameters);
    // Use 'secret' as the parameter name (per SRS WHIP convention).
    if (!query.containsKey('secret') && !query.containsKey('token')) {
      query['secret'] = trimmedToken;
    }
    return uri.replace(queryParameters: query);
  }

  Future<void> _toggleMic() async {
    final audioTracks =
        _localStream?.getAudioTracks() ?? const <MediaStreamTrack>[];
    if (audioTracks.isEmpty) return;

    final next = !_isMicEnabled;
    audioTracks.first.enabled = next;
    if (!mounted) return;
    setState(() {
      _isMicEnabled = next;
    });
  }

  Future<void> _toggleCameraVideo() async {
    final videoTracks =
        _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[];
    if (videoTracks.isEmpty) return;

    final next = !_isCameraEnabled;
    videoTracks.first.enabled = next;
    if (!mounted) return;
    setState(() {
      _isCameraEnabled = next;
    });
  }

  Future<void> _switchCamera() async {
    final videoTracks =
        _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[];
    if (videoTracks.isEmpty) return;

    try {
      await Helper.switchCamera(videoTracks.first);
      if (!mounted) return;
      setState(() {
        _isFrontCamera = !_isFrontCamera;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = context.l10n.t('publishSwitchCameraFailed');
      });
    }
  }

  void _startCommentsPolling() {
    _commentsPollTimer?.cancel();
    unawaited(_fetchComments());
    _commentsPollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_fetchComments()),
    );
  }

  void _startLikesPolling() {
    _likesPollTimer?.cancel();
    unawaited(_loadLikes());
    _likesPollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_loadLikes()),
    );
  }

  void _startViewerCountPolling() {
    _viewerCountPollTimer?.cancel();
    unawaited(_loadViewerCount());
    _viewerCountPollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_loadViewerCount()),
    );
  }

  Future<void> _loadViewerCount() async {
    try {
      final api = ref.read(streamApiClientProvider);
      final session = ref.read(streamSessionContextProvider);
      final count = await api.fetchViewerCount(
        accessToken: session.accessToken,
        streamId: widget.streamId,
      );
      if (mounted && _viewerCount != count) {
        setState(() => _viewerCount = count);
      }
    } catch (_) {
      // Ignore polling errors.
    }
  }

  Future<void> _loadLikes() async {
    try {
      final api = ref.read(streamApiClientProvider);
      final session = ref.read(streamSessionContextProvider);
      final result = await api.getStreamLikes(
        accessToken: session.accessToken,
        streamId: widget.streamId,
      );
      if (mounted && _likesCount != result.likes) {
        setState(() {
          _likesCount = result.likes;
        });
      }
    } catch (_) {
      // Ignore polling errors.
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
        for (final c in items) {
          final a = c.authorAvatar?.trim();
          if (a != null && a.isNotEmpty && c.authorId.isNotEmpty) {
            _authorAvatarCache[c.authorId] = a;
          }
        }
      });
      if (_showComments) _scrollCommentsToBottom();
    } catch (_) {
      // Ignore polling errors.
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

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSendingComment) return;

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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = context.l10n.t('publishCommentFailed');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSendingComment = false;
        });
      }
    }
  }

  Future<void> _cleanupLocalMedia() async {
    final pc = _peerConnection;
    _peerConnection = null;
    if (pc != null) {
      await pc.close();
      await pc.dispose();
    }

    final stream = _localStream;
    _localStream = null;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();
    }

    _localRenderer.srcObject = null;
    await WakelockPlus.disable();
  }

  Future<void> _stopStreaming({required bool notifyServer}) async {
    if (_hasStopped) return;
    _hasStopped = true;

    final api = ref.read(streamApiClientProvider);
    final session = ref.read(streamSessionContextProvider);

    _commentsPollTimer?.cancel();
    _likesPollTimer?.cancel();
    _viewerCountPollTimer?.cancel();

    if (notifyServer) {
      if (_hasMarkedLive) {
        try {
          await api.markStreamEnded(
            accessToken: session.accessToken,
            streamId: widget.streamId,
          );
        } catch (_) {}
      }
      try {
        await api.deleteStreamSession(
          accessToken: session.accessToken,
          streamId: widget.streamId,
        );
      } catch (_) {}
    }

    await _cleanupLocalMedia();
    if (!mounted) return;
    setState(() {
      _isPublishing = false;
    });
  }

  Future<void> _confirmStopAndExit() async {
    if (_isStopping) return;

    final shouldStop = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoTheme(
        data: const CupertinoThemeData(brightness: Brightness.dark),
        child: CupertinoAlertDialog(
          title: Text(context.l10n.t('publishStopTitle')),
          content: Text(context.l10n.t('publishStopBody')),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.t('commonCancel')),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.t('commonStop')),
            ),
          ],
        ),
      ),
    );

    if (shouldStop != true) return;
    setState(() {
      _isStopping = true;
    });

    await _stopStreaming(notifyServer: true);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final maxCommentsHeight = MediaQuery.of(context).size.height * 0.35;
    final orderedComments = _comments.toList()
      ..sort((a, b) {
        final aDate = DateTime.tryParse(a.createdAt);
        final bDate = DateTime.tryParse(b.createdAt);
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
    final currentUser = ref.read(authSessionProvider).user;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _isStopping) return;
        unawaited(_confirmStopAndExit());
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(
          child: Stack(
            children: [
              Positioned.fill(
                child: _rendererReady && _localRenderer.srcObject != null
                    ? RepaintBoundary(
                        child: RTCVideoView(
                          _localRenderer,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          mirror: _isFrontCamera,
                        ),
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
              Positioned.fill(
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
              Positioned(
                top: topInset + 14,
                left: 14,
                right: 132,
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
                    // Row 1: LIVE pill — viewer count — stop
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LiveStatusPill(isLive: _isPublishing),
                        const SizedBox(width: 8),
                        _ViewerCountBadge(count: _viewerCount),
                        const SizedBox(width: 8),
                        Container(
                          decoration: const BoxDecoration(
                            color: Color(0xAA6B121E),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: _isStarting ? null : _confirmStopAndExit,
                            icon: const Icon(Icons.stop_circle_rounded),
                            color: Colors.white,
                            iconSize: 40,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _TopControlButton(
                      icon: _isMicEnabled ? Icons.mic : Icons.mic_off,
                      onTap: _isPublishing ? _toggleMic : null,
                    ),
                    const SizedBox(height: 10),
                    _TopControlButton(
                      icon: _isCameraEnabled
                          ? Icons.videocam
                          : Icons.videocam_off,
                      onTap: _isPublishing ? _toggleCameraVideo : null,
                    ),
                    const SizedBox(height: 10),
                    _TopControlButton(
                      icon: Icons.flip_camera_android,
                      onTap: _isPublishing ? _switchCamera : null,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: 48,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 48,
                            height: 48,
                            child: Center(
                              child: Icon(
                                Icons.favorite_rounded,
                                color: Color(0xFFFF5B7E),
                                size: 28,
                                shadows: [
                                  Shadow(blurRadius: 6, color: Colors.black54),
                                ],
                              ),
                            ),
                          ),
                          if (_likesCount > 0)
                            Text(
                              '$_likesCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Urbanist',
                                shadows: [
                                  Shadow(blurRadius: 4, color: Colors.black54),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
                                                      fontWeight:
                                                          FontWeight.w700,
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
                                                      fontWeight:
                                                          FontWeight.w500,
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
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Urbanist',
                              ),
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
                            decoration: const BoxDecoration(
                              color: Color(0xCC1A8CF3),
                              shape: BoxShape.circle,
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
      ),
    );
  }
}

class _TopControlButton extends StatelessWidget {
  const _TopControlButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(
          icon,
          color: onTap == null ? const Color(0xFF6F7D97) : Colors.white,
          size: 28,
          shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
        ),
      ),
    );
  }
}

class _StreamerLikes extends StatelessWidget {
  const _StreamerLikes({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.favorite_rounded,
          color: Color(0xFFFF5B7E),
          size: 34,
          shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
        ),
        const SizedBox(height: 1),
        Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            fontFamily: 'Urbanist',
            shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
          ),
        ),
      ],
    );
  }
}

class _LiveStatusPill extends StatelessWidget {
  const _LiveStatusPill({required this.isLive});

  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isLive ? const Color(0xFFDC2626) : const Color(0xFF374151),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isLive
            ? context.l10n.t('commonLive').toUpperCase()
            : context.l10n.t('statusStarting'),
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
