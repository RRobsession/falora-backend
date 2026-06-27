/**
 * Fal sonuçlarında tekrar eden cümle/yapı ve tarot kart uyumunu ölçer.
 * Kullanım: node scripts/audit-fortune-repetition.js [--limit=100]
 */
const path = require('path');
const admin = require('firebase-admin');

const SERVICE_ACCOUNT_PATH = path.join(
  __dirname,
  '..',
  'firebase-service-account.json',
);

const BANNED_OPENING_PATTERNS = [
  /^baktığımda/i,
  /^şu an gördüğüm/i,
  /^kartların dili/i,
  /^genel olarak/i,
  /^yolun açılıyor/i,
  /^kalbinin tarafı/i,
];

const COMMON_CLICHES = [
  'yolun açılıyor',
  'kalbinin tarafı',
  'içinden geçen',
  'bu dönemde',
  'genel olarak',
  'kartların dili',
  'baktığımda',
  'enerjinde',
  'sabırla',
];

function normalizeText(text) {
  return String(text || '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

function firstSentence(text) {
  const match = String(text || '').match(/^[^.!?]+[.!?]?/);
  return match ? match[0].trim() : '';
}

function countCliches(text) {
  const lower = normalizeText(text);
  const hits = {};
  for (const phrase of COMMON_CLICHES) {
    const count = lower.split(phrase).length - 1;
    if (count > 0) hits[phrase] = count;
  }
  return hits;
}

function repeatedNGrams(text, n = 4) {
  const words = normalizeText(text).split(' ').filter(Boolean);
  if (words.length < n * 2) return [];
  const counts = new Map();
  for (let i = 0; i <= words.length - n; i++) {
    const gram = words.slice(i, i + n).join(' ');
    counts.set(gram, (counts.get(gram) || 0) + 1);
  }
  return [...counts.entries()]
    .filter(([, c]) => c > 1)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5);
}

function cardNamesFromSelection(selectedCards) {
  if (!Array.isArray(selectedCards)) return [];
  return selectedCards
    .map((c) => {
      const name = c?.nameTr || c?.nameEn || c?.id || '';
      return String(name).trim();
    })
    .filter((n) => n && !/^[mcwsp]\d{2}$/i.test(n));
}

function countCardsMentioned(result, cardNames) {
  if (!cardNames.length) return { mentioned: 0, total: 0, ratio: 1 };
  const lower = normalizeText(result);
  let mentioned = 0;
  for (const name of cardNames) {
    if (lower.includes(normalizeText(name))) mentioned++;
  }
  return {
    mentioned,
    total: cardNames.length,
    ratio: cardNames.length ? mentioned / cardNames.length : 1,
  };
}

function parseLimit(argv) {
  const arg = argv.find((a) => a.startsWith('--limit='));
  if (!arg) return 100;
  const n = Number.parseInt(arg.split('=')[1], 10);
  return Number.isFinite(n) && n > 0 ? n : 100;
}

async function main() {
  const limit = parseLimit(process.argv.slice(2));

  if (!admin.apps.length) {
    const serviceAccount = require(SERVICE_ACCOUNT_PATH);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  }

  const db = admin.firestore();
  const snap = await db
    .collection('fortune_requests')
    .orderBy('createdAt', 'desc')
    .limit(limit)
    .get();

  const openingCounts = new Map();
  const clicheTotals = new Map();
  const tarotCoverage = [];
  let withResult = 0;
  let bannedOpeningHits = 0;

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const result = typeof data.result === 'string' ? data.result.trim() : '';
    if (!result || result.length < 80) continue;
    withResult++;

    const opening = firstSentence(result);
    const openingKey = normalizeText(opening).slice(0, 80);
    openingCounts.set(openingKey, (openingCounts.get(openingKey) || 0) + 1);

    if (BANNED_OPENING_PATTERNS.some((re) => re.test(opening))) {
      bannedOpeningHits++;
    }

    const cliches = countCliches(result);
    for (const [phrase, count] of Object.entries(cliches)) {
      clicheTotals.set(phrase, (clicheTotals.get(phrase) || 0) + count);
    }

    const cards = data.selectedCards || data.selectedTarotCards;
    const names = cardNamesFromSelection(cards);
    if (names.length >= 4) {
      tarotCoverage.push({
        id: doc.id,
        ...countCardsMentioned(result, names),
      });
    }
  }

  const topOpenings = [...openingCounts.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10);

  const topCliches = [...clicheTotals.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10);

  const avgTarotRatio =
    tarotCoverage.length > 0
      ? tarotCoverage.reduce((s, r) => s + r.ratio, 0) / tarotCoverage.length
      : null;

  const lowTarot = tarotCoverage.filter((r) => r.ratio < 0.5).length;

  console.log('\n=== FAL TEKRAR DENETİMİ ===');
  console.log(`Örneklenen kayıt: ${snap.size} | Sonuçlu: ${withResult}`);
  console.log(`Yasaklı açılış kalıbı: ${bannedOpeningHits}/${withResult}`);
  if (avgTarotRatio != null) {
    console.log(
      `Tarot kart adı geçme oranı (ort.): ${(avgTarotRatio * 100).toFixed(1)}% | Düşük uyum (<50%): ${lowTarot}/${tarotCoverage.length}`,
    );
  }

  console.log('\n--- En sık açılış cümleleri ---');
  for (const [text, count] of topOpenings) {
    console.log(`(${count}x) ${text}`);
  }

  console.log('\n--- En sık klişe ifadeler ---');
  for (const [phrase, count] of topCliches) {
    console.log(`"${phrase}": ${count} kez`);
  }

  if (tarotCoverage.length > 0) {
    console.log('\n--- Düşük tarot uyumu (örnek 5) ---');
    tarotCoverage
      .filter((r) => r.ratio < 0.5)
      .slice(0, 5)
      .forEach((r) => {
        console.log(`${r.id}: ${r.mentioned}/${r.total} kart geçti`);
      });
  }

  console.log('\n=== BİTTİ ===\n');
}

main().catch((err) => {
  console.error('Denetim başarısız:', err.message);
  process.exit(1);
});
