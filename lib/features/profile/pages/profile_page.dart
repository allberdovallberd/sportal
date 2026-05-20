import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportal/ui/sportal_colors.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../ui/sportal_text_styles.dart';
import '../../../ui/widgets/sportal_avatar.dart';
import '../../../ui/widgets/sportal_background.dart';
import '../../../ui/widgets/sportal_bottom_nav_bar.dart';
import '../../auth/providers/auth_session_provider.dart';
import '../../auth/models/auth_models.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SportalColors.dialogBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.t('profileLogoutTitle'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          l10n.t('profileLogoutBody'),
          style: TextStyle(color: Color(0xFFBCC6DE)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.t('commonCancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.t('profileLogout')),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    ref.read(authSessionProvider.notifier).clear();
    if (!context.mounted) return;
    context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(authSessionProvider);
    final user = session.user;

    final items = <_ProfileItem>[
      _ProfileItem(
        icon: Icons.account_circle_rounded,
        accent: Color(0xFF1A8CF3),
        title: l10n.t('profileInfo'),
        route: '/profile/edit',
      ),
      _ProfileItem(
        icon: Icons.notifications_active_rounded,
        accent: Color(0xFFFFB020),
        title: l10n.t('profileNotifications'),
        route: '/notifications',
      ),
      _ProfileItem(
        icon: Icons.tune_rounded,
        accent: Color(0xFF35B6FF),
        title: l10n.t('profileSettings'),
        route: '/profile/settings',
      ),
      _ProfileItem(
        icon: Icons.translate_rounded,
        accent: Color(0xFF7C5CFF),
        title: l10n.t('profileLanguage'),
        route: '/profile/language',
      ),
      _ProfileItem(
        icon: Icons.support_agent_rounded,
        accent: Color(0xFF22C55E),
        title: l10n.t('profileHelp'),
        route: '/profile/help',
      ),
      _ProfileItem(
        icon: Icons.gavel_rounded,
        accent: Color(0xFF9CA8FF),
        title: l10n.t('profileLegal'),
        route: '/profile/legal',
      ),
      _ProfileItem(
        icon: Icons.stadium_rounded,
        accent: Color(0xFFFF7A59),
        title: l10n.t('profileAbout'),
        route: '/profile/about',
      ),
      _ProfileItem(
        icon: Icons.logout_rounded,
        accent: Color(0xFFFF5B7E),
        title: l10n.t('profileLogout'),
        isDanger: true,
      ),
    ];

    return Scaffold(
      body: SportalBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
                  children: [
                    Text(
                      l10n.t('profileTitle'),
                      style: SportalTextStyles.h1.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // ── Avatar header card ──
                    _ProfileHeaderCard(
                      user: user,
                      editTooltip: l10n.t('profileEdit'),
                      userRoleLabel: l10n.t('commonUser'),
                      adminRoleLabel: l10n.t('profileAdmin'),
                      onEditTap: () => context.push('/profile/edit'),
                    ),
                    const SizedBox(height: 14),
                    // ── Menu list ──
                    Container(
                      decoration: BoxDecoration(
                        color: SportalColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.32),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < items.length; i++) ...[
                            _ProfileRow(
                              item: items[i],
                              onTap: () {
                                if (items[i].isDanger) {
                                  _confirmLogout(context, ref);
                                  return;
                                }
                                final route = items[i].route;
                                if (route != null && route.isNotEmpty) {
                                  context.push(route);
                                }
                              },
                            ),
                            if (i < items.length - 1)
                              Divider(
                                height: 1,
                                indent: 60,
                                endIndent: 14,
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SportalBottomNavBar(activeTab: SportalNavTab.profile),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileItem {
  const _ProfileItem({
    required this.icon,
    required this.title,
    this.accent = SportalColors.primaryBlue,
    this.isDanger = false,
    this.route,
  });

  final IconData icon;
  final String title;
  final Color accent;
  final bool isDanger;
  final String? route;
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.item, required this.onTap});

  final _ProfileItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = item.isDanger ? const Color(0xFFFF5B7E) : Colors.white;
    final accent = item.accent;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            // Distinctive squircle badge (rounded-square instead of plain circle)
            // gives a more modern, sport-app feel than uniform circles.
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.30),
                    accent.withValues(alpha: 0.14),
                  ],
                ),
                border: Border.all(
                  color: accent.withValues(alpha: 0.45),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(item.icon, size: 19, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                style: SportalTextStyles.b1.copyWith(
                  fontSize: 15,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Colors.white.withValues(alpha: 0.40),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.user,
    required this.onEditTap,
    required this.editTooltip,
    required this.userRoleLabel,
    required this.adminRoleLabel,
  });

  final SportalUser user;
  final VoidCallback onEditTap;
  final String editTooltip;
  final String userRoleLabel;
  final String adminRoleLabel;

  @override
  Widget build(BuildContext context) {
    final isAdmin = user.role == SportalUserRole.admin;
    final displayName = user.email;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        // Brighter, more vivid gradient that no longer fades into the dark
        // background on the right edge.
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A8CF3), Color(0xFF1B4FB8), Color(0xFF2A66D9)],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: SportalColors.primaryBlue.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          SportalAvatar(
            name: displayName,
            avatar: user.avatar,
            size: 60,
            borderColor: Colors.white.withValues(alpha: 0.55),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SportalTextStyles.b1.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Text(
                    isAdmin ? adminRoleLabel : userRoleLabel,
                    style: SportalTextStyles.t1.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEditTap,
            icon: const Icon(Icons.edit_rounded, size: 20),
            color: Colors.white.withValues(alpha: 0.85),
            tooltip: editTooltip,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}
