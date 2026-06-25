const { getFirestore } = require('./fcm');
const {
  FORTUNE_COLLECTION,
  COUPLE_COLLECTION,
} = require('./fortune_result_persist');

const RETENTION_DAYS = Number(process.env.FORTUNE_RETENTION_DAYS) || 7;
const CLEANUP_INTERVAL_MS =
  Number(process.env.FORTUNE_RETENTION_CLEANUP_MS) || 6 * 60 * 60 * 1000;
const DELETE_BATCH_SIZE = 200;

let cleanupTimer = null;
let cleanupInFlight = false;

function retentionCutoffDate(now = new Date()) {
  return new Date(now.getTime() - RETENTION_DAYS * 24 * 60 * 60 * 1000);
}

async function deleteExpiredFromCollection(db, collection, cutoffDate) {
  let deleted = 0;

  while (true) {
    const snap = await db
      .collection(collection)
      .where('createdAt', '<', cutoffDate)
      .limit(DELETE_BATCH_SIZE)
      .get();

    if (snap.empty) {
      return deleted;
    }

    const batch = db.batch();
    for (const doc of snap.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
    deleted += snap.size;

    if (snap.size < DELETE_BATCH_SIZE) {
      return deleted;
    }
  }
}

async function runFortuneRetentionCleanup() {
  if (cleanupInFlight) {
    console.log('FORTUNE RETENTION SKIP | reason=in_flight');
    return { ok: false, reason: 'in_flight', deleted: 0 };
  }

  const db = getFirestore();
  if (!db) {
    console.log('FORTUNE RETENTION SKIP | reason=firestore_unavailable');
    return { ok: false, reason: 'firestore_unavailable', deleted: 0 };
  }

  cleanupInFlight = true;
  const cutoffDate = retentionCutoffDate();

  try {
    const [fortunesDeleted, couplesDeleted] = await Promise.all([
      deleteExpiredFromCollection(db, FORTUNE_COLLECTION, cutoffDate),
      deleteExpiredFromCollection(db, COUPLE_COLLECTION, cutoffDate),
    ]);

    const deleted = fortunesDeleted + couplesDeleted;
    console.log(
      'FORTUNE RETENTION OK | days=',
      RETENTION_DAYS,
      '| cutoff=',
      cutoffDate.toISOString(),
      '| fortunesDeleted=',
      fortunesDeleted,
      '| couplesDeleted=',
      couplesDeleted,
    );

    return { ok: true, deleted };
  } catch (err) {
    console.error('FORTUNE RETENTION ERROR:', err.message);
    return { ok: false, reason: 'cleanup_failed', deleted: 0 };
  } finally {
    cleanupInFlight = false;
  }
}

function startFortuneRetentionCleanupLoop() {
  if (cleanupTimer) {
    return cleanupTimer;
  }

  console.log(
    'FORTUNE RETENTION LOOP START | days=',
    RETENTION_DAYS,
    '| intervalMs=',
    CLEANUP_INTERVAL_MS,
  );

  void runFortuneRetentionCleanup();
  cleanupTimer = setInterval(() => {
    void runFortuneRetentionCleanup();
  }, CLEANUP_INTERVAL_MS);

  return cleanupTimer;
}

module.exports = {
  RETENTION_DAYS,
  runFortuneRetentionCleanup,
  startFortuneRetentionCleanupLoop,
};
