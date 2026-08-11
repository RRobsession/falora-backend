function countWords(text) {
  return String(text || '')
    .trim()
    .split(/\s+/)
    .filter(Boolean).length;
}

function splitSentences(text) {
  const t = String(text || '').trim();
  if (!t) return [];
  const parts = t.match(/[^.!?…]+[.!?…]+|[^.!?…]+$/g);
  return parts ? parts.map((s) => s.trim()).filter(Boolean) : [t];
}

function trimToMaxWords(text, maxWords) {
  const trimmed = String(text || '').trim();
  if (countWords(trimmed) <= maxWords) return trimmed;

  const sentences = splitSentences(trimmed);
  let built = '';
  for (const sentence of sentences) {
    const candidate = built ? `${built} ${sentence}` : sentence;
    if (countWords(candidate) > maxWords) break;
    built = candidate;
  }
  if (built && countWords(built) >= Math.max(1, maxWords - 25)) {
    return built.trim();
  }

  const words = trimmed.split(/\s+/).filter(Boolean);
  let slice = words.slice(0, maxWords).join(' ');
  const lastEnd = Math.max(
    slice.lastIndexOf('.'),
    slice.lastIndexOf('!'),
    slice.lastIndexOf('?'),
    slice.lastIndexOf('…'),
  );
  if (lastEnd > slice.length * 0.55) {
    slice = slice.slice(0, lastEnd + 1);
  }
  return slice.trim();
}

function getPromptWordRange(teller) {
  return {
    min: teller.promptMinWords ?? teller.minWords,
    max: teller.promptMaxWords ?? teller.maxWords,
  };
}

function hasProductionWordTarget(teller) {
  return teller.promptMinWords != null || teller.promptMaxWords != null;
}

function expansionTokenBudget(teller, needed) {
  const estimate = Math.ceil(needed * 2.8);
  return Math.min(Math.max(estimate, 120), 360, teller.maxCompletionTokens);
}

function buildExpandPrompt(teller, result, words) {
  const needed = teller.minWords - words;
  return `Sen ${teller.name} olarak yazıyorsun. Mevcut fal yorumu ${words} kelime; en az ${teller.minWords} kelime olmalı.
Aynı isim, niyet ve tonu koruyarak yoruma yaklaşık ${needed} kelimelik yoğun bir devam paragrafı ekle.
Yalnızca eksik tamamlayıcı kısmı yaz; mevcut metni baştan yazma.
Üst sınır: toplam ${teller.maxWords} kelimeyi aşma.

MEVCUT YORUM:
${result}`;
}

function isInWordRange(words, teller) {
  return words >= teller.minWords && words <= teller.maxWords;
}

function targetWordCount(teller) {
  const prompt = getPromptWordRange(teller);
  return Math.round((prompt.min + prompt.max) / 2);
}

function firstPassCompletionTokens(teller) {
  if (hasProductionWordTarget(teller)) {
    return teller.maxCompletionTokens;
  }
  const prompt = getPromptWordRange(teller);
  const target = targetWordCount(teller);
  const estimate = Math.ceil(target * 1.52);
  const floor = Math.ceil(teller.minWords * 1.45);
  const ceiling = Math.ceil(prompt.max * 1.42);
  return Math.min(
    Math.max(estimate, floor),
    ceiling,
    teller.maxCompletionTokens,
  );
}

function firstPassMinCompletionTokens(teller) {
  return null;
}

function buildGizemFirstPassLead(teller) {
  if (teller.id !== 'gizem_ana') return null;
  const prompt = getPromptWordRange(teller);
  return `ÖNCELİK: Yanıtın EN AZ ${teller.minWords} kelime olacak; hedef ${prompt.min}-${prompt.max} kelime. ${teller.minWords} kelimenin altı kabul edilmez.`;
}

function buildFirstPassRetryPrompt(baseUserPrompt, teller, words, pass = 2) {
  const prompt = getPromptWordRange(teller);
  const floor =
    hasProductionWordTarget(teller) && pass >= 3
      ? prompt.min
      : teller.minWords;
  const targetHint = hasProductionWordTarget(teller)
    ? `; hedef ${prompt.min}-${prompt.max} kelime`
    : '';
  return `${baseUserPrompt}

KABUL EDİLMEZ (${pass}. deneme): Yanıtın yalnızca ${words} kelimeydi.
Bu sefer EN AZ ${floor} kelime yaz${targetHint}. Daha kısa yanıt sistem tarafından reddedilir. Metni baştan yaz.`;
}

function buildFirstPassLengthBlock(teller) {
  const prompt = getPromptWordRange(teller);
  const target = targetWordCount(teller);

  if (hasProductionWordTarget(teller)) {
    return `KELİME ARALIĞI — İLK YANITTA ZORUNLU:
- ASLA ${teller.minWords} kelimenin altına inme; daha kısa yanıt red edilir.
- Üretim hedefi: ${prompt.min}-${prompt.max} kelime; ilk yanıtta buna otur.
- Kabul edilen aralık: ${teller.minWords}-${teller.maxWords} kelime.
- ${teller.minWords} kelimenin altındaki cevap kabul edilemez.
- ${teller.maxWords} kelimenin üstüne çıkma.`;
  }

  return `KELİME ARALIĞI — İLK YANITTA ZORUNLU:
- ${teller.minWords}-${teller.maxWords} kelime; hedef ~${target}.
- İlk metninde aralığa otur; eksik veya fazla yazma.
- Yoğunluk ve kaliteyi koruyarak bu banda sığdır.`;
}

function buildFinalLengthInstruction(teller) {
  const prompt = getPromptWordRange(teller);
  const target = targetWordCount(teller);

  if (hasProductionWordTarget(teller)) {
    return `SON TALİMAT — ZORUNLU: En az ${teller.minWords} kelime yaz; hedef ${prompt.min}-${prompt.max} kelime (kabul aralığı ${teller.minWords}-${teller.maxWords}). ${teller.minWords} kelimenin altındaki cevap kabul edilemez. ${teller.maxWords} kelimeden fazla yazma.`;
  }

  return `SON TALİMAT: Yanıtın tam ${teller.minWords}-${teller.maxWords} kelime olsun (hedef ~${target}). ${teller.minWords} kelimeden az, ${teller.maxWords} kelimeden fazla yazma.`;
}

module.exports = {
  countWords,
  trimToMaxWords,
  getPromptWordRange,
  expansionTokenBudget,
  buildExpandPrompt,
  isInWordRange,
  targetWordCount,
  firstPassCompletionTokens,
  firstPassMinCompletionTokens,
  hasProductionWordTarget,
  buildGizemFirstPassLead,
  buildFirstPassRetryPrompt,
  buildFirstPassLengthBlock,
  buildFinalLengthInstruction,
};
