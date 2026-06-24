const { getFirestore } = require('./fcm');
const {
  FORTUNE_COLLECTION,
  COUPLE_COLLECTION,
} = require('./fortune_result_persist');

const DEFAULT_TOKEN_COST = {
  [FORTUNE_COLLECTION]: 50,
  [COUPLE_COLLECTION]: 100,
};

/**
 * Başarısız fal / çift uyumu için jeton iadesi (idempotent).
 * Yalnızca result boş ve status error iken iade yapılır.
 */
async function refundFortuneRequest({
  uid,
  requestId,
  collection = FORTUNE_COLLECTION,
}) {
  if (!requestId || typeof requestId !== 'string' || !requestId.trim()) {
    return { ok: false, reason: 'no_request_id', amount: 0 };
  }

  const db = getFirestore();
  if (!db) {
    return { ok: false, reason: 'firestore_unavailable', amount: 0 };
  }

  const ref = db.collection(collection).doc(requestId.trim());
  const userRef = db.collection('users').doc(uid);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      return { ok: false, reason: 'not_found', amount: 0 };
    }

    const data = snap.data() || {};
    if (data.userId !== uid) {
      return { ok: false, reason: 'forbidden', amount: 0 };
    }

    if (data.tokensRefunded === true) {
      return { ok: true, reason: 'already_refunded', amount: 0 };
    }

    const result = typeof data.result === 'string' ? data.result.trim() : '';
    if (result) {
      return { ok: false, reason: 'has_result', amount: 0 };
    }

    if (data.status !== 'error') {
      return { ok: false, reason: 'not_failed', amount: 0 };
    }

    const amount =
      Number(data.tokenCost) > 0
        ? Number(data.tokenCost)
        : DEFAULT_TOKEN_COST[collection] || 50;

    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) {
      return { ok: false, reason: 'user_not_found', amount: 0 };
    }

    const tokens = Number(userSnap.data()?.tokens) || 0;
    tx.update(userRef, { tokens: tokens + amount });
    tx.update(ref, { tokensRefunded: true });

    return { ok: true, reason: 'refunded', amount };
  });
}

module.exports = {
  refundFortuneRequest,
};
