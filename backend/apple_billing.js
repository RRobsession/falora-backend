const admin = require('firebase-admin');
const {
  APIException,
  AppStoreServerAPIClient,
  Environment,
} = require('@apple/app-store-server-library');
const { getFirestore, initFirebaseAdmin } = require('./fcm');

const APPLE_PURCHASES_COLLECTION = 'apple_purchases';
const USERS_COLLECTION = 'users';
const APPLE_BUNDLE_ID = process.env.APPLE_IAP_BUNDLE_ID || 'com.rrlime.falora';

const APPLE_TOKEN_PRODUCTS = {
  tokens_50: { tokens: 50 },
  tokens_150: { tokens: 150 },
  tokens_500: { tokens: 500 },
  tokens_1000: { tokens: 1000 },
  tokens_1500: {
    tokens: 0,
    specialFortuneRights: 1,
    kind: 'special_fortune_right',
  },
};

function isNonEmptyString(value) {
  return typeof value === 'string' && value.trim().length > 0;
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

function readAppleCredentials() {
  const keyId = process.env.APPLE_IAP_KEY_ID?.trim();
  const issuerId = process.env.APPLE_IAP_ISSUER_ID?.trim();
  const encodedKey = process.env.APPLE_IAP_PRIVATE_KEY?.trim();

  if (!keyId || !issuerId || !encodedKey) {
    const error = new Error(
      'Apple App Store satın alma doğrulaması yapılandırılmadı.',
    );
    error.statusCode = 503;
    throw error;
  }

  const signingKey = encodedKey.includes('BEGIN PRIVATE KEY')
    ? encodedKey.replace(/\\n/g, '\n')
    : Buffer.from(encodedKey, 'base64').toString('utf8');

  if (!signingKey.includes('BEGIN PRIVATE KEY')) {
    const error = new Error('Apple IAP private key biçimi geçersiz.');
    error.statusCode = 503;
    throw error;
  }

  return { keyId, issuerId, signingKey };
}

function createAppleClient(environment) {
  const { keyId, issuerId, signingKey } = readAppleCredentials();
  return new AppStoreServerAPIClient(
    signingKey,
    keyId,
    issuerId,
    APPLE_BUNDLE_ID,
    environment,
  );
}

function decodeAppleSignedTransaction(signedTransactionInfo) {
  if (!isNonEmptyString(signedTransactionInfo)) {
    const error = new Error('Apple işlem doğrulama yanıtı eksik.');
    error.statusCode = 502;
    throw error;
  }
  const parts = signedTransactionInfo.split('.');
  if (parts.length !== 3) {
    const error = new Error('Apple işlem doğrulama yanıtı geçersiz.');
    error.statusCode = 502;
    throw error;
  }
  try {
    return JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
  } catch (_) {
    const error = new Error('Apple işlem bilgisi çözümlenemedi.');
    error.statusCode = 502;
    throw error;
  }
}

function isTransactionNotFound(error) {
  return error instanceof APIException && error.httpStatusCode === 404;
}

async function fetchAppleTransaction(transactionId) {
  try {
    const response = await createAppleClient(Environment.PRODUCTION)
      .getTransactionInfo(transactionId);
    return {
      environment: Environment.PRODUCTION,
      transaction: decodeAppleSignedTransaction(response.signedTransactionInfo),
    };
  } catch (error) {
    if (!isTransactionNotFound(error)) throw error;
  }

  const response = await createAppleClient(Environment.SANDBOX)
    .getTransactionInfo(transactionId);
  return {
    environment: Environment.SANDBOX,
    transaction: decodeAppleSignedTransaction(response.signedTransactionInfo),
  };
}

function validateApplePayload(body) {
  const definition = APPLE_TOKEN_PRODUCTS[body.productId];
  if (!definition) {
    const error = new Error('Tanımsız Apple jeton ürünü.');
    error.statusCode = 400;
    throw error;
  }
  if (!isNonEmptyString(body.purchaseId)) {
    const error = new Error('Apple transactionId gerekli.');
    error.statusCode = 400;
    throw error;
  }
  return definition;
}

function assertAppleTransaction(body, verified) {
  const transaction = verified.transaction;
  if (
    transaction.transactionId !== body.purchaseId.trim() ||
    transaction.productId !== body.productId ||
    transaction.bundleId !== APPLE_BUNDLE_ID
  ) {
    const error = new Error('Apple satın alma bilgileri uygulamayla eşleşmiyor.');
    error.statusCode = 409;
    throw error;
  }
  if (transaction.type !== 'Consumable') {
    const error = new Error('Apple ürünü consumable olarak doğrulanamadı.');
    error.statusCode = 409;
    throw error;
  }
  if (transaction.environment !== verified.environment) {
    const error = new Error('Apple satın alma ortamı doğrulanamadı.');
    error.statusCode = 409;
    throw error;
  }
  if (transaction.revocationDate != null) {
    const error = new Error('İade edilmiş Apple satın alımı kullanılamaz.');
    error.statusCode = 409;
    throw error;
  }
  if (Number(transaction.quantity || 1) !== 1) {
    const error = new Error('Apple satın alma miktarı geçersiz.');
    error.statusCode = 409;
    throw error;
  }
}

async function completeAppleTokenPurchase(auth, body) {
  const firestore = getFirestoreOrThrow();
  const definition = validateApplePayload(body);
  const verified = await fetchAppleTransaction(body.purchaseId.trim());
  assertAppleTransaction(body, verified);

  const transaction = verified.transaction;
  const ledgerRef = firestore
    .collection(APPLE_PURCHASES_COLLECTION)
    .doc(transaction.transactionId);
  const userRef = firestore.collection(USERS_COLLECTION).doc(auth.uid);

  return firestore.runTransaction(async (tx) => {
    const existingLedger = await tx.get(ledgerRef);
    if (existingLedger.exists) {
      const existingData = existingLedger.data() || {};
      if (existingData.uid !== auth.uid) {
        const error = new Error('Bu Apple işlemi başka bir hesapta kullanılmış.');
        error.statusCode = 409;
        throw error;
      }
      return {
        tokensGranted: Number(existingData.tokensGranted) || 0,
        specialFortuneRightsGranted:
          Number(existingData.specialFortuneRightsGranted) || 0,
        alreadyProcessed: true,
      };
    }

    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) {
      const error = new Error('Kullanıcı kaydı bulunamadı.');
      error.statusCode = 404;
      throw error;
    }

    const userUpdate = {};
    if (definition.tokens > 0) {
      userUpdate.tokens = Number(userSnap.data()?.tokens || 0) + definition.tokens;
    }
    if (definition.specialFortuneRights > 0) {
      userUpdate.specialFortuneRights =
        Number(userSnap.data()?.specialFortuneRights || 0) +
        definition.specialFortuneRights;
    }
    tx.update(userRef, userUpdate);
    tx.set(ledgerRef, {
      uid: auth.uid,
      platform: 'ios',
      kind: definition.kind || 'token_pack',
      productId: transaction.productId,
      transactionId: transaction.transactionId,
      originalTransactionId: transaction.originalTransactionId || null,
      bundleId: transaction.bundleId,
      environment: transaction.environment,
      purchaseDate: transaction.purchaseDate || null,
      tokensGranted: definition.tokens,
      specialFortuneRightsGranted: definition.specialFortuneRights || 0,
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      tokensGranted: definition.tokens,
      specialFortuneRightsGranted: definition.specialFortuneRights || 0,
      alreadyProcessed: false,
    };
  });
}

module.exports = {
  APPLE_PURCHASES_COLLECTION,
  completeAppleTokenPurchase,
  _test: {
    assertAppleTransaction,
    decodeAppleSignedTransaction,
  },
};
