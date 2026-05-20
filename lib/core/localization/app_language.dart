import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _appLanguagePrefsKey = 'app_language_code';

enum AppLanguage {
  turkmen('tk', 'Türkmençe', '🇹🇲'),
  russian('ru', 'Русский', '🇷🇺'),
  english('en', 'English', '🇬🇧');

  const AppLanguage(this.code, this.nativeName, this.flag);

  final String code;
  final String nativeName;
  final String flag;

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) {
    for (final value in values) {
      if (value.code == code) return value;
    }
    return AppLanguage.turkmen;
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

final appLanguageProvider =
    StateNotifierProvider<AppLanguageController, AppLanguage>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return AppLanguageController(
        prefs,
        initialLanguage: AppLanguageController.loadSaved(prefs),
      );
    });

class AppLanguageController extends StateNotifier<AppLanguage> {
  AppLanguageController(this._prefs, {required AppLanguage initialLanguage})
    : super(initialLanguage);

  final SharedPreferences _prefs;

  static AppLanguage loadSaved(SharedPreferences prefs) {
    final savedCode = prefs.getString(_appLanguagePrefsKey);
    return AppLanguage.fromCode(savedCode);
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (state == language) return;
    state = language;
    await _prefs.setString(_appLanguagePrefsKey, language.code);
  }
}
