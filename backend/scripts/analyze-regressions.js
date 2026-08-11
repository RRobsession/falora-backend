#!/usr/bin/env node
/**
 * Belirgin gerileme gösteren vakaları ayrıntılı analiz eder.
 * Kullanım: node scripts/analyze-regressions.js
 */
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const OpenAI = require('openai');
const lib = require('./compare-prompt-optimization-lib');

const {
  buildTestCases,
  scoreFortune,
  generateFortune,
  legacyBuildSystemPrompt,
  legacyBuildUserPrompt,
  buildOptimizedUserPrompt,
  estimateTokens,
  FORTUNE_TELLERS,
  getCaseMeta,
} = lib;

const { buildFortuneSystemPrompt } = require('../fortune_personas');

const REGRESSION_CASES = ['case-1', 'case-4', 'case-8', 'case-10', 'case-30'];

function diffCriteria(legacy, newer) {
  const checks = [
    ['inRange', 'Kelime aralığı'],
    ['nameMentioned', 'İsim geçiyor'],
    ['intentionHits', 'Niyet kelimeleri (≥1)'],
    ['bannedOpening', 'Yasak açılış'],
    ['aiLeak', 'AI terimi'],
    ['completeEnding', 'Tamamlanmış bitiş'],
    ['cardCoverage', 'Kart kapsamı'],
    ['symbolCoverage', 'Sembol kapsamı'],
  ];
  const diffs = [];
  for (const [key, label] of checks) {
    const l = legacy[key];
    const n = newer[key];
    if (key === 'intentionHits') {
      if ((l >= 1) !== (n >= 1) || l !== n) diffs.push({ label, legacy: l, new: n });
    } else if (key === 'cardCoverage' || key === 'symbolCoverage') {
      if (Math.abs(l - n) > 0.01) diffs.push({ label, legacy: l, new: n });
    } else if (key === 'bannedOpening' || key === 'aiLeak') {
      if (l !== n) diffs.push({ label, legacy: l, new: n });
    } else if (Boolean(l) !== Boolean(n)) {
      diffs.push({ label, legacy: l, new: n });
    }
  }
  return diffs;
}

async function main() {
  if (!process.env.OPENAI_API_KEY) {
    console.error('OPENAI_API_KEY gerekli');
    process.exit(1);
  }

  const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  const allCases = buildTestCases(30);
  const targets = allCases.filter((c) => REGRESSION_CASES.includes(c.id));

  console.log('=== 5 GERİLEYEN ÖRNEK AYRINTILI ANALİZ ===\n');

  for (const testCase of targets) {
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

    const legacyResult = await generateFortune(openai, legacySystem, legacyUser, teller);
    const newResult = await generateFortune(openai, newSystem, newUser, teller);

    const bodyWithTeller = { ...testCase.body, tellerId: testCase.tellerId };
    const legacyScore = scoreFortune(legacyResult.text, bodyWithTeller);
    const newScore = scoreFortune(newResult.text, bodyWithTeller);
    const delta = newScore.qualityScore - legacyScore.qualityScore;
    const drops = diffCriteria(legacyScore, newScore);

    console.log(`--- ${testCase.id} ---`);
    console.log(`Kategori: ${meta.category}`);
    console.log(`Falcı: ${meta.tellerName}`);
    console.log(`Eski kalite skoru: ${legacyScore.qualityScore.toFixed(2)}`);
    console.log(`Yeni kalite skoru: ${newScore.qualityScore.toFixed(2)}`);
    console.log(`Skor farkı: ${delta >= 0 ? '+' : ''}${delta.toFixed(2)}`);
    console.log(`Eski kelime sayısı: ${legacyResult.words}`);
    console.log(`Yeni kelime sayısı: ${newResult.words}`);
    console.log(
      `Eski retry/expansion: attempt=${legacyResult.attempt}, expanded=${legacyResult.expanded}`,
    );
    console.log(
      `Yeni retry/expansion: attempt=${newResult.attempt}, expanded=${newResult.expanded}`,
    );
    console.log('Düşen kriterler:');
    if (drops.length === 0) console.log('  (belirgin tek kriter düşüşü yok)');
    for (const d of drops) {
      console.log(`  - ${d.label}: ${d.legacy} → ${d.new}`);
    }
    console.log(`Kişiselleştirme: eski=${legacyScore.personalization}/4 yeni=${newScore.personalization}/4`);
    console.log('');
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
