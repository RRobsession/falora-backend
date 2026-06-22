const admin = require('firebase-admin');
const { getFirestore, initFirebaseAdmin } = require('./fcm');

const REFERRAL_REWARD_TOKENS = 100;

function getFirestoreOrThrow() {
  if (!initFirebaseAdmin()) {
    const error = new Error(
      'Firebase Admin yapılandırılmadı. Referral işlemleri için service account gerekli.',
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

function normalizeReferralCode(raw) {
  return String(raw || '').trim().toUpperCase();
}

/**
 * Referans ödülünü tek transaction ile işler (Admin SDK — rules bypass).
 */
async function claimReferral({ uid, referralCode }) {
  const code = normalizeReferralCode(referralCode);
  if (!code) {
    return { ok: false, code: 'referral_code_required' };
  }

  console.log('REFERRAL_CLAIM_START uid=%s code=%s', uid, code);

  const db = getFirestoreOrThrow();
  const codeRef = db.collection('referral_codes').doc(code);
  const newUserRef = db.collection('users').doc(uid);

  try {
    const outcome = await db.runTransaction(async (tx) => {
      const codeSnap = await tx.get(codeRef);
      if (!codeSnap.exists) {
        console.log('REFERRAL_CODE_NOT_FOUND code=%s', code);
        return { ok: false, code: 'not_found' };
      }

      const inviterUid = codeSnap.data()?.uid;
      if (!inviterUid || typeof inviterUid !== 'string') {
        console.log('REFERRAL_CODE_NOT_FOUND missing inviter uid code=%s', code);
        return { ok: false, code: 'not_found' };
      }

      if (inviterUid === uid) {
        console.log('REFERRAL_SELF_REFERRAL_BLOCKED uid=%s', uid);
        return { ok: false, code: 'self_referral' };
      }

      const newUserSnap = await tx.get(newUserRef);
      if (!newUserSnap.exists) {
        throw new Error('user_doc_missing');
      }

      const newUserData = newUserSnap.data() ?? {};
      const referredBy = newUserData.referredBy;
      const alreadyClaimed = newUserData.referralRewardClaimed === true;

      if (alreadyClaimed) {
        console.log('REFERRAL_ALREADY_CLAIMED uid=%s', uid);
        return { ok: false, code: 'already_claimed' };
      }

      if (typeof referredBy === 'string' && referredBy.length > 0) {
        console.log('REFERRAL_ALREADY_CLAIMED referredBy set uid=%s', uid);
        return { ok: false, code: 'already_claimed' };
      }

      const inviterRef = db.collection('users').doc(inviterUid);
      const creditRef = inviterRef.collection('referral_credits').doc(uid);
      const creditSnap = await tx.get(creditRef);
      if (creditSnap.exists) {
        console.log('REFERRAL_ALREADY_CLAIMED credit exists uid=%s', uid);
        return { ok: false, code: 'already_claimed' };
      }

      const inviterSnap = await tx.get(inviterRef);
      if (!inviterSnap.exists) {
        console.log('REFERRAL_CODE_NOT_FOUND inviter missing uid=%s', inviterUid);
        return { ok: false, code: 'not_found' };
      }

      const inviterData = inviterSnap.data() ?? {};
      const newUserTokens =
        (typeof newUserData.tokens === 'number' ? newUserData.tokens : 0) +
        REFERRAL_REWARD_TOKENS;
      const inviterTokens =
        (typeof inviterData.tokens === 'number' ? inviterData.tokens : 0) +
        REFERRAL_REWARD_TOKENS;
      const inviteCount =
        (typeof inviterData.referralInviteCount === 'number'
          ? inviterData.referralInviteCount
          : 0) + 1;

      console.log('REFERRAL_NEW_USER_REWARD_START uid=%s amount=%s', uid, REFERRAL_REWARD_TOKENS);
      console.log(
        'REFERRAL_INVITER_REWARD_START inviter=%s amount=%s',
        inviterUid,
        REFERRAL_REWARD_TOKENS,
      );

      tx.update(newUserRef, {
        tokens: newUserTokens,
        referredBy: inviterUid,
        referralRewardClaimed: true,
        referralRewardAmount: REFERRAL_REWARD_TOKENS,
        referralRewardedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      tx.update(inviterRef, {
        tokens: inviterTokens,
        referralInviteCount: inviteCount,
      });

      tx.set(creditRef, {
        fromUid: uid,
        amount: REFERRAL_REWARD_TOKENS,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        code,
      });

      return {
        ok: true,
        code: 'success',
        rewardTokens: REFERRAL_REWARD_TOKENS,
        inviterUid,
      };
    });

    if (outcome.ok) {
      console.log('REFERRAL_TRANSACTION_SUCCESS uid=%s', uid);
    } else if (outcome.code === 'not_found') {
      console.log('REFERRAL_IGNORED_REGISTRATION_CONTINUES uid=%s', uid);
    }

    return outcome;
  } catch (error) {
    console.error('REFERRAL_TRANSACTION_FAILED uid=%s error=%s', uid, error.message);
    throw error;
  }
}

module.exports = {
  REFERRAL_REWARD_TOKENS,
  claimReferral,
};
