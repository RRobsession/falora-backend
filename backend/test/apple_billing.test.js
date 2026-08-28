const assert = require('node:assert/strict');
const test = require('node:test');
const { _test } = require('../apple_billing');

function signedPayload(payload) {
  const encoded = Buffer.from(JSON.stringify(payload)).toString('base64url');
  return `header.${encoded}.signature`;
}

const validTransaction = {
  transactionId: '2000000123456789',
  originalTransactionId: '2000000123456789',
  productId: 'tokens_500',
  bundleId: 'com.rrlime.falora',
  type: 'Consumable',
  environment: 'Sandbox',
  quantity: 1,
};

test('decodes Apple signed transaction payload', () => {
  assert.deepEqual(
    _test.decodeAppleSignedTransaction(signedPayload(validTransaction)),
    validTransaction,
  );
});

test('accepts a matching consumable transaction', () => {
  assert.doesNotThrow(() =>
    _test.assertAppleTransaction(
      { purchaseId: validTransaction.transactionId, productId: 'tokens_500' },
      { environment: 'Sandbox', transaction: validTransaction },
    ),
  );
});

test('rejects mismatched product, bundle, environment, and refunded purchases', () => {
  const body = {
    purchaseId: validTransaction.transactionId,
    productId: 'tokens_500',
  };
  for (const transaction of [
    { ...validTransaction, productId: 'tokens_1000' },
    { ...validTransaction, bundleId: 'com.example.falora' },
    { ...validTransaction, environment: 'Production' },
    { ...validTransaction, revocationDate: Date.now() },
  ]) {
    assert.throws(() =>
      _test.assertAppleTransaction(body, {
        environment: 'Sandbox',
        transaction,
      }),
    );
  }
});
