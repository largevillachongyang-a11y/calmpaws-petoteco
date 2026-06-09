// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

// Web：注册 FCM Service Worker（gh-pages 子路径，相对 base href）
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

Future<void> registerFcmServiceWorkerIfNeeded() async {
  final sw = html.window.navigator.serviceWorker;
  if (sw == null) return;

  final scriptUrl = Uri.base.resolve('firebase-messaging-sw.js').toString();
  try {
    await sw.register(scriptUrl);
  } catch (e) {
    // index.html 可能已注册
    debugPrint('[FCM SW] register: $e');
  }
  await sw.ready;
}
