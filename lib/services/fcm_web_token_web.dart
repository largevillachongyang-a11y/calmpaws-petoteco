import 'dart:js' as js;
import 'dart:js_util' as js_util;
import '../firebase_options.dart';

/// 通过 index.html 中的 calmPawsGetFcmToken 在子路径下获取 token。
Future<String?> fetchWebFcmToken(String vapidKey) async {
  final opts = DefaultFirebaseOptions.web;
  final config = js_util.jsify({
    'apiKey': opts.apiKey,
    'appId': opts.appId,
    'messagingSenderId': opts.messagingSenderId,
    'projectId': opts.projectId,
    'storageBucket': opts.storageBucket,
    'authDomain': opts.authDomain,
  });

  try {
    final fn = js.context['calmPawsGetFcmToken'];
    if (fn == null) {
      print('[FCM] calmPawsGetFcmToken 未加载');
      return null;
    }
    final promise = js_util.callMethod(fn, 'call', [
      js.context,
      vapidKey,
      config,
    ]);
    final token = await js_util.promiseToFuture(promise);
    if (token == null) return null;
    return token.toString();
  } catch (e) {
    print('[FCM] fetchWebFcmToken: $e');
    return null;
  }
}
