#!/usr/bin/env node
/**
 * Üç falcı için örnek yorum üretir ve kelime sayısını doğrular.
 * Kullanım: node scripts/verify-teller-word-ranges.js
 */
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const OpenAI = require('openai');
const {
  FORTUNE_TELLERS,
  pickFortuneStructure,
  pickFortuneStructureForTeller,
  buildFortuneSystemPrompt,
  buildFortuneUserPrompt,
} = require('../fortune_personas');

const MODEL = process.env.OPENAI_MODEL || 'gpt-4o-mini';

const SAMPLE_BODY = {
  category: 'Kahve Falı',
  name: 'Elif',
  age: 29,
  zodiac: 'Yengeç',
  maritalStatus: 'Bekar',
  intention: 'Yeni bir ilişki için kalbimde umut var ama geçmişten korkuyorum.',
  imageNames: ['fincan1.jpg'],
  requestId: `verify-${Date.now()}`,
};

function countWords(text) {
  return String(text || '')
    .trim()
    .split(/\s+/)
    .filter(Boolean).length;
}

function expansionTokenBudget(teller, needed) {
  const estimate = Math.ceil(needed * 2.8);
  return Math.min(Math.max(estimate, 120), 360, teller.maxCompletionTokens);
}

async function generateForTeller(openai, tellerId) {
  const teller = FORTUNE_TELLERS[tellerId];
  const structure = pickFortuneStructureForTeller(tellerId);
  const systemPrompt = buildFortuneSystemPrompt(teller, structure);
  const baseUserPrompt = buildFortuneUserPrompt(SAMPLE_BODY, teller, structure);
  let lastWords = 0;

  for (let attempt = 1; attempt <= 3; attempt++) {
    let userPrompt = baseUserPrompt;
    if (attempt > 1) {
      if (lastWords < teller.minWords) {
        userPrompt = `${baseUserPrompt}

YETERSİZ UZUNLUK: Önceki yanıt ${lastWords} kelimeydi; minimum ${teller.minWords} kelime şart. Aynı fal verisi ve ${teller.name} sesiyle metni baştan, daha kapsamlı ve en az ${teller.minWords} kelime olacak şekilde yeniden yaz. Maksimum ${teller.maxWords} kelime.`;
      } else {
        userPrompt = `${baseUserPrompt}

FAZLA UZUN: Önceki yanıt ${lastWords} kelimeydi; maksimum ${teller.maxWords} kelime. Metni ${teller.minWords}-${teller.maxWords} aralığına sığdırarak yeniden yaz.`;
      }
    }

    const response = await openai.chat.completions.create({
      model: MODEL,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt },
      ],
      max_completion_tokens: teller.maxCompletionTokens,
      temperature: 0.9,
      frequency_penalty: 0.55,
      presence_penalty: 0.3,
    });

    let text = response.choices?.[0]?.message?.content?.trim() || '';
    let words = countWords(text);
    let totalCompletionTokens = response.usage?.completion_tokens ?? null;

    if (words < teller.minWords) {
      const needed = teller.minWords - words;
      const expandResponse = await openai.chat.completions.create({
        model: MODEL,
        messages: [
          { role: 'system', content: systemPrompt },
          {
            role: 'user',
            content: `Sen ${teller.name} olarak yazıyorsun. Mevcut fal yorumu ${words} kelime; en az ${teller.minWords} kelime olmalı.
Aynı isim, niyet ve tonu koruyarak yoruma yaklaşık ${needed} kelimelik yoğun bir devam paragrafı ekle.
Yalnızca eksik tamamlayıcı kısmı yaz; mevcut metni baştan yazma.
Üst sınır: toplam ${teller.maxWords} kelimeyi aşma.

MEVCUT YORUM:
${text}`,
          },
        ],
        max_completion_tokens: expansionTokenBudget(teller, needed),
        temperature: 0.9,
        frequency_penalty: 0.55,
        presence_penalty: 0.3,
      });
      const addition =
        expandResponse.choices?.[0]?.message?.content?.trim() || '';
      text = `${text.trim()}\n\n${addition.trim()}`.trim();
      words = countWords(text);
      totalCompletionTokens =
        (totalCompletionTokens ?? 0) +
        (expandResponse.usage?.completion_tokens ?? 0);
    }

    lastWords = words;
    const inRange = words >= teller.minWords && words <= teller.maxWords;
    if (inRange || attempt === 3) {
      return {
        tellerId,
        name: teller.name,
        minWords: teller.minWords,
        maxWords: teller.maxWords,
        maxCompletionTokens: teller.maxCompletionTokens,
        wordCount: words,
        inRange,
        attempt,
        completionTokens: totalCompletionTokens,
        preview: text.slice(0, 220) + (text.length > 220 ? '…' : ''),
        text,
      };
    }
  }
}

async function main() {
  if (!process.env.OPENAI_API_KEY) {
    console.error('OPENAI_API_KEY eksik — .env dosyasını kontrol edin.');
    process.exit(1);
  }

  const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  const tellerIds = ['gizem_ana', 'medyum_aylin', 'ustat_hakan'];
  const results = [];

  for (const tellerId of tellerIds) {
    console.log(`\nÜretiliyor: ${tellerId}…`);
    const result = await generateForTeller(openai, tellerId);
    results.push(result);
    console.log(
      JSON.stringify(
        {
          teller: result.name,
          words: result.wordCount,
          range: `${result.minWords}-${result.maxWords}`,
          ok: result.inRange,
          completionTokens: result.completionTokens,
          maxCompletionTokens: result.maxCompletionTokens,
        },
        null,
        2,
      ),
    );
  }

  const failed = results.filter((r) => !r.inRange);
  console.log('\n--- ÖZET ---');
  for (const r of results) {
    console.log(
      `${r.inRange ? 'OK' : 'FAIL'} | ${r.name}: ${r.wordCount} kelime (hedef ${r.minWords}-${r.maxWords}) | completion_tokens=${r.completionTokens}`,
    );
  }

  if (failed.length > 0) {
    console.error(`\n${failed.length} sonuç hedef aralığın dışında.`);
    process.exit(1);
  }

  console.log('\nTüm sonuçlar hedef aralıkta.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
