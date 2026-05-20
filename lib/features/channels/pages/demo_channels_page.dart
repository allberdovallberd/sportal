import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';

import '../../../ui/sportal_colors.dart';
import '../../../ui/sportal_text_styles.dart';
import '../../../ui/widgets/sportal_background.dart';
import '../models/tv_channel.dart';
import 'channel_player_page.dart';

/// A page that lists all available demo TV channels in a 2-column grid.
///
/// Channels are loaded from `assets/channels.json` and ordered by priority
/// (high → priority → normal). Within each priority bucket the list is
/// sorted alphabetically.
class DemoChannelsPage extends StatefulWidget {
  const DemoChannelsPage({super.key});

  @override
  State<DemoChannelsPage> createState() => _DemoChannelsPageState();
}

class _DemoChannelsPageState extends State<DemoChannelsPage> {
  Future<List<TvChannel>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _loadChannels();
  }

  Future<List<TvChannel>> _loadChannels() async {
    // Tiny delay before parsing so the page transition animation can finish
    // without competing for the UI thread — this prevents jank when opening
    // the screen from streams home.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final raw = await rootBundle.loadString('assets/channels.json');
    final data = json.decode(raw) as Map<String, dynamic>;
    final list = (data['channels'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(TvChannel.fromJson)
        .toList();

    int priorityRank(ChannelPriority p) {
      switch (p) {
        case ChannelPriority.high:
          return 0;
        case ChannelPriority.priority:
          return 1;
        case ChannelPriority.normal:
          return 2;
      }
    }

    list.sort((a, b) {
      final pa = priorityRank(a.priority);
      final pb = priorityRank(b.priority);
      if (pa != pb) return pa.compareTo(pb);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  void _openChannel(TvChannel channel) {
    Navigator.of(context).push(
      _fadeRoute(
        ChannelPlayerPage(channelName: channel.name, hlsUrl: channel.url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SportalBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: FutureBuilder<List<TvChannel>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: SportalColors.primaryBlue,
                        ),
                      );
                    }
                    if (snapshot.hasError || !snapshot.hasData) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Kanallar ýüklenip bilmedi',
                            textAlign: TextAlign.center,
                            style: SportalTextStyles.b2.copyWith(
                              color: SportalColors.errorRed,
                            ),
                          ),
                        ),
                      );
                    }
                    final channels = snapshot.data!;
                    return _ChannelSectionsView(
                      channels: channels,
                      onTap: _openChannel,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            splashRadius: 18,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TV Kanallar',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SportalTextStyles.h2.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Göni efir',
                  style: SportalTextStyles.t1.copyWith(
                    color: SportalColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelSectionsView extends StatelessWidget {
  const _ChannelSectionsView({required this.channels, required this.onTap});

  final List<TvChannel> channels;
  final void Function(TvChannel) onTap;

  @override
  Widget build(BuildContext context) {
    final high = channels
        .where((channel) => channel.priority == ChannelPriority.high)
        .toList();
    final priority = channels
        .where((channel) => channel.priority == ChannelPriority.priority)
        .toList();
    final normal = channels
        .where((channel) => channel.priority == ChannelPriority.normal)
        .toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildSection('High Priority', high),
        _buildSection('Priority Channels', priority),
        _buildSection('All Channels', normal, addBottomPadding: true),
      ],
    );
  }

  Widget _buildSection(
    String title,
    List<TvChannel> items, {
    bool addBottomPadding = false,
  }) {
    if (items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Text(
                  title,
                  style: SportalTextStyles.b1.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${items.length}',
                    style: SportalTextStyles.t1.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, addBottomPadding ? 32 : 4),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate((context, index) {
              return _ChannelGridCard(
                channel: items[index],
                delay: Duration(milliseconds: 24 * (index % 8)),
                onTap: () => onTap(items[index]),
              );
            }, childCount: items.length),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 14,
              mainAxisExtent: 180,
            ),
          ),
        ),
      ],
    );
  }
}

/// Card that mimics the visual style of the live-stream card on the home
/// page: rounded white container, 16:9 image with LIVE chip overlay, and a
/// title strip underneath.
class _ChannelGridCard extends StatefulWidget {
  const _ChannelGridCard({
    required this.channel,
    required this.onTap,
    required this.delay,
  });

  final TvChannel channel;
  final VoidCallback onTap;
  final Duration delay;

  @override
  State<_ChannelGridCard> createState() => _ChannelGridCardState();
}

class _ChannelGridCardState extends State<_ChannelGridCard> {
  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.all(Radius.circular(16));
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 240),
      opacity: _visible ? 1 : 0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: borderRadius,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: borderRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: borderRadius,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final imageHeight = constraints.maxHeight * 0.8;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: imageHeight,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _ChannelThumbnail(channel: widget.channel),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    stops: const [0.55, 1.0],
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.55),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const Positioned(
                              left: 8,
                              top: 8,
                              child: _LiveChip(),
                            ),
                            if (widget.channel.priority !=
                                ChannelPriority.normal)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: _PriorityChip(
                                  priority: widget.channel.priority,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            widget.channel.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0E1A3D),
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelThumbnail extends StatelessWidget {
  const _ChannelThumbnail({required this.channel});

  final TvChannel channel;

  @override
  Widget build(BuildContext context) {
    // Priority-themed gradient is always drawn as the base. If a thumbnail
    // asset exists, let it cover the full image area so the tile does not
    // look letterboxed.
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _gradientFor(channel),
            ),
          ),
        ),
        if (channel.logo != null)
          _buildLogo()
        else
          _InitialOverlay(name: channel.name),
      ],
    );
  }

  Widget _buildLogo() {
    final logoPath = channel.logo!;
    if (logoPath.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(
        logoPath,
        fit: BoxFit.cover,
        placeholderBuilder: (_) => _InitialOverlay(name: channel.name),
      );
    }

    return Image.asset(
      logoPath,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => _InitialOverlay(name: channel.name),
    );
  }

  List<Color> _gradientFor(TvChannel ch) {
    switch (ch.priority) {
      case ChannelPriority.high:
        return const [Color(0xFF1F3A93), Color(0xFF0B132B)];
      case ChannelPriority.priority:
        return const [Color(0xFF1F6FEB), Color(0xFF152238)];
      case ChannelPriority.normal:
        return const [Color(0xFF2A3556), Color(0xFF101729)];
    }
  }
}

class _InitialOverlay extends StatelessWidget {
  const _InitialOverlay({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : trimmed.characters.first.toUpperCase();
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 1,
          shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
        ),
      ),
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Text(
        'LIVE',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          height: 1,
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});

  final ChannelPriority priority;

  @override
  Widget build(BuildContext context) {
    final isHigh = priority == ChannelPriority.high;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isHigh ? const Color(0xFFFFC107) : SportalColors.primaryBlue,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isHigh ? Icons.star : Icons.flash_on,
            color: Colors.white,
            size: 10,
          ),
          const SizedBox(width: 3),
          Text(
            isHigh ? 'TOP' : 'HOT',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

PageRoute<void> _fadeRoute(Widget page) {
  return PageRouteBuilder<void>(
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
    transitionDuration: const Duration(milliseconds: 220),
  );
}
