const path = require('path');
const admin = require('firebase-admin');
const { google } = require('googleapis');
const { getFirestore, initFirebaseAdmin } = require('./fcm');
const { loadServiceAccount } = require('./service_account_config');

const PLAY_PURCHASES_COLLECTION = 'play_purchases';
const USERS_COLLECTION = 'users';

const PACKAGE_NAME = process.env.GOOGLE_PLAY_PACKAGE_NAME || 'com.rrlime.falora';

const TOKEN_PRODUCTS = {
  tokens_50: { tokens: 50 },
  tokens_100: { tokens: 100 },
  tokens_150: { tokens: 150 },
  tokens_200: { tokens: 200 },
  tokens_1500: { tokens: 1500 },
};

let androidPublisher = null;
let resolvedPlayBillingAccount = null;

function isNonEmptyString(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

function resolveGooglePlayServiceAccount() {
  if (resolvedPlayBillingAccount) return resolvedPlayBillingAccount;

  const playLoaded = loadServiceAccount({
    label: 'Google Play',
    jsonEnv: 'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON',
    pathEnv: 'GOOGLE_PLAY_SERVICE_ACCOUNT_PATH',
    defaultPath: path.join(__dirname, 'google-play-service-account.json'),
  });
  if (playLoaded) {
    resolvedPlayBillingAccount = {
      credentials: playLoaded.credentials,
      source: playLoaded.source,
      clientEmail: playLoaded.credentials.client_email,
    };
    return resolvedPlayBillingAccount;
  }

  const firebaseLoaded = loadServiceAccount({
    label: 'Google Play (Firebase fallback)',
    jsonEnv: 'FIREBASE_SERVICE_ACCOUNT_JSON',
    pathEnv: 'FIREBASE_SERVICE_ACCOUNT_PATH',
    defaultPath: path.join(__dirname, 'firebase-service-account.json'),
  });
  if (firebaseLoaded) {
    resolvedPlayBillingAccount = {
      credentials: firebaseLoaded.credentials,
      source: firebaseLoaded.source,
      clientEmail: firebaseLoaded.credentials.client_email,
    };
    return resolvedPlayBillingAccount;
  }

  return null;
}

function logPlayBillingAccountUsage(context) {
  const resolved = resolveGooglePlayServiceAccount();
  if (!resolved) {
    console.error(`PLAY BILLING ${context}: servis hesabı yapılandırılmadı.`);
    return;
  }
  console.log(
    `PLAY BILLING ${context}: client_email=${resolved.clientEmail} source=${resolved.source} package=${PACKAGE_NAME}`,
  );
}

const PLAY_VERIFY_API_METHOD = 'androidpublisher.purchases.products.get';

function maskPurchaseToken(token) {
  if (!isNonEmptyString(token)) return 'missing';
  const trimmed = token.trim();
  if (trimmed.length <= 10) return `${trimmed.slice(0, 3)}...`;
  return `${trimmed.slice(0, 8)}...${trimmed.slice(-4)}`;
}

function extractGoogleApiErrorFields(responseData) {
  const apiError = responseData?.error;
  if (!apiError) {
    return { reason: null, details: null };
  }

  const nestedErrors = Array.isArray(apiError.errors) ? apiError.errors : [];
  const firstNested = nestedErrors[0] ?? null;

  return {
    reason: apiError.reason ?? firstNested?.reason ?? null,
    details: apiError.details ?? nestedErrors,
  };
}

function logGooglePlayApiCall({ productId, purchaseToken }) {
  console.log(
    `PLAY BILLING API call method=${PLAY_VERIFY_API_METHOD} packageName=${PACKAGE_NAME} productId=${productId} purchaseToken=${maskPurchaseToken(purchaseToken)}`,
  );
}

function logGooglePlayApiError(context, error) {
  const response = error?.response;
  const status = response?.status ?? null;
  const responseBody = response?.data ?? null;
  const apiError = responseBody?.error ?? null;
  const { reason, details } = extractGoogleApiErrorFields(responseBody);

  console.error(`PLAY BILLING API ERROR ${context}`);
  console.error(`PLAY BILLING API method=${PLAY_VERIFY_API_METHOD}`);
  console.error(`PLAY BILLING API httpStatus=${status ?? 'n/a'}`);

  if (apiError) {
    console.error(`PLAY BILLING API error.code=${apiError.code ?? 'n/a'}`);
    console.error(`PLAY BILLING API error.message=${apiError.message ?? 'n/a'}`);
    console.error(`PLAY BILLING API error.reason=${reason ?? 'n/a'}`);
    console.error(`PLAY BILLING API error.details=${JSON.stringify(details ?? null)}`);
  } else {
    console.error(`PLAY BILLING API error.reason=n/a`);
    console.error(`PLAY BILLING API error.details=${JSON.stringify(null)}`);
  }

  console.error(
    `PLAY BILLING API responseBody=${JSON.stringify(responseBody ?? { message: error?.message ?? null })}`,
  );
}

function getAndroidPublisher() {
  if (androidPublisher) return androidPublisher;

  const resolved = resolveGooglePlayServiceAccount();
  if (!resolved) {
    const error = new Error(
      'Google Play servis hesabı yapılandırılmadı. GOOGLE_PLAY_SERVICE_ACCOUNT_JSON veya GOOGLE_PLAY_SERVICE_ACCOUNT_PATH ekleyin.',
    );
    error.statusCode = 503;
    throw error;
  }

  logPlayBillingAccountUsage('init');

  const auth = new google.auth.GoogleAuth({
    credentials: resolved.credentials,
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });

  androidPublisher = google.androidpublisher({
    version: 'v3',
    auth,
  });
  return androidPublisher;
}

function getFirestoreOrThrow() {
  if (!initFirebaseAdmin()) {
    const error = new Error(
      'Firebase Admin yapılandırılmadı. Billing işlemleri için service account gerekli.',
    );
    error.statusCode = 503;
    throw error;
  }
  const firestore = getFirestore();
  if (!firestore) {
    const error = new Error('Firestore başlatılamadı.');
    error.statusCode = 503;
    throw error;
  }
  return firestore;
}

async function verifyProductPurchase(productId, purchaseToken) {
  logPlayBillingAccountUsage(`verify productId=${productId}`);
  logGooglePlayApiCall({ productId, purchaseToken });
  try {
    const publisher = getAndroidPublisher();
    const response = await publisher.purchases.products.get({
      packageName: PACKAGE_NAME,
      productId,
      token: purchaseToken,
    });
    console.log(
      `PLAY BILLING API success method=${PLAY_VERIFY_API_METHOD} productId=${productId} orderId=${response.data?.orderId || 'n/a'}`,
    );
    return response.data;
  } catch (error) {
    logGooglePlayApiError(`verify productId=${productId}`, error);
    const reason =
      error?.response?.data?.error?.message ||
      error?.message ||
      'Google Play doğrulaması başarısız.';
    const wrapped = new Error(`Google Play doğrulaması başarısız: ${reason}`);
    wrapped.statusCode = error?.response?.status || 400;
    throw wrapped;
  }
}

function validateTokenPayload(body) {
  const definition = TOKEN_PRODUCTS[body.productId];
  if (!definition) {
    const error = new Error('Tanımsız jeton ürünü.');
    error.statusCode = 400;
    throw error;
  }

  if (!isNonEmptyString(body.purchaseToken)) {
    const error = new Error('purchaseToken gerekli.');
    error.statusCode = 400;
    throw error;
  }

  return definition;
}

function assertVerifiedPurchase(productId, purchaseToken, purchaseData) {
  if (!purchaseData) {
    const error = new Error('Satın alma doğrulama verisi alınamadı.');
    error.statusCode = 400;
    throw error;
  }

  if (purchaseData.purchaseState !== 0) {
    const error = new Error('Satın alma tamamlanmış görünmüyor.');
    error.statusCode = 409;
    throw error;
  }

  if (purchaseData.consumptionState === 1 && !purchaseData.orderId) {
    const error = new Error('Satın alma kaydı eksik görünüyor.');
    error.statusCode = 409;
    throw error;
  }

  if (!isNonEmptyString(purchaseToken) || !isNonEmptyString(productId)) {
    const error = new Error('Satın alma bilgisi eksik.');
    error.statusCode = 400;
    throw error;
  }
}

function buildPurchaseLedger({
  uid,
  productId,
  purchaseToken,
  purchaseId,
  source,
  transactionDate,
  purchaseData,
  kind,
  linkedRequestId,
  tokensGranted,
}) {
  return {
    uid,
    kind,
    productId,
    purchaseToken,
    purchaseId: purchaseId || null,
    source: source || 'purchased',
    packageName: PACKAGE_NAME,
    orderId: purchaseData.orderId || null,
    purchaseState: purchaseData.purchaseState ?? null,
    acknowledgementState: purchaseData.acknowledgementState ?? null,
    consumptionState: purchaseData.consumptionState ?? null,
    purchaseTimeMillis: purchaseData.purchaseTimeMillis || transactionDate || null,
    purchaseType: purchaseData.purchaseType ?? null,
    linkedRequestId: linkedRequestId || null,
    tokensGranted: tokensGranted || 0,
    verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

async function completeTokenPurchase(auth, body) {
  const firestore = getFirestoreOrThrow();
  const definition = validateTokenPayload(body);
  const purchaseData = await verifyProductPurchase(body.productId, body.purchaseToken);
  assertVerifiedPurchase(body.productId, body.purchaseToken, purchaseData);

  const ledgerRef = firestore.collection(PLAY_PURCHASES_COLLECTION).doc(body.purchaseToken);
  const userRef = firestore.collection(USERS_COLLECTION).doc(auth.uid);

  return firestore.runTransaction(async (tx) => {
    const existingLedger = await tx.get(ledgerRef);
    if (existingLedger.exists) {
      const existingData = existingLedger.data() || {};
      if (existingData.uid !== auth.uid) {
        const error = new Error('Bu purchaseToken başka bir hesapta kullanılmış.');
        error.statusCode = 409;
        throw error;
      }
      return {
        tokensGranted: Number(existingData.tokensGranted) || 0,
        alreadyProcessed: true,
      };
    }

    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) {
      const error = new Error('Kullanıcı kaydı bulunamadı.');
      error.statusCode = 404;
      throw error;
    }

    const currentTokens = Number(userSnap.data()?.tokens || 0);
    tx.update(userRef, {
      tokens: currentTokens + definition.tokens,
    });

    tx.set(ledgerRef, buildPurchaseLedger({
      uid: auth.uid,
      productId: body.productId,
      purchaseToken: body.purchaseToken,
      purchaseId: body.purchaseId,
      source: body.source,
      transactionDate: body.transactionDate,
      purchaseData,
      kind: 'token_pack',
      tokensGranted: definition.tokens,
    }));

    return {
      tokensGranted: definition.tokens,
      alreadyProcessed: false,
    };
  });
}

async function restorePurchasesForUser(uid) {
  const firestore = getFirestoreOrThrow();
  const snap = await firestore
    .collection(PLAY_PURCHASES_COLLECTION)
    .where('uid', '==', uid)
    .orderBy('verifiedAt', 'desc')
    .limit(20)
    .get();

  const docs = snap.docs.map((doc) => doc.data());
  return {
    processedCount: docs.length,
    lastProductId: docs[0]?.productId || null,
    purchases: docs,
  };
}

module.exports = {
  completeTokenPurchase,
  restorePurchasesForUser,
  PLAY_PURCHASES_COLLECTION,
};
