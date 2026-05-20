import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../channels/pages/demo_channels_page.dart';
import '../../core/network/sportal_api_providers.dart';
import '../../ui/sportal_colors.dart';
import '../../ui/sportal_text_styles.dart';
import '../../ui/widgets/sportal_background.dart';
import '../../ui/widgets/sportal_bottom_nav_bar.dart';
import '../../ui/widgets/sportal_category_row.dart';
import '../../ui/widgets/sportal_search_bar.dart';
import 'models/home_models.dart';
import 'providers/home_providers.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late final TextEditingController _searchController;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(homeSearchQueryProvider),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.read(homeRefreshKeyProvider.notifier).state++;
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      ref.read(homeVisibleCountProvider.notifier).state = 20;
      ref.read(homeSearchQueryProvider.notifier).state = value.trim();
    });
  }

  void _onCategorySelected(String? id) {
    ref.read(homeVisibleCountProvider.notifier).state = 20;
    ref.read(selectedHomeCategoryIdProvider.notifier).state = id;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final categoriesAsync = ref.watch(homeCategoriesProvider);
    final newsAsync = ref.watch(homeNewsProvider);
    final selectedCategoryId = ref.watch(selectedHomeCategoryIdProvider);
    final visibleCount = ref.watch(homeVisibleCountProvider);

    return Scaffold(
      body: SportalBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => _refreshAll(),
                  color: SportalColors.primaryBlue,
                  backgroundColor: SportalColors.fieldBackground,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(0, 28, 0, 16),
                    children: [
                      _sectionPadding(_buildTopRow(context)),
                      const SizedBox(height: 14),
                      _sectionPadding(
                        SportalSearchBar(
                          controller: _searchController,
                          hintText: l10n.t('homeSearchHint'),
                          onChanged: _onSearchChanged,
                          onSubmitted: (value) {
                            _searchDebounce?.cancel();
                            ref.read(homeVisibleCountProvider.notifier).state =
                                20;
                            ref.read(homeSearchQueryProvider.notifier).state =
                                value.trim();
                          },
                          onClear: () {
                            _searchDebounce?.cancel();
                            ref.read(homeVisibleCountProvider.notifier).state =
                                20;
                            ref.read(homeSearchQueryProvider.notifier).state =
                                '';
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      _sectionPadding(_buildTopBanner()),
                      const SizedBox(height: 14),
                      _buildCategories(
                        categoriesAsync: categoriesAsync,
                        selectedCategoryId: selectedCategoryId,
                      ),
                      const SizedBox(height: 18),
                      ..._buildNewsSection(
                        newsAsync: newsAsync,
                        visibleCount: visibleCount,
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

  List<Widget> _buildNewsSection({
    required AsyncValue<List<NewsModel>> newsAsync,
    required int visibleCount,
  }) {
    return newsAsync.when(
      loading: () => <Widget>[
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (error, _) => <Widget>[
        _sectionPadding(
          Text(
            context.l10n.t('homeNewsLoadFailed'),
            style: SportalTextStyles.b2.copyWith(color: SportalColors.errorRed),
          ),
        ),
      ],
      data: (news) {
        if (news.isEmpty) {
          return <Widget>[
            _sectionPadding(
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withValues(alpha: 0.06),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  context.l10n.t('homeNoNews'),
                  style: SportalTextStyles.b2.copyWith(
                    color: SportalColors.textSecondary,
                  ),
                ),
              ),
            ),
          ];
        }

        final shown = news.take(visibleCount).toList();
        final widgets = <Widget>[];

        for (var i = 0; i < shown.length; i++) {
          widgets.add(
            _sectionPadding(
              _NewsCard(
                item: shown[i],
                onTap: () =>
                    context.push('/news/${shown[i].id}', extra: shown[i]),
              ),
            ),
          );

          if (i == 2 && shown.length > 3) {
            widgets.add(const SizedBox(height: 12));
            widgets.add(_sectionPadding(_buildMiddleBanner()));
            widgets.add(const SizedBox(height: 12));
          } else if (i < shown.length - 1) {
            widgets.add(const SizedBox(height: 12));
          }
        }

        if (shown.length < news.length) {
          widgets.add(const SizedBox(height: 12));
          widgets.add(
            _sectionPadding(
              _buildShowAllButton(
                onTap: () {
                  final next = (ref.read(homeVisibleCountProvider) + 20).clamp(
                    20,
                    news.length,
                  );
                  ref.read(homeVisibleCountProvider.notifier).state = next;
                },
              ),
            ),
          );
        }

        widgets.add(const SizedBox(height: 6));
        return widgets;
      },
    );
  }

  Widget _buildTopRow(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 34,
            height: 34,
            child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'SPORTPORTAL',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SportalTextStyles.h2.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 21,
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () => context.go('/streams'),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: SportalColors.primaryBlue.withValues(alpha: 0.18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/icons/live.svg',
                  width: 16,
                  height: 16,
                ),
                const SizedBox(width: 5),
                Text(
                  l10n.t('homeLive'),
                  style: SportalTextStyles.b2.copyWith(
                    fontWeight: FontWeight.w600,
                    color: SportalColors.accentCyan,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () =>
              Navigator.of(context).push(_fadeRoute(const DemoChannelsPage())),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: SportalColors.primaryBlue.withValues(alpha: 0.18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/icons/live.svg',
                  width: 16,
                  height: 16,
                ),
                const SizedBox(width: 5),
                Text(
                  'Kanallar',
                  style: SportalTextStyles.b2.copyWith(
                    fontWeight: FontWeight.w600,
                    color: SportalColors.accentCyan,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/notifications'),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SportalColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.notifications_none_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 3.28,
        child: Image.asset('assets/images/banner_top.png', fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildMiddleBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 3.28,
        child: Image.asset(
          'assets/images/banner_middle.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildCategories({
    required AsyncValue<List<SportCategoryModel>> categoriesAsync,
    required String? selectedCategoryId,
  }) {
    final categories =
        categoriesAsync.valueOrNull ?? const <SportCategoryModel>[];

    return SportalCategoryRow<SportCategoryModel>(
      items: categories,
      selectedKey: selectedCategoryId,
      keyOf: (c) => c.id,
      labelOf: (c) => c.name,
      onSelected: _onCategorySelected,
    );
  }

  Widget _buildShowAllButton({required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: SportalColors.primaryBlue),
        ),
        child: Text(
          context.l10n.t('homeShowAllNews'),
          style: SportalTextStyles.b1.copyWith(
            color: SportalColors.primaryBlue,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

PageRoute<void> _fadeRoute(Widget page) {
  return PageRouteBuilder<void>(
    pageBuilder: (_, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 160),
    reverseTransitionDuration: const Duration(milliseconds: 120),
    transitionsBuilder: (_, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(opacity: curved, child: child);
    },
  );
}

class _NewsCard extends ConsumerWidget {
  const _NewsCard({required this.item, required this.onTap});

  final NewsModel item;
  final VoidCallback onTap;

  String _formatDate(DateTime? value) {
    if (value == null) return '--.--.----';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day.$month.$year';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(sportalApiClientProvider).config;
    final imageUrl = item.resolveThumbnail(config);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 96,
              height: 92,
              child: imageUrl.isEmpty
                  ? Image.asset(
                      'assets/images/news_placeholder.png',
                      fit: BoxFit.cover,
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) {
                        return Image.asset(
                          'assets/images/news_placeholder.png',
                          fit: BoxFit.cover,
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 92,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width - 138,
                  child: Text(
                    item.categoryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SportalTextStyles.t1.copyWith(
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: MediaQuery.of(context).size.width - 138,
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SportalTextStyles.h3.copyWith(
                      fontWeight: FontWeight.w500,
                      height: 1.22,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(item.displayDate),
                  style: SportalTextStyles.b2.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
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
