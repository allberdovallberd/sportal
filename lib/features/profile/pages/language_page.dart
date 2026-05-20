import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../ui/sportal_colors.dart';
import '../../../ui/sportal_text_styles.dart';
import '../../../ui/widgets/sportal_background.dart';
import '../../../ui/widgets/sportal_section_card.dart';

class LanguagePage extends ConsumerWidget {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selected = ref.watch(appLanguageProvider);

    return Scaffold(
      body: SportalBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            children: [
              SportalPageHeader(
                title: l10n.t('languageTitle'),
                subtitle: l10n.t('languageSubtitle'),
                onBack: () => context.pop(),
              ),
              const SizedBox(height: 18),
              SportalSectionCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < AppLanguage.values.length; i++) ...[
                      _LangRow(
                        lang: AppLanguage.values[i],
                        selected: selected == AppLanguage.values[i],
                        onTap: () {
                          ref
                              .read(appLanguageProvider.notifier)
                              .setLanguage(AppLanguage.values[i]);
                        },
                      ),
                      if (i < AppLanguage.values.length - 1)
                        Divider(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                    ],
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

class _LangRow extends StatelessWidget {
  const _LangRow({
    required this.lang,
    required this.selected,
    required this.onTap,
  });

  final AppLanguage lang;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(lang.flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                lang.name,
                style: SportalTextStyles.b1.copyWith(fontSize: 15),
              ),
            ),
            if (selected)
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: SportalColors.primaryBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              )
            else
              Icon(
                Icons.radio_button_unchecked,
                size: 22,
                color: Colors.white.withValues(alpha: 0.4),
              ),
          ],
        ),
      ),
    );
  }
}
