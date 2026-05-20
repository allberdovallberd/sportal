import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/email_verification_page.dart';
import '../features/auth/forgot_password_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/providers/auth_session_provider.dart';
import '../features/auth/signup_page.dart';
import '../features/federations/models/federation_model.dart';
import '../features/federations/pages/federation_detail_page.dart';
import '../features/federations/pages/federations_page.dart';
import '../features/home/home_page.dart';
import '../features/home/models/home_models.dart';
import '../features/home/news_detail_page.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/profile/pages/profile_page.dart';
import '../features/profile/pages/notifications_page.dart';
import '../features/profile/pages/edit_profile_page.dart';
import '../features/profile/pages/change_password_page.dart';
import '../features/profile/pages/settings_page.dart';
import '../features/profile/pages/language_page.dart';
import '../features/profile/pages/about_page.dart';
import '../features/profile/pages/help_page.dart';
import '../features/profile/pages/legal_page.dart';
import '../features/streams/pages/streams_home_page.dart';

CustomTransitionPage<void> _fadeScalePage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 160),
    reverseTransitionDuration: const Duration(milliseconds: 120),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      );

      final disableAnimations =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;

      if (disableAnimations) {
        return child;
      }

      return FadeTransition(opacity: curved, child: child);
    },
  );
}

final sportalRouterProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.read(authSessionProvider).isAuthenticated;
  return GoRouter(
    initialLocation: isAuthenticated ? '/home' : '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) =>
            _fadeScalePage(state: state, child: const OnboardingPage()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            _fadeScalePage(state: state, child: const LoginPage()),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (context, state) =>
            _fadeScalePage(state: state, child: const SignUpPage()),
      ),
      GoRoute(
        path: '/verify-email',
        pageBuilder: (context, state) => _fadeScalePage(
          state: state,
          child: EmailVerificationPage(
            initialEmail: state.uri.queryParameters['email'] ?? '',
            initialPassword: state.extra is String
                ? state.extra as String
                : null,
          ),
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) => _fadeScalePage(
          state: state,
          child: ForgotPasswordPage(
            initialEmail: state.uri.queryParameters['email'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) =>
            _fadeScalePage(state: state, child: const HomePage()),
      ),
      GoRoute(
        path: '/news/:id',
        pageBuilder: (context, state) => _fadeScalePage(
          state: state,
          child: NewsDetailPage(
            newsId: state.pathParameters['id'] ?? '',
            initialNews: state.extra is NewsModel
                ? state.extra as NewsModel
                : null,
          ),
        ),
      ),
      GoRoute(
        path: '/federations',
        pageBuilder: (context, state) =>
            _fadeScalePage(state: state, child: const FederationsPage()),
      ),
      GoRoute(
        path: '/federations/:id',
        pageBuilder: (context, state) => _fadeScalePage(
          state: state,
          child: FederationDetailPage(
            federationId: state.pathParameters['id'] ?? '',
            initialFederation: state.extra is FederationModel
                ? state.extra as FederationModel
                : null,
          ),
        ),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) =>
            _fadeScalePage(state: state, child: const ProfilePage()),
      ),
      GoRoute(
        path: '/streams',
        pageBuilder: (context, state) =>
            _fadeScalePage(state: state, child: const StreamsHomePage()),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) =>
            _fadeScalePage(state: state, child: const NotificationsPage()),
      ),
      GoRoute(
        path: '/profile/edit',
        pageBuilder: (context, state) =>
            _fadeScalePage(state: state, child: const EditProfilePage()),
      ),
      GoRoute(
        path: '/profile/change-password',
        pageBuilder: (context, state) =>
            _fadeScalePage(state: state, child: const ChangePasswordPage()),
      ),
      GoRoute(
        path: '/profile/settings',
        pageBuilder: (context, state) =>
            _fadeScalePage(state: state, child: const SettingsPage()),
      ),
      GoRoute(
        path: '/profile/language',
        pageBuilder: (context, state) =>
            _fadeScalePage(state: state, child: const LanguagePage()),
      ),
      GoRoute(
        path: '/profile/about',
        pageBuilder: (context, state) =>
            _fadeScalePage(state: state, child: const AboutPage()),
      ),
      GoRoute(
        path: '/profile/help',
        pageBuilder: (context, state) =>
            _fadeScalePage(state: state, child: const HelpPage()),
      ),
      GoRoute(
        path: '/profile/legal',
        pageBuilder: (context, state) =>
            _fadeScalePage(state: state, child: const LegalPage()),
      ),
    ],
  );
});

class SportalTheme {
  const SportalTheme._();

  static ThemeData get themeData {
    const overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      systemNavigationBarIconBrightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Urbanist',
      scaffoldBackgroundColor: Colors.transparent,
      splashFactory: InkRipple.splashFactory,
      brightness: Brightness.dark,
      appBarTheme: const AppBarTheme(systemOverlayStyle: overlayStyle),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Color(0xFF1A8CF3),
        selectionColor: Color(0x661A8CF3),
        selectionHandleColor: Color(0xFF1A8CF3),
      ),
    );
  }
}
