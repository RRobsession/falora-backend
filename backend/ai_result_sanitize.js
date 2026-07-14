/**
 * AI yanıtlarındaki model özel token'larını temizler.
 */
function sanitizeAiResult(text) {
  if (typeof text !== 'string') return '';
  return ensureCompleteSentenceEnding(
    text
      .replace(/<\|endoftext\|>/gi, '')
      .replace(/<\|end\|>/gi, '')
      .replace(/<\|im_end\|>/gi, '')
      .trim(),
  );
}

/**
 * Model çıktısı token limitinde kesildiyse son tam cümleye kırpar.
 */
function ensureCompleteSentenceEnding(text) {
  const trimmed = String(text || '').trim();
  if (!trimmed) return trimmed;
  if (/[.!?…]["')\]]*\s*$/.test(trimmed)) return trimmed;

  const sentences = trimmed.match(/[^.!?…]+[.!?…]+["')\]]*|[^.!?…]+$/g);
  if (!sentences || sentences.length < 2) return `${trimmed}.`;

  let built = '';
  for (const sentence of sentences) {
    const candidate = built ? `${built} ${sentence.trim()}` : sentence.trim();
    if (!/[.!?…]["')\]]*\s*$/.test(candidate)) continue;
    built = candidate;
  }

  if (built && built.length >= Math.max(60, trimmed.length * 0.35)) {
    return built.trim();
  }

  return `${trimmed}.`;
}

module.exports = { sanitizeAiResult, ensureCompleteSentenceEnding };
