const test = require('node:test');
const assert = require('node:assert/strict');
const { normalize, limits } = require('../community');
const { _test, APPLE_COMMUNITY_SUBSCRIPTION_ID } = require('../apple_billing');

test('normalizes common Turkish moderation bypasses', () => {
  assert.equal(normalize('  K.Ü.F.Ü.R  '), 'k u f u r');
  assert.equal(normalize('S333LAAAM'), 'seelaam');
  assert.ok(limits.pageMax <= 20);
});

test('accepts only the configured Apple auto-renewable subscription', () => {
  const transaction = {
    transactionId: 'tx-1',
    productId: APPLE_COMMUNITY_SUBSCRIPTION_ID,
    bundleId: 'com.rrlime.falora',
    type: 'Auto-Renewable Subscription',
    environment: 'Production',
  };
  assert.doesNotThrow(() => _test.assertCommunitySubscription(
    { purchaseId: 'tx-1' },
    { environment: 'Production', transaction },
  ));
  assert.throws(() => _test.assertCommunitySubscription(
    { purchaseId: 'tx-1' },
    { environment: 'Production', transaction: { ...transaction, type: 'Consumable' } },
  ));
});
