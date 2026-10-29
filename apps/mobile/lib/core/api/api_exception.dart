/// Failure of an API call. [code] is the backend's stable error code, or one
/// of the client-side codes below; the UI localizes it.
class ApiException implements Exception {
  const ApiException(this.code, {this.statusCode, this.message});

  /// No connection, DNS failure or TLS error.
  static const network = 'network';

  /// The server did not answer in time.
  static const timeout = 'timeout';

  /// The refresh token was rejected; the user must sign in again.
  static const sessionExpired = 'session_expired';

  /// The response was not what the API contract promises.
  static const badResponse = 'bad_response';

  /// 5xx without a code.
  static const server = 'server_error';

  final String code;
  final int? statusCode;
  final String? message;

  @override
  String toString() => 'ApiException($code, status: $statusCode, message: $message)';
}
