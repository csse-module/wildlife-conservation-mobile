class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  bool get canRetry =>
      statusCode == null || statusCode! >= 500 || statusCode == 429;

  @override
  String toString() => message;
}
