const {
  FORTUNE_TELLERS,
  FORTUNE_STRUCTURE_VARIANTS,
  formatSelectedTarotCards,
  formatSelectedPlayingCards,
  formatBaklaScatter,
  formatWaterScatter,
  categoryGuidance,
} = require('../fortune_personas');
const {
  countWords,
  trimToMaxWords,
  expansionTokenBudget,
  buildExpandPrompt,
  isInWordRange,
  firstPassCompletionTokens,
  buildFirstPassRetryPrompt,
  hasProductionWordTarget,
} = require('../fortune_word_range');

const MODEL = process.env.OPENAI_MODEL || 'gpt-4o-mini';

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
  'Fatma', 'Oğuz', 'Ece', 'Serkan', 'Lale', 'Tuna',
];
const ZODIACS = ['Yengeç', 'Koç', 'Terazi', 'Akrep', 'Aslan', 'Kova', 'Balık', 'Boğa'];
const INTENTIONS = [
  'Yeni bir ilişki için kalbimde umut var ama geçmişten korkuyorum.',
  'İş değişikliği yapmalı mıyım, içimde belirsizlik var.',
  'Aile içi huzuru yeniden kurmak istiyorum.',
  'Maddi sıkıntılarımın ne zaman hafifleyeceğini merak ediyorum.',
  'Eski sevgilimle barışma ihtimali aklımı kurcalıyor.',
  'Kendime güvenimi yeniden bulmak istiyorum.',
  'Yakınlarımdan birinin sağlığı beni endişelendiriyor.',
  'Taşınma kararı vermek üzereyim, doğru zaman mı?',
];

const CATEGORY_DEFS = [
  { category: 'Kahve Falı', extras: { imageNames: ['f1.jpg'] } },
  { category: 'Tarot Falı', extras: { selectedCards: TAROT_CARDS } },
  { category: 'Su Falı', extras: { waterScatter: WATER_SCATTER } },
  { category: 'Bakla Falı', extras: { baklaScatter: BAKLA_SCATTER } },
  { category: 'İskambil Falı', extras: { selectedCards: PLAYING_CARDS } },
];

const TELLER_IDS = ['gizem_ana', 'medyum_aylin', 'ustat_hakan'];

function estimateTokens(text) {
  return Math.ceil(String(text || '').length / 3.5);
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

function optimizedPickCategoryGuidance(category, hints) {
  if (category === 'Kahve Falı') {
    return `Kahve: fincan ve telve imgelerini niyetle bağla. Bu oturumda özellikle: ${hints}.`;
  }
  const base = categoryGuidance(category);
  return `${base} Bu oturumda özellikle şu imgeleri canlı ve özgün betimle: ${hints}.`;
}

function optimizedUniqueness(requestId) {
  return `BENZERSİZLİK (oturum ${requestId}):
- Bu yorum önceki fallardan, şablon metinlerden ve tekrarlayan kalıplardan farklı olsun.
- Danışanın niyetine özel somut imgeler üret; jenerik metin yazma.
- Aynı cümle iskeletini tekrarlama; giriş ve kapanış yalnızca bu oturuma özgü olsun.`;
}

function buildOptimizedUserPrompt(body, teller, structure, options) {
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
    : optimizedPickCategoryGuidance(category, kahveHints);
  const uniqueness = optimizedUniqueness(requestId);
  const maritalSuffix = marital
    ? `, medeni durum: ${marital} (aşk ve ilişki yorumunda dikkate al)`
    : '';
  const tierLengthBoost =
    teller.id === 'ustat_hakan'
      ? 'Detaylı tier: geçmiş, şimdi ve yakın gelecek katmanlarını; sembol, duygu ve niyet bağlantısını ayrı paragraflarla derinleştir.'
      : '';
  const structureReminder =
    category === 'Tarot Falı' || category === 'İskambil Falı'
      ? `\n${structure.instruction}`
      : '';

  return `${ritualSection}${guidance}
Danışan: ${name}, ${age} yaş, ${zodiac}${maritalSuffix}. Niyet: "${intention}"
${cardsSection}${uniqueness}
${tierLengthBoost ? `${tierLengthBoost}\n` : ''}[id:${requestId}]
${teller.minWords}-${teller.maxWords} kelime (kesin aralık; üst sınır ${teller.maxWords}).${structureReminder}`;
}

function buildTestCases(count, balanced = false) {
  const cases = [];
  const combos = [];
  if (balanced) {
    for (const cat of CATEGORY_DEFS) {
      for (const tellerId of TELLER_IDS) combos.push({ cat, tellerId });
    }
  }

  while (cases.length < count) {
    let cat;
    let tellerId;
    if (balanced) {
      const combo = combos[cases.length % combos.length];
      cat = combo.cat;
      tellerId = combo.tellerId;
    } else {
      cat = CATEGORY_DEFS[cases.length % CATEGORY_DEFS.length];
      tellerId = TELLER_IDS[cases.length % TELLER_IDS.length];
    }
    const structure =
      FORTUNE_STRUCTURE_VARIANTS[cases.length % FORTUNE_STRUCTURE_VARIANTS.length];
    cases.push({
      id: `case-${cases.length + 1}`,
      tellerId,
      structure,
      body: {
        category: cat.category,
        name: NAMES[cases.length % NAMES.length],
        age: 24 + (cases.length % 15),
        zodiac: ZODIACS[cases.length % ZODIACS.length],
        maritalStatus: cases.length % 2 === 0 ? 'Bekar' : 'Evli',
        intention: INTENTIONS[cases.length % INTENTIONS.length],
        requestId: `compare-${cases.length + 1}`,
        ...cat.extras,
      },
      kahveHints: 'kuş figürü, yol çizgisi, halka',
    });
  }
  return cases;
}

function getCaseMeta(testCase) {
  const teller = FORTUNE_TELLERS[testCase.tellerId];
  return {
    category: testCase.body.category,
    tellerName: teller.name,
    tellerId: testCase.tellerId,
  };
}

function scoreFortune(text, body) {
  const words = countWords(text);
  const teller = FORTUNE_TELLERS[body.tellerId || 'gizem_ana'];
  const inRange = words >= teller.minWords && words <= teller.maxWords;
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
    const mentioned = symbols.filter((s) =>
      text.toLowerCase().includes(s.toLowerCase()),
    ).length;
    symbolCoverage = mentioned / symbols.length;
  }
  if (body.waterScatter?.symbols) {
    const symbols = body.waterScatter.symbols;
    const mentioned = symbols.filter((s) =>
      text.toLowerCase().includes(s.toLowerCase()),
    ).length;
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

function fitFortuneLength(result, teller) {
  let text = String(result || '').trim();
  let words = countWords(text);
  if (words > teller.maxWords) {
    text = trimToMaxWords(text, teller.maxWords);
    words = countWords(text);
  }
  return { text, words };
}

async function callFortune(openai, systemPrompt, userPrompt, maxTokens) {
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
  return response.choices?.[0]?.message?.content?.trim() || '';
}

async function generateFirstPassFortune(openai, teller, systemPrompt, baseUserPrompt) {
  const maxPasses = hasProductionWordTarget(teller) ? 4 : 1;
  let userPrompt = baseUserPrompt;
  let text = '';
  let words = 0;
  let firstApiWords = 0;

  for (let pass = 1; pass <= maxPasses; pass++) {
    text = await callFortune(
      openai,
      systemPrompt,
      userPrompt,
      firstPassCompletionTokens(teller),
    );
    if (pass === 1) {
      firstApiWords = countWords(text);
    }
    let fitted = fitFortuneLength(text, teller);
    text = fitted.text;
    words = fitted.words;
    if (words >= teller.minWords) {
      return { text, words, pass, firstApiWords };
    }
    if (pass < maxPasses) {
      userPrompt = buildFirstPassRetryPrompt(baseUserPrompt, teller, words, pass + 1);
    }
  }

  return { text, words, pass: maxPasses, firstApiWords };
}

async function generateFortune(openai, systemPrompt, baseUserPrompt, teller) {
  let expanded = false;
  let retried = false;

  let { text, words, pass: firstPassCount, firstApiWords } =
    await generateFirstPassFortune(openai, teller, systemPrompt, baseUserPrompt);
  const firstPassWords = words;
  const firstPassMeetsMin = words >= teller.minWords;
  const firstPassInRange = isInWordRange(words, teller);
  const firstApiMeetsMin = firstApiWords >= teller.minWords;

  if (firstPassInRange) {
    return {
      text,
      words,
      inRange: true,
      attempt: firstPassCount,
      expanded,
      retried,
      firstPassWords,
      firstPassMeetsMin,
      firstPassInRange,
      firstApiWords,
      firstApiMeetsMin,
    };
  }

  if (words < teller.minWords) {
    expanded = true;
    const addition = await callFortune(
      openai,
      systemPrompt,
      buildExpandPrompt(teller, text, words),
      expansionTokenBudget(teller, teller.minWords - words),
    );
    text = `${text.trim()}\n\n${addition.trim()}`.trim();
    let fitted = fitFortuneLength(text, teller);
    text = fitted.text;
    words = fitted.words;
    if (isInWordRange(words, teller)) {
      return {
        text,
        words,
        inRange: true,
        attempt: firstPassCount,
        expanded,
        retried,
        firstPassWords,
        firstPassMeetsMin,
        firstPassInRange,
        firstApiWords,
        firstApiMeetsMin,
      };
    }
  }

  retried = true;
  const retryPrompt =
    words < teller.minWords
      ? `${baseUserPrompt}

YETERSİZ UZUNLUK: Önceki yanıt ${words} kelimeydi; minimum ${teller.minWords} kelime şart. Aynı fal verisi ve ${teller.name} sesiyle metni baştan, en az ${teller.minWords} kelime olacak şekilde yeniden yaz. Maksimum ${teller.maxWords} kelime.`
      : `${baseUserPrompt}

FAZLA UZUN: Önceki yanıt ${words} kelimeydi; maksimum ${teller.maxWords} kelime. Metni ${teller.minWords}-${teller.maxWords} aralığına sığdırarak yeniden yaz.`;

  text = await callFortune(
    openai,
    systemPrompt,
    retryPrompt,
    teller.maxCompletionTokens,
  );
  let fitted = fitFortuneLength(text, teller);
  text = fitted.text;
  words = fitted.words;

  if (words < teller.minWords) {
    expanded = true;
    const addition = await callFortune(
      openai,
      systemPrompt,
      buildExpandPrompt(teller, text, words),
      expansionTokenBudget(teller, teller.minWords - words),
    );
    text = `${text.trim()}\n\n${addition.trim()}`.trim();
    fitted = fitFortuneLength(text, teller);
    text = fitted.text;
    words = fitted.words;
  }

  return {
    text,
    words,
    inRange: isInWordRange(words, teller),
    attempt: firstPassCount + 1,
    expanded,
    retried,
    firstPassWords,
    firstPassMeetsMin,
    firstPassInRange,
    firstApiWords,
    firstApiMeetsMin,
  };
}

module.exports = {
  MODEL,
  FORTUNE_TELLERS,
  estimateTokens,
  countWords,
  buildTestCases,
  getCaseMeta,
  scoreFortune,
  generateFortune,
  expansionTokenBudget,
  legacyBuildSystemPrompt,
  legacyBuildUserPrompt,
  buildOptimizedUserPrompt,
  CATEGORY_DEFS,
  TELLER_IDS,
};
