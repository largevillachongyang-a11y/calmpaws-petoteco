// Web：在 gh-pages 子路径下注册 FCM Service Worker，供 getToken 使用。
import 'dart:html' as html;

Future<void> registerFcmServiceWorkerIfNeeded() async {
  final sw = html.window.navigator.serviceWorker;
  if (sw == null) return;

  final scriptUrl = Uri.base.resolve('firebase-messaging-sw.js').toString();

  try {
    await sw.register(scriptUrl);
    await sw.ready;
  } catch (_) {
    // index.html 可能已注册；忽略重复注册错误
    await sw.ready;
  }
}
