import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../ui/sportal_colors.dart';
import '../../../ui/sportal_text_styles.dart';

class ChannelPlayerPage extends StatefulWidget {
  const ChannelPlayerPage({
    super.key,
    required this.channelName,
    required this.hlsUrl,
  });

  final String channelName;
  final String hlsUrl;

  @override
  State<ChannelPlayerPage> createState() => _ChannelPlayerPageState();
}

class _ChannelPlayerPageState extends State<ChannelPlayerPage>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  Timer? _healthTimer;

  bool _isStarting = true;
  bool _isRecovering = false;
  bool _isLandscape = false;
  bool _isPausedByUser = false;
  String? _errorText;
  Duration _lastPosition = Duration.zero;
  int _stallTicks = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enterFullscreen();
    unawaited(_initPlayer());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _healthTimer?.cancel();
      _controller?.pause();
    } else if (state == AppLifecycleState.resumed) {
      if (_controller != null) {
        if (!_isPausedByUser) {
          _controller!.play();
          _startHealthMonitor();
        }
      } else {
        unawaited(_initPlayer());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _healthTimer?.cancel();
    unawaited(_cleanup());
    unawaited(_exitFullscreen());
    super.dispose();
  }

  Future<void> _enterFullscreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
  }

  Future<void> _exitFullscreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
  }

  Future<void> _toggleOrientation() async {
    final next = !_isLandscape;
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

  Future<void> _cleanup() async {
    _healthTimer?.cancel();
    final ctrl = _controller;
    _controller = null;
    await ctrl?.dispose();
    await WakelockPlus.disable();
  }

  Future<void> _initPlayer() async {
    if (!mounted) return;
    setState(() {
      _isStarting = true;
      _errorText = null;
    });

    // Retry up to 5 times with 2s delay between each — some streams need
    // a moment to produce their first segment.
    const maxAttempts = 5;
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (!mounted) return;
      try {
        await _loadController(widget.hlsUrl);
        lastError = null;
        break;
      } catch (e) {
        lastError = e;
        if (attempt < maxAttempts) {
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
    }

    if (!mounted) return;
    if (lastError != null) {
      setState(() {
        _isStarting = false;
        _errorText = 'Kanal yüklenemedi. Lütfen tekrar deneyin.';
      });
    } else {
      setState(() => _isStarting = false);
    }
  }

  Future<void> _loadController(String url) async {
    final old = _controller;
    _controller = null;
    await old?.dispose();

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );
    await controller.initialize();

    // Keep TV a bit behind true live edge. The additional headroom lets HLS
    // stay a few segments ahead and makes playback noticeably smoother.
    final dur = controller.value.duration;
    const liveEdge = Duration(seconds: 12);
    if (dur > liveEdge + const Duration(seconds: 2)) {
      await controller.seekTo(dur - liveEdge);
    }

    // Warm up hidden playback with muted audio. Paused HLS generally buffers
    // very little; letting it advance briefly while hidden fills a few
    // segments so playback starts with a maintained delay instead of a hitch.
    await controller.setVolume(0);
    await controller.play();
    final preloadStart = DateTime.now();
    const minWarmup = Duration(milliseconds: 1600);
    const maxWarmup = Duration(seconds: 5);
    while (mounted && DateTime.now().difference(preloadStart) < maxWarmup) {
      final value = controller.value;
      final bufferedAhead = value.buffered.isEmpty
          ? Duration.zero
          : value.buffered.last.end - value.position;
      if (DateTime.now().difference(preloadStart) >= minWarmup &&
          value.position >= const Duration(milliseconds: 1200) &&
          bufferedAhead >= const Duration(seconds: 2) &&
          !value.isBuffering) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }

    if (!mounted) {
      await controller.dispose();
      return;
    }

    final refreshedDuration = controller.value.duration;
    if (refreshedDuration > liveEdge + const Duration(seconds: 2)) {
      await controller.seekTo(refreshedDuration - liveEdge);
    }
    await controller.setVolume(1);
    await WakelockPlus.enable();

    if (mounted) {
      _controller = controller;
      _isPausedByUser = false;
      _lastPosition = controller.value.position;
      _stallTicks = 0;
      _startHealthMonitor();
    } else {
      await controller.dispose();
    }
  }

  Future<void> _togglePlayback() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;

    if (ctrl.value.isPlaying) {
      await ctrl.pause();
      if (mounted) {
        setState(() => _isPausedByUser = true);
      }
      return;
    }

    await ctrl.play();
    _startHealthMonitor();
    if (mounted) {
      setState(() => _isPausedByUser = false);
    }
  }

  void _startHealthMonitor() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final ctrl = _controller;
      if (ctrl == null || !ctrl.value.isInitialized) return;
      if (_isRecovering) return;

      if (ctrl.value.hasError) {
        unawaited(_recover());
        return;
      }

      final pos = ctrl.value.position;
      final shouldPlay = ctrl.value.isPlaying || ctrl.value.isBuffering;
      if (shouldPlay && pos == _lastPosition) {
        _stallTicks++;
      } else {
        _stallTicks = 0;
      }
      _lastPosition = pos;

      if (_stallTicks >= 4) {
        _stallTicks = 0;
        unawaited(_recover());
      }
    });
  }

  Future<void> _recover() async {
    if (_isRecovering) return;
    _isRecovering = true;
    try {
      await _loadController(widget.hlsUrl);
    } catch (_) {
      // Health monitor will try again next cycle.
    } finally {
      _isRecovering = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    final hasVideo = ctrl != null && ctrl.value.isInitialized && !_isStarting;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video layer
          if (hasVideo)
            Center(
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: ctrl,
                builder: (context, value, child) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _togglePlayback,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(
                          aspectRatio: value.aspectRatio,
                          child: VideoPlayer(ctrl),
                        ),
                        if (!value.isPlaying && !value.isBuffering)
                          Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.42),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 42,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            )
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: SportalColors.primaryBlue,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Kanal taýýarlanýar...',
                    style: SportalTextStyles.b2.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    splashRadius: 20,
                  ),
                  Expanded(
                    child: Text(
                      widget.channelName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SportalTextStyles.h3.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [
                          const Shadow(blurRadius: 8, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),
                  // Rotate button
                  IconButton(
                    onPressed: _toggleOrientation,
                    icon: Icon(
                      _isLandscape
                          ? Icons.stay_current_portrait_rounded
                          : Icons.stay_current_landscape_rounded,
                      color: Colors.white,
                    ),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          // Error banner
          if (_errorText != null)
            Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SportalColors.errorRed.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _errorText!,
                      textAlign: TextAlign.center,
                      style: SportalTextStyles.b2.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => unawaited(_initPlayer()),
                      child: Text(
                        'Yeniden Dene',
                        style: SportalTextStyles.b2.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Live badge
          if (hasVideo)
            const Positioned(bottom: 16, right: 16, child: _LiveBadge()),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'LIVE',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
