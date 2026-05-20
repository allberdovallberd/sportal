import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_models.dart';

class AuthSessionState {
  const AuthSessionState({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  const AuthSessionState.guest()
    : accessToken = '',
      refreshToken = '',
      user = const SportalUser(
        id: '',
        email: 'Guest',
        role: SportalUserRole.guest,
        isVerified: false,
      );

  final String accessToken;
  final String refreshToken;
  final SportalUser user;

  bool get isAuthenticated => accessToken.isNotEmpty;
  bool get isAdmin => user.role == SportalUserRole.admin;

  AuthSessionState copyWith({
    String? accessToken,
    String? refreshToken,
    SportalUser? user,
  }) {
    return AuthSessionState(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      user: user ?? this.user,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'user': <String, dynamic>{
        'id': user.id,
        'email': user.email,
        'role': user.role.name,
        'is_verified': user.isVerified,
        if (user.username != null && user.username!.isNotEmpty)
          'username': user.username,
        if (user.avatar != null && user.avatar!.isNotEmpty)
          'avatar': user.avatar,
      },
    };
  }

  factory AuthSessionState.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    return AuthSessionState(
      accessToken: (json['access_token'] ?? '').toString(),
      refreshToken: (json['refresh_token'] ?? '').toString(),
      user: SportalUser.fromJson(
        userJson is Map<String, dynamic> ? userJson : const <String, dynamic>{},
      ),
    );
  }
}

class AuthSessionStore {
  static const String _sessionKey = 'sportal.auth.session';

  static Future<AuthSessionState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.trim().isEmpty) {
      return const AuthSessionState.guest();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const AuthSessionState.guest();
      }
      return AuthSessionState.fromJson(decoded);
    } catch (_) {
      return const AuthSessionState.guest();
    }
  }

  static Future<void> save(AuthSessionState session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}

class AuthSessionNotifier extends StateNotifier<AuthSessionState> {
  AuthSessionNotifier({AuthSessionState? initialSession})
    : super(initialSession ?? const AuthSessionState.guest());

  void setSession(AuthSuccessPayload payload) {
    state = AuthSessionState(
      accessToken: payload.accessToken,
      refreshToken: payload.refreshToken,
      user: payload.user,
    );
    unawaited(AuthSessionStore.save(state));
  }

  void setUser(SportalUser user) {
    state = state.copyWith(user: user);
    unawaited(AuthSessionStore.save(state));
  }

  void setTokens({required String accessToken, required String refreshToken}) {
    state = state.copyWith(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    unawaited(AuthSessionStore.save(state));
  }

  void clear() {
    state = const AuthSessionState.guest();
    unawaited(AuthSessionStore.clear());
  }
}

final authSessionProvider =
    StateNotifierProvider<AuthSessionNotifier, AuthSessionState>((ref) {
      return AuthSessionNotifier();
    });
