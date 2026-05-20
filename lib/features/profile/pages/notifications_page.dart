import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../ui/sportal_colors.dart';
import '../../../ui/sportal_text_styles.dart';
import '../../../ui/widgets/sportal_background.dart';
import '../../../ui/widgets/sportal_section_card.dart';

/// A read-only Notifications inbox.
///
/// The backend does not yet expose a notifications endpoint (see
/// API_ENDPOINTS.md). The page renders a small set of locally generated
/// activity items (welcome, latest stream, latest news placeholder) and shows
/// an empty state when nothing is available. When the backend ships, swap the
/// local list out for a Riverpod-driven future provider.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final items = _NotificationItem.demoFeed(l10n);

    return Scaffold(
      body: SportalBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            children: [
              SportalPageHeader(
                title: l10n.t('profileNotifications'),
                subtitle: l10n.t('notificationsSubtitle'),
                onBack: () => context.pop(),
                trailing: IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.t('notificationsMarkedRead')),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.done_all_rounded,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (items.isEmpty)
                SportalSectionCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 32,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.notifications_off_rounded,
                        size: 38,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.t('notificationsEmpty'),
                        style: SportalTextStyles.b1.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      _NotificationTile(item: items[i]),
                      if (i < items.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationItem {
  const _NotificationItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
    this.unread = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;
  final bool unread;

  static List<_NotificationItem> demoFeed(AppLocalizations l10n) {
    return [
      _NotificationItem(
        icon: Icons.live_tv_rounded,
        iconColor: Color(0xFFFF3B5C),
        title: l10n.t('notificationLiveStartedTitle'),
        subtitle: l10n.t('notificationLiveStartedSubtitle'),
        time: l10n.t('timeNow'),
        unread: true,
      ),
      _NotificationItem(
        icon: Icons.article_rounded,
        iconColor: Color(0xFF1A8CF3),
        title: l10n.t('notificationNewsPublishedTitle'),
        subtitle: l10n.t('notificationNewsPublishedSubtitle'),
        time: l10n.t('time15MinAgo'),
        unread: true,
      ),
      _NotificationItem(
        icon: Icons.emoji_events_rounded,
        iconColor: Color(0xFFFFB020),
        title: l10n.t('notificationFederationUpdatedTitle'),
        subtitle: l10n.t('notificationFederationUpdatedSubtitle'),
        time: l10n.t('time2HoursAgo'),
      ),
      _NotificationItem(
        icon: Icons.celebration_rounded,
        iconColor: Color(0xFF4CD964),
        title: l10n.t('notificationWelcomeTitle'),
        subtitle: l10n.t('notificationWelcomeSubtitle'),
        time: l10n.t('timeYesterday'),
      ),
    ];
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});

  final _NotificationItem item;

  @override
  Widget build(BuildContext context) {
    return SportalSectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SportalTextStyles.b1.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (item.unread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: SportalColors.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SportalTextStyles.b2.copyWith(
                    color: Colors.white.withValues(alpha: 0.74),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.time,
                  style: SportalTextStyles.t1.copyWith(
                    color: Colors.white.withValues(alpha: 0.55),
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
