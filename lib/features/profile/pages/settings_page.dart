import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../ui/sportal_text_styles.dart';
import '../../../ui/widgets/sportal_background.dart';
import '../../../ui/widgets/sportal_section_card.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _pushNotifications = true;
  bool _liveStreamAlerts = true;
  bool _dataSaver = false;
  bool _autoplayVideos = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SportalBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            children: [
              SportalPageHeader(
                title: l10n.t('settingsTitle'),
                subtitle: l10n.t('settingsSubtitle'),
                onBack: () => context.pop(),
              ),
              const SizedBox(height: 18),
              _Group(
                title: l10n.t('settingsNotificationsGroup'),
                children: [
                  _SwitchTile(
                    icon: Icons.notifications_active_rounded,
                    label: l10n.t('settingsPushNotifications'),
                    value: _pushNotifications,
                    onChanged: (v) => setState(() => _pushNotifications = v),
                  ),
                  _SwitchTile(
                    icon: Icons.live_tv_rounded,
                    label: l10n.t('settingsLiveAlerts'),
                    value: _liveStreamAlerts,
                    onChanged: (v) => setState(() => _liveStreamAlerts = v),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Group(
                title: l10n.t('settingsPlayerGroup'),
                children: [
                  _SwitchTile(
                    icon: Icons.data_saver_off_rounded,
                    label: l10n.t('settingsDataSaver'),
                    value: _dataSaver,
                    onChanged: (v) => setState(() => _dataSaver = v),
                  ),
                  _SwitchTile(
                    icon: Icons.play_circle_rounded,
                    label: l10n.t('settingsAutoplay'),
                    value: _autoplayVideos,
                    onChanged: (v) => setState(() => _autoplayVideos = v),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Group(
                title: l10n.t('settingsAccountGroup'),
                children: [
                  _NavTile(
                    icon: Icons.lock_rounded,
                    label: l10n.t('settingsChangePassword'),
                    onTap: () => context.push('/profile/change-password'),
                  ),
                  _NavTile(
                    icon: Icons.language_rounded,
                    label: l10n.t('profileLanguage'),
                    onTap: () => context.push('/profile/language'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: SportalTextStyles.t1.copyWith(
              fontSize: 11,
              letterSpacing: 1.2,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ),
        SportalSectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.8)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: SportalTextStyles.b1.copyWith(fontSize: 15),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.8)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: SportalTextStyles.b1.copyWith(fontSize: 15),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}
