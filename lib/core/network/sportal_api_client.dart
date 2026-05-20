import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'sportal_api_config.dart';
import 'sportal_api_exception.dart';

class SportalApiClient {
  SportalApiClient({
    http.Client? client,
    SportalApiConfig? config,
    String? Function()? getRefreshToken,
    void Function(String accessToken, String refreshToken)? onTokensRefreshed,
  }) : _client = client ?? http.Client(),
       _config = config ?? SportalApiConfig.current,
       _getRefreshToken = getRefreshToken,
       _onTokensRefreshed = onTokensRefreshed;

  final http.Client _client;
  final SportalApiConfig _config;
  final String? Function()? _getRefreshToken;
  final void Function(String accessToken, String refreshToken)?
  _onTokensRefreshed;
  Future<String?>? _refreshInFlight;

  SportalApiConfig get config => _config;

  Future<Map<String, dynamic>> get(
    String path, {
    String? accessToken,
    Map<String, dynamic>? query,
  }) {
    return _send(
      method: 'GET',
      path: path,
      accessToken: accessToken,
      query: query,
    );
  }

  Future<Map<String, dynamic>> post(
    String path, {
    String? accessToken,
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) {
    return _send(
      method: 'POST',
      path: path,
      accessToken: accessToken,
      body: body,
      query: query,
    );
  }

  Future<Map<String, dynamic>> put(
    String path, {
    String? accessToken,
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) {
    return _send(
      method: 'PUT',
      path: path,
      accessToken: accessToken,
      body: body,
      query: query,
    );
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    String? accessToken,
    Map<String, dynamic>? query,
  }) {
    return _send(
      method: 'DELETE',
      path: path,
      accessToken: accessToken,
      query: query,
    );
  }

  /// Upload a single file via multipart/form-data POST.
  ///
  /// Returns the parsed JSON body. The server is expected to return either
  /// `{ "data": { "url": "..." } }` or `{ "url": "..." }`.
  Future<Map<String, dynamic>> uploadFile({
    required String path,
    required File file,
    String fieldName = 'file',
    String? accessToken,
  }) async {
    final uri = _buildUri(path, null, baseUrl: _config.apiBaseUrl);
    final request = http.MultipartRequest('POST', uri);
    request.headers['X-Client-Platform'] = 'mobile';
    if (accessToken != null && accessToken.trim().isNotEmpty) {
      request.headers['Authorization'] = 'Bearer ${accessToken.trim()}';
    }
    request.files.add(await http.MultipartFile.fromPath(fieldName, file.path));

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SportalApiException(
        message: 'Upload failed (${response.statusCode}).',
        code: 'UPLOAD_FAILED',
        statusCode: response.statusCode,
      );
    }

    if (response.body.isEmpty) return const <String, dynamic>{};
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{'data': decoded};
  }

  Future<Map<String, dynamic>> _send({
    required String method,
    required String path,
    String? accessToken,
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-Client-Platform': 'mobile',
      if (accessToken != null && accessToken.trim().isNotEmpty)
        'Authorization': 'Bearer ${accessToken.trim()}',
    };

    final candidates = <String>[
      _config.apiBaseUrl,
      ..._fallbackApiBaseUrls(_config.apiBaseUrl),
    ];

    Object? lastNetworkError;
    Uri? lastTriedUri;

    for (final baseUrl in candidates) {
      final uri = _buildUri(path, query, baseUrl: baseUrl);
      lastTriedUri = uri;

      try {
        var response = await _sendRequest(
          method: method,
          uri: uri,
          headers: headers,
          body: body,
        );

        if (response.statusCode == 401 &&
            accessToken != null &&
            accessToken.trim().isNotEmpty) {
          final refreshedAccessToken = await _refreshAccessToken();
          if (refreshedAccessToken != null &&
              refreshedAccessToken.trim().isNotEmpty) {
            final retryHeaders = <String, String>{
              'Content-Type': 'application/json',
              'X-Client-Platform': 'mobile',
              'Authorization': 'Bearer ${refreshedAccessToken.trim()}',
            };
            response = await _sendRequest(
              method: method,
              uri: uri,
              headers: retryHeaders,
              body: body,
            );
          }
        }

        final decoded = _decodeJsonBody(response.body);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw SportalApiException(
            statusCode: response.statusCode,
            code: decoded['error']?.toString(),
            message:
                decoded['message']?.toString() ??
                'Request failed (${response.statusCode}).',
          );
        }

        return decoded;
      } on SocketException catch (error) {
        lastNetworkError = error;
      } on HandshakeException catch (error) {
        lastNetworkError = error;
      } on TimeoutException catch (error) {
        lastNetworkError = error;
      } on http.ClientException catch (error) {
        lastNetworkError = error;
      }
    }

    throw SportalApiException(
      message: _buildNetworkErrorMessage(lastTriedUri, lastNetworkError),
      code: 'NETWORK_ERROR',
    );
  }

  Future<http.Response> _sendRequest({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required Map<String, dynamic>? body,
  }) async {
    try {
      switch (method) {
        case 'GET':
          return _client
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 20));
        case 'POST':
          return _client
              .post(
                uri,
                headers: headers,
                body: jsonEncode(body ?? const <String, dynamic>{}),
              )
              .timeout(const Duration(seconds: 20));
        case 'PUT':
          return _client
              .put(
                uri,
                headers: headers,
                body: jsonEncode(body ?? const <String, dynamic>{}),
              )
              .timeout(const Duration(seconds: 20));
        case 'DELETE':
          return _client
              .delete(uri, headers: headers)
              .timeout(const Duration(seconds: 20));
        default:
          throw SportalApiException(message: 'Unsupported method: $method');
      }
    } on SocketException {
      rethrow;
    } on HandshakeException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } on http.ClientException {
      rethrow;
    }
  }

  List<String> _fallbackApiBaseUrls(String primaryBaseUrl) {
    final cleanedPrimary = primaryBaseUrl.trim();
    if (cleanedPrimary.isEmpty) {
      return const <String>[];
    }

    final fallbacks = <String>{};
    final primaryUri = Uri.tryParse(cleanedPrimary);
    final host = primaryUri?.host.toLowerCase();
    if (primaryUri != null && (host == 'localhost' || host == '127.0.0.1')) {
      final emulatorHost = cleanedPrimary
          .replaceFirst('localhost', '10.0.2.2')
          .replaceFirst('127.0.0.1', '10.0.2.2');
      fallbacks.add(emulatorHost);
    }

    return fallbacks.toList(growable: false);
  }

  Future<String?> _refreshAccessToken() async {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _performRefresh();
    _refreshInFlight = future;
    try {
      return await future;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<String?> _performRefresh() async {
    final refreshToken = _getRefreshToken?.call()?.trim() ?? '';
    if (refreshToken.isEmpty) {
      return null;
    }

    final uri = _buildUri(
      SportalApiConfig.authRefreshPath,
      null,
      baseUrl: _config.apiBaseUrl,
    );

    try {
      final response = await _client
          .post(
            uri,
            headers: const <String, String>{
              'Content-Type': 'application/json',
              'X-Client-Platform': 'mobile',
            },
            body: jsonEncode(<String, dynamic>{'refresh_token': refreshToken}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = _decodeJsonBody(response.body);
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        return null;
      }

      final nextAccessToken = (data['access_token'] ?? '').toString().trim();
      if (nextAccessToken.isEmpty) {
        return null;
      }

      final nextRefreshToken = (data['refresh_token'] ?? refreshToken)
          .toString()
          .trim();
      _onTokensRefreshed?.call(nextAccessToken, nextRefreshToken);
      return nextAccessToken;
    } catch (_) {
      return null;
    }
  }

  String _buildNetworkErrorMessage(Uri? uri, Object? error) {
    if (error is HandshakeException) {
      return 'Serwere baglanyp bolmady (SSL sertifikat problemasy). '
          'HTTPS sertifikatyny barlap, tazeden synanyshyn.';
    }
    final suffix = error is TimeoutException ? ' (wagty gecdi)' : '';
    return 'Serwere baglanyp bolmady$suffix. '
        'Backendi we internet baglanyshygyny barlap, tazeden synanyshyn.';
  }

  Uri _buildUri(
    String path,
    Map<String, dynamic>? query, {
    required String baseUrl,
  }) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final raw = '${baseUrl.trim()}$normalizedPath';
    final parsed = Uri.parse(raw);
    if (query == null || query.isEmpty) {
      return parsed;
    }

    final filtered = <String, String>{};
    query.forEach((key, value) {
      if (value == null) return;
      final stringValue = value.toString().trim();
      if (stringValue.isEmpty) return;
      filtered[key] = stringValue;
    });

    return parsed.replace(queryParameters: filtered.isEmpty ? null : filtered);
  }

  Map<String, dynamic> _decodeJsonBody(String rawBody) {
    if (rawBody.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(rawBody);
      return decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'data': decoded};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}
