// =============================================================================
// environment_config.dart — 服务器与环境配置
// =============================================================================
// baseUrl 集中于此；device_id 来自用户绑定列表；鉴权用 Firebase Bearer（见 auth_api_helper）。
// =============================================================================

class EnvironmentConfig {
  EnvironmentConfig._();

  /// 服务器 API 基础 URL（无尾部斜杠）
  static const String baseUrl = 'https://api.myvideotest2026.top';

  /// API 请求超时
  static const Duration requestTimeout = Duration(seconds: 10);

  /// 是否启用调试日志
  static const bool debugMode = true;

  /// 去掉用户输入 URL 尾部斜杠
  static String normalizeBaseUrl(String url) =>
      url.trim().replaceAll(RegExp(r'/$'), '');

  /// 构造 API URI（不含鉴权 query；/api/health 等公开接口同样使用）。
  static Uri apiUri(
    String path, {
    String? baseUrlOverride,
    Map<String, String>? queryParameters,
  }) {
    final base = normalizeBaseUrl(baseUrlOverride ?? baseUrl);
    final uri = Uri.parse('$base$path');
    if (queryParameters == null || queryParameters.isEmpty) return uri;
    return uri.replace(queryParameters: queryParameters);
  }
}
