const assert = require('node:assert/strict');
const test = require('node:test');
const { _test } = require('../play_billing');

test('rejects an unknown product and a missing purchase token', () => {
  assert.throws(() =>
    _test.validateTokenPayload({ productId: 'unknown', purchaseToken: 'token' }),
  );
  assert.throws(() =>
    _test.validateTokenPayload({ productId: 'tokens_50', purchaseToken: '' }),
  );
});

test('requires Google Play to report a completed purchase', () => {
  assert.doesNotThrow(() =>
    _test.assertVerifiedPurchase('tokens_50', 'purchase-token', {
      purchaseState: 0,
      orderId: 'GPA.3319-2729-3899-48402',
    }),
  );
  assert.throws(() =>
    _test.assertVerifiedPurchase('tokens_50', 'purchase-token', {
      purchaseState: 1,
    }),
  );
});

test('builds admin sale fields from trusted backend and Google data', () => {
  const ledger = _test.buildPurchaseLedger({
    uid: 'user-1',
    productId: 'tokens_50',
    purchaseToken: 'purchase-token',
    purchaseData: {
      orderId: 'GPA.3319-2729-3899-48402',
      purchaseState: 0,
      purchaseTimeMillis: '1788264000000',
    },
    kind: 'token_pack',
    tokensGranted: 50,
    specialFortuneRightsGranted: 0,
    displayName: '50 Jeton Paketi',
    userEmail: 'user@example.com',
    priceData: {
      priceMicros: 9940000,
      price: 9.94,
      currencyCode: 'TRY',
      regionCode: 'TR',
    },
  });

  assert.equal(ledger.userId, 'user-1');
  assert.equal(ledger.orderId, 'GPA.3319-2729-3899-48402');
  assert.equal(ledger.displayPackageName, '50 Jeton Paketi');
  assert.equal(ledger.tokensGranted, 50);
  assert.equal(ledger.price, 9.94);
  assert.equal(ledger.currencyCode, 'TRY');
  assert.equal(ledger.purchaseToken, 'purchase-token');
});
