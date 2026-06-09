// =============================================================================
// auth_api_helper.dart — Firebase Bearer 鉴权 HTTP（铁律 5）
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/environment_config.dart';
import 'api_exception.dart';

typedef AuthSessionInvalidCallback = Future<void> Function();

class AuthApiHelper {
  AuthApiHelper._();
  static final AuthApiHelper instance = AuthApiHelper._();

  AuthSessionInvalidCallback? onSessionInvalid;

  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return user.getIdToken(forceRefresh);
  }

  Future<Map<String, String>> authHeaders({bool forceRefresh = false}) async {
    final token = await getIdToken(forceRefresh: forceRefresh);
    if (token == null) {
      throw const ApiException(
        kind: ApiErrorKind.unauthorized,
        message: '用户未登录',
      );
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Uri uri(
    String path, {
    String? baseUrlOverride,
    Map<String, String>? queryParameters,
  }) =>
      EnvironmentConfig.apiUri(
        path,
        baseUrlOverride: baseUrlOverride,
        queryParameters: queryParameters,
      );

  Future<http.Response> get(
    Uri url, {
    bool retryOn401 = true,
  }) async {
    return _send(
      () async => http.get(url, headers: await authHeaders()).timeout(
            EnvironmentConfig.requestTimeout,
          ),
      retryOn401: retryOn401,
      retry: () async => http.get(url, headers: await authHeaders(forceRefresh: true)).timeout(
            EnvironmentConfig.requestTimeout,
          ),
    );
  }

  Future<http.Response> post(
    Uri url, {
    Object? body,
    bool retryOn401 = true,
  }) async {
    final encoded = body is String ? body : jsonEncode(body);
    return _send(
      () async => http
          .post(url, headers: await authHeaders(), body: encoded)
          .timeout(EnvironmentConfig.requestTimeout),
      retryOn401: retryOn401,
      retry: () async => http
          .post(url, headers: await authHeaders(forceRefresh: true), body: encoded)
          .timeout(EnvironmentConfig.requestTimeout),
    );
  }

  Future<http.Response> _send(
    Future<http.Response> Function() request, {
    required bool retryOn401,
    required Future<http.Response> Function() retry,
  }) async {
    try {
      var resp = await request();
      if (resp.statusCode == 401 && retryOn401) {
        resp = await retry();
      }
      if (resp.statusCode == 401) {
        await onSessionInvalid?.call();
        throw ApiException.fromStatus(401, body: resp.body);
      }
      return resp;
    } on TimeoutException {
      throw const ApiException(
        kind: ApiErrorKind.network,
        message: '请求超时',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      if (EnvironmentConfig.debugMode && kDebugMode) {
        debugPrint('[AuthAPI] 请求失败：$e');
      }
      throw ApiException(
        kind: ApiErrorKind.network,
        message: '连接失败：$e',
      );
    }
  }
}
