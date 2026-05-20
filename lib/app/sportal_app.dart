import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:turkmen_localization_support/turkmen_localization_support.dart';

import '../core/localization/app_language.dart';
import '../core/localization/app_localizations.dart';
import 'sportal_theme.dart';

class SportalApp extends ConsumerWidget {
  const SportalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLanguage = ref.watch(appLanguageProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Sportal',
      theme: SportalTheme.themeData,
      locale: appLanguage.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...TkDelegates.delegates,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(sportalRouterProvider),
    );
  }
}
