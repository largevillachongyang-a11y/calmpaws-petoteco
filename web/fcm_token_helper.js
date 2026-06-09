// gh-pages 子路径 FCM token（延迟加载 compat SDK，避免与 FlutterFire 登录冲突）
(function () {
  function loadScript(src) {
    return new Promise(function (resolve, reject) {
      if (document.querySelector('script[src="' + src + '"]')) {
        resolve();
        return;
      }
      var s = document.createElement('script');
      s.src = src;
      s.onload = resolve;
      s.onerror = reject;
      document.head.appendChild(s);
    });
  }

  async function ensureFirebaseCompat() {
    await loadScript(
      'https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js'
    );
    await loadScript(
      'https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js'
    );
  }

  window.calmPawsGetFcmToken = async function (vapidKey, firebaseConfig) {
    await ensureFirebaseCompat();

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
})();
