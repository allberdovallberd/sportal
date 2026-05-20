import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/sportal_api_providers.dart';
import '../../core/utils/html_text.dart';
import '../../ui/sportal_colors.dart';
import '../../ui/sportal_text_styles.dart';
import '../../ui/widgets/sportal_background.dart';
import 'models/home_models.dart';
import 'providers/home_providers.dart';
import 'services/home_api_client.dart';
import '../auth/providers/auth_session_provider.dart';

class NewsDetailPage extends ConsumerWidget {
  const NewsDetailPage({super.key, required this.newsId, this.initialNews});

  final String newsId;
  final NewsModel? initialNews;

  String _formatDate(DateTime? value) {
    if (value == null) return '--.--.----';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day.$month.$year';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNews = ref.watch(homeNewsDetailProvider(newsId));
    final news = asyncNews.valueOrNull ?? initialNews;

    return Scaffold(
      body: SportalBackground(
        child: SafeArea(
          child: news == null
              ? _buildFallbackState(context: context, asyncNews: asyncNews)
              : _NewsDetailContent(
                  news: news,
                  imageUrl: news.resolveThumbnail(
                    ref.watch(sportalApiClientProvider).config,
                  ),
                  formattedDate: _formatDate(news.displayDate),
                ),
        ),
      ),
    );
  }

  Widget _buildFallbackState({
    required BuildContext context,
    required AsyncValue<NewsModel> asyncNews,
  }) {
    final l10n = context.l10n;
    return asyncNews.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.t('newsNotFound'),
                style: SportalTextStyles.h3.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: SportalTextStyles.b2.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => context.pop(),
                child: Text(
                  l10n.t('newsBack'),
                  style: SportalTextStyles.b2.copyWith(
                    color: const Color(0xFF1A8CF3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (_) => const SizedBox.shrink(),
    );
  }
}

class _NewsDetailContent extends ConsumerStatefulWidget {
  const _NewsDetailContent({
    required this.news,
    required this.imageUrl,
    required this.formattedDate,
  });

  final NewsModel news;
  final String imageUrl;
  final String formattedDate;

  @override
  ConsumerState<_NewsDetailContent> createState() => _NewsDetailContentState();
}

class _NewsDetailContentState extends ConsumerState<_NewsDetailContent> {
  late bool _liked;
  late int _likesCount;
  bool _likeLoading = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.news.isLiked;
    _likesCount = widget.news.likesCount;
  }

  Future<void> _toggleLike() async {
    if (_likeLoading) return;
    setState(() {
      _likeLoading = true;
      _liked = !_liked;
      _likesCount += _liked ? 1 : -1;
    });
    try {
      final session = ref.read(authSessionProvider);
      final result = await ref
          .read(homeApiClientProvider)
          .likeNews(
            id: widget.news.id,
            accessToken: session.accessToken.isNotEmpty
                ? session.accessToken
                : null,
          );
      if (mounted) setState(() => _liked = result);
    } catch (_) {
      if (mounted) {
        setState(() {
          _liked = !_liked;
          _likesCount += _liked ? 1 : -1;
        });
      }
    } finally {
      if (mounted) setState(() => _likeLoading = false);
    }
  }

  Future<void> _share() async {
    try {
      final session = ref.read(authSessionProvider);
      await ref
          .read(homeApiClientProvider)
          .shareNews(
            id: widget.news.id,
            platform: 'other',
            accessToken: session.accessToken.isNotEmpty
                ? session.accessToken
                : null,
          );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final plainTextContent = stripHtmlToPlainText(widget.news.content);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── Hero image with gradient overlay ──
        Stack(
          children: [
            AspectRatio(
              aspectRatio: 1.77,
              child: widget.imageUrl.isEmpty
                  ? Image.asset(
                      'assets/images/news_placeholder.png',
                      fit: BoxFit.cover,
                    )
                  : Image.network(
                      widget.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Image.asset(
                        'assets/images/news_placeholder.png',
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
            // Bottom gradient
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 100,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC0B122F)],
                  ),
                ),
              ),
            ),
            // Back button
            Positioned(
              top: 8,
              left: 4,
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: Colors.white,
                  style: IconButton.styleFrom(backgroundColor: Colors.black26),
                ),
              ),
            ),
            // Share button
            Positioned(
              top: 8,
              right: 4,
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  onPressed: _share,
                  icon: const Icon(Icons.share_outlined),
                  color: Colors.white,
                  style: IconButton.styleFrom(backgroundColor: Colors.black26),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Category chip + date ──
              Row(
                children: [
                  _MetaChip(label: widget.news.categoryName),
                  const Spacer(),
                  Text(
                    widget.formattedDate,
                    style: SportalTextStyles.t1.copyWith(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // ── Title ──
              Text(
                widget.news.title,
                style: SportalTextStyles.h1.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  height: 1.22,
                ),
              ),
              const SizedBox(height: 14),
              // ── Like/share row ──
              Row(
                children: [
                  _LikeButton(
                    liked: _liked,
                    count: _likesCount,
                    loading: _likeLoading,
                    onTap: _toggleLike,
                  ),
                  const SizedBox(width: 16),
                  _ShareButton(count: widget.news.sharesCount, onTap: _share),
                ],
              ),
              const SizedBox(height: 16),
              // ── Divider ──
              Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
              const SizedBox(height: 16),
              // ── Body ──
              Text(
                plainTextContent.isEmpty ? '...' : plainTextContent,
                style: SportalTextStyles.b1.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: SportalColors.primaryBlue.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: SportalColors.primaryBlue.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        label,
        style: SportalTextStyles.t1.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: SportalColors.primaryBlue,
        ),
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({
    required this.liked,
    required this.count,
    required this.loading,
    required this.onTap,
  });

  final bool liked;
  final int count;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFFFF5B7E);
    final inactiveColor = Colors.white.withValues(alpha: 0.6);
    final color = liked ? activeColor : inactiveColor;

    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          loading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              : Icon(
                  liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 22,
                  color: color,
                ),
          const SizedBox(width: 5),
          Text(
            '$count',
            style: SportalTextStyles.t1.copyWith(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Colors.white.withValues(alpha: 0.6);
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(Icons.share_outlined, size: 20, color: color),
          const SizedBox(width: 5),
          Text(
            '$count',
            style: SportalTextStyles.t1.copyWith(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
