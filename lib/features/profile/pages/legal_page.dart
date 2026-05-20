import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../ui/sportal_text_styles.dart';
import '../../../ui/widgets/sportal_background.dart';
import '../../../ui/widgets/sportal_section_card.dart';

class LegalPage extends ConsumerWidget {
  const LegalPage({super.key});

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
                title: l10n.t('legalTitle'),
                subtitle: l10n.t('legalSubtitle'),
                onBack: () => context.pop(),
              ),
              const SizedBox(height: 18),
              SportalSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _section(
                      l10n.t('legalSection1Title'),
                      l10n.t('legalSection1Body'),
                    ),
                    _section(
                      l10n.t('legalSection2Title'),
                      l10n.t('legalSection2Body'),
                    ),
                    _section(
                      l10n.t('legalSection3Title'),
                      l10n.t('legalSection3Body'),
                    ),
                    _section(
                      l10n.t('legalSection4Title'),
                      l10n.t('legalSection4Body'),
                    ),
                    _section(
                      l10n.t('legalSection5Title'),
                      l10n.t('legalSection5Body'),
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

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: SportalTextStyles.b1.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: SportalTextStyles.b2.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
