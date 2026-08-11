/* Falora Firebase Cloud Messaging service worker */
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCqVS_DSnsv9V8Rm9NpJLmVTn45Hde7PXs',
  appId: '1:36770284037:web:3928a19e47f183c79ad26c',
  messagingSenderId: '36770284037',
  projectId: 'tombikteyze',
  authDomain: 'tombikteyze.firebaseapp.com',
  storageBucket: 'tombikteyze.firebasestorage.app',
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
