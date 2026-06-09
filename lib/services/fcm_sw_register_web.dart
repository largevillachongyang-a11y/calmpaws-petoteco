// Web：注册 FCM Service Worker（gh-pages 子路径，相对 base href）
import 'dart:html' as html;

Future<void> registerFcmServiceWorkerIfNeeded() async {
  final sw = html.window.navigator.serviceWorker;
  if (sw == null) return;

  final scriptUrl = Uri.base.resolve('firebase-messaging-sw.js').toString();
  try {
    await sw.register(scriptUrl);
  } catch (e) {
    // index.html 可能已注册
    print('[FCM SW] register: $e');
  }
  await sw.ready;
}
