/* Falora Firebase Cloud Messaging service worker */
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCoEZyfII5OgKEWbx5zMNhOJso-z7uQMNk',
  appId: '1:688744850733:web:c78e84eef0b6f50f665fa4',
  messagingSenderId: '688744850733',
  projectId: 'falora35',
  authDomain: 'falora35.firebaseapp.com',
  storageBucket: 'falora35.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log(
    'FCM BACKGROUND MESSAGE:',
    payload.notification?.title,
    payload.notification?.body,
    payload.data,
  );
});
