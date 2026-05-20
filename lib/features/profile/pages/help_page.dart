import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../ui/sportal_colors.dart';
import '../../../ui/sportal_text_styles.dart';
import '../../../ui/widgets/sportal_background.dart';
import '../../../ui/widgets/sportal_section_card.dart';

class HelpPage extends ConsumerWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final faqs = <_Faq>[
      _Faq(
        question: l10n.t('faqJoinStreamQ'),
        answer: l10n.t('faqJoinStreamA'),
      ),
      _Faq(
        question: l10n.t('faqAdminStartQ'),
        answer: l10n.t('faqAdminStartA'),
      ),
      _Faq(question: l10n.t('faqObsQ'), answer: l10n.t('faqObsA')),
      _Faq(
        question: l10n.t('faqForgotPasswordQ'),
        answer: l10n.t('faqForgotPasswordA'),
      ),
    ];
    return Scaffold(
      body: SportalBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            children: [
              SportalPageHeader(
                title: l10n.t('helpTitle'),
                subtitle: l10n.t('helpSubtitle'),
                onBack: () => context.pop(),
              ),
              const SizedBox(height: 18),
              SportalSectionCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _ContactTile(
                      icon: Icons.mail_rounded,
                      label: 'support@sportal.tm',
                      sub: l10n.t('helpEmailSub'),
                      onTap: () {},
                    ),
                    Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    _ContactTile(
                      icon: Icons.phone_rounded,
                      label: '+993 12 000 000',
                      sub: l10n.t('helpPhoneSub'),
                      onTap: () {},
                    ),
                    Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    _ContactTile(
                      svgAsset: 'assets/icons/instagram-logo-fill.svg',
                      label: '@sportportal.tm',
                      sub: l10n.t('helpInstagramSub'),
                      onTap: () async {
                        final uri = Uri.parse(
                          'https://www.instagram.com/sportportal.tm',
                        );
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.t('helpFaqTitle'),
                style: SportalTextStyles.b1.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              for (final faq in faqs) ...[
                _FaqTile(faq: faq),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Faq {
  const _Faq({required this.question, required this.answer});

  final String question;
  final String answer;
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.faq});

  final _Faq faq;

  @override
  Widget build(BuildContext context) {
    return SportalSectionCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          listTileTheme: const ListTileThemeData(textColor: Colors.white),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          collapsedIconColor: Colors.white70,
          iconColor: SportalColors.primaryBlue,
          title: Text(
            faq.question,
            style: SportalTextStyles.b1.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                faq.answer,
                style: SportalTextStyles.b2.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    this.icon,
    this.svgAsset,
    required this.label,
    required this.sub,
    required this.onTap,
  }) : assert(icon != null || svgAsset != null);

  final IconData? icon;
  final String? svgAsset;
  final String label;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: SportalColors.primaryBlue.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: svgAsset != null
                    ? SvgPicture.asset(
                        svgAsset!,
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          SportalColors.primaryBlue,
                          BlendMode.srcIn,
                        ),
                      )
                    : Icon(icon, color: SportalColors.primaryBlue, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: SportalTextStyles.b1.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: SportalTextStyles.t1.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
