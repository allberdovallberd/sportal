class SportalApiException implements Exception {
  const SportalApiException({
    required this.message,
    this.code,
    this.statusCode,
  });

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() {
    return 'SportalApiException(statusCode: $statusCode, code: $code, message: $message)';
  }
}
