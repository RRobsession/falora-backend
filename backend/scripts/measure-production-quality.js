#!/usr/bin/env node
/**
 * Üretim prompt + retry ile kalite skoru ölçer (yalnızca optimize prompt çıktısı).
 * Kullanım: node scripts/measure-production-quality.js
 */
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const OpenAI = require('openai');
const { buildFortuneSystemPrompt } = require('../fortune_personas');
const lib = require('./compare-prompt-optimization-lib');

const SAMPLE_COUNT = Number(process.env.SAMPLE_COUNT || 10);

async function main() {
  if (!process.env.OPENAI_API_KEY) {
    console.error('OPENAI_API_KEY gerekli');
    process.exit(1);
  }

  const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  const cases = lib.buildTestCases(SAMPLE_COUNT, true);
  const scores = [];
  let inRange = 0;
  let totalInput = 0;
  let totalOutput = 0;
  let apiCalls = 0;

  for (let i = 0; i < cases.length; i++) {
    const testCase = cases[i];
    const teller = lib.FORTUNE_TELLERS[testCase.tellerId];
    const opts = {
      requestId: testCase.body.requestId,
      kahveHints: testCase.kahveHints,
    };
    const systemPrompt = buildFortuneSystemPrompt(teller, testCase.structure);
    const userPrompt = lib.buildOptimizedUserPrompt(
      testCase.body,
      teller,
      testCase.structure,
      opts,
    );

    process.stdout.write(`[${i + 1}/${cases.length}] ${testCase.body.category} / ${teller.name}… `);
    const result = await lib.generateFortune(openai, systemPrompt, userPrompt, teller);
    const score = lib.scoreFortune(result.text, {
      ...testCase.body,
      tellerId: testCase.tellerId,
    });
    scores.push(score.qualityScore);
    if (score.inRange) inRange += 1;
    console.log(
      `skor=${score.qualityScore.toFixed(1)} kelime=${result.words} retry=${result.attempt} expand=${result.expanded}`,
    );
  }

  const avg = scores.reduce((a, b) => a + b, 0) / scores.length;
  console.log('\n=== ÖZET ===');
  console.log(`Ortalama kalite skoru: ${avg.toFixed(2)}`);
  console.log(`Kelime aralığında: ${inRange}/${cases.length}`);
  console.log(`Min/Max skor: ${Math.min(...scores).toFixed(1)} / ${Math.max(...scores).toFixed(1)}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
