// gh-pages 子路径：用 compat SDK + 已注册的 SW 获取 FCM token（绕过 Flutter 默认根路径）
window.calmPawsGetFcmToken = async function (vapidKey, firebaseConfig) {
  try {
    if (!firebase.apps.length) {
      firebase.initializeApp(firebaseConfig);
    }
  } catch (e) {
    try {
      firebase.app();
    } catch (_) {
      firebase.initializeApp(firebaseConfig);
    }
  }

  var swUrl = new URL('firebase-messaging-sw.js', document.baseURI).href;
  console.log('[FCM] SW url:', swUrl);

  var registration = await navigator.serviceWorker.register(swUrl);
  await navigator.serviceWorker.ready;

  var messaging = firebase.messaging();
  var token = await messaging.getToken({
    vapidKey: vapidKey,
    serviceWorkerRegistration: registration,
  });

  console.log('[FCM] token:', token ? token.substring(0, 12) + '…' : 'empty');
  return token || null;
};
