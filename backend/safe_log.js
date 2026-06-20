const IS_PRODUCTION = process.env.NODE_ENV === 'production';

function safeLog(...args) {
  if (!IS_PRODUCTION) {
    console.log(...args);
  }
}

function safeError(...args) {
  console.error(...args);
}

/** Kişisel veri içerebilecek alanları loglamaz. */
function logFortuneRequest(tellerId, structureId, wordRange) {
  safeLog(
    `[fortune] teller=${tellerId} | structure=${structureId} | words=${wordRange}`,
  );
}

function logCoupleRequest(hasWomanImage, hasManImage) {
  safeLog(
    `[couple] images woman=${hasWomanImage} man=${hasManImage}`,
  );
}

module.exports = {
  safeLog,
  safeError,
  logFortuneRequest,
  logCoupleRequest,
};
