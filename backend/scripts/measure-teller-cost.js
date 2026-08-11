#!/usr/bin/env node
/**
 * Tek falcı/kategori için üretim retry yoluyla token ve kuruş maliyeti ölçer.
 * Kullanım: node scripts/measure-teller-cost.js gizem_ana "Kahve Falı"
 */
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const OpenAI = require('openai');
const {
  FORTUNE_TELLERS,
  buildFortuneSystemPrompt,
  buildFortuneUserPrompt,
  pickFortuneStructureForTeller,
} = require('../fortune_personas');
const lib = require('./compare-prompt-optimization-lib');

const TRY_PER_USD = Number(process.env.TRY_PER_USD || 47);
const INPUT_RATE = 0.15 / 1_000_000;
const OUTPUT_RATE = 0.6 / 1_000_000;
const MODEL = process.env.OPENAI_MODEL || 'gpt-4o-mini';

function kurus(usd) {
  return (usd * TRY_PER_USD * 100).toFixed(1);
}

function addUsage(total, usage) {
  if (!usage) return total;
  total.input +=
    usage.prompt_tokens ?? usage.input_tokens ?? 0;
  total.output +=
    usage.completion_tokens ?? usage.output_tokens ?? 0;
  return total;
}

async function call(openai, systemPrompt, userPrompt, maxTokens) {
  const response = await openai.chat.completions.create({
    model: MODEL,
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userPrompt },
    ],
    max_completion_tokens: maxTokens,
    temperature: 0.9,
    frequency_penalty: 0.55,
    presence_penalty: 0.3,
  });
  const text = response.choices?.[0]?.message?.content?.trim() || '';
  return { text, usage: response.usage };
}

async function generateWithUsage(openai, teller, structure, body) {
  const systemPrompt = buildFortuneSystemPrompt(teller, structure);
  const baseUserPrompt = buildFortuneUserPrompt(body, teller, structure);
  const usage = { input: 0, output: 0, calls: 0 };
  let lastWords = 0;
  let expanded = false;
  let attempt = 0;
  let result = '';

  for (let i = 1; i <= 3; i++) {
    attempt = i;
    let userPrompt = baseUserPrompt;
    if (i > 1) {
      if (lastWords < teller.minWords) {
        userPrompt = `${baseUserPrompt}

YETERSİZ UZUNLUK: Önceki yanıt ${lastWords} kelimeydi; minimum ${teller.minWords} kelime şart. Aynı fal verisi ve ${teller.name} sesiyle metni baştan, daha kapsamlı ve en az ${teller.minWords} kelime olacak şekilde yeniden yaz. Maksimum ${teller.maxWords} kelime.`;
      } else {
        userPrompt = `${baseUserPrompt}

FAZLA UZUN: Önceki yanıt ${lastWords} kelimeydi; maksimum ${teller.maxWords} kelime. Metni ${teller.minWords}-${teller.maxWords} aralığına sığdırarak yeniden yaz.`;
      }
    }

    const callResult = await call(
      openai,
      systemPrompt,
      userPrompt,
      teller.maxCompletionTokens,
    );
    addUsage(usage, callResult.usage);
    usage.calls += 1;
    result = callResult.text;
    let words = lib.countWords(result);
    lastWords = words;

    if (words < teller.minWords) {
      expanded = true;
      const needed = teller.minWords - words;
      const expandPrompt = `Sen ${teller.name} olarak yazıyorsun. Mevcut fal yorumu ${words} kelime; en az ${teller.minWords} kelime olmalı.
Aynı isim, niyet ve tonu koruyarak yoruma yaklaşık ${needed} kelimelik yoğun bir devam paragrafı ekle.
Yalnızca eksik tamamlayıcı kısmı yaz; mevcut metni baştan yazma.
Üst sınır: toplam ${teller.maxWords} kelimeyi aşma.

MEVCUT YORUM:
${result}`;
      const expandResult = await call(
        openai,
        systemPrompt,
        expandPrompt,
        lib.expansionTokenBudget(teller, needed),
      );
      addUsage(usage, expandResult.usage);
      usage.calls += 1;
      result = `${result.trim()}\n\n${expandResult.text.trim()}`.trim();
      words = lib.countWords(result);
      lastWords = words;
    }

    const inRange = words >= teller.minWords && words <= teller.maxWords;
    if (inRange || i === 3) {
      return { text: result, words, inRange, attempt, expanded, usage };
    }
  }

  return { text: result, words: lastWords, inRange: false, attempt, expanded, usage };
}

async function main() {
  const tellerId = process.argv[2] || 'gizem_ana';
  const category = process.argv[3] || 'Kahve Falı';
  const teller = FORTUNE_TELLERS[tellerId];
  if (!teller) {
    console.error('Geçersiz teller:', tellerId);
    process.exit(1);
  }
  if (!process.env.OPENAI_API_KEY) {
    console.error('OPENAI_API_KEY gerekli');
    process.exit(1);
  }

  const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  const structure = pickFortuneStructureForTeller(tellerId);
  const body = {
    requestId: `cost-${Date.now()}`,
    category,
    name: 'Elif',
    age: 29,
    zodiac: 'Yengeç',
    maritalStatus: 'Bekar',
    intention: 'İş hayatımda doğru adımı atıp atmayacağımı anlamak istiyorum.',
    imageNames: ['fincan1.jpg'],
  };
  const systemPrompt = buildFortuneSystemPrompt(teller, structure);
  const userPrompt = buildFortuneUserPrompt(body, teller, structure);

  console.log(`Model: ${MODEL}`);
  console.log(`Teller: ${teller.name} (${teller.minWords}-${teller.maxWords} kelime)`);
  console.log(`Kategori: ${category}`);
  console.log(
    `Prompt tahmini: system ~${lib.estimateTokens(systemPrompt)} | user ~${lib.estimateTokens(userPrompt)} tok`,
  );

  const result = await generateWithUsage(openai, teller, structure, body);
  const usd =
    result.usage.input * INPUT_RATE + result.usage.output * OUTPUT_RATE;
  const score = lib.scoreFortune(result.text, { ...body, tellerId });

  console.log('\n=== SONUÇ ===');
  console.log(
    `Kelime: ${result.words} (aralık=${result.inRange}, retry=${result.attempt}, expand=${result.expanded})`,
  );
  console.log(`Kalite skoru: ${score.qualityScore.toFixed(1)}`);
  console.log(
    `API çağrısı: ${result.usage.calls} | input=${result.usage.input} output=${result.usage.output}`,
  );
  console.log(`Maliyet: ${kurus(usd)} kr ($${usd.toFixed(6)})`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
