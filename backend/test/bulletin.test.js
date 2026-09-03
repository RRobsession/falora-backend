const assert=require('node:assert/strict');
const test=require('node:test');
const {youtubeId,istanbulEndOfDay,normalize}=require('../bulletin');

test('accepts supported YouTube URL formats',()=>{
  const id='dQw4w9WgXcQ';
  assert.equal(youtubeId(`https://www.youtube.com/watch?v=${id}`),id);
  assert.equal(youtubeId(`https://youtu.be/${id}`),id);
  assert.equal(youtubeId(`https://youtube.com/shorts/${id}`),id);
  assert.equal(youtubeId('https://example.com/video'),null);
});

test('calculates midnight in Europe/Istanbul (UTC+3)',()=>{
  const now=Date.parse('2026-09-03T18:20:00.000Z');
  assert.equal(istanbulEndOfDay(now).toMillis(),Date.parse('2026-09-03T21:00:00.000Z'));
});

test('normalizes common Turkish moderation bypasses',()=>{
  assert.equal(normalize('s.İ.K.T.İ.R'),'s i k t i r');
  assert.equal(normalize('a m 1 n a'),'a m i n a');
});
