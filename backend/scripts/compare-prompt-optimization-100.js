#!/usr/bin/env node
/**
 * 100+ örnek dengeli prompt karşılaştırması.
 * Kullanım: node scripts/compare-prompt-optimization-100.js
 */
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const OpenAI = require('openai');
const { buildFortuneSystemPrompt } = require('../fortune_personas');
const lib = require('./compare-prompt-optimization-lib');

const {
  MODEL,
  FORTUNE_TELLERS,
  buildTestCases,
  getCaseMeta,
  scoreFortune,
  generateFortune,
  legacyBuildSystemPrompt,
  legacyBuildUserPrompt,
  buildOptimizedUserPrompt,
  estimateTokens,
  CATEGORY_DEFS,
  TELLER_IDS,
} = lib;

const SAMPLE_COUNT = Number(process.env.SAMPLE_COUNT || 105);

async function main() {
  const cases = buildTestCases(SAMPLE_COUNT, true);
  const tokenStats = { legacy: [], optimized: [] };
  const rows = [];

  for (const testCase of cases) {
    const teller = FORTUNE_TELLERS[testCase.tellerId];
    const opts = {
      requestId: testCase.body.requestId,
      kahveHints: testCase.kahveHints,
    };
    const legacySystem = legacyBuildSystemPrompt(teller, testCase.structure);
    const legacyUser = legacyBuildUserPrompt(testCase.body, teller, testCase.structure, opts);
    const newSystem = buildFortuneSystemPrompt(teller, testCase.structure);
    const newUser = buildOptimizedUserPrompt(testCase.body, teller, testCase.structure, opts);
    tokenStats.legacy.push(estimateTokens(legacySystem) + estimateTokens(legacyUser));
    tokenStats.optimized.push(estimateTokens(newSystem) + estimateTokens(newUser));
  }

  const avg = (arr) => arr.reduce((a, b) => a + b, 0) / arr.length;
  const legacyTokenAvg = avg(tokenStats.legacy);
  const newTokenAvg = avg(tokenStats.optimized);
  const tokenSavingPct = ((legacyTokenAvg - newTokenAvg) / legacyTokenAvg) * 100;

  console.log('=== TOKEN TAHMİNİ ===');
  console.log(`Örnek sayısı: ${SAMPLE_COUNT}`);
  console.log(`Eski ortalama input: ${Math.round(legacyTokenAvg)}`);
  console.log(`Yeni ortalama input: ${Math.round(newTokenAvg)}`);
  console.log(`Tasarruf: %${tokenSavingPct.toFixed(1)}`);

  if (!process.env.OPENAI_API_KEY) {
    console.error('OPENAI_API_KEY gerekli');
    process.exit(1);
  }

  const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  console.log(`\n=== ${SAMPLE_COUNT} ÖRNEK ÜRETİM (${MODEL}) ===\n`);

  for (let i = 0; i < cases.length; i++) {
    const testCase = cases[i];
    const teller = FORTUNE_TELLERS[testCase.tellerId];
    const meta = getCaseMeta(testCase);
    const opts = {
      requestId: testCase.body.requestId,
      kahveHints: testCase.kahveHints,
    };
    const legacySystem = legacyBuildSystemPrompt(teller, testCase.structure);
    const legacyUser = legacyBuildUserPrompt(testCase.body, teller, testCase.structure, opts);
    const newSystem = buildFortuneSystemPrompt(teller, testCase.structure);
    const newUser = buildOptimizedUserPrompt(testCase.body, teller, testCase.structure, opts);

    process.stdout.write(`[${i + 1}/${cases.length}] ${meta.category} / ${meta.tellerName}… `);
    const legacyResult = await generateFortune(openai, legacySystem, legacyUser, teller);
    const newResult = await generateFortune(openai, newSystem, newUser, teller);
    const body = { ...testCase.body, tellerId: testCase.tellerId };
    const legacyScore = scoreFortune(legacyResult.text, body);
    const newScore = scoreFortune(newResult.text, body);
    const delta = newScore.qualityScore - legacyScore.qualityScore;
    const regression = delta < -0.5;

    rows.push({
      id: testCase.id,
      category: meta.category,
      teller: meta.tellerName,
      legacyScore: legacyScore.qualityScore,
      newScore: newScore.qualityScore,
      delta,
      regression,
      legacyWords: legacyResult.words,
      newWords: newResult.words,
      legacyInRange: legacyScore.inRange,
      newInRange: newScore.inRange,
      legacyRetry: legacyResult.attempt,
      newRetry: newResult.attempt,
      legacyExpanded: legacyResult.expanded,
      newExpanded: newResult.expanded,
      nameOk: newScore.nameMentioned,
      intentionHits: newScore.intentionHits,
      bannedOpening: newScore.bannedOpening,
      personalization: newScore.personalization,
    });

    console.log(
      `L=${legacyScore.qualityScore.toFixed(1)} N=${newScore.qualityScore.toFixed(1)} Δ${delta >= 0 ? '+' : ''}${delta.toFixed(1)}`,
    );
  }

  const avgScore = (key) => rows.reduce((a, r) => a + r[key], 0) / rows.length;
  const legacyQuality = avgScore('legacyScore');
  const newQuality = avgScore('newScore');
  const regressions = rows.filter((r) => r.regression);
  const newInRangeCount = rows.filter((r) => r.newInRange).length;
  const bannedCount = rows.filter((r) => r.bannedOpening).length;
  const nameOkCount = rows.filter((r) => r.nameOk).length;
  const intentionOkCount = rows.filter((r) => r.intentionHits >= 1).length;
  const personalizationOk = rows.filter((r) => r.personalization >= 3).length;

  const distribution = {};
  for (const cat of CATEGORY_DEFS) {
    for (const tellerId of TELLER_IDS) {
      const key = `${cat.category} / ${FORTUNE_TELLERS[tellerId].name}`;
      distribution[key] = rows.filter(
        (r) => r.category === cat.category && r.teller === FORTUNE_TELLERS[tellerId].name,
      ).length;
    }
  }

  console.log('\n=== DAĞILIM (kategori × falcı) ===');
  for (const [k, v] of Object.entries(distribution)) console.log(`${k}: ${v}`);

  console.log('\n=== KRİTER TABLOSU ===');
  console.log('| Kriter | Hedef | Sonuç | Durum |');
  console.log('|--------|-------|-------|-------|');
  const qDelta = legacyQuality - newQuality;
  console.log(
    `| Ort. kalite farkı | ≤0,10 | ${qDelta.toFixed(2)} | ${qDelta <= 0.1 ? '✅' : '❌'} |`,
  );
  const regPct = (regressions.length / rows.length) * 100;
  console.log(
    `| Belirgin gerileme | ≤%5 | %${regPct.toFixed(1)} (${regressions.length}/${rows.length}) | ${regPct <= 5 ? '✅' : '❌'} |`,
  );
  const inRangePct = (newInRangeCount / rows.length) * 100;
  console.log(
    `| Kelime aralığı | ≥%98 | %${inRangePct.toFixed(1)} (${newInRangeCount}/${rows.length}) | ${inRangePct >= 98 ? '✅' : '❌'} |`,
  );
  console.log(
    `| Yasak açılış | 0 | ${bannedCount} | ${bannedCount === 0 ? '✅' : '❌'} |`,
  );
  console.log(
    `| İsim geçiyor | yüksek | ${nameOkCount}/${rows.length} | ${nameOkCount === rows.length ? '✅' : '⚠️'} |`,
  );
  console.log(
    `| Niyet kelimesi (≥1) | yüksek | ${intentionOkCount}/${rows.length} | ${intentionOkCount / rows.length >= 0.95 ? '✅' : '⚠️'} |`,
  );
  console.log(
    `| Kişiselleştirme (≥3/4) | yüksek | ${personalizationOk}/${rows.length} | ${personalizationOk / rows.length >= 0.95 ? '✅' : '⚠️'} |`,
  );
  console.log(
    `| Input token tasarrufu | ≥%20 | %${tokenSavingPct.toFixed(1)} | ${tokenSavingPct >= 20 ? '✅' : '❌'} |`,
  );

  if (regressions.length > 0) {
    console.log('\n=== GERİLEYEN ÖRNEKLER ===');
    console.log('| Örnek | Kategori | Falcı | Eski | Yeni | Δ | Eski kelime | Yeni kelime | Retry (E/N) | Expansion (E/N) |');
    console.log('|-------|----------|-------|------|------|---|-------------|-------------|-------------|-----------------|');
    for (const r of regressions) {
      console.log(
        `| ${r.id} | ${r.category} | ${r.teller} | ${r.legacyScore.toFixed(1)} | ${r.newScore.toFixed(1)} | ${r.delta.toFixed(1)} | ${r.legacyWords} | ${r.newWords} | ${r.legacyRetry}/${r.newRetry} | ${r.legacyExpanded}/${r.newExpanded} |`,
      );
    }
  }

  const passed =
    qDelta <= 0.1 &&
    regPct <= 5 &&
    inRangePct >= 98 &&
    bannedCount === 0 &&
    tokenSavingPct >= 20;

  console.log(passed ? '\n✅ Tüm kriterler sağlandı.' : '\n❌ Bazı kriterler sağlanmadı.');
  process.exit(passed ? 0 : 1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
