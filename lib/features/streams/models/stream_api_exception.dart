class StreamApiException implements Exception {
  const StreamApiException({
    required this.error,
    required this.message,
    this.statusCode,
  });

  final String error;
  final String message;
  final int? statusCode;

  @override
  String toString() => '$error: $message';
}
