import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../sportal_colors.dart';
import '../sportal_text_styles.dart';

enum SportalNavTab { home, federations, profile }

class SportalBottomNavBar extends StatelessWidget {
  const SportalBottomNavBar({super.key, required this.activeTab});

  final SportalNavTab activeTab;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      height: 66 + bottomInset,
      padding: EdgeInsets.fromLTRB(12, 6, 12, bottomInset),
      decoration: BoxDecoration(
        color: SportalColors.navBackground,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            iconPath: 'assets/icons/home.svg',
            label: l10n.t('navHome'),
            isActive: activeTab == SportalNavTab.home,
            onTap: () => context.go('/home'),
          ),
          _NavItem(
            iconPath: 'assets/icons/federation.svg',
            label: l10n.t('navFederations'),
            isActive: activeTab == SportalNavTab.federations,
            onTap: () => context.go('/federations'),
          ),
          _NavItem(
            iconPath: 'assets/icons/profile.svg',
            label: l10n.t('navProfile'),
            isActive: activeTab == SportalNavTab.profile,
            onTap: () => context.go('/profile'),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.iconPath,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String iconPath;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? SportalColors.primaryBlue : Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 92,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            SvgPicture.asset(
              iconPath,
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textScaler: TextScaler.noScaling,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SportalTextStyles.t1.copyWith(
                color: color,
                fontSize: 10.5,
                height: 1.0,
                fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
