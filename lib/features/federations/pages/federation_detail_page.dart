import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportal/ui/sportal_colors.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/sportal_api_providers.dart';
import '../../../ui/sportal_text_styles.dart';
import '../../../ui/widgets/sportal_background.dart';
import '../models/federation_model.dart';
import '../providers/federation_providers.dart';

class FederationDetailPage extends ConsumerWidget {
  const FederationDetailPage({
    super.key,
    required this.federationId,
    this.initialFederation,
  });

  final String federationId;
  final FederationModel? initialFederation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final asyncFederation = ref.watch(federationDetailProvider(federationId));
    final federation = asyncFederation.valueOrNull ?? initialFederation;
    final config = ref.watch(sportalApiClientProvider).config;

    return Scaffold(
      body: SportalBackground(
        child: SafeArea(
          child: federation == null
              ? asyncFederation.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.t('federationNotFound'),
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
                        ],
                      ),
                    ),
                  ),
                  data: (_) => const SizedBox.shrink(),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(10, 24, 10, 18),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          splashRadius: 18,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.share_outlined,
                            color: Colors.white,
                          ),
                          splashRadius: 18,
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.white,
                          ),
                          splashRadius: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      federation.name,
                      style: SportalTextStyles.h2.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: AspectRatio(
                        aspectRatio: 1.68,
                        child: _buildImage(
                          federation: federation,
                          baseUrl: config.uploadBaseUrl,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (federation.description.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: SportalColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.16),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          federation.description,
                          style: SportalTextStyles.b2.copyWith(
                            fontSize: 14,
                            height: 1.5,
                            color: Colors.white.withValues(alpha: 0.86),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Container(
                      decoration: BoxDecoration(
                        color: SportalColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _DetailRow(
                            iconAsset: 'assets/icons/user-circle.svg',
                            label: l10n.t('federationPresident'),
                            value: federation.president,
                          ),
                          _detailDivider(),
                          _DetailRow(
                            iconAsset: 'assets/icons/location-marker.svg',
                            label: l10n.t('federationAddress'),
                            value: federation.address,
                          ),
                          _detailDivider(),
                          _DetailRow(
                            iconAsset: 'assets/icons/phone.svg',
                            label: l10n.t('federationPhone'),
                            value: federation.phone,
                            copyable: true,
                            copiedSnackText: l10n.t('federationPhoneCopied'),
                          ),
                          _detailDivider(),
                          _DetailRow(
                            iconAsset: 'assets/icons/mail.svg',
                            label: l10n.t('federationEmail'),
                            value: federation.email,
                            copyable: true,
                            copiedSnackText: l10n.t('federationEmailCopied'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildImage({
    required FederationModel federation,
    required String baseUrl,
  }) {
    final imagePath = federation.thumbnail.isNotEmpty
        ? federation.thumbnail
        : federation.logo;

    if (imagePath.isEmpty) {
      return Image.asset(
        'assets/images/news_placeholder.png',
        fit: BoxFit.cover,
      );
    }

    final imageUrl = imagePath.startsWith('http')
        ? imagePath
        : imagePath.startsWith('/')
        ? '$baseUrl$imagePath'
        : '$baseUrl/$imagePath';

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) {
        return Image.asset(
          'assets/images/news_placeholder.png',
          fit: BoxFit.cover,
        );
      },
    );
  }

  Widget _detailDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withValues(alpha: 0.16),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.iconAsset,
    required this.label,
    required this.value,
    this.copyable = false,
    this.copiedSnackText,
  });

  final String iconAsset;
  final String label;
  final String value;
  final bool copyable;
  final String? copiedSnackText;

  @override
  Widget build(BuildContext context) {
    final trimmed = value.trim();
    final hasValue = trimmed.isNotEmpty;
    final safeValue = hasValue ? trimmed : '-';

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SvgPicture.asset(
            iconAsset,
            width: 18,
            height: 18,
            colorFilter: ColorFilter.mode(
              Colors.white.withValues(alpha: 0.7),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: SportalTextStyles.b2.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    safeValue,
                    textAlign: TextAlign.right,
                    style: SportalTextStyles.b2.copyWith(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                ),
                if (copyable && hasValue) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.copy_rounded,
                    size: 14,
                    color: SportalColors.primaryBlue,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (!copyable || !hasValue) return row;

    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: trimmed));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(copiedSnackText ?? context.l10n.t('commonCopied')),
          ),
        );
      },
      child: row,
    );
  }
}
