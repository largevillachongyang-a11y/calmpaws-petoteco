// =============================================================================
// api_exception.dart — 服务器 HTTP 错误分类（最终对接）
// =============================================================================

enum ApiErrorKind {
  unauthorized,
  forbidden,
  notFound,
  conflict,
  server,
  network,
  unknown,
}

class ApiException implements Exception {
  final int? statusCode;
  final ApiErrorKind kind;
  final String message;

  const ApiException({
    this.statusCode,
    required this.kind,
    required this.message,
  });

  static ApiException fromStatus(int statusCode, {String? body}) {
    final kind = switch (statusCode) {
      401 => ApiErrorKind.unauthorized,
      403 => ApiErrorKind.forbidden,
      404 => ApiErrorKind.notFound,
      409 => ApiErrorKind.conflict,
      >= 500 => ApiErrorKind.server,
      _ => ApiErrorKind.unknown,
    };
    return ApiException(
      statusCode: statusCode,
      kind: kind,
      message: body?.trim().isNotEmpty == true ? body!.trim() : 'HTTP $statusCode',
    );
  }

  @override
  String toString() => 'ApiException($statusCode, $kind, $message)';
}
