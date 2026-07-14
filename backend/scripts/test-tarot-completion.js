#!/usr/bin/env node
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const OpenAI = require('openai');
const {
  FORTUNE_TELLERS,
  buildFortuneSystemPrompt,
  buildFortuneUserPrompt,
  pickFortuneStructureForTeller,
} = require('../fortune_personas');
const { countWords } = require('../fortune_word_range');
const { sanitizeAiResult } = require('../ai_result_sanitize');

const TAROT_CARDS = [
  { id: 'm00', positionIndex: 1, isReversed: false },
  { id: 'm06', positionIndex: 2, isReversed: true },
  { id: 'c03', positionIndex: 3, isReversed: false },
  { id: 'w07', positionIndex: 4, isReversed: false },
  { id: 's10', positionIndex: 5, isReversed: true },
  { id: 'p02', positionIndex: 6, isReversed: false },
  { id: 'm13', positionIndex: 7, isReversed: false },
  { id: 'm17', positionIndex: 8, isReversed: true },
];

const EXPECTED = [
  'Deli',
  'Aşıklar',
  'Üç Kupa',
  'Yedi Kupa',
  'On Kılıç',
  'İki Tılsım',
  'Ölüm',
  'Yıldız',
];

function resolveFortuneCompletionTokens(teller, body) {
  let tokens = teller.maxCompletionTokens;
  if (body?.category === 'Tarot Falı') {
    if (teller.id === 'gizem_ana') tokens = Math.max(tokens, 780);
    else if (teller.id === 'medyum_aylin') tokens = Math.max(tokens, 820);
    else tokens = Math.max(tokens, 900);
  }
  return tokens;
}

function endsComplete(text) {
  return /[.!?…]["')\]]*\s*$/.test(String(text || '').trim());
}

function cardHits(text, names) {
  const lower = text.toLowerCase();
  return names.map((name) => ({
    name,
    hit: lower.includes(name.toLowerCase()),
  }));
}

async function main() {
  const MODEL = process.env.OPENAI_MODEL || 'gpt-4o-mini';
  const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

  for (const tellerId of ['gizem_ana', 'medyum_aylin']) {
    const teller = FORTUNE_TELLERS[tellerId];
    const structure = pickFortuneStructureForTeller(tellerId);
    const body = {
      category: 'Tarot Falı',
      name: 'Elif',
      age: 28,
      zodiac: 'Yengeç',
      maritalStatus: 'Bekar',
      intention: 'Aşk hayatımda doğru yönde miyim?',
      selectedCards: TAROT_CARDS,
      requestId: `test-tarot-${tellerId}`,
    };
    const maxTokens = resolveFortuneCompletionTokens(teller, body);
    const res = await openai.chat.completions.create({
      model: MODEL,
      temperature: 0.9,
      max_completion_tokens: maxTokens,
      frequency_penalty: 0.55,
      presence_penalty: 0.3,
      messages: [
        { role: 'system', content: buildFortuneSystemPrompt(teller, structure) },
        { role: 'user', content: buildFortuneUserPrompt(body, teller, structure) },
      ],
    });
    const raw = res.choices?.[0]?.message?.content?.trim() || '';
    const text = sanitizeAiResult(raw);
    const out = res.usage?.completion_tokens ?? 0;
    const hits = cardHits(text, EXPECTED);
    const hitCount = hits.filter((h) => h.hit).length;
    console.log(`=== ${teller.name} ===`);
    console.log(`max_completion_tokens: ${maxTokens} | output_tokens: ${out}`);
    console.log(
      `Kelime: ${countWords(text)} | Tam bitiş: ${endsComplete(text) ? 'EVET' : 'HAYIR'}`,
    );
    console.log(`Kart kapsamı: ${hitCount}/8`);
    const missed = hits.filter((h) => !h.hit).map((h) => h.name);
    if (missed.length) console.log(`Eksik kartlar: ${missed.join(', ')}`);
    console.log(`Son 100 karakter: ${text.slice(-100)}`);
    console.log('');
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
