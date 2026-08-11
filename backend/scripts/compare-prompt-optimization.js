#!/usr/bin/env node
/**
 * Eski ve yeni prompt sürümlerini 30 örnek fal ile karşılaştırır.
 * Kullanım: node scripts/compare-prompt-optimization.js
 */
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const OpenAI = require('openai');
const {
  FORTUNE_TELLERS,
  FORTUNE_STRUCTURE_VARIANTS,
  buildFortuneSystemPrompt,
  buildFortuneUserPrompt,
  formatSelectedTarotCards,
  formatSelectedPlayingCards,
  formatBaklaScatter,
  formatWaterScatter,
  categoryGuidance,
} = require('../fortune_personas');

const MODEL = process.env.OPENAI_MODEL || 'gpt-4o-mini';
const SAMPLE_COUNT = 30;

const LEGACY_COMPACT_OUTPUT_RULES = `KISA YORUM KALİTESİ (uzunluk kısalsa da kalite düşmesin):
- Her cümle yeni bir içgörü taşısın; dolgu, selamlama veya uzatma cümlesi ekleme.
- Girişte uzun ön söz yok; doğrudan fal yorumuna gir.
- Kapanışta tekrarlayan genel motivasyon kalıpları yok; kısa ama isabetli bir final cümlesi yeter.
- Metin kısa görünmemeli: yoğun, akıcı, doğal Türkçe ve kişiye özel kalsın.
- Genel geçer ifadeler yerine danışanın niyetine doğrudan odaklan.`;

const LEGACY_SHARED_RULES = `ORTAK KURALLAR:
- İsim, yaş, burç, niyet veya çift bilgilerini organik yedir; etiket listesi yapma.
- Her cümle yeni bir içgörü sunsun; aynı fikri veya aynı cümle kalıbını tekrarlama.
- Cevabı mutlaka tamamlanmış bir cümleyle bitir; yarım cümle bırakma.
- Son kapanış kısa ve net olsun; kapanış cümlesi önceki fallardan farklı olsun.
- Başlık, madde, numara, emoji kullanma.
- "AI", "model", "algoritma", "veri", "analiz ettim" gibi ifadeler yasak.
- "Genel olarak", "bu dönemde", "olabilir", "yolun açılıyor", "kartların dili" klişelerinden kaçın.
- Kesin kader, tıbbi/hukuki tavsiye, evlilik/aldatma garantisi yok.
- Makale veya Google metni gibi jenerik burç kalıpları yok.
- Robotik, şablon veya her seferinde aynı giriş cümlesi kullanma.
- Şu açılışları varsayılan giriş olarak kullanma: "Baktığımda...", "Şu an gördüğüm...", "Kartların dili...", "Genel olarak...".`;

const LEGACY_VOCABULARY_STYLE_RULE = `KELİME HAVUZU KURALI:
- Aşağıdaki kelime örnekleri yalnızca TON rehberidir; kelimesi kelimesine kopyalama.
- Her oturumda farklı eş anlamlı ve özgün ifadeler üret.
- Aynı oturum içinde bir ifadeyi iki kez kullanma.`;

const LEGACY_KAHVE_GUIDANCE =
  'Kahve: fincan, telve, yol, kuş, halka, kapı, göz, kalp sembolleriyle niyeti bağla.';

const TAROT_FLOW_HINT =
  'Her seçili kartın Türkçe adını metinde geçir; kartları akıcı paragraflar içinde, seçim sırasına sadık kalarak yorumla.';
const PLAYING_FLOW_HINT =
  'Her kartı pozisyon anlamıyla birlikte yorumla; yedi kartın tamamının Türkçe adı metinde geçsin.';

const BANNED_OPENINGS = [
  /^baktığımda/i,
  /^şu an gördüğüm/i,
  /^kartların dili/i,
  /^genel olarak/i,
];

const AI_TERMS = /\b(ai|model|algoritma|analiz ettim)\b/i;

function estimateTokens(text) {
  return Math.ceil(String(text || '').length / 3.5);
}

function countWords(text) {
  return String(text || '')
    .trim()
    .split(/\s+/)
    .filter(Boolean).length;
}

function legacyCompactRulesForTeller(teller) {
  if (teller.id === 'ustat_hakan') {
    return `DETAYLI YORUM KALİTESİ:
- 300-400 kelime bandında yoğun kal; her paragraf yeni bir katman eklesin.
- Geçmiş, şimdi, yakın gelecek, duygu ve niyet bağlantısını ayrı derinlikte işle.
- Dolgu veya tekrar yok; ama detayı kısa kesme — yoğun ve profesyonel kal.`;
  }
  return LEGACY_COMPACT_OUTPUT_RULES;
}

function legacyBuildSystemPrompt(teller, structure) {
  const wordRule = `- KESİN kelime aralığı: ${teller.minWords}-${teller.maxWords} kelime (altına veya üstüne çıkma).
- Bu aralık maliyet optimizasyonu içindir; isabet, akıcılık, kişiselleştirme ve profesyonellik aynı seviyede kalsın.`;
  return `Sen ${teller.name} adında deneyimli bir Türk falcısısın. Gerçek bir oturumda danışanın karşısındasın.

KİŞİLİK VE SES:
${teller.voice}

KELİME TARZIN:
${teller.vocabulary}

YORUMLAMA YAKLAŞIMIN:
${teller.approach}

UZUNLUK TALİMATI:
${teller.lengthDirective}

BU YORUMUN YAPISI — ${structure.name}:
${structure.instruction}

${LEGACY_SHARED_RULES}
${legacyCompactRulesForTeller(teller)}
${LEGACY_VOCABULARY_STYLE_RULE}
${wordRule}

Kendini ${teller.name} olarak tut; başka isim veya persona kullanma.
Analiz kalitesi ve doğruluk seviyesi her zaman en yüksek düzeyde kalsın; yalnızca uzunluk değişir.`;
}

function legacyPickCategoryGuidance(category, hints) {
  if (category === 'Kahve Falı') {
    return `${LEGACY_KAHVE_GUIDANCE} Bu oturumda özellikle şu imgeleri canlı ve özgün betimle: ${hints}.`;
  }
  const base = categoryGuidance(category);
  return `${base} Bu oturumda özellikle şu imgeleri canlı ve özgün betimle: ${hints}.`;
}

function legacyBuildUniqueness(requestId, body) {
  const intentSnippet = String(body.intention ?? '')
    .trim()
    .slice(0, 80);
  const namePart = String(body.name ?? '').trim();
  const categoryPart = String(body.category ?? '').trim();
  const maritalPart = String(body.maritalStatus ?? '').trim();
  return `BENZERSİZLİK (oturum ${requestId}):
- Bu yorum önceki tüm fallardan, şablon metinlerden ve tekrarlayan fal kalıplarından farklı olsun.
- ${categoryPart ? `Kategori: ${categoryPart}.` : ''} ${namePart ? `Danışan: ${namePart}.` : ''}
- ${maritalPart ? `Medeni durum: ${maritalPart} — aşk/ilişki bağlamını buna göre yorumla.` : ''}
- Niyet: "${intentSnippet}" — bu niyete özel somut imgeler üret; jenerik metin yazma.
- Aynı cümleyi veya cümle iskeletini birden fazla kez kullanma.
- Giriş ve kapanış cümlelerini yalnızca bu oturuma özgü kur.`;
}

function legacyBuildUserPrompt(body, teller, structure, options) {
  const {
    requestId,
    kahveHints,
    tarotFlowHint = TAROT_FLOW_HINT,
    playingFlowHint = PLAYING_FLOW_HINT,
  } = options;
  const {
    category,
    name,
    age,
    zodiac,
    maritalStatus,
    intention,
    imageNames,
    selectedCards,
  } = body;
  const photos =
    Array.isArray(imageNames) && imageNames.length > 0
      ? `Fotoğraf: ${imageNames.length} adet.`
      : '';
  const marital =
    typeof maritalStatus === 'string' && maritalStatus.trim()
      ? maritalStatus.trim()
      : '';
  const cardsSection =
    category === 'İskambil Falı'
      ? formatSelectedPlayingCards(selectedCards, playingFlowHint)
      : formatSelectedTarotCards(selectedCards, tarotFlowHint);
  const baklaSection = formatBaklaScatter(body.baklaScatter);
  const waterSection = formatWaterScatter(body.waterScatter);
  const ritualSection = baklaSection || waterSection;
  const guidance = ritualSection
    ? categoryGuidance(category)
    : legacyPickCategoryGuidance(category, kahveHints);
  const uniqueness = legacyBuildUniqueness(requestId, body);
  const maritalLine = marital ? `, medeni durum: ${marital}` : '';
  const tierLengthBoost =
    teller.id === 'ustat_hakan'
      ? 'Detaylı tier: geçmiş, şimdi ve yakın gelecek katmanlarını; sembol, duygu ve niyet bağlantısını ayrı paragraflarla derinleştir.'
      : '';

  return `${ritualSection}${guidance}
Danışan: ${name}, ${age} yaş, ${zodiac}${maritalLine}. Niyet: "${intention}"${photos ? ` ${photos}` : ''}
${marital ? `Medeni durumu (${marital}) aşk, bağ ve yakın gelecek yorumlarında dikkate al; buna aykırı varsayımlar kurma.` : ''}
Falcı: ${teller.name} | Yapı: ${structure.name}
${cardsSection}${uniqueness}
${tierLengthBoost ? `${tierLengthBoost}\n` : ''}[id:${requestId}]
${teller.minWords}-${teller.maxWords} kelime (kesin aralık; ${teller.minWords} kelimeden az, ${teller.maxWords} kelimeden fazla yazma). ${structure.instruction}
Cevabı tamamlanmış cümleyle bitir.`;
}

function buildDeterministicUserPrompt(body, teller, structure, options) {
  const {
    requestId,
    kahveHints,
    tarotFlowHint = TAROT_FLOW_HINT,
    playingFlowHint = PLAYING_FLOW_HINT,
  } = options;
  const {
    category,
    name,
    age,
    zodiac,
    maritalStatus,
    intention,
    imageNames,
    selectedCards,
  } = body;
  const photos =
    Array.isArray(imageNames) && imageNames.length > 0
      ? `Fotoğraf: ${imageNames.length} adet.`
      : '';
  const marital =
    typeof maritalStatus === 'string' && maritalStatus.trim()
      ? maritalStatus.trim()
      : '';
  const cardsSection =
    category === 'İskambil Falı'
      ? formatSelectedPlayingCards(selectedCards, playingFlowHint)
      : formatSelectedTarotCards(selectedCards, tarotFlowHint);
  const baklaSection = formatBaklaScatter(body.baklaScatter);
  const waterSection = formatWaterScatter(body.waterScatter);
  const ritualSection = baklaSection || waterSection;
  let guidance;
  if (ritualSection) {
    guidance = categoryGuidance(category);
  } else if (category === 'Kahve Falı') {
    guidance = `Kahve: fincan ve telve imgelerini niyetle bağla. Bu oturumda özellikle: ${kahveHints}.`;
  } else {
    const base = categoryGuidance(category);
    guidance = `${base} Bu oturumda özellikle şu imgeleri canlı ve özgün betimle: ${kahveHints}.`;
  }
  const maritalSuffix = marital
    ? `, medeni durum: ${marital} (aşk ve ilişki yorumunda dikkate al)`
    : '';
  const tierLengthBoost =
    teller.id === 'ustat_hakan'
      ? 'Detaylı tier: geçmiş, şimdi ve yakın gelecek katmanlarını; sembol, duygu ve niyet bağlantısını ayrı paragraflarla derinleştir.'
      : '';
  const uniqueness = `BENZERSİZLİK (oturum ${requestId}):
- Bu yorum önceki fallardan, şablon metinlerden ve tekrarlayan kalıplardan farklı olsun.
- Aynı cümle iskeletini tekrarlama; giriş ve kapanış yalnızca bu oturuma özgü olsun.`;

  return `${ritualSection}${guidance}
Danışan: ${name}, ${age} yaş, ${zodiac}${maritalSuffix}. Niyet: "${intention}"${photos ? ` ${photos}` : ''}
${cardsSection}${uniqueness}
${tierLengthBoost ? `${tierLengthBoost}\n` : ''}[id:${requestId}]
${teller.minWords}-${teller.maxWords} kelime (kesin aralık).`;
}

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

const PLAYING_CARDS = [
  { id: 'h_k', nameTr: 'Kupa Kralı', positionIndex: 1, isReversed: false },
  { id: 'd_7', nameTr: 'Karo Yedi', positionIndex: 2, isReversed: true },
  { id: 's_a', nameTr: 'Sinek Ası', positionIndex: 3, isReversed: false },
  { id: 'c_q', nameTr: 'Maça Kraliçesi', positionIndex: 4, isReversed: false },
  { id: 'h_5', nameTr: 'Kupa Beş', positionIndex: 5, isReversed: true },
  { id: 'd_10', nameTr: 'Karo On', positionIndex: 6, isReversed: false },
  { id: 's_3', nameTr: 'Sinek Üç', positionIndex: 7, isReversed: false },
];

const BAKLA_SCATTER = {
  beanCount: 42,
  densityBias: 'merkeze yığılma',
  patternTraits: ['spiral dizilim', 'sağa yığılma'],
  spreadSummary: '42 bakla döküldü; merkezde boşluk var.',
  markedSymbols: [
    { symbol: 'Yıldız', zone: 'üst-sol', normX: 0.22, normY: 0.18, nearCluster: true },
    { symbol: 'Kalp', zone: 'merkez', normX: 0.51, normY: 0.49, nearCluster: false },
    { symbol: 'Yol', zone: 'alt-sağ', normX: 0.74, normY: 0.81, nearCluster: true },
  ],
};

const WATER_SCATTER = {
  fortuneType: 'water',
  symbols: ['yüzey dalgası', 'yansıma', 'ışık kırılması'],
  waterClarity: 'berrak',
  rippleCount: 5,
  motion: 'yavaş dalgalanma',
  dominantSymbol: 'yansıma',
  reflectionStrength: 'güçlü',
};

const NAMES = [
  'Elif', 'Can', 'Zeynep', 'Murat', 'Selin', 'Emre',
  'Ayşe', 'Burak', 'Deniz', 'Mira', 'Koray', 'Aslı',
  'Fatma', 'Oğuz', 'Ece', 'Serkan',
];
const ZODIACS = ['Yengeç', 'Koç', 'Terazi', 'Akrep', 'Aslan', 'Kova', 'Balık', 'Boğa'];
const INTENTIONS = [
  'Yeni bir ilişki için kalbimde umut var ama geçmişten korkuyorum.',
  'İş değişikliği yapmalı mıyım, içimde belirsizlik var.',
  'Aile içi huzuru yeniden kurmak istiyorum.',
  'Maddi sıkıntılarımın ne zaman hafifleyeceğini merak ediyorum.',
  'Eski sevgilimle barışma ihtimali aklımı kurcalıyor.',
  'Kendime güvenimi yeniden bulmak istiyorum.',
];

function buildTestCases() {
  const categories = [
    { category: 'Kahve Falı', extras: { imageNames: ['f1.jpg'] } },
    { category: 'Tarot Falı', extras: { selectedCards: TAROT_CARDS } },
    { category: 'Su Falı', extras: { waterScatter: WATER_SCATTER } },
    { category: 'Bakla Falı', extras: { baklaScatter: BAKLA_SCATTER } },
    { category: 'İskambil Falı', extras: { selectedCards: PLAYING_CARDS } },
  ];
  const tellers = ['gizem_ana', 'medyum_aylin', 'ustat_hakan'];
  const cases = [];
  let idx = 0;

  while (cases.length < SAMPLE_COUNT) {
    const cat = categories[cases.length % categories.length];
    const tellerId = tellers[cases.length % tellers.length];
    const structure = FORTUNE_STRUCTURE_VARIANTS[cases.length % FORTUNE_STRUCTURE_VARIANTS.length];
    cases.push({
      id: `case-${cases.length + 1}`,
      tellerId,
      structure,
      body: {
        category: cat.category,
        name: NAMES[idx % NAMES.length],
        age: 24 + (cases.length % 15),
        zodiac: ZODIACS[cases.length % ZODIACS.length],
        maritalStatus: cases.length % 2 === 0 ? 'Bekar' : 'Evli',
        intention: INTENTIONS[cases.length % INTENTIONS.length],
        requestId: `compare-${cases.length + 1}`,
        ...cat.extras,
      },
      kahveHints: 'kuş figürü, yol çizgisi, halka',
    });
    idx += 1;
  }

  return cases;
}

function scoreFortune(text, body) {
  const words = countWords(text);
  const teller = FORTUNE_TELLERS[body.tellerId || 'gizem_ana'];
  const inRange =
    words >= teller.minWords && words <= teller.maxWords;
  const nameMentioned = new RegExp(body.name, 'i').test(text);
  const intentionTokens = body.intention
    .toLowerCase()
    .split(/\s+/)
    .filter((w) => w.length > 4)
    .slice(0, 4);
  const intentionHits = intentionTokens.filter((t) =>
    text.toLowerCase().includes(t),
  ).length;
  const bannedOpening = BANNED_OPENINGS.some((re) => re.test(text.trim()));
  const aiLeak = AI_TERMS.test(text);
  const completeEnding = /[.!?…"]\s*$/.test(text.trim());

  let cardCoverage = 1;
  if (body.category === 'Tarot Falı' && Array.isArray(body.selectedCards)) {
    const block = formatSelectedTarotCards(body.selectedCards, TAROT_FLOW_HINT);
    const labels = block
      .split('\n')
      .slice(1)
      .filter((line) => /^\d+\./.test(line))
      .map((line) => line.replace(/^\d+\.\s*/, '').replace(/\s*\((Düz|Ters)\)$/, ''));
    const mentioned = labels.filter((l) => text.includes(l)).length;
    cardCoverage = labels.length ? mentioned / labels.length : 1;
  }
  if (body.category === 'İskambil Falı' && Array.isArray(body.selectedCards)) {
    const labels = body.selectedCards.map((c) => c.nameTr);
    const mentioned = labels.filter((l) => text.includes(l)).length;
    cardCoverage = mentioned / labels.length;
  }

  let symbolCoverage = 1;
  if (body.baklaScatter?.markedSymbols) {
    const symbols = body.baklaScatter.markedSymbols.map((s) => s.symbol);
    const mentioned = symbols.filter((s) => text.toLowerCase().includes(s.toLowerCase())).length;
    symbolCoverage = mentioned / symbols.length;
  }
  if (body.waterScatter?.symbols) {
    const symbols = body.waterScatter.symbols;
    const mentioned = symbols.filter((s) => text.toLowerCase().includes(s.toLowerCase())).length;
    symbolCoverage = mentioned / symbols.length;
  }

  const personalization =
    (nameMentioned ? 1 : 0) +
    (intentionHits >= 1 ? 1 : 0) +
    (cardCoverage >= 0.5 ? 1 : 0) +
    (symbolCoverage >= 0.33 ? 1 : 0);

  return {
    words,
    inRange,
    nameMentioned,
    intentionHits,
    bannedOpening,
    aiLeak,
    completeEnding,
    cardCoverage,
    symbolCoverage,
    personalization,
    qualityScore:
      (inRange ? 2 : 0) +
      (nameMentioned ? 1 : 0) +
      (intentionHits >= 1 ? 1 : 0) +
      (!bannedOpening ? 1 : 0) +
      (!aiLeak ? 1 : 0) +
      (completeEnding ? 1 : 0) +
      cardCoverage +
      symbolCoverage,
  };
}

async function generateFortune(openai, systemPrompt, baseUserPrompt, teller) {
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
    lastWords = words;

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
        max_completion_tokens: Math.min(420, teller.maxCompletionTokens),
        temperature: 0.9,
        frequency_penalty: 0.55,
        presence_penalty: 0.3,
      });
      const addition =
        expandResponse.choices?.[0]?.message?.content?.trim() || '';
      text = `${text.trim()}\n\n${addition.trim()}`.trim();
      words = countWords(text);
      lastWords = words;
    }

    const inRange = words >= teller.minWords && words <= teller.maxWords;
    if (inRange || attempt === 3) {
      return { text, words, inRange, attempt };
    }
  }

  return { text: '', words: 0, inRange: false, attempt: 3 };
}

async function main() {
  const cases = buildTestCases();
  const tokenStats = { legacy: [], optimized: [] };
  const qualityStats = { legacy: [], optimized: [] };

  console.log('=== PROMPT TOKEN KARŞILAŞTIRMASI (tahmini) ===\n');
  for (const testCase of cases) {
    const teller = FORTUNE_TELLERS[testCase.tellerId];
    const opts = {
      requestId: testCase.body.requestId,
      kahveHints: testCase.kahveHints,
    };
    const legacySystem = legacyBuildSystemPrompt(teller, testCase.structure);
    const legacyUser = legacyBuildUserPrompt(
      testCase.body,
      teller,
      testCase.structure,
      opts,
    );
    const newSystem = buildFortuneSystemPrompt(teller, testCase.structure);
    const newUser = buildDeterministicUserPrompt(
      testCase.body,
      teller,
      testCase.structure,
      opts,
    );

    const legacyInput = estimateTokens(legacySystem) + estimateTokens(legacyUser);
    const newInput = estimateTokens(newSystem) + estimateTokens(newUser);
    tokenStats.legacy.push(legacyInput);
    tokenStats.optimized.push(newInput);

    if (cases.indexOf(testCase) < 3) {
      console.log(
        `${testCase.id} | ${testCase.body.category} | ${teller.name}: legacy≈${legacyInput} optimized≈${newInput} (Δ${legacyInput - newInput})`,
      );
    }
  }

  const avg = (arr) => arr.reduce((a, b) => a + b, 0) / arr.length;
  const legacyAvg = avg(tokenStats.legacy);
  const newAvg = avg(tokenStats.optimized);
  const tokenSavingPct = ((legacyAvg - newAvg) / legacyAvg) * 100;

  console.log(`\nOrtalama tahmini input token (30 örnek):`);
  console.log(`  Eski:  ${Math.round(legacyAvg)}`);
  console.log(`  Yeni:  ${Math.round(newAvg)}`);
  console.log(`  Tasarruf: %${tokenSavingPct.toFixed(1)}`);

  if (!process.env.OPENAI_API_KEY) {
    console.log('\nOPENAI_API_KEY yok — canlı fal karşılaştırması atlandı.');
    return;
  }

  const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  console.log(`\n=== 30 ÖRNEK FAL ÜRETİMİ (${MODEL}) ===\n`);

  for (let i = 0; i < cases.length; i++) {
    const testCase = cases[i];
    const teller = FORTUNE_TELLERS[testCase.tellerId];
    const opts = {
      requestId: testCase.body.requestId,
      kahveHints: testCase.kahveHints,
    };
    const legacySystem = legacyBuildSystemPrompt(teller, testCase.structure);
    const legacyUser = legacyBuildUserPrompt(
      testCase.body,
      teller,
      testCase.structure,
      opts,
    );
    const newSystem = buildFortuneSystemPrompt(teller, testCase.structure);
    const newUser = buildDeterministicUserPrompt(
      testCase.body,
      teller,
      testCase.structure,
      opts,
    );

    process.stdout.write(`[${i + 1}/${cases.length}] ${testCase.id}… `);
    const legacyResult = await generateFortune(
      openai,
      legacySystem,
      legacyUser,
      teller,
    );
    const newResult = await generateFortune(
      openai,
      newSystem,
      newUser,
      teller,
    );

    const legacyScore = scoreFortune(legacyResult.text, {
      ...testCase.body,
      tellerId: testCase.tellerId,
    });
    const newScore = scoreFortune(newResult.text, {
      ...testCase.body,
      tellerId: testCase.tellerId,
    });
    qualityStats.legacy.push(legacyScore);
    qualityStats.optimized.push(newScore);

    const delta = newScore.qualityScore - legacyScore.qualityScore;
    console.log(
      `legacy=${legacyScore.qualityScore.toFixed(1)} new=${newScore.qualityScore.toFixed(1)} Δ${delta >= 0 ? '+' : ''}${delta.toFixed(1)}`,
    );
  }

  const sumBool = (arr, key) => arr.filter((s) => s[key]).length;
  const avgScore = (arr) => arr.reduce((a, s) => a + s.qualityScore, 0) / arr.length;
  const legacyQuality = avgScore(qualityStats.legacy);
  const newQuality = avgScore(qualityStats.optimized);
  const regressions = qualityStats.optimized.filter((n, i) =>
    n.qualityScore < qualityStats.legacy[i].qualityScore - 0.5,
  ).length;

  console.log('\n=== KALİTE ÖZETİ ===');
  console.log(`Ortalama kalite skoru — Eski: ${legacyQuality.toFixed(2)} | Yeni: ${newQuality.toFixed(2)}`);
  console.log(`Kelime aralığında (eski): ${sumBool(qualityStats.legacy, 'inRange')}/${SAMPLE_COUNT}`);
  console.log(`Kelime aralığında (yeni): ${sumBool(qualityStats.optimized, 'inRange')}/${SAMPLE_COUNT}`);
  console.log(`İsim geçiyor (eski/yeni): ${sumBool(qualityStats.legacy, 'nameMentioned')}/${sumBool(qualityStats.optimized, 'nameMentioned')}`);
  console.log(`Yasak açılış (eski/yeni): ${sumBool(qualityStats.legacy, 'bannedOpening')}/${sumBool(qualityStats.optimized, 'bannedOpening')}`);
  console.log(`Belirgin gerileme (Δ<-0.5): ${regressions}`);

  if (newQuality < legacyQuality - 0.2 || regressions >= 8) {
    console.error('\n❌ Kalite düşüşü tespit edildi — değişiklikler geri alınmalı.');
    process.exit(1);
  }

  console.log('\n✅ Kalite korundu; optimizasyon güvenli.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
