const test = require('node:test');
const assert = require('node:assert/strict');

const {
  getFortuneTeller,
  pickFortuneStructureForTeller,
  buildFortuneSystemPrompt,
} = require('../fortune_personas');

test('fortune prompts do not leak example person names', () => {
  for (const tellerId of ['gizem_ana', 'medyum_aylin', 'ustat_hakan']) {
    const teller = getFortuneTeller(tellerId);
    const structure = pickFortuneStructureForTeller(tellerId);
    const prompt = buildFortuneSystemPrompt(teller, structure);

    assert.doesNotMatch(prompt, /Büşra|Ahmet/u);
    assert.match(
      prompt,
      /Kullanıcı girdisinde bulunmayan hiçbir kişi adını üretme/u,
    );
  }
});
