const fs = require('fs');
const path = require('path');

const ENV_PATH = path.resolve(__dirname, '.env');
const ENV_EXAMPLE_PATH = path.resolve(__dirname, '.env.example');

function decodeEnvFile(buffer) {
  if (buffer.length === 0) return '';

  if (buffer[0] === 0xff && buffer[1] === 0xfe) {
    return buffer.toString('utf16le');
  }

  const utf8 = buffer.toString('utf8');
  if (utf8.includes('=')) {
    return utf8;
  }

  const utf16 = buffer.toString('utf16le');
  if (utf16.includes('=')) {
    console.warn('UYARI: .env UTF-16 olarak okundu. UTF-8 kaydetmeniz önerilir.');
    return utf16;
  }

  return utf8;
}

function applyEnvLines(text) {
  const parsed = {};

  for (const line of text.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;

    const eq = trimmed.indexOf('=');
    if (eq === -1) continue;

    const key = trimmed.slice(0, eq).trim().replace(/^\uFEFF/, '');
    const value = trimmed.slice(eq + 1).trim().replace(/^["']|["']$/g, '');

    if (!key) continue;
    parsed[key] = value;
    if (process.env[key] === undefined) {
      process.env[key] = value;
    }
  }

  return parsed;
}

function loadEnv() {
  console.log('process.cwd():', process.cwd());
  console.log('dotenv path:', ENV_PATH);

  if (!fs.existsSync(ENV_PATH)) {
    if (fs.existsSync(ENV_EXAMPLE_PATH)) {
      console.error(
        'HATA: .env dosyası yok. backend/.env.example dosyasını .env olarak kopyalayıp OPENAI_API_KEY ekleyin.',
      );
    } else {
      console.error('HATA: .env dosyası bulunamadı:', ENV_PATH);
    }
    return {};
  }

  const size = fs.statSync(ENV_PATH).size;
  if (size === 0) {
    console.error(
      'HATA: .env dosyası var ama boş (0 byte). OPENAI_API_KEY satırını yazıp dosyayı kaydedin.',
    );
    return {};
  }

  const dotenvResult = require('dotenv').config({ path: ENV_PATH });
  let parsed = dotenvResult.parsed ?? {};

  if (dotenvResult.error) {
    console.error('dotenv yükleme hatası:', dotenvResult.error.message);
  }

  if (!parsed.OPENAI_API_KEY) {
    const manualParsed = applyEnvLines(decodeEnvFile(fs.readFileSync(ENV_PATH)));
    parsed = { ...parsed, ...manualParsed };
  }

  const loadedKeys = Object.keys(parsed);
  console.log(
    'dotenv yüklendi, anahtarlar:',
    loadedKeys.length > 0 ? loadedKeys.join(', ') : '(dosya boş veya okunamadı)',
  );

  return parsed;
}

loadEnv();

if (!process.env.FIREBASE_SERVICE_ACCOUNT_PATH) {
  process.env.FIREBASE_SERVICE_ACCOUNT_PATH = path.join(
    __dirname,
    'firebase-service-account.json',
  );
}

function readApiKey() {
  let key = process.env.OPENAI_API_KEY;
  if (!key) return undefined;
  key = key.trim();
  if (key.charCodeAt(0) === 0xfeff) {
    key = key.slice(1).trim();
  }
  if (!key || key === 'sk-your-key-here') return undefined;
  return key;
}

const apiKey = readApiKey();
console.log('OPENAI_API_KEY bulundu mu:', !!apiKey);

if (!apiKey) {
  throw new Error('OPENAI_API_KEY bulunamadı');
}

const cors = require('cors');
const express = require('express');
const OpenAI = require('openai');

const PORT = Number(process.env.PORT) || 3000;
const MODEL = process.env.OPENAI_MODEL || 'gpt-4o-mini';
const VISION_MODEL = process.env.VISION_MODEL || 'gpt-4o-mini';
const FORTUNE_MAX_COMPLETION_TOKENS =
  Number(process.env.FORTUNE_MAX_COMPLETION_TOKENS) || 650;
const COUPLE_MAX_COMPLETION_TOKENS =
  Number(process.env.COUPLE_MAX_COMPLETION_TOKENS) || 800;
const TEMPERATURE = Number(process.env.TEMPERATURE) || 0.9;
const FREQUENCY_PENALTY = Number(process.env.FREQUENCY_PENALTY) || 0.55;
const PRESENCE_PENALTY = Number(process.env.PRESENCE_PENALTY) || 0.3;
const COUPLE_TEMPERATURE = Number(process.env.COUPLE_TEMPERATURE) || 0.9;
const COUPLE_FREQUENCY_PENALTY =
  Number(process.env.COUPLE_FREQUENCY_PENALTY) || 0.6;
const COUPLE_PRESENCE_PENALTY = Number(process.env.COUPLE_PRESENCE_PENALTY) || 0.5;

const ZODIAC_ELEMENTS = {
  Koç: 'ateş',
  Aslan: 'ateş',
  Yay: 'ateş',
  Boğa: 'toprak',
  Başak: 'toprak',
  Oğlak: 'toprak',
  İkizler: 'hava',
  Terazi: 'hava',
  Kova: 'hava',
  Yengeç: 'su',
  Akrep: 'su',
  Balık: 'su',
};

const {
  getFortuneTeller,
  pickFortunePersona,
  pickFortuneStructure,
  pickFortuneStructureForTeller,
  pickCoupleStructure,
  buildFortuneSystemPrompt,
  buildCoupleSystemPrompt,
  buildFortuneUserPrompt,
  buildCoupleUserPrompt,
  validateAutoCategoryInput,
  buildAutoCategorySystemPrompt,
  buildAutoCategoryUserPrompt,
  buildRelationshipAdviceSystemPrompt,
  buildRelationshipAdviceUserPrompt,
} = require('./fortune_personas');
const { sanitizeAiResult } = require('./ai_result_sanitize');
const { countWords } = require('./fortune_word_range');

function newRequestId() {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

function createClient() {
  return new OpenAI({ apiKey });
}

function nameEnergyHash(text) {
  let h = 5381;
  for (let i = 0; i < text.length; i++) {
    h = ((h << 5) + h + text.charCodeAt(i)) & 0x7fffffff;
  }
  return h;
}

function zodiacElement(sign) {
  return ZODIAC_ELEMENTS[sign] || null;
}

function elementCompatibilityScore(el1, el2) {
  if (!el1 || !el2) return 2;
  if (el1 === el2) return 9;

  const complementary = {
    'ateş-hava': 13,
    'hava-ateş': 13,
    'toprak-su': 13,
    'su-toprak': 13,
    'ateş-toprak': 5,
    'toprak-ateş': 5,
    'hava-su': 5,
    'su-hava': 5,
    'ateş-su': -3,
    'su-ateş': -3,
    'toprak-hava': -3,
    'hava-toprak': -3,
  };

  return complementary[`${el1}-${el2}`] ?? 4;
}

function calculateCompatibilityPercent(body, hasPhotos) {
  const womanAge = Number(body.womanAge);
  const manAge = Number(body.manAge);
  const ageGap = Math.abs(womanAge - manAge);

  let score = 68;

  if (ageGap <= 2) score += 8;
  else if (ageGap <= 5) score += 5;
  else if (ageGap <= 9) score += 1;
  else if (ageGap <= 14) score -= 3;
  else score -= 7;

  score += elementCompatibilityScore(
    zodiacElement(body.womanZodiac),
    zodiacElement(body.manZodiac),
  );

  if (body.womanZodiac === body.manZodiac) score += 2;

  const nameSeed = nameEnergyHash(
    `${body.womanName.trim().toLowerCase()}|${body.manName.trim().toLowerCase()}`,
  );
  score += (nameSeed % 11) - 5;

  const avgAge = (womanAge + manAge) / 2;
  if (avgAge >= 27 && avgAge <= 43) score += 3;
  else if (avgAge < 22) score -= 2;

  if (hasPhotos) score += 4;

  if (body.womanImageBase64 && body.manImageBase64) {
    const imgSeed =
      (body.womanImageBase64.length + body.manImageBase64.length) % 9;
    score += imgSeed - 4;
  }

  const dynamicSeed = nameEnergyHash(
    `${body.womanZodiac}|${body.manZodiac}|${womanAge}|${manAge}`,
  );
  score += (dynamicSeed % 7) - 3;

  score = Math.max(55, Math.min(94, Math.round(score)));

  if (score <= 56 || score >= 93) {
    score = Math.max(58, Math.min(91, score));
  }

  return score;
}

function ensureCompatibilityHeader(result, percent) {
  const header = `Uyumluluk: %${percent}`;
  const trimmed = result.trim();
  if (trimmed.startsWith('Uyumluluk:')) {
    return trimmed.replace(/^Uyumluluk:\s*%?\d+/, header);
  }
  return `${header}\n\n${trimmed}`;
}

function parseImageField(base64, mime) {
  if (!base64 || typeof base64 !== 'string' || base64.length < 32) {
    return null;
  }
  const clean = base64.replace(/^data:image\/\w+;base64,/, '').trim();
  if (!clean) return null;
  return {
    base64: clean,
    mime: mime && mime.startsWith('image/') ? mime : 'image/jpeg',
  };
}

function buildCoupleImageContent(userPrompt, womanImage, manImage) {
  const content = [{ type: 'text', text: userPrompt }];

  if (womanImage) {
    content.push({
      type: 'text',
      text: `Kadın fotoğrafı (${womanImage.label}):`,
    });
    content.push({
      type: 'image_url',
      image_url: {
        url: `data:${womanImage.mime};base64,${womanImage.base64}`,
        detail: 'low',
      },
    });
  }

  if (manImage) {
    content.push({
      type: 'text',
      text: `Erkek fotoğrafı (${manImage.label}):`,
    });
    content.push({
      type: 'image_url',
      image_url: {
        url: `data:${manImage.mime};base64,${manImage.base64}`,
        detail: 'low',
      },
    });
  }

  return content;
}

function parseChatImages(body) {
  const raw = body?.chatImages;
  if (!Array.isArray(raw)) return [];

  return raw
    .slice(0, 3)
    .map((item, index) => {
      const parsed = parseImageField(item?.base64, item?.mime);
      if (!parsed) return null;
      parsed.label = item?.name || `sohbet-${index + 1}`;
      return parsed;
    })
    .filter(Boolean);
}

function parseFortuneImages(body) {
  const raw = body?.fortuneImages;
  if (!Array.isArray(raw)) return [];
  return raw
    .slice(0, 2)
    .map((item, index) => {
      const parsed = parseImageField(item?.base64, item?.mime);
      if (!parsed) return null;
      parsed.label = item?.name || (index === 0 ? 'sağ el' : 'sol el');
      return parsed;
    })
    .filter(Boolean);
}

function buildPalmImageContent(userPrompt, images) {
  const content = [{ type: 'text', text: userPrompt }];
  const handLabels = ['Sağ el', 'Sol el'];
  images.forEach((image, index) => {
    content.push({
      type: 'text',
      text: `${handLabels[index]} fotoğrafı (${image.label}):`,
    });
    content.push({
      type: 'image_url',
      image_url: {
        url: `data:${image.mime};base64,${image.base64}`,
        detail: 'high',
      },
    });
  });
  return content;
}

const IMAGE_VALIDATION_RULES = {
  palm: `İki slot zorunlu: right_hand ve left_hand. Her görselde tek, açık ve avuç içi kameraya dönük bir insan eli bulunmalı. Avuç ve ana çizgiler yorumlanabilecek kadar net, aydınlık ve kadraj içinde olmalı. El dışı görseli, el sırtını, kapalı yumruğu, çizimi, ekran görüntüsünü ve aşırı bulanık/karanlık görseli reddet. İki görsel aynı veya yakın kopya olmamalı. Kamera aynalaması nedeniyle yalnızca sağ/sol yönü belirsiz diye reddetme.`,
  coffee: `Üç slot zorunlu: cup_1, cup_2 ve saucer. cup_1 ile cup_2 görsellerinde kahve fincanının iç yüzeyi ve telve izleri net görünmeli. saucer görselinde kahve tabağı ve telve/akıntı izleri görünmeli. Boş fincanı, yalnızca fincan dışını, alakasız nesneyi, çizimi ve okunamayacak kadar bulanık/karanlık görseli reddet. Görseller aynı veya yakın kopya olmamalı.`,
  couple: `İki slot zorunlu: woman ve man. Her görselde tam olarak bir yetişkin insanın yüzü yeterince büyük, önden veya hafif açıyla ve net görünmeli. Grup fotoğrafını, yüzü kapalı/kesilmiş görseli, insan içermeyen görseli, çizimi ve aşırı bulanık/karanlık görseli reddet. Slot etiketindeki cinsiyeti görüntüden doğrulamaya çalışma. İki dosya aynı veya yakın kopya olmamalı.`,
  relationship_chat: `Her görsel gerçek bir mesajlaşma veya sohbet ekran görüntüsü olmalı ve en az birkaç okunabilir mesaj balonu ya da konuşma satırı içermeli. Selfie, manzara, boş ekran, sosyal medya profil sayfası, yalnızca klavye veya okunamayacak kadar bulanık görüntüyü reddet. Birden fazla görsel varsa aynı veya yakın kopya olmamalı.`,
};

function buildValidationImageContent(kind, images) {
  const content = [
    {
      type: 'text',
      text: `Doğrulama türü: ${kind}\nKurallar: ${IMAGE_VALIDATION_RULES[kind]}`,
    },
  ];
  images.forEach((image) => {
    content.push({ type: 'text', text: `Slot: ${image.slot}` });
    content.push({
      type: 'image_url',
      image_url: {
        url: `data:${image.mime};base64,${image.base64}`,
        detail: 'high',
      },
    });
  });
  return content;
}

function parseValidationImages(body) {
  const raw = body?.images;
  if (!Array.isArray(raw)) return [];
  return raw.slice(0, 3).map((item, index) => {
    const parsed = parseImageField(item?.base64, item?.mime);
    if (!parsed) return null;
    parsed.slot = String(item?.slot || `image_${index + 1}`);
    return parsed;
  }).filter(Boolean);
}

function expectedValidationCount(kind, count) {
  if (kind === 'palm' || kind === 'couple') return count === 2;
  if (kind === 'coffee') return count === 3;
  if (kind === 'relationship_chat') return count >= 1 && count <= 3;
  return false;
}

function buildRelationshipChatImageContent(userPrompt, images) {
  const content = [{ type: 'text', text: userPrompt }];

  images.forEach((img, index) => {
    content.push({
      type: 'text',
      text: `Sohbet ekran görüntüsü ${index + 1} (${img.label}):`,
    });
    content.push({
      type: 'image_url',
      image_url: {
        url: `data:${img.mime};base64,${img.base64}`,
        detail: 'high',
      },
    });
  });

  return content;
}

function logTokenUsage(kind, usage) {
  if (!usage) {
    console.log(`[${kind}] token usage: unavailable`);
    return;
  }

  const input_tokens = usage.input_tokens ?? usage.prompt_tokens;
  const output_tokens = usage.output_tokens ?? usage.completion_tokens;
  const total_tokens =
    usage.total_tokens ??
    (input_tokens != null && output_tokens != null
      ? input_tokens + output_tokens
      : undefined);

  console.log(
    `[${kind}] input_tokens=${input_tokens} output_tokens=${output_tokens} total_tokens=${total_tokens}`,
  );
}

function resolveFortuneCompletionTokens(teller, body) {
  let tokens = teller.maxCompletionTokens;
  if (body?.category === 'Tarot Falı') {
    if (teller.id === 'gizem_ana') tokens = Math.max(tokens, 780);
    else if (teller.id === 'medyum_aylin') tokens = Math.max(tokens, 820);
    else tokens = Math.max(tokens, 900);
  }
  return tokens;
}

async function generateFortuneForTeller(openai, teller, structure, body) {
  const systemPrompt = buildFortuneSystemPrompt(teller, structure, body);
  const userPrompt = buildFortuneUserPrompt(body, teller, structure);
  const maxTokens = resolveFortuneCompletionTokens(teller, body);

  let result;
  if (body?.category === 'El Falı') {
    const images = parseFortuneImages(body);
    if (images.length !== 2) {
      throw new Error('El falı için sağ ve sol el fotoğrafları gerekli');
    }
    const completion = await openai.chat.completions.create({
      model: VISION_MODEL,
      temperature: TEMPERATURE,
      max_completion_tokens: maxTokens,
      frequency_penalty: FREQUENCY_PENALTY,
      presence_penalty: PRESENCE_PENALTY,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: buildPalmImageContent(userPrompt, images) },
      ],
    });
    logTokenUsage('palm_fortune', completion.usage);
    result = completion.choices?.[0]?.message?.content?.trim();
    if (!result) throw new Error('Boş AI cevabı');
    result = sanitizeAiResult(result);
  } else {
    result = await generate(
      openai,
      'fortune',
      systemPrompt,
      userPrompt,
      maxTokens,
    );
  }

  const words = countWords(result);
  const endsComplete = /[.!?…]["')\]]*\s*$/.test(result.trim());
  console.log(
    `[fortune] teller=${teller.id} words=${words} max=${teller.maxWords} completion_tokens=${maxTokens} complete_end=${endsComplete}`,
  );
  return result;
}

async function generateCouple(openai, systemPrompt, userPrompt, images) {
  const imageCount = (images.woman ? 1 : 0) + (images.man ? 1 : 0);
  console.log('VISION IMAGE COUNT:', imageCount);

  if (imageCount === 0) {
    throw new Error('Vision analizi için fotoğraf gerekli');
  }

  const userMessage = {
    role: 'user',
    content: buildCoupleImageContent(userPrompt, images.woman, images.man),
  };

  console.log('VISION ANALYSIS START');
  console.log(`VISION MODEL: ${VISION_MODEL}`);
  if (images.woman) {
    console.log(
      `VISION woman image: ${images.woman.label} | mime=${images.woman.mime} | base64=${images.woman.base64.length} chars`,
    );
  }
  if (images.man) {
    console.log(
      `VISION man image: ${images.man.label} | mime=${images.man.mime} | base64=${images.man.base64.length} chars`,
    );
  }

  const completion = await openai.chat.completions.create({
    model: VISION_MODEL,
    temperature: COUPLE_TEMPERATURE,
    max_completion_tokens: COUPLE_MAX_COMPLETION_TOKENS,
    frequency_penalty: COUPLE_FREQUENCY_PENALTY,
    presence_penalty: COUPLE_PRESENCE_PENALTY,
    messages: [
      { role: 'system', content: systemPrompt },
      userMessage,
    ],
  });

  logTokenUsage('couple', completion.usage);

  const result = completion.choices?.[0]?.message?.content?.trim();
  if (!result) {
    throw new Error('Boş AI cevabı');
  }

  console.log('VISION ANALYSIS SUCCESS');
  return sanitizeAiResult(result);
}

async function generateRelationshipAdvice(
  openai,
  systemPrompt,
  userPrompt,
  chatImages,
) {
  if (chatImages.length > 0) {
    console.log('RELATIONSHIP ADVICE VISION IMAGE COUNT:', chatImages.length);
    const completion = await openai.chat.completions.create({
      model: VISION_MODEL,
      temperature: COUPLE_TEMPERATURE,
      max_completion_tokens: COUPLE_MAX_COMPLETION_TOKENS,
      frequency_penalty: COUPLE_FREQUENCY_PENALTY,
      presence_penalty: COUPLE_PRESENCE_PENALTY,
      messages: [
        { role: 'system', content: systemPrompt },
        {
          role: 'user',
          content: buildRelationshipChatImageContent(userPrompt, chatImages),
        },
      ],
    });

    logTokenUsage('relationship_advice', completion.usage);
    const result = completion.choices?.[0]?.message?.content?.trim();
    if (!result) {
      throw new Error('Boş AI cevabı');
    }
    return sanitizeAiResult(result);
  }

  return generate(openai, 'relationship_advice', systemPrompt, userPrompt, 2200);
}

async function generate(
  openai,
  kind,
  systemPrompt,
  userPrompt,
  maxCompletionTokens = FORTUNE_MAX_COMPLETION_TOKENS,
) {
  const completion = await openai.chat.completions.create({
    model: MODEL,
    temperature: TEMPERATURE,
    max_completion_tokens: maxCompletionTokens,
    frequency_penalty: FREQUENCY_PENALTY,
    presence_penalty: PRESENCE_PENALTY,
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userPrompt },
    ],
  });

  logTokenUsage(kind, completion.usage);

  const result = completion.choices?.[0]?.message?.content?.trim();
  if (!result) {
    throw new Error('Boş AI cevabı');
  }
  return sanitizeAiResult(result);
}

const openai = createClient();
const {
  initFirebaseAdmin,
  isFcmReady,
  getFirestore,
  sendNotification,
  notifyFortuneReady,
  notifyAdminsNewManualRequest,
  scheduleFortuneNotify,
} = require('./fcm');
const {
  completeTokenPurchase,
  restorePurchasesForUser,
} = require('./play_billing');
const { parseServiceAccountJson } = require('./service_account_config');

function resolveDeployGitCommit() {
  return (
    process.env.RAILWAY_GIT_COMMIT_SHA ||
    process.env.RAILWAY_GIT_COMMIT ||
    process.env.GIT_COMMIT ||
    'local'
  );
}

function readFirebaseServiceAccountClientEmail() {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!raw?.trim()) return null;
  try {
    return parseServiceAccountJson(String(raw)).client_email;
  } catch (_) {
    return null;
  }
}

function logFirebaseServiceAccountClientEmail() {
  const clientEmail = readFirebaseServiceAccountClientEmail();
  if (clientEmail) {
    console.log(`FIREBASE_SERVICE_ACCOUNT_JSON client_email=${clientEmail}`);
    return clientEmail;
  }
  console.error('FIREBASE_SERVICE_ACCOUNT_JSON client_email=missing');
  return null;
}
const { claimReferral } = require('./referrals');
const {
  requireAuth,
  requireVerifiedEmail,
  requireMatchingUserId,
  requireAdmin,
} = require('./auth_middleware');
const {
  publishDailyHoroscope,
  getDailyHoroscope,
  istanbulDateKey,
  ZODIACS: HOROSCOPE_ZODIACS,
} = require('./daily_horoscope');
const { broadcastNotification } = require('./broadcast_notification');
const { sendAngelCardNotifications } = require('./angel_cards');
const { grantTokensByEmail } = require('./admin_grant_tokens');
const { safeLog, safeError, logFortuneRequest, logCoupleRequest } = require('./safe_log');
const {
  FORTUNE_COLLECTION,
  COUPLE_COLLECTION,
  persistFortuneResult,
} = require('./fortune_result_persist');
const { refundFortuneRequest } = require('./fortune_refund');
const {
  RETENTION_DAYS,
  startFortuneRetentionCleanupLoop,
} = require('./fortune_retention');
const { processAccountDeletionRequest } = require('./account_deletion');

async function saveGeneratedResult(req, result, collection) {
  const requestId = req.body?.requestId;
  if (!requestId) return;
  try {
    await persistFortuneResult({
      uid: req.auth.uid,
      requestId,
      result,
      collection,
    });
  } catch (err) {
    console.error('FORTUNE PERSIST ERROR:', err.message);
  }
}

const app = express();

const corsOptions = {
  origin: '*',
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
};

app.use(cors(corsOptions));
app.options('*', cors(corsOptions));
app.use(express.json({ limit: '20mb' }));
app.use(express.urlencoded({ extended: false }));
app.use(express.static(path.join(__dirname, 'public')));

app.get('/delete-account', (_req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'delete-account.html'));
});

app.post('/delete-account', async (req, res) => {
  try {
    const email = req.body?.email;
    const result = await processAccountDeletionRequest({
      email,
      source: 'web',
    });
    return res.json(result);
  } catch (err) {
    console.error('account deletion error:', err.message);
    return res
      .status(err.statusCode || 500)
      .json({ error: err.message || 'Hesap silme talebi işlenemedi.' });
  }
});

app.get('/health', (_req, res) => {
  res.json({
    status: 'ok',
    openAiConfigured: true,
    fcmConfigured: isFcmReady(),
    model: MODEL,
    visionModel: VISION_MODEL,
    deployGitCommit: resolveDeployGitCommit(),
    firebaseClientEmail: readFirebaseServiceAccountClientEmail(),
  });
});

app.post(
  '/validate-fortune-images',
  requireAuth,
  requireVerifiedEmail,
  async (req, res) => {
    const kind = String(req.body?.kind || '').trim();
    if (!Object.prototype.hasOwnProperty.call(IMAGE_VALIDATION_RULES, kind)) {
      return res.status(400).json({ error: 'Geçersiz fotoğraf doğrulama türü.' });
    }
    const images = parseValidationImages(req.body);
    if (!expectedValidationCount(kind, images.length)) {
      return res.status(400).json({ error: 'Gerekli fotoğrafların tamamını ekleyin.' });
    }

    try {
      const completion = await openai.chat.completions.create({
        model: VISION_MODEL,
        temperature: 0.1,
        max_completion_tokens: 500,
        response_format: { type: 'json_object' },
        messages: [
          {
            role: 'system',
            content: `Sen yalnızca yüklenen fal fotoğraflarının teknik ve kategori uygunluğunu denetleyen bir görsel kalite kontrol sistemisin.
Görsellerden kimlik, etnik köken, sağlık durumu veya kişilik çıkarımı yapma. Fal yorumu üretme.
Kuralları katı ama adil uygula. Emin değilsen valid=false döndür.
Yalnızca şu JSON yapısını döndür:
{"valid":true|false,"message":"Kullanıcıya Türkçe kısa açıklama","issues":[{"slot":"slot adı","code":"kısa_kod","message":"Türkçe sorun"}],"confidence":0.0}`,
          },
          {
            role: 'user',
            content: buildValidationImageContent(kind, images),
          },
        ],
      });
      logTokenUsage('fortune_image_validation', completion.usage);
      const raw = completion.choices?.[0]?.message?.content?.trim();
      if (!raw) throw new Error('Boş doğrulama cevabı');
      const result = JSON.parse(raw);
      const confidence = Math.max(0, Math.min(1, Number(result?.confidence) || 0));
      const valid = result?.valid === true && confidence >= 0.75;
      const message = String(
        confidence < 0.75
          ? 'Fotoğraflar yeterince net doğrulanamadı. Lütfen daha aydınlık ve net fotoğraflar yükleyin.'
          : result?.message ||
              (valid
                ? 'Fotoğraflar uygun.'
                : 'Fotoğraflar bu fal türüne uygun görünmüyor.'),
      ).slice(0, 300);
      return res.json({
        valid,
        message,
        issues: Array.isArray(result?.issues) ? result.issues.slice(0, 3) : [],
        confidence,
      });
    } catch (error) {
      console.error('FORTUNE IMAGE VALIDATION ERROR:', error.message);
      return res.status(503).json({
        error: 'Fotoğraf kontrolü şu anda tamamlanamadı. Lütfen tekrar deneyin.',
      });
    }
  },
);

app.post('/send-notification', requireAuth, async (req, res) => {
  const { token, title, body } = req.body ?? {};
  if (!token || !title || !body) {
    return res.status(400).json({ error: 'token, title ve body gerekli' });
  }

  try {
    const messageId = await sendNotification({ token, title, body });
    if (messageId == null) {
      return res.json({ success: false, reason: 'fcm_not_configured' });
    }
    return res.json({ success: true, messageId });
  } catch (err) {
    console.error('FCM SEND ERROR:', err.message);
    return res.status(500).json({ error: 'Bildirim gönderilemedi' });
  }
});

app.get('/admin/daily-horoscope', requireAuth, requireAdmin, async (req, res) => {
  try {
    const dateKey =
      typeof req.query.date === 'string' && req.query.date.trim()
        ? req.query.date.trim()
        : istanbulDateKey();
    const doc = await getDailyHoroscope(dateKey);
    return res.json({
      date: dateKey,
      zodiacs: HOROSCOPE_ZODIACS,
      horoscope: doc,
    });
  } catch (err) {
    console.error('DAILY HOROSCOPE GET ERROR:', err.message);
    return res.status(500).json({ error: 'Günlük burç okunamadı' });
  }
});

app.post(
  '/admin/daily-horoscope',
  requireAuth,
  requireAdmin,
  async (req, res) => {
    try {
      const { signs, date, sendNotifications } = req.body ?? {};
      const result = await publishDailyHoroscope({
        signs,
        adminUid: req.auth.uid,
        dateKey: date,
        sendNotifications: sendNotifications !== false,
      });
      console.log(
        `DAILY HOROSCOPE PUBLISHED date=${result.date} by=${req.auth.uid}`,
      );
      return res.json({ success: true, ...result });
    } catch (err) {
      console.error('DAILY HOROSCOPE PUBLISH ERROR:', err.message);
      if (
        err.code === 'invalid_signs' ||
        err.code === 'empty_sign' ||
        err.code === 'sign_too_long'
      ) {
        return res.status(400).json({
          error: err.message,
          code: err.code,
          zodiac: err.zodiac,
        });
      }
      return res.status(500).json({ error: 'Günlük burç yayınlanamadı' });
    }
  },
);

app.post(
  '/admin/broadcast-notification',
  requireAuth,
  requireAdmin,
  async (req, res) => {
    try {
      const { title, body } = req.body ?? {};
      const result = await broadcastNotification({
        title,
        body,
        adminUid: req.auth.uid,
      });
      console.log(
        `ADMIN BROADCAST sent=${result.sent} failed=${result.failed} by=${req.auth.uid}`,
      );
      return res.json({ success: true, ...result });
    } catch (err) {
      console.error('ADMIN BROADCAST ERROR:', err.message);
      if (
        err.code === 'invalid_title' ||
        err.code === 'invalid_body' ||
        err.code === 'title_too_long' ||
        err.code === 'body_too_long'
      ) {
        return res.status(400).json({ error: err.message, code: err.code });
      }
      if (err.code === 'fcm_not_configured') {
        return res.status(503).json({ error: err.message, code: err.code });
      }
      return res.status(500).json({ error: 'Toplu bildirim gönderilemedi' });
    }
  },
);

app.post(
  '/admin/angel-cards',
  requireAuth,
  requireAdmin,
  async (req, res) => {
    try {
      const { title, cards, groupSize } = req.body ?? {};
      const result = await sendAngelCardNotifications({
        title,
        cards,
        groupSize,
        adminUid: req.auth.uid,
      });
      console.log(
        `ADMIN ANGEL CARDS sent=${result.sent} failed=${result.failed} ` +
          `groups=${result.groupCount} size=${result.groupSize} ` +
          `cards=${result.cardCount} by=${req.auth.uid}`,
      );
      return res.json({ success: true, ...result });
    } catch (err) {
      console.error('ADMIN ANGEL CARDS ERROR:', err.message);
      if (
        err.code === 'invalid_title' ||
        err.code === 'title_too_long' ||
        err.code === 'invalid_cards' ||
        err.code === 'too_few_cards' ||
        err.code === 'too_many_cards' ||
        err.code === 'card_too_long' ||
        err.code === 'invalid_group_size'
      ) {
        return res.status(400).json({ error: err.message, code: err.code });
      }
      if (err.code === 'fcm_not_configured') {
        return res.status(503).json({ error: err.message, code: err.code });
      }
      return res.status(500).json({ error: 'Melek kartı gönderilemedi' });
    }
  },
);

app.post(
  '/admin/grant-tokens',
  requireAuth,
  requireAdmin,
  async (req, res) => {
    try {
      const { email, amount } = req.body ?? {};
      const result = await grantTokensByEmail({
        email,
        amount,
        adminUid: req.auth.uid,
      });
      console.log(
        `ADMIN GRANT TOKENS email=${result.email} +${result.amount} ` +
          `${result.before}->${result.after} by=${req.auth.uid}`,
      );
      return res.json({ success: true, ...result });
    } catch (err) {
      console.error('ADMIN GRANT TOKENS ERROR:', err.message);
      if (
        err.code === 'invalid_email' ||
        err.code === 'invalid_amount' ||
        err.code === 'amount_too_large' ||
        err.code === 'user_not_found' ||
        err.code === 'user_doc_missing'
      ) {
        return res.status(400).json({ error: err.message, code: err.code });
      }
      return res.status(500).json({ error: 'Jeton yüklenemedi' });
    }
  },
);

app.post(
  '/notify-ready',
  requireAuth,
  requireMatchingUserId,
  async (req, res) => {
  const { userId, type, readingId } = req.body ?? {};
  if (!userId || !type) {
    return res.status(400).json({ error: 'userId ve type gerekli' });
  }

  try {
    const result = await notifyFortuneReady(userId, type, readingId);
    return res.json(result);
  } catch (err) {
    console.error('FCM NOTIFY READY ERROR:', err.message);
    if (err.code === 'invalid_type') {
      return res.status(400).json({ error: err.message });
    }
    return res.status(500).json({ error: 'Hazır bildirimi gönderilemedi' });
  }
},
);

app.post('/notify-admin-manual-request', requireAuth, async (req, res) => {
  const { requestId, readerName, categoryLabel, clientName } = req.body ?? {};
  if (!requestId || typeof requestId !== 'string' || !requestId.trim()) {
    return res.status(400).json({ error: 'requestId gerekli' });
  }

  const db = getFirestore();
  if (!db) {
    return res.status(503).json({ error: 'Firebase Admin yapılandırılmadı' });
  }

  try {
    const doc = await db
      .collection('manual_fortune_requests')
      .doc(requestId.trim())
      .get();
    if (!doc.exists) {
      return res.status(404).json({ error: 'Talep bulunamadı' });
    }

    const data = doc.data() || {};
    if (data.userId !== req.auth.uid) {
      return res.status(403).json({ error: 'Yetkisiz' });
    }
    if (data.status !== 'pending') {
      return res.json({ success: false, reason: 'not_pending' });
    }

    const result = await notifyAdminsNewManualRequest({
      requestId: requestId.trim(),
      readerName: readerName || data.readerName,
      categoryLabel: categoryLabel || data.fortuneType,
      clientName: clientName || data.name,
    });
    return res.json(result);
  } catch (err) {
    console.error('FCM ADMIN MANUAL REQUEST ERROR:', err.message);
    return res.status(500).json({ error: 'Admin bildirimi gönderilemedi' });
  }
});

app.post(
  '/schedule-notify',
  requireAuth,
  requireMatchingUserId,
  async (req, res) => {
  const { userId, type, notifyAt, readingId } = req.body ?? {};
  if (!userId || !type || !notifyAt) {
    return res.status(400).json({ error: 'userId, type ve notifyAt gerekli' });
  }

  try {
    const result = await scheduleFortuneNotify(userId, type, notifyAt, readingId);
    return res.json(result);
  } catch (err) {
    console.error('FCM SCHEDULE ERROR:', err.message);
    if (err.code === 'invalid_type' || err.code === 'invalid_notify_at') {
      return res.status(400).json({ error: err.message });
    }
    return res.status(500).json({ error: 'Bildirim planlanamadı' });
  }
},
);

app.post(
  '/billing/tokens/complete',
  requireAuth,
  requireVerifiedEmail,
  requireMatchingUserId,
  async (req, res) => {
    try {
      const result = await completeTokenPurchase(req.auth, req.body ?? {});
      return res.json(result);
    } catch (err) {
      console.error('token billing error:', err.message);
      return res
        .status(err.statusCode || 500)
        .json({ error: err.message || 'Satın alma doğrulanamadı' });
    }
  },
);

app.post(
  '/referrals/claim',
  requireAuth,
  requireVerifiedEmail,
  async (req, res) => {
    const { referralCode } = req.body ?? {};
    if (!referralCode || typeof referralCode !== 'string' || !referralCode.trim()) {
      return res.status(400).json({ error: 'referralCode gerekli' });
    }

    try {
      const result = await claimReferral({
        uid: req.auth.uid,
        referralCode,
      });

      if (!result.ok) {
        const status =
          result.code === 'already_claimed' || result.code === 'self_referral'
            ? 409
            : result.code === 'not_found'
              ? 404
              : 400;
        return res.status(status).json({
          ok: false,
          code: result.code,
          rewardTokens: 0,
        });
      }

      return res.json({
        ok: true,
        code: 'success',
        rewardTokens: result.rewardTokens,
        inviterUid: result.inviterUid,
      });
    } catch (err) {
      console.error('referral claim error:', err.message);
      return res
        .status(err.statusCode || 500)
        .json({ error: err.message || 'Referans ödülü işlenemedi' });
    }
  },
);

app.post(
  '/billing/restore',
  requireAuth,
  requireVerifiedEmail,
  async (req, res) => {
    try {
      const result = await restorePurchasesForUser(req.auth.uid);
      return res.json(result);
    } catch (err) {
      console.error('restore billing error:', err.message);
      return res
        .status(err.statusCode || 500)
        .json({ error: err.message || 'Restore işlemi tamamlanamadı' });
    }
  },
);

app.post(
  '/generate-yes-no',
  requireAuth,
  requireVerifiedEmail,
  async (req, res) => {
    const question = String(req.body?.question || '').trim();
    const cards = Array.isArray(req.body?.cards) ? req.body.cards : [];
    const paymentMethod = req.body?.paymentMethod;
    if (question.length < 5 || question.length > 500) {
      return res.status(400).json({ error: 'Soru 5-500 karakter olmalı' });
    }
    if (cards.length !== 3 || !cards.every((card) =>
      card && typeof card.id === 'string' && card.id.trim().length > 0
    )) {
      return res.status(400).json({ error: 'Tam olarak 3 tarot kartı gerekli' });
    }
    if (paymentMethod !== 'token' && paymentMethod !== 'ad') {
      return res.status(400).json({ error: 'Geçersiz ödeme yöntemi' });
    }

    let chargedToken = false;
    let chargedUserRef = null;
    try {
      if (paymentMethod === 'token') {
        const db = getFirestore();
        if (!db) {
          return res.status(503).json({ error: 'Jeton servisi kullanılamıyor' });
        }
        chargedUserRef = db.collection('users').doc(req.auth.uid);
        await db.runTransaction(async (transaction) => {
          const snapshot = await transaction.get(chargedUserRef);
          if (!snapshot.exists) {
            const error = new Error('Kullanıcı kaydı bulunamadı');
            error.statusCode = 404;
            throw error;
          }
          const balance = Number(snapshot.data()?.tokens || 0);
          if (!Number.isFinite(balance) || balance < 20) {
            const error = new Error('Bu fal için 20 jeton gerekiyor');
            error.statusCode = 402;
            throw error;
          }
          transaction.update(chargedUserRef, {
            tokens: Math.floor(balance) - 20,
          });
        });
        chargedToken = true;
      }

      const cardLines = cards.map((card, index) =>
        `${index + 1}. ${String(card.id).trim()} (${card.isReversed ? 'ters' : 'düz'})`
      ).join('\n');
      const result = await generate(
        openai,
        'yes_no',
        'Kullanıcının sorusuna verilen 3 tarot kartını birlikte değerlendirerek son derece kısa ve net yanıt ver. Yanıt tam olarak tek satır olmalı ve yalnızca "EVET — kısa cümle" veya "HAYIR — kısa cümle" biçiminde yazılmalı. BELİRSİZ deme; mutlaka EVET ya da HAYIR seç. Açıklama en fazla 18 kelime olsun. Kart isimlerini tek tek yorumlama; başlık, madde, paragraf, "Genel yorum" veya ek açıklama kullanma. Kesin gelecek garantisi verme.',
        `Soru: ${question}\nKartlar:\n${cardLines}`,
        80,
      );

      return res.json({ result });
    } catch (err) {
      console.error('generate-yes-no error:', err.message);
      if (chargedToken && chargedUserRef) {
        try {
          await getFirestore().runTransaction(async (transaction) => {
            const snapshot = await transaction.get(chargedUserRef);
            if (!snapshot.exists) return;
            const balance = Number(snapshot.data()?.tokens || 0);
            transaction.update(chargedUserRef, {
              tokens: Math.floor(balance) + 20,
            });
          });
        } catch (refundError) {
          console.error('generate-yes-no refund error:', refundError.message);
        }
      }
      return res
        .status(err.statusCode || 500)
        .json({ error: err.statusCode ? err.message : 'Fal yorumlanamadı' });
    }
  },
);

app.post(
  '/generate-fortune',
  requireAuth,
  requireVerifiedEmail,
  async (req, res) => {
  const { categoryType, inputData, category, name, age, zodiac, intention, tellerId } =
    req.body ?? {};

  if (categoryType) {
    const validation = validateAutoCategoryInput(categoryType, inputData);
    if (!validation.ok) {
      return res.status(400).json({ error: validation.error });
    }

    try {
      if (categoryType === 'relationship_advice') {
        const chatImages = parseChatImages(req.body);
        console.log(
          `RELATIONSHIP ADVICE REQUEST images=${chatImages.length}`,
        );
        const systemPrompt = buildRelationshipAdviceSystemPrompt(
          chatImages.length > 0,
        );
        const userPrompt = buildRelationshipAdviceUserPrompt(
          inputData,
          chatImages.length > 0,
        );
        const result = await generateRelationshipAdvice(
          openai,
          systemPrompt,
          userPrompt,
          chatImages,
        );
        await saveGeneratedResult(req, result);
        return res.json({ result });
      }

      const persona = pickFortunePersona();
      const structure = pickFortuneStructure();
      console.log(`AUTO CATEGORY REQUEST: ${categoryType}`);

      const result = await generate(
        openai,
        'fortune',
        buildAutoCategorySystemPrompt(categoryType, persona),
        buildAutoCategoryUserPrompt(categoryType, inputData, persona, structure),
        1800,
      );
      await saveGeneratedResult(req, result);
      return res.json({ result });
    } catch (err) {
      console.error(`generate-fortune auto category error (${categoryType}):`, err.message);
      return res.status(500).json({ error: 'AI yanıtı üretilemedi' });
    }
  }

  if (!category || !name || !age || !zodiac || !intention) {
    return res.status(400).json({ error: 'Eksik alanlar' });
  }

  try {
    const teller = getFortuneTeller(
      category === 'El Falı' ? 'pinar_baci' : tellerId || 'gizem_ana',
    );
    const structure = pickFortuneStructureForTeller(teller.id);
    logFortuneRequest(teller.id, structure.id, `max=${teller.maxWords}`);

    const result = await generateFortuneForTeller(
      openai,
      teller,
      structure,
      req.body,
    );
    await saveGeneratedResult(req, result);
    return res.json({ result });
  } catch (err) {
    console.error('generate-fortune error:', err.message);
    return res.status(500).json({ error: 'AI yanıtı üretilemedi' });
  }
},
);

app.post(
  '/fortune/refund',
  requireAuth,
  requireVerifiedEmail,
  async (req, res) => {
    const { requestId, type } = req.body ?? {};
    if (!requestId) {
      return res.status(400).json({ error: 'requestId gerekli' });
    }

    const collection =
      type === 'couple' ? COUPLE_COLLECTION : FORTUNE_COLLECTION;

    try {
      const result = await refundFortuneRequest({
        uid: req.auth.uid,
        requestId,
        collection,
      });
      if (!result.ok && result.reason === 'forbidden') {
        return res.status(403).json({ error: 'Yetkisiz işlem' });
      }
      if (!result.ok && result.reason === 'not_found') {
        return res.status(404).json({ error: 'Kayıt bulunamadı' });
      }
      return res.json(result);
    } catch (err) {
      console.error('fortune refund error:', err.message);
      return res.status(500).json({ error: 'Jeton iadesi yapılamadı' });
    }
  },
);

app.post(
  '/generate-couple',
  requireAuth,
  requireVerifiedEmail,
  async (req, res) => {
  const {
    womanName,
    womanAge,
    womanZodiac,
    manName,
    manAge,
    manZodiac,
    womanImageBase64,
    manImageBase64,
    womanImageMime,
    manImageMime,
    womanImageName,
    manImageName,
  } = req.body ?? {};

  if (
    !womanName ||
    !womanAge ||
    !womanZodiac ||
    !manName ||
    !manAge ||
    !manZodiac
  ) {
    return res.status(400).json({ error: 'Eksik alanlar' });
  }

  const womanImage = parseImageField(womanImageBase64, womanImageMime);
  const manImage = parseImageField(manImageBase64, manImageMime);
  if (womanImage) womanImage.label = womanImageName || womanName;
  if (manImage) manImage.label = manImageName || manName;

  logCoupleRequest(!!womanImage, !!manImage);

  if (!womanImage || !manImage) {
    safeError('generate-couple: fotoğraflar eksik veya parse edilemedi');
    return res.status(400).json({
      error: 'Kadın ve erkek fotoğrafları gerekli ve geçerli olmalı',
    });
  }

  const hasPhotos = true;
  const requestId = newRequestId();
  const timestamp = new Date().toISOString();
  const compatibilityPercent = calculateCompatibilityPercent(req.body, hasPhotos);

  safeLog('COUPLE COMPATIBILITY PERCENT:', compatibilityPercent);
  safeLog('COUPLE requestId:', requestId);

  try {
    const persona = pickFortunePersona();
    const structure = pickCoupleStructure();
    console.log(
      `[couple] persona=${persona.id} (${persona.name}) | structure=${structure.id}`,
    );

    const raw = await generateCouple(
      openai,
      buildCoupleSystemPrompt(persona, structure),
      buildCoupleUserPrompt(
        req.body,
        hasPhotos,
        compatibilityPercent,
        requestId,
        timestamp,
        persona,
        structure,
      ),
      { woman: womanImage, man: manImage },
    );
    const result = ensureCompatibilityHeader(
      sanitizeAiResult(raw),
      compatibilityPercent,
    );
    await saveGeneratedResult(req, result, COUPLE_COLLECTION);
    return res.json({ result });
  } catch (err) {
    console.error('generate-couple error:', err.message);
    return res.status(500).json({ error: 'AI yanıtı üretilemedi' });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  const fcmReady = initFirebaseAdmin();
  logFirebaseServiceAccountClientEmail();
  console.log(`DEPLOY git_commit=${resolveDeployGitCommit()}`);
  console.log(`Falora AI backend http://0.0.0.0:${PORT}`);
  console.log(`Yerel erişim: http://127.0.0.1:${PORT}`);
  console.log(`LAN erişim: http://192.168.1.101:${PORT}`);
  console.log(
    `Model: ${MODEL} | Vision: ${VISION_MODEL} | fal max_completion_tokens: ${FORTUNE_MAX_COMPLETION_TOKENS} | çift max_completion_tokens: ${COUPLE_MAX_COMPLETION_TOKENS}`,
  );
  console.log(
    `temperature: ${TEMPERATURE} | frequency_penalty: ${FREQUENCY_PENALTY} | presence_penalty: ${PRESENCE_PENALTY}`,
  );
  console.log(
    `couple: temperature=${COUPLE_TEMPERATURE} frequency_penalty=${COUPLE_FREQUENCY_PENALTY} presence_penalty=${COUPLE_PRESENCE_PENALTY}`,
  );
  console.log('OpenAI yapılandırması hazır.');
  console.log(
    `Google Play Billing package: ${process.env.GOOGLE_PLAY_PACKAGE_NAME || 'com.rrlime.falora'}`,
  );
  console.log(
    process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON ||
      process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_PATH
      ? 'Google Play servis hesabı env tanımlı.'
      : 'Google Play servis hesabı env eksik. Billing doğrulaması canlıda çalışmaz.',
  );
  if (fcmReady) {
    console.log('Firebase Admin aktif (auth + FCM + Firestore).');
    startFortuneRetentionCleanupLoop();
    console.log(`Fal kayit saklama suresi: ${RETENTION_DAYS} gun.`);
  } else {
    console.error(
      'Firebase Admin kapalı — Railway Variables içine FIREBASE_SERVICE_ACCOUNT_JSON ekleyin.',
    );
  }
});
