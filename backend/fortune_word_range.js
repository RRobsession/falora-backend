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
  return Math.round((teller.minWords + teller.maxWords) / 2);
}

function firstPassCompletionTokens(teller) {
  const target = targetWordCount(teller);
  const estimate = Math.ceil(target * 1.5);
  const floor = Math.ceil(teller.minWords * 1.4);
  const ceiling = Math.ceil(teller.maxWords * 1.45);
  return Math.min(
    Math.max(estimate, floor),
    ceiling,
    teller.maxCompletionTokens,
  );
}

function buildFirstPassLengthBlock(teller) {
  const target = targetWordCount(teller);
  return `KELİME ARALIĞI — İLK YANITTA ZORUNLU:
- ${teller.minWords}-${teller.maxWords} kelime; hedef ~${target}.
- İlk metninde aralığa otur; eksik veya fazla yazma.
- Yoğunluk ve kaliteyi koruyarak bu banda sığdır.`;
}

function buildFinalLengthInstruction(teller) {
  const target = targetWordCount(teller);
  return `SON TALİMAT: Yanıtın tam ${teller.minWords}-${teller.maxWords} kelime olsun (hedef ~${target}). ${teller.minWords} kelimeden az, ${teller.maxWords} kelimeden fazla yazma.`;
}

module.exports = {
  countWords,
  trimToMaxWords,
  expansionTokenBudget,
  buildExpandPrompt,
  isInWordRange,
  targetWordCount,
  firstPassCompletionTokens,
  buildFirstPassLengthBlock,
  buildFinalLengthInstruction,
};
