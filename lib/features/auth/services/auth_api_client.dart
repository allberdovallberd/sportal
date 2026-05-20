import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/sportal_api_client.dart';
import '../../../core/network/sportal_api_config.dart';
import '../../../core/network/sportal_api_exception.dart';
import '../../../core/network/sportal_api_providers.dart';
import '../models/auth_models.dart';
import 'dart:io' show File;

class AuthApiClient {
  const AuthApiClient({required SportalApiClient api}) : _api = api;

  final SportalApiClient _api;

  Future<AuthSuccessPayload> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.post(
      SportalApiConfig.authLoginPath,
      body: <String, dynamic>{'email': email.trim(), 'password': password},
    );

    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const SportalApiException(
        message: 'Login response is invalid.',
        code: 'INVALID_PAYLOAD',
      );
    }

    final payload = AuthSuccessPayload.fromJson(data);
    if (payload.accessToken.isEmpty) {
      throw const SportalApiException(
        message: 'Access token is missing.',
        code: 'INVALID_PAYLOAD',
      );
    }

    return payload;
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
    String? firebaseToken,
  }) async {
    await _api.post(
      SportalApiConfig.authRegisterPath,
      body: <String, dynamic>{
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
        if (firebaseToken != null && firebaseToken.trim().isNotEmpty)
          'firebase_token': firebaseToken.trim(),
      },
    );
  }

  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    await _api.post(
      SportalApiConfig.authVerifyPath,
      body: <String, dynamic>{'email': email.trim(), 'code': code.trim()},
    );
  }

  Future<void> resendCode({required String email}) async {
    await _api.post(
      SportalApiConfig.authResendCodePath,
      body: <String, dynamic>{'email': email.trim()},
    );
  }

  Future<void> forgotPassword({required String email}) async {
    await _api.post(
      SportalApiConfig.authForgotPasswordPath,
      body: <String, dynamic>{'email': email.trim()},
    );
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _api.post(
      SportalApiConfig.authResetPasswordPath,
      body: <String, dynamic>{
        'email': email.trim(),
        'code': code.trim(),
        'new_password': newPassword,
      },
    );
  }

  Future<SportalUser> fetchMe({required String accessToken}) async {
    final response = await _api.get(
      SportalApiConfig.usersMePath,
      accessToken: accessToken,
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const SportalApiException(
        message: 'User profile response is invalid.',
        code: 'INVALID_PAYLOAD',
      );
    }
    return SportalUser.fromJson(data);
  }

  Future<SportalUser> updateProfile({
    required String accessToken,
    String? avatar,
    String? username,
    String? phone,
  }) async {
    final response = await _api.put(
      SportalApiConfig.usersMePath,
      accessToken: accessToken,
      body: <String, dynamic>{
        if (avatar != null) 'avatar': avatar,
        if (username != null) 'username': username,
        if (phone != null) 'phone': phone,
      },
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const SportalApiException(
        message: 'Update profile response is invalid.',
        code: 'INVALID_PAYLOAD',
      );
    }
    return SportalUser.fromJson(data);
  }

  /// Upload an avatar image and return its server URL.
  ///
  /// Uses the authenticated `POST /users/me/avatar` endpoint (see
  /// API_ENDPOINTS.md §14.2). Available to any verified user.
  Future<String> uploadAvatar({
    required String accessToken,
    required File file,
  }) async {
    final response = await _api.uploadFile(
      path: SportalApiConfig.usersMeAvatarPath,
      file: file,
      fieldName: 'file',
      accessToken: accessToken,
    );
    final data = response['data'];
    String? url;
    if (data is Map<String, dynamic>) {
      url = (data['url'] ?? data['path'])?.toString();
    }
    url ??= (response['url'] ?? response['path'])?.toString();
    if (url == null || url.isEmpty) {
      throw const SportalApiException(
        message: 'Upload response did not include a URL.',
        code: 'INVALID_PAYLOAD',
      );
    }
    return url;
  }
}

final authApiClientProvider = Provider<AuthApiClient>((ref) {
  final api = ref.watch(sportalApiClientProvider);
  return AuthApiClient(api: api);
});
