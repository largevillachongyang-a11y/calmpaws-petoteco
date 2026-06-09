// Firebase Cloud Messaging service worker (Web push)
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBUEY5rILv3La2iwI-Ot40uCTkZt0Rreto',
  appId: '1:847480478175:web:5209c62a778cbee445cc6a',
  messagingSenderId: '847480478175',
  projectId: 'petoteco-5e807',
  storageBucket: 'petoteco-5e807.firebasestorage.app',
  authDomain: 'petoteco-5e807.firebaseapp.com',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
  const title = payload.notification?.title || 'CalmPaws';
  const body = payload.notification?.body || '';
  return self.registration.showNotification(title, {
    body: body,
    icon: '/favicon.png',
  });
});
