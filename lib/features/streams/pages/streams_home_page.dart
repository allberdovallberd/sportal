import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../ui/sportal_colors.dart';
import '../../../ui/sportal_text_styles.dart';
import '../../../ui/widgets/sportal_background.dart';
import '../../../ui/widgets/sportal_bottom_nav_bar.dart';
import '../../../ui/widgets/sportal_category_row.dart';
import '../../../ui/widgets/sportal_primary_button.dart';
import '../models/stream_api_exception.dart';
import '../models/stream_models.dart';
import '../providers/stream_providers.dart';
import 'publish_stream_page.dart';
import 'watch_stream_page.dart';

class StreamsHomePage extends ConsumerStatefulWidget {
  const StreamsHomePage({super.key});

  @override
  ConsumerState<StreamsHomePage> createState() => _StreamsHomePageState();
}

class _StreamsHomePageState extends ConsumerState<StreamsHomePage> {
  bool _creating = false;
  String? _errorText;
  String? _deletingStreamId;

  static const List<_SportOption> _sportOptions = [
    _SportOption(
      key: 'all',
      imageAsset: '',
      backendValue: null,
      supportedForCreate: false,
    ),
    _SportOption(
      key: 'football',
      imageAsset: 'assets/images/football.jpg',
      backendValue: 'football',
      supportedForCreate: true,
    ),
    _SportOption(
      key: 'basketball',
      imageAsset: 'assets/images/basketball.jpg',
      backendValue: null,
      supportedForCreate: false,
    ),
    _SportOption(
      key: 'tennis',
      imageAsset: 'assets/images/tennis.jpg',
      backendValue: null,
      supportedForCreate: false,
    ),
    _SportOption(
      key: 'volleyball',
      imageAsset: 'assets/images/volleyball.jpg',
      backendValue: 'volleyball',
      supportedForCreate: true,
    ),
    _SportOption(
      key: 'boxing',
      imageAsset: 'assets/images/boxing.jpg',
      backendValue: null,
      supportedForCreate: false,
    ),
    _SportOption(
      key: 'mma',
      imageAsset: 'assets/images/mma.jpg',
      backendValue: null,
      supportedForCreate: false,
    ),
    _SportOption(
      key: 'formula_one',
      imageAsset: 'assets/images/formula_one.jpg',
      backendValue: null,
      supportedForCreate: false,
    ),
  ];

  void _refresh() {
    ref.read(streamRefreshKeyProvider.notifier).state++;
  }

  Future<void> _openCreateDialog() async {
    final l10n = context.l10n;
    final session = ref.read(streamSessionContextProvider);
    if (!session.isAdmin) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.t('streamsOnlyAdmin'))));
      return;
    }

    final draft = await showDialog<_CreateStreamDraft>(
      context: context,
      builder: (dialogContext) {
        final titleController = TextEditingController();
        var selectedSportKey = 'football';
        String? dialogError;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedOption = _sportOptions.firstWhere(
              (option) => option.key == selectedSportKey,
              orElse: () => _sportOptions[1],
            );
            return AlertDialog(
              backgroundColor: SportalColors.dialogBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                l10n.t('streamsNewTitle'),
                style: SportalTextStyles.h3.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        style: SportalTextStyles.b2,
                        decoration: InputDecoration(
                          hintText: l10n.t('streamsTitleHint'),
                          hintStyle: SportalTextStyles.b2.copyWith(
                            color: SportalColors.textSecondary,
                          ),
                          filled: true,
                          fillColor: SportalColors.surfaceMuted,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 88,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _sportOptions.length - 1,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final option = _sportOptions[index + 1];
                            final isSelected = selectedSportKey == option.key;
                            return InkWell(
                              onTap: () {
                                setDialogState(() {
                                  selectedSportKey = option.key;
                                  dialogError = null;
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 98,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? SportalColors.primaryBlue
                                        : Colors.white.withValues(alpha: 0.22),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(9),
                                      child: Image.asset(
                                        option.imageAsset,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            9,
                                          ),
                                          gradient: LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                            colors: [
                                              Colors.black.withValues(
                                                alpha: 0.55,
                                              ),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: 6,
                                      right: 6,
                                      bottom: 6,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _sportLabel(context, option),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: SportalTextStyles.t1
                                                .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          if (!option.supportedForCreate)
                                            Text(
                                              l10n.t('streamsSoon'),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: SportalTextStyles.t1
                                                  .copyWith(
                                                    fontSize: 10,
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.82,
                                                        ),
                                                  ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (dialogError != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          dialogError!,
                          style: SportalTextStyles.t1.copyWith(
                            color: SportalColors.errorRed,
                          ),
                        ),
                      ] else if (!selectedOption.supportedForCreate) ...[
                        const SizedBox(height: 10),
                        Text(
                          l10n.t('streamsSupportedSportsHint'),
                          style: SportalTextStyles.t1.copyWith(
                            color: SportalColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    l10n.t('commonCancel'),
                    style: SportalTextStyles.b2.copyWith(
                      color: SportalColors.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isEmpty) {
                      setDialogState(() {
                        dialogError = l10n.t('streamsEnterTitle');
                      });
                      return;
                    }
                    if (!selectedOption.supportedForCreate ||
                        selectedOption.backendValue == null) {
                      setDialogState(() {
                        dialogError = l10n.t('streamsBackendSportsOnly');
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(
                      _CreateStreamDraft(
                        title: title,
                        sport: selectedOption.backendValue!,
                      ),
                    );
                  },
                  child: Text(
                    l10n.t('commonStart'),
                    style: SportalTextStyles.b2.copyWith(
                      color: SportalColors.primaryBlue,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (draft == null) return;

    setState(() {
      _creating = true;
      _errorText = null;
    });

    try {
      final api = ref.read(streamApiClientProvider);
      final session = ref.read(streamSessionContextProvider);
      final createdResponse = await api.createStreamSession(
        accessToken: session.accessToken,
        title: draft.title,
        sport: draft.sport,
      );

      if (!mounted) return;
      await Navigator.of(context).push(
        _fadeRoute(
          PublishStreamPage(
            streamId: createdResponse.session.id,
            streamTitle: createdResponse.session.title,
            publishToken: createdResponse.publish?.secret,
            whipUrl: createdResponse.publish?.whipUrl,
          ),
        ),
      );
      _refresh();
    } on StreamApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = l10n.t('streamsCreateFailed');
      });
    } finally {
      if (mounted) {
        setState(() {
          _creating = false;
        });
      }
    }
  }

  Future<void> _deleteStream(StreamSessionModel stream) async {
    final l10n = context.l10n;
    final session = ref.read(streamSessionContextProvider);
    if (!session.isAdmin || _deletingStreamId != null) return;
    // OBS streams are not deletable from app.
    if (stream.isObs) return;

    final shouldDelete = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoTheme(
        data: const CupertinoThemeData(brightness: Brightness.dark),
        child: CupertinoAlertDialog(
          title: Text(l10n.t('streamsDeleteTitle')),
          content: Text(
            l10n.format('streamsDeleteBody', {'title': stream.title}),
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.t('streamsDeleteCancel')),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.t('streamsDeleteConfirm')),
            ),
          ],
        ),
      ),
    );

    if (shouldDelete != true) return;

    setState(() {
      _deletingStreamId = stream.id;
      _errorText = null;
    });

    try {
      final api = ref.read(streamApiClientProvider);
      await api.deleteStreamSession(
        accessToken: session.accessToken,
        streamId: stream.id,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.t('streamsDeleted'))));
      _refresh();
    } on StreamApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = l10n.t('streamsDeleteFailed');
      });
    } finally {
      if (mounted) {
        setState(() {
          _deletingStreamId = null;
        });
      }
    }
  }

  Future<void> _openStream(StreamSessionModel stream) async {
    final l10n = context.l10n;

    // Tapping a list item is always "join as viewer". Admins start new
    // streams via the dedicated "Go Live" button; never via a list entry.
    // This prevents an admin who taps an already-running (or just-created)
    // stream from being routed into the publish flow, which on exit would
    // delete the session — wiping out streams started from another client
    // (e.g. the web/PC publisher).
    if (stream.isLive) {
      await Navigator.of(context).push(
        _fadeRoute(
          WatchStreamPage(
            streamId: stream.id,
            streamTitle: stream.title,
            isObs: stream.isObs,
          ),
        ),
      );
      _refresh();
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.t('streamsNotLive'))));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(streamSessionContextProvider);
    final selectedFilter = ref.watch(streamCategoryFilterProvider);
    final streamsAsync = ref.watch(streamSessionsProvider);

    return Scaffold(
      body: SportalBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  color: SportalColors.primaryBlue,
                  backgroundColor: SportalColors.fieldBackground,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(0, 28, 0, 16),
                    children: [
                      _sectionPadding(_buildHeader(context)),
                      _buildCategoryFilter(selectedFilter),
                      const SizedBox(height: 14),
                      if (session.isAdmin)
                        _sectionPadding(
                          SportalPrimaryButton(
                            label: _creating
                                ? l10n.t('commonLoading')
                                : l10n.t('streamsGoLive'),
                            enabled: !_creating,
                            onPressed: _openCreateDialog,
                          ),
                        ),
                      if (_errorText != null) ...[
                        const SizedBox(height: 10),
                        _sectionPadding(
                          Text(
                            _errorText!,
                            style: SportalTextStyles.b2.copyWith(
                              color: SportalColors.errorRed,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      streamsAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 26),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (error, _) => _sectionPadding(
                          Text(
                            l10n.t('streamsLoadFailed'),
                            style: SportalTextStyles.b2.copyWith(
                              color: SportalColors.errorRed,
                            ),
                          ),
                        ),
                        data: (streams) {
                          // Single unified list — both webrtc and OBS/RTMP
                          // streams are shown together. Per-item permissions
                          // (start/delete) are gated by `stream.isObs`.
                          final filtered = streams;

                          if (filtered.isEmpty) {
                            return _sectionPadding(
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: SportalColors.surface,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.22,
                                      ),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  l10n.t('streamsEmpty'),
                                  style: SportalTextStyles.b2.copyWith(
                                    color: SportalColors.textSecondary,
                                  ),
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: [
                              for (var i = 0; i < filtered.length; i++) ...[
                                _sectionPadding(
                                  _StreamNewsLikeCard(
                                    stream: filtered[i],
                                    onTap: () => _openStream(filtered[i]),
                                    // Long-press delete is only available for
                                    // Sportal-live (webrtc) streams; Kanal-live
                                    // (OBS/rtmp) streams are watch-only — even
                                    // for admins.
                                    onLongPress:
                                        (session.isAdmin && !filtered[i].isObs)
                                        ? () => _deleteStream(filtered[i])
                                        : null,
                                    imageAsset: _sportImageFor(
                                      filtered[i].sport,
                                    ),
                                    isDeleting:
                                        _deletingStreamId == filtered[i].id,
                                  ),
                                ),
                                if (i < filtered.length - 1)
                                  const SizedBox(height: 14),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SportalBottomNavBar(activeTab: SportalNavTab.home),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionPadding(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          splashRadius: 18,
        ),
        Expanded(
          child: Text(
            context.l10n.t('streamsTitle'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SportalTextStyles.h2.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilter(String selectedFilter) {
    final options = _sportOptions.where((o) => o.key != 'all').toList();
    return SportalCategoryRow<_SportOption>(
      items: options,
      selectedKey: selectedFilter == 'all' ? null : selectedFilter,
      keyOf: (o) => o.key,
      labelOf: (o) => _sportLabel(context, o),
      onSelected: (key) {
        ref.read(streamCategoryFilterProvider.notifier).state = key ?? 'all';
      },
    );
  }

  String _sportLabel(BuildContext context, _SportOption option) {
    switch (option.key) {
      case 'all':
        return context.l10n.t('sportAll');
      case 'football':
        return context.l10n.t('sportFootball');
      case 'basketball':
        return context.l10n.t('sportBasketball');
      case 'tennis':
        return context.l10n.t('sportTennis');
      case 'volleyball':
        return context.l10n.t('sportVolleyball');
      case 'boxing':
        return context.l10n.t('sportBoxing');
      case 'mma':
        return context.l10n.t('sportMma');
      case 'formula_one':
        return context.l10n.t('sportFormulaOne');
    }
    return context.l10n.t('sportAll');
  }

  String _sportImageFor(String sport) {
    final key = sport.trim().toLowerCase();
    for (final option in _sportOptions) {
      if (option.key == key && option.imageAsset.isNotEmpty) {
        return option.imageAsset;
      }
    }
    return 'assets/images/news_placeholder.png';
  }
}

class _StreamNewsLikeCard extends StatelessWidget {
  const _StreamNewsLikeCard({
    required this.stream,
    required this.onTap,
    required this.imageAsset,
    this.onLongPress,
    this.isDeleting = false,
  });

  final StreamSessionModel stream;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String imageAsset;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.all(Radius.circular(18));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Image with gradient-shadow and LIVE chip overlay ──
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(imageAsset, fit: BoxFit.cover),
                      // Bottom-of-image gradient that creates the shadow falling
                      // onto the title strip below.
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.55, 1.0],
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.52),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Live ribbon — every stream in this list is currently
                      // active, so always render the banner so it visually
                      // matches the design across both webrtc and OBS items.
                      Positioned(left: 12, top: 12, child: _LiveChip()),
                    ],
                  ),
                ),
                // ── Title strip on white with shadow cast from image ──
                Container(
                  color: Colors.white,
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        child: Text(
                          isDeleting
                              ? context.l10n.t('streamsDeleting')
                              : stream.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0E1A3D),
                            height: 1.2,
                          ),
                        ),
                      ),
                      // Gradient overlay at the top of the title strip that
                      // simulates the image shadow falling onto the title area.
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 26,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.22),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: SportalColors.liveRed,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: SportalColors.liveRed.withValues(alpha: 0.45),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.double_arrow_rounded, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            context.l10n.t('commonLive'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SportOption {
  const _SportOption({
    required this.key,
    required this.imageAsset,
    required this.backendValue,
    required this.supportedForCreate,
  });

  final String key;
  final String imageAsset;
  final String? backendValue;
  final bool supportedForCreate;
}

class _CreateStreamDraft {
  const _CreateStreamDraft({required this.title, required this.sport});

  final String title;
  final String sport;
}

PageRoute<void> _fadeRoute(Widget page) {
  return PageRouteBuilder<void>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 160),
    reverseTransitionDuration: const Duration(milliseconds: 120),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      );

      return FadeTransition(opacity: curved, child: child);
    },
  );
}
