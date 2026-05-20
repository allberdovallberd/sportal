import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportal/ui/sportal_colors.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/sportal_api_providers.dart';
import '../../../ui/sportal_text_styles.dart';
import '../../../ui/widgets/sportal_background.dart';
import '../../../ui/widgets/sportal_bottom_nav_bar.dart';
import '../../../ui/widgets/sportal_search_bar.dart';
import '../models/federation_model.dart';
import '../providers/federation_providers.dart';

class FederationsPage extends ConsumerStatefulWidget {
  const FederationsPage({super.key});

  @override
  ConsumerState<FederationsPage> createState() => _FederationsPageState();
}

class _FederationsPageState extends ConsumerState<FederationsPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final listAsync = ref.watch(federationListProvider);

    return Scaffold(
      body: SportalBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.read(federationRefreshKeyProvider.notifier).state++;
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
                    children: [
                      Text(
                        l10n.t('federationsTitle'),
                        style: SportalTextStyles.h2.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // ── Search bar (shared) ──
                      SportalSearchBar(
                        controller: _searchController,
                        hintText: l10n.t('federationsSearchHint'),
                        onChanged: (v) =>
                            setState(() => _query = v.toLowerCase()),
                        onClear: () => setState(() => _query = ''),
                      ),
                      const SizedBox(height: 14),
                      listAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (error, _) => Text(
                          l10n.t('federationsLoadFailed'),
                          style: SportalTextStyles.b2.copyWith(
                            color: const Color(0xFFFF5B7E),
                          ),
                        ),
                        data: (items) {
                          final filtered = _query.isEmpty
                              ? items
                              : items
                                    .where(
                                      (f) =>
                                          f.name.toLowerCase().contains(_query),
                                    )
                                    .toList();

                          if (filtered.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Text(
                                _query.isEmpty
                                    ? l10n.t('federationsEmpty')
                                    : l10n.t('federationsNoResults'),
                                textAlign: TextAlign.center,
                                style: SportalTextStyles.b2.copyWith(
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: [
                              for (var i = 0; i < filtered.length; i++) ...[
                                _FederationTile(
                                  item: filtered[i],
                                  onTap: () => context.push(
                                    '/federations/${filtered[i].id}',
                                    extra: filtered[i],
                                  ),
                                ),
                                if (i < filtered.length - 1)
                                  const SizedBox(height: 10),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SportalBottomNavBar(activeTab: SportalNavTab.federations),
            ],
          ),
        ),
      ),
    );
  }
}

class _FederationTile extends ConsumerWidget {
  const _FederationTile({required this.item, required this.onTap});

  final FederationModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(sportalApiClientProvider).config;
    final image = item.logo.isNotEmpty ? item.logo : item.thumbnail;
    final imageUrl = image.isEmpty
        ? ''
        : image.startsWith('http')
        ? image
        : image.startsWith('/')
        ? '${config.uploadBaseUrl}$image'
        : '${config.uploadBaseUrl}/$image';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SportalColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 64,
                height: 64,
                color: Colors.white,
                padding: const EdgeInsets.all(6),
                child: image.isEmpty
                    ? _placeholder()
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => _placeholder(),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SportalTextStyles.b2.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (item.president.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.president,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SportalTextStyles.t1.copyWith(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SportalTextStyles.t1.copyWith(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF1A3A6A),
      alignment: Alignment.center,
      child: const Icon(Icons.shield_outlined, size: 28, color: Colors.white38),
    );
  }
}
