#!/usr/bin/env node
/**
 * Gizem Ana için 200 örnek üretir; first-pass ve expansion oranlarını raporlar.
 * Kullanım: node scripts/measure-gizem-expansion-rate.js
 */
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const OpenAI = require('openai');
const { buildFortuneSystemPrompt, buildFortuneUserPrompt, pickFortuneStructureForTeller } = require('../fortune_personas');
const lib = require('./compare-prompt-optimization-lib');

const SAMPLE_COUNT = Number(process.env.SAMPLE_COUNT || 200);
const NAMES = [
  'Elif', 'Can', 'Zeynep', 'Murat', 'Selin', 'Emre',
  'Ayşe', 'Burak', 'Deniz', 'Mira', 'Koray', 'Aslı',
];

function buildGizemCases(count) {
  const cases = [];
  for (let i = 0; i < count; i++) {
    const cat = lib.CATEGORY_DEFS[i % lib.CATEGORY_DEFS.length];
    cases.push({
      id: `gizem-${i + 1}`,
      tellerId: 'gizem_ana',
      body: {
        category: cat.category,
        name: NAMES[i % NAMES.length],
        age: 24 + (i % 15),
        zodiac: ['Yengeç', 'Koç', 'Terazi', 'Akrep', 'Aslan', 'Kova', 'Balık', 'Boğa'][i % 8],
        maritalStatus: i % 2 === 0 ? 'Bekar' : 'Evli',
        intention: [
          'Yeni bir ilişki için kalbimde umut var ama geçmişten korkuyorum.',
          'İş değişikliği yapmalı mıyım, içimde belirsizlik var.',
          'Aile içi huzuru yeniden kurmak istiyorum.',
          'Maddi sıkıntılarımın ne zaman hafifleyeceğini merak ediyorum.',
          'Eski sevgilimle barışma ihtimali aklımı kurcalıyor.',
          'Kendime güvenimi yeniden bulmak istiyorum.',
          'Yakınlarımdan birinin sağlığı beni endişelendiriyor.',
          'Taşınma kararı vermek üzereyim, doğru zaman mı?',
        ][i % 8],
        requestId: `gizem-exp-${i + 1}`,
        ...cat.extras,
      },
    });
  }
  return cases;
}

async function main() {
  if (!process.env.OPENAI_API_KEY) {
    console.error('OPENAI_API_KEY gerekli');
    process.exit(1);
  }

  const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  const teller = lib.FORTUNE_TELLERS.gizem_ana;
  const cases = buildGizemCases(SAMPLE_COUNT);

  let firstApiMeetsMin = 0;
  let firstPassMeetsMin = 0;
  let firstPassInRange = 0;
  let expandedCount = 0;
  let retriedCount = 0;
  let finalInRange = 0;

  console.log(`Model: ${lib.MODEL}`);
  console.log(`Falcı: ${teller.name} | kabul: ${teller.minWords}-${teller.maxWords} | hedef: ${teller.promptMinWords}-${teller.promptMaxWords}`);
  console.log(`Örnek sayısı: ${SAMPLE_COUNT}\n`);

  for (let i = 0; i < cases.length; i++) {
    const testCase = cases[i];
    const structure = pickFortuneStructureForTeller('gizem_ana');
    const systemPrompt = buildFortuneSystemPrompt(teller, structure);
    const userPrompt = buildFortuneUserPrompt(testCase.body, teller, structure);

    process.stdout.write(`[${i + 1}/${cases.length}] ${testCase.body.category}… `);
    const result = await lib.generateFortune(openai, systemPrompt, userPrompt, teller);

    if (result.firstApiMeetsMin) firstApiMeetsMin += 1;
    if (result.firstPassMeetsMin) firstPassMeetsMin += 1;
    if (result.firstPassInRange) firstPassInRange += 1;
    if (result.expanded) expandedCount += 1;
    if (result.retried) retriedCount += 1;
    if (result.inRange) finalInRange += 1;

    console.log(
      `1stApi=${result.firstApiWords} 1stPass=${result.firstPassWords} minOk=${result.firstPassMeetsMin} expand=${result.expanded} final=${result.words}`,
    );
  }

  const pct = (n) => ((n / SAMPLE_COUNT) * 100).toFixed(1);

  console.log('\n=== ÖZET ===');
  console.log(`İlk API çağrısı ≥${teller.minWords} kelime: ${firstApiMeetsMin}/${SAMPLE_COUNT} (%${pct(firstApiMeetsMin)})`);
  console.log(`İlk geçiş (expansion öncesi) ≥${teller.minWords} kelime: ${firstPassMeetsMin}/${SAMPLE_COUNT} (%${pct(firstPassMeetsMin)})`);
  console.log(`İlk yanıt kabul aralığında (${teller.minWords}-${teller.maxWords}): ${firstPassInRange}/${SAMPLE_COUNT} (%${pct(firstPassInRange)})`);
  console.log(`Expansion çalıştı: ${expandedCount}/${SAMPLE_COUNT} (%${pct(expandedCount)})`);
  console.log(`Retry çalıştı: ${retriedCount}/${SAMPLE_COUNT} (%${pct(retriedCount)})`);
  console.log(`Final kabul aralığında: ${finalInRange}/${SAMPLE_COUNT} (%${pct(finalInRange)})`);

  const targetMet = firstPassMeetsMin / SAMPLE_COUNT >= 0.98;
  console.log(`\nHedef (ilk geçiş ≥${teller.minWords} ≥%98): ${targetMet ? '✅' : '❌'}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
