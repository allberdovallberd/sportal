import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/sportal_app.dart';
import 'core/localization/app_language.dart';
import 'features/auth/providers/auth_session_provider.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  final splashTimer = Future<void>.delayed(const Duration(milliseconds: 2500));
  final initialSession = await AuthSessionStore.load();
  final sharedPreferences = await SharedPreferences.getInstance();
  await splashTimer;
  FlutterNativeSplash.remove();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        authSessionProvider.overrideWith(
          (ref) => AuthSessionNotifier(initialSession: initialSession),
        ),
      ],
      child: const SportalApp(),
    ),
  );
}
