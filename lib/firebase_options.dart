// Firebase configuration for all platforms
// Project: petoteco-5e807
//
// ⚠️ Web appId 需要从 Firebase Console 添加 Web 应用后获取真实值
// 当前 Web 使用 Android 配置作为临时方案
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  // Web平台配置（已在 Firebase Console 注册 Web 应用）
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBUEY5rILv3La2iwI-Ot40uCTkZt0Rreto',
    appId: '1:847480478175:web:5209c62a778cbee445cc6a',
    messagingSenderId: '847480478175',
    projectId: 'petoteco-5e807',
    storageBucket: 'petoteco-5e807.firebasestorage.app',
    authDomain: 'petoteco-5e807.firebaseapp.com',
    measurementId: 'G-WXC5R3PL5D',
  );

  // Android配置
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAxR9wEoAD3h9slHvc7Hb90VSEOBvd-5so',
    appId: '1:847480478175:android:1b0dd7256c0ec74e45cc6a',
    messagingSenderId: '847480478175',
    projectId: 'petoteco-5e807',
    storageBucket: 'petoteco-5e807.firebasestorage.app',
  );

  // iOS配置
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCEDxo2N85Wts47drDqbe78nb_9a4HZmmY',
    appId: '1:847480478175:ios:3b3fdda19ce008cf45cc6a',
    messagingSenderId: '847480478175',
    projectId: 'petoteco-5e807',
    storageBucket: 'petoteco-5e807.firebasestorage.app',
    iosClientId: '',
    iosBundleId: 'com.petoteco.app',
  );
}
