// =============================================================================
// environment_config.dart — 服务器与环境配置（P0-1 铁律 2）
// =============================================================================
// 所有 API baseUrl / deviceKey / 默认 deviceId 必须从此读取，禁止散落在业务代码中。
// 测试期临时值；多设备 / 正式域名改造时只改本文件（或后续 env 分支）。
// =============================================================================

class EnvironmentConfig {
  EnvironmentConfig._();

  /// 服务器 API 基础 URL（无尾部斜杠）
  static const String baseUrl = 'https://api.myvideotest2026.top';

  /// 设备 key（开发期全局 key；多设备改造后改为每设备独立）
  static const String deviceKey = 'calmpaws_secret';

  /// 当前测试设备 ID
  static const String testDeviceId = 'collar_001';

  /// API 请求超时
  static const Duration requestTimeout = Duration(seconds: 10);

  /// 是否启用调试日志
  static const bool debugMode = true;

  /// 去掉用户输入 URL 尾部斜杠
  static String normalizeBaseUrl(String url) =>
      url.trim().replaceAll(RegExp(r'/$'), '');

  /// 构造带 `key` 的 API URI。
  /// [path] 必须以 `/` 开头，例如 `/api/health`、`/api/status/collar_001`。
  static Uri apiUri(
    String path, {
    String? baseUrlOverride,
    Map<String, String>? queryParameters,
  }) {
    final base = normalizeBaseUrl(baseUrlOverride ?? baseUrl);
    final params = <String, String>{
      'key': deviceKey,
      if (queryParameters != null) ...queryParameters,
    };
    return Uri.parse('$base$path').replace(queryParameters: params);
  }
}
