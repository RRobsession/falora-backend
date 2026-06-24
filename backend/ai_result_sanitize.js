/**
 * AI yanıtlarındaki model özel token'larını temizler.
 */
function sanitizeAiResult(text) {
  if (typeof text !== 'string') return '';
  return text
    .replace(/<\|endoftext\|>/gi, '')
    .replace(/<\|end\|>/gi, '')
    .replace(/<\|im_end\|>/gi, '')
    .trim();
}

module.exports = { sanitizeAiResult };
