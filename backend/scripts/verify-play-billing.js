#!/usr/bin/env node
/**
 * Play billing service account doğrulamasını test eder.
 * Kullanım: node scripts/verify-play-billing.js
 */
const path = require('path');
const { google } = require('googleapis');
const { loadServiceAccount } = require('../service_account_config');

const PACKAGE_NAME = process.env.GOOGLE_PLAY_PACKAGE_NAME || 'com.rrlime.falora';
const PLAY_VERIFY_API_METHOD = 'androidpublisher.purchases.products.get';

function logGooglePlayApiError(label, error) {
  const response = error?.response;
  const status = response?.status ?? null;
  const responseBody = response?.data ?? null;
  const apiError = responseBody?.error ?? null;
  const nestedErrors = Array.isArray(apiError?.errors) ? apiError.errors : [];
  const reason = apiError?.reason ?? nestedErrors[0]?.reason ?? null;
  const details = apiError?.details ?? nestedErrors;

  console.error(`PLAY BILLING API ERROR ${label}`);
  console.error(`PLAY BILLING API method=${PLAY_VERIFY_API_METHOD}`);
  console.error(`PLAY BILLING API httpStatus=${status ?? 'n/a'}`);
  if (apiError) {
    console.error(`PLAY BILLING API error.code=${apiError.code ?? 'n/a'}`);
    console.error(`PLAY BILLING API error.message=${apiError.message ?? 'n/a'}`);
    console.error(`PLAY BILLING API error.reason=${reason ?? 'n/a'}`);
    console.error(`PLAY BILLING API error.details=${JSON.stringify(details ?? null)}`);
  }
  console.error(
    `PLAY BILLING API responseBody=${JSON.stringify(responseBody ?? { message: error?.message ?? null })}`,
  );
}

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
    console.log(
      `PLAY BILLING API call method=${PLAY_VERIFY_API_METHOD} packageName=${PACKAGE_NAME} productId=tokens_100 purchaseToken=invalid-test-token`,
    );
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
      console.log(
        `PLAY BILLING API expected failure (${credentials.client_email}) httpStatus=${status} message=${message}`,
      );
      return true;
    }
    logGooglePlayApiError(`verify-play-billing (${credentials.client_email})`, error);
    return false;
  }
}

main();
