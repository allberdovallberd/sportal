class SportalApiConfig {
  const SportalApiConfig({
    required this.apiBaseUrl,
    required this.streamHttpBaseUrl,
    required this.streamWebRtcBaseUrl,
    required this.srsWhipBaseUrl,
    required this.srsWhepBaseUrl,
  });

  final String apiBaseUrl;
  final String streamHttpBaseUrl;
  final String streamWebRtcBaseUrl;
  final String srsWhipBaseUrl;
  final String srsWhepBaseUrl;

  String get uploadBaseUrl {
    final uri = Uri.parse(apiBaseUrl);
    final portStr = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$portStr';
  }

  static const String _defaultApiHost = String.fromEnvironment(
    'SPORTAL_API_HOST',
    defaultValue: 'https://asyllypent.com.tm/sport',
  );

  static const String _defaultApiBaseUrl = String.fromEnvironment(
    'SPORTAL_API_BASE_URL',
    defaultValue: '$_defaultApiHost/api/v1',
  );

  static const String _defaultStreamHttpBaseUrl = String.fromEnvironment(
    'SPORTAL_STREAM_HTTP_BASE_URL',
    defaultValue: 'https://asyllypent.com.tm/sport',
  );

  static const String _defaultStreamWebRtcBaseUrl = String.fromEnvironment(
    'SPORTAL_STREAM_WEBRTC_BASE_URL',
    defaultValue: 'webrtc://asyllypent.com.tm/sport/live/',
  );

  static const String authLoginPath = '/auth/login';
  static const String authRegisterPath = '/auth/register';
  static const String authVerifyPath = '/auth/verify';
  static const String authRefreshPath = '/auth/refresh';
  static const String authResendCodePath = '/auth/resend-code';
  static const String authForgotPasswordPath = '/auth/forgot-password';
  static const String authResetPasswordPath = '/auth/reset-password';
  static const String usersMePath = '/users/me';
  static const String usersMeAvatarPath = '/users/me/avatar';
  static const String adminUploadPath = '/admin/upload';

  static const SportalApiConfig current = SportalApiConfig(
    apiBaseUrl: _defaultApiBaseUrl,
    streamHttpBaseUrl: _defaultStreamHttpBaseUrl,
    streamWebRtcBaseUrl: _defaultStreamWebRtcBaseUrl,
    srsWhipBaseUrl: String.fromEnvironment(
      'SRS_WHIP_BASE_URL',
      defaultValue: _defaultApiHost,
    ),
    srsWhepBaseUrl: String.fromEnvironment(
      'SRS_WHEP_BASE_URL',
      defaultValue: _defaultApiHost,
    ),
  );
}
