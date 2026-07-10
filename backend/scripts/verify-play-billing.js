#!/usr/bin/env node
/**
 * Play billing service account doğrulamasını test eder.
 * Kullanım: node scripts/verify-play-billing.js
 */
const path = require('path');
const { google } = require('googleapis');
const { loadServiceAccount } = require('../service_account_config');

const PACKAGE_NAME = process.env.GOOGLE_PLAY_PACKAGE_NAME || 'com.rrlime.falora';

async function main() {
  const candidates = [];
  const playLoaded = loadServiceAccount({
    label: 'Google Play',
    jsonEnv: 'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON',
    pathEnv: 'GOOGLE_PLAY_SERVICE_ACCOUNT_PATH',
    defaultPath: path.join(__dirname, '..', 'google-play-service-account.json'),
  });
  if (playLoaded) candidates.push(playLoaded);

  const firebaseLoaded = loadServiceAccount({
    label: 'Google Play (Firebase fallback)',
    jsonEnv: 'FIREBASE_SERVICE_ACCOUNT_JSON',
    pathEnv: 'FIREBASE_SERVICE_ACCOUNT_PATH',
    defaultPath: path.join(__dirname, '..', 'firebase-service-account.json'),
  });
  if (firebaseLoaded) candidates.push(firebaseLoaded);

  if (!candidates.length) {
    console.error('Google Play service account bulunamadı.');
    process.exit(1);
  }

  for (const entry of candidates) {
    const ok = await testAccount(entry.credentials);
    if (ok) {
      console.log('OK: Play billing doğrulama erişimi hazır.');
      console.log(`package=${PACKAGE_NAME} account=${entry.credentials.client_email}`);
      return;
    }
  }

  process.exit(1);
}

async function testAccount(credentials) {
  const auth = new google.auth.GoogleAuth({
    credentials,
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  const publisher = google.androidpublisher({ version: 'v3', auth });

  try {
    await publisher.purchases.products.get({
      packageName: PACKAGE_NAME,
      productId: 'tokens_100',
      token: 'invalid-test-token',
    });
    console.log(`Beklenmeyen başarı (${credentials.client_email})`);
    return false;
  } catch (error) {
    const status = error?.response?.status;
    const message = error?.response?.data?.error?.message || error.message;
    if (status === 400 || status === 404) {
      return true;
    }
    console.error(`HATA (${credentials.client_email}) ${status}: ${message}`);
    return false;
  }
}

main();
