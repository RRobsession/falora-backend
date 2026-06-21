const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const { google } = require('googleapis');
const { getFirestore, initFirebaseAdmin } = require('./fcm');

const PLAY_PURCHASES_COLLECTION = 'play_purchases';
const MANUAL_REQUESTS_COLLECTION = 'manual_fortune_requests';
const USERS_COLLECTION = 'users';

const PACKAGE_NAME = process.env.GOOGLE_PLAY_PACKAGE_NAME || 'com.rrlime.falora';

const TOKEN_PRODUCTS = {
  tokens_50: { tokens: 50 },
  tokens_150: { tokens: 150 },
  tokens_300: { tokens: 300 },
  tokens_750: { tokens: 750 },
  tokens_1500: { tokens: 1500 },
};

const MANUAL_PRODUCTS = {
  serdar_tarot_4q_350: {
    category: 'tarot',
    readerId: 'serdar',
    priceTRY: 350,
    questionLimit: 4,
    requiresIntention: false,
  },
  hatice_tarot_4q_350: {
    category: 'tarot',
    readerId: 'hatice',
    priceTRY: 350,
    questionLimit: 4,
    requiresIntention: false,
  },
  serdar_kahve_2q_500: {
    category: 'kahve',
    readerId: 'serdar',
    priceTRY: 500,
    questionLimit: 2,
    requiresIntention: true,
  },
  hatice_kahve_2q_500: {
    category: 'kahve',
    readerId: 'hatice',
    priceTRY: 500,
    questionLimit: 2,
    requiresIntention: true,
  },
  serdar_bakla_2q_500: {
    category: 'bakla',
    readerId: 'serdar',
    priceTRY: 500,
    questionLimit: 2,
    requiresIntention: true,
  },
  hatice_bakla_2q_500: {
    category: 'bakla',
    readerId: 'hatice',
    priceTRY: 500,
    questionLimit: 2,
    requiresIntention: true,
  },
  serdar_su_2q_500: {
    category: 'su',
    readerId: 'serdar',
    priceTRY: 500,
    questionLimit: 2,
    requiresIntention: true,
  },
  hatice_su_2q_500: {
    category: 'su',
    readerId: 'hatice',
    priceTRY: 500,
    questionLimit: 2,
    requiresIntention: true,
  },
  serdar_iskambil_2q_250: {
    category: 'iskambil',
    readerId: 'serdar',
    priceTRY: 250,
    questionLimit: 2,
    requiresIntention: false,
  },
  hatice_iskambil_2q_250: {
    category: 'iskambil',
    readerId: 'hatice',
    priceTRY: 250,
    questionLimit: 2,
    requiresIntention: false,
  },
};

let androidPublisher = null;

function isNonEmptyString(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

function normalizeQuestions(questions) {
  if (!Array.isArray(questions)) return [];
  return questions.map((item) => String(item || '').trim()).filter(Boolean);
}

function normalizeImageInfo(imageInfo) {
  if (!Array.isArray(imageInfo)) return [];
  return imageInfo
    .filter((item) => item && typeof item === 'object')
    .map((item) => ({
      name: String(item.name || '').trim(),
      mime: String(item.mime || '').trim(),
      base64: String(item.base64 || '').trim(),
    }))
    .filter((item) => item.name && item.mime && item.base64);
}

function parseServiceAccountEnv(name) {
  if (!process.env[name]) return null;
  return JSON.parse(process.env[name]);
}

function resolveGooglePlayServiceAccount() {
  const inline = parseServiceAccountEnv('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON');
  if (inline) return inline;

  const explicitPath = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_PATH;
  if (explicitPath) {
    const resolved = path.isAbsolute(explicitPath)
      ? explicitPath
      : path.resolve(__dirname, explicitPath);
    if (fs.existsSync(resolved)) {
      return JSON.parse(fs.readFileSync(resolved, 'utf8'));
    }
  }

  const firebaseInline = parseServiceAccountEnv('FIREBASE_SERVICE_ACCOUNT_JSON');
  if (firebaseInline) return firebaseInline;

  const firebasePath =
    process.env.FIREBASE_SERVICE_ACCOUNT_PATH ||
    path.resolve(__dirname, 'firebase-service-account.json');
  const resolvedFirebasePath = path.isAbsolute(firebasePath)
    ? firebasePath
    : path.resolve(__dirname, firebasePath);
  if (fs.existsSync(resolvedFirebasePath)) {
    return JSON.parse(fs.readFileSync(resolvedFirebasePath, 'utf8'));
  }

  return null;
}

function getAndroidPublisher() {
  if (androidPublisher) return androidPublisher;

  const serviceAccount = resolveGooglePlayServiceAccount();
  if (!serviceAccount) {
    const error = new Error(
      'Google Play servis hesabı yapılandırılmadı. GOOGLE_PLAY_SERVICE_ACCOUNT_JSON veya GOOGLE_PLAY_SERVICE_ACCOUNT_PATH ekleyin.',
    );
    error.statusCode = 503;
    throw error;
  }

  const auth = new google.auth.GoogleAuth({
    credentials: serviceAccount,
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
  try {
    const publisher = getAndroidPublisher();
    const response = await publisher.purchases.products.get({
      packageName: PACKAGE_NAME,
      productId,
      token: purchaseToken,
    });
    return response.data;
  } catch (error) {
    const reason =
      error?.response?.data?.error?.message ||
      error?.message ||
      'Google Play doğrulaması başarısız.';
    const wrapped = new Error(`Google Play doğrulaması başarısız: ${reason}`);
    wrapped.statusCode = error?.response?.status || 400;
    throw wrapped;
  }
}

function validateManualPayload(body) {
  const definition = MANUAL_PRODUCTS[body.productId];
  if (!definition) {
    const error = new Error('Tanımsız manuel ürün.');
    error.statusCode = 400;
    throw error;
  }

  if (!isNonEmptyString(body.requestId)) {
    const error = new Error('requestId gerekli.');
    error.statusCode = 400;
    throw error;
  }

  if (!isNonEmptyString(body.purchaseToken)) {
    const error = new Error('purchaseToken gerekli.');
    error.statusCode = 400;
    throw error;
  }

  if (body.category !== definition.category || body.readerId !== definition.readerId) {
    const error = new Error('Ürün ile fal türü eşleşmiyor.');
    error.statusCode = 400;
    throw error;
  }

  if (Number(body.priceTRY) !== definition.priceTRY) {
    const error = new Error('Fiyat doğrulaması başarısız.');
    error.statusCode = 400;
    throw error;
  }

  if (Number(body.questionLimit) !== definition.questionLimit) {
    const error = new Error('Soru limiti doğrulaması başarısız.');
    error.statusCode = 400;
    throw error;
  }

  if (Boolean(body.requiresIntention) !== definition.requiresIntention) {
    const error = new Error('Niyet zorunluluğu eşleşmiyor.');
    error.statusCode = 400;
    throw error;
  }

  const questions = normalizeQuestions(body.questions);
  if (questions.length !== definition.questionLimit) {
    const error = new Error(`Bu ürün için ${definition.questionLimit} soru gerekli.`);
    error.statusCode = 400;
    throw error;
  }

  if (definition.requiresIntention && !isNonEmptyString(body.intention)) {
    const error = new Error('Bu fal türü için niyet alanı zorunlu.');
    error.statusCode = 400;
    throw error;
  }

  return {
    definition,
    questions,
    imageInfo: normalizeImageInfo(body.imageInfo),
  };
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

async function completeManualFortunePurchase(auth, body) {
  const firestore = getFirestoreOrThrow();
  const { definition, questions, imageInfo } = validateManualPayload(body);
  const purchaseData = await verifyProductPurchase(body.productId, body.purchaseToken);
  assertVerifiedPurchase(body.productId, body.purchaseToken, purchaseData);

  const ledgerRef = firestore.collection(PLAY_PURCHASES_COLLECTION).doc(body.purchaseToken);
  const requestRef = firestore.collection(MANUAL_REQUESTS_COLLECTION).doc(body.requestId);

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
        requestId: existingData.linkedRequestId || body.requestId,
        alreadyProcessed: true,
      };
    }

    tx.set(ledgerRef, buildPurchaseLedger({
      uid: auth.uid,
      productId: body.productId,
      purchaseToken: body.purchaseToken,
      purchaseId: body.purchaseId,
      source: body.source,
      transactionDate: body.transactionDate,
      purchaseData,
      kind: 'manual_fortune',
      linkedRequestId: body.requestId,
    }));

    tx.set(requestRef, {
      userId: auth.uid,
      userEmail: isNonEmptyString(auth.email)
        ? auth.email.trim()
        : String(body.userEmail || '').trim(),
      fortuneType: definition.category,
      readerId: body.readerId,
      readerName: String(body.readerName || '').trim(),
      priceTRY: definition.priceTRY,
      productId: body.productId,
      questionLimit: definition.questionLimit,
      requiresIntention: definition.requiresIntention,
      status: 'pending',
      name: String(body.name || '').trim(),
      age: Number(body.age) || 0,
      zodiac: String(body.zodiac || '').trim(),
      intention: String(body.intention || '').trim(),
      questions,
      imageInfo,
      purchaseToken: body.purchaseToken,
      paymentStatus: body.source === 'restored' ? 'restored' : 'verified',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      requestId: body.requestId,
      alreadyProcessed: false,
    };
  });
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
  completeManualFortunePurchase,
  completeTokenPurchase,
  restorePurchasesForUser,
  PLAY_PURCHASES_COLLECTION,
};
