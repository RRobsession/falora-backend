const { getFirestore } = require('./fcm');
const { sanitizeAiResult } = require('./ai_result_sanitize');

const FORTUNE_COLLECTION = 'fortune_requests';
const COUPLE_COLLECTION = 'couple_compatibility_requests';

/**
 * AI sonucunu Firestore'a yazar (yalnızca result; readyAt kapısı istemcide kalır).
 * requestId yoksa sessizce atlanır — eski uygulama sürümleri etkilenmez.
 */
async function persistFortuneResult({
  uid,
  requestId,
  result,
  collection = FORTUNE_COLLECTION,
}) {
  if (!requestId || typeof requestId !== 'string' || !requestId.trim()) {
    return { ok: false, reason: 'no_request_id' };
  }
  const trimmed = sanitizeAiResult(typeof result === 'string' ? result : '');
  if (!trimmed) {
    return { ok: false, reason: 'empty_result' };
  }

  const db = getFirestore();
  if (!db) {
    console.error('FORTUNE PERSIST SKIP | firestore_unavailable | id=', requestId);
    return { ok: false, reason: 'firestore_unavailable' };
  }

  const ref = db.collection(collection).doc(requestId.trim());
  const snap = await ref.get();
  if (!snap.exists) {
    console.error('FORTUNE PERSIST SKIP | not_found | id=', requestId);
    return { ok: false, reason: 'not_found' };
  }

  const data = snap.data() || {};
  if (data.userId !== uid) {
    console.error('FORTUNE PERSIST SKIP | forbidden | id=', requestId);
    return { ok: false, reason: 'forbidden' };
  }

  const existing = typeof data.result === 'string' ? data.result.trim() : '';
  if (existing) {
    return { ok: true, reason: 'already_saved' };
  }

  const patch = { result: trimmed };
  if (data.status === 'error') {
    patch.status = 'pending';
  }

  await ref.update(patch);
  console.log(
    'FORTUNE PERSIST OK | collection=',
    collection,
    '| id=',
    requestId,
    '| len=',
    trimmed.length,
  );
  return { ok: true, reason: 'saved' };
}

module.exports = {
  FORTUNE_COLLECTION,
  COUPLE_COLLECTION,
  persistFortuneResult,
};
