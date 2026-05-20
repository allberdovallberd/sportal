import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../ui/sportal_colors.dart';
import '../../../ui/sportal_text_styles.dart';
import '../../../ui/widgets/sportal_background.dart';
import '../../../ui/widgets/sportal_logo.dart';
import '../../../ui/widgets/sportal_section_card.dart';

class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      body: SportalBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            children: [
              SportalPageHeader(
                title: l10n.t('aboutTitle'),
                onBack: () => context.pop(),
              ),
              const SizedBox(height: 22),
              const Center(child: SportalLogo(size: 110)),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  'Sportal',
                  style: SportalTextStyles.h1.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  l10n.t('aboutVersion'),
                  style: SportalTextStyles.b2.copyWith(
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SportalSectionCard(
                child: Text(
                  l10n.t('aboutDescription'),
                  style: SportalTextStyles.b1.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SportalSectionCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _Row(
                      icon: Icons.code_rounded,
                      label: l10n.t('aboutBuild'),
                      value: '1.0.0+1',
                    ),
                    const Divider(height: 1, color: Colors.white12),
                    _Row(
                      icon: Icons.public_rounded,
                      label: l10n.t('aboutWebsite'),
                      value: 'sportal.tm',
                    ),
                    const Divider(height: 1, color: Colors.white12),
                    _Row(
                      icon: Icons.copyright_rounded,
                      label: l10n.t('aboutCopyright'),
                      value: '© 2025 Sportal',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SportalSectionCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _LinkTile(
                      icon: Icons.privacy_tip_rounded,
                      label: l10n.t('aboutPrivacy'),
                      onTap: () => context.push('/profile/legal'),
                    ),
                    Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    _LinkTile(
                      icon: Icons.gavel_rounded,
                      label: l10n.t('aboutTerms'),
                      onTap: () => context.push('/profile/legal'),
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
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.7)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: SportalTextStyles.b1.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
          Text(
            value,
            style: SportalTextStyles.b2.copyWith(
              color: SportalColors.primaryBlue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.7)),
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
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ],
        ),
      ),
    );
  }
}
