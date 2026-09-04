const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

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

const PHOTO_UPLOAD_KINDS = new Set([
  'palm',
  'coffee',
  'couple',
  'relationship_chat',
]);

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
  notifyAdminsNewTokenPurchase,
  notifyAdminsForProblemReport,
  notifyUserSupportReply,
  notifyAdminsSupportReply,
  scheduleFortuneNotify,
} = require('./fcm');
const {
  completeTokenPurchase,
  restorePurchasesForUser,
} = require('./play_billing');
const bulletin = require('./bulletin');
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

async function failGeneratedRequest(req, collection = FORTUNE_COLLECTION) {
  const requestId = req.body?.requestId;
  if (!requestId || !req.auth?.uid) return;
  try {
    const db = getFirestore();
    if (!db) return;
    const ref = db.collection(collection).doc(String(requestId).trim());
    const snap = await ref.get();
    if (!snap.exists || snap.data()?.userId !== req.auth.uid) return;
    const result = String(snap.data()?.result || '').trim();
    if (result) return;
    await ref.update({ status: 'error' });
    const refund = await refundFortuneRequest({
      uid: req.auth.uid,
      requestId,
      collection,
    });
    console.error(
      'FORTUNE FAILED AND REFUNDED | id=',
      requestId,
      '| reason=',
      refund.reason,
      '| amount=',
      refund.amount,
    );
  } catch (persistError) {
    console.error('FORTUNE FAILURE PERSIST ERROR:', persistError.message);
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
    if (!PHOTO_UPLOAD_KINDS.has(kind)) {
      return res.status(400).json({ error: 'Geçersiz fotoğraf doğrulama türü.' });
    }
    const images = parseValidationImages(req.body);
    if (!expectedValidationCount(kind, images.length)) {
      return res.status(400).json({ error: 'Gerekli fotoğrafların tamamını ekleyin.' });
    }

    return res.json({
      valid: true,
      message: 'Fotoğraflar alındı.',
      issues: [],
      confidence: 1,
    });
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
  '/admin/editorial-ai',
  requireAuth,
  requireAdmin,
  async (req, res) => {
    try {
      const type = String(req.body?.type || '').trim();
      const count = Math.min(50, Math.max(2, Number(req.body?.count) || 7));
      const date = String(req.body?.date || new Date().toISOString().slice(0, 10));
      const nonce = newRequestId();
      let system;
      let user;
      if (type === 'horoscope') {
        system = `Sen Tombik Teyze uygulamasının Türkçe editörüsün. Tam olarak 12 burç için günlük, birbirinden belirgin biçimde farklı, klişesiz ve burcun karakterine özel yorumlar yaz. HER BURÇ YORUMU 350-380 KELİME OLMALIDIR; kısa özet yazma. Yorumu akıcı paragraflara böl; duygu, ilişki, gündelik yaşam, içsel farkındalık ve uygulanabilir önerileri burca özgü biçimde işle. Kesin gelecek, sağlık veya finans vaadi verme. Aynı cümle kalıbını iki burçta kullanma. Her değer yalnızca tamamlanmış düz metin cümlelerinden oluşmalı ve son cümle nokta, ünlem veya soru işaretiyle bitmelidir. Nesne, tema etiketi, anahtar, markdown veya yer tutucu kullanma. Yalnızca JSON döndür: {"signs":{"Koç":"...","Boğa":"...","İkizler":"...","Yengeç":"...","Aslan":"...","Başak":"...","Terazi":"...","Akrep":"...","Yay":"...","Oğlak":"...","Kova":"...","Balık":"..."}}`;
        user = `Tarih: ${date}. Üretim kimliği: ${nonce}. Bugüne özgü farklı temalar ve somut, kişisel hissettiren öneriler kullan.`;
      } else if (type === 'angel_cards') {
        system = `Sen Tombik Teyze uygulamasının Türkçe editörüsün. Kullanıcıya kişisel hitap eden, birbirini tekrar etmeyen, sıcak ama abartısız melek kartı mesajları yaz. HER KART BOŞLUKLAR DAHİL 320-420 KARAKTER OLMALIDIR; 300 karakterin altında bırakma. Birkaç kısa ve tamamlanmış cümle kullan; gereksiz uzatma ve tekrar yapma. Her kartta ayrı bir ana tema, küçük bir farkındalık, uygulanabilir tek öneri ve sakin bir kapanış bulunmalı. Kesin gelecek, sağlık veya finans vaadi verme. cards dizisinin her elemanı SADECE DÜZ METİN STRING olmalıdır; nesne, theme/message anahtarı, etiket, markdown, süslü parantez veya yer tutucu asla kullanma. Her kartın son cümlesini mutlaka nokta, ünlem veya soru işaretiyle tamamla. Yalnızca JSON döndür: {"title":"...","cards":["...","..."]}`;
        user = `Tarih: ${date}. Üretim kimliği: ${nonce}. Tam olarak ${count} farklı kart üret; her kartın teması ve açılış cümlesi farklı olsun.`;
      } else {
        return res.status(400).json({ error: 'Geçersiz içerik türü' });
      }
      const complete = (text) => /[.!?…]$/u.test(text.trim());
      const validate = (parsed) => {
        if (type === 'angel_cards') {
          if (!Array.isArray(parsed?.cards) || parsed.cards.length !== count) return false;
          return parsed.cards.every((card) =>
            typeof card === 'string' &&
            card.trim().length >= 250 &&
            complete(card) &&
            !/[{}]/u.test(card));
        }
        const signs = parsed?.signs;
        const names = ['Koç','Boğa','İkizler','Yengeç','Aslan','Başak','Terazi','Akrep','Yay','Oğlak','Kova','Balık'];
        return signs && names.every((sign) =>
          typeof signs[sign] === 'string' &&
          signs[sign].trim().length >= 500 &&
          complete(signs[sign]) &&
          !/[{}]/u.test(signs[sign]));
      };
      for (let attempt = 0; attempt < 2; attempt += 1) {
        const completion = await openai.chat.completions.create({
          model: MODEL,
          temperature: attempt === 0 ? 1 : 0.75,
          frequency_penalty: 0.65,
          presence_penalty: 0.45,
          max_tokens: type === 'horoscope' ? 12000 : 16000,
          response_format: { type: 'json_object' },
          messages: [
            { role: 'system', content: system },
            {
              role: 'user',
              content: attempt === 0
                ? user
                : `${user} Önceki çıktı biçim veya uzunluk kontrolünü geçemedi. Bu kez kelimeleri say, yalnızca string değerler kullan ve bütün son cümleleri tamamla.`,
            },
          ],
        });
        const parsed = JSON.parse(completion.choices?.[0]?.message?.content || '{}');
        if (validate(parsed)) return res.json(parsed);
      }
      return res.status(502).json({
        error: 'AI metni eksik veya hatalı biçimde oluşturdu. Lütfen yeniden deneyin.',
      });
    } catch (err) {
      console.error('ADMIN EDITORIAL AI ERROR:', err.message);
      return res.status(500).json({ error: 'AI içeriği oluşturulamadı' });
    }
  },
);

app.post(
  '/admin/manual-reader-avatar-ai',
  requireAuth,
  requireAdmin,
  async (req, res) => {
    try {
      const name = String(req.body?.name || '').trim().slice(0, 50);
      const title = String(req.body?.title || '').trim().slice(0, 80);
      const gender = String(req.body?.gender || 'unspecified').trim();
      if (!name) return res.status(400).json({ error: 'Falcı ismi zorunludur.' });
      if (!['female', 'male', 'unspecified'].includes(gender)) {
        return res.status(400).json({ error: 'Geçersiz cinsiyet seçimi.' });
      }
      const presentation = gender === 'female'
        ? 'adult Turkish woman'
        : gender === 'male'
          ? 'adult Turkish man'
          : 'adult Turkish person with a gender-neutral presentation';
      const result = await openai.images.generate({
        model: process.env.OPENAI_IMAGE_MODEL || 'gpt-image-2',
        size: '1024x1024',
        quality: 'low',
        output_format: 'jpeg',
        prompt: `Create an original square profile portrait for a fictional fortune reader named ${name}. The character is an ${presentation}. Professional head-and-shoulders composition, looking toward the camera, warm trustworthy expression. Tombik Teyze visual world: refined Anatolian warmth, subtle mystical atmosphere, antique gold, parchment beige and deep brown palette, soft cinematic studio light, elegant handcrafted details. ${title ? `Their role is: ${title}.` : ''} No text, no lettering, no logo, no watermark, no cards covering the face, no resemblance to a real celebrity. High quality app avatar, centered face, uncluttered background.`,
      });
      const imageBase64 = result.data?.[0]?.b64_json;
      if (!imageBase64) throw new Error('Image API returned no image data');
      return res.json({ imageBase64, mimeType: 'image/jpeg' });
    } catch (err) {
      console.error('ADMIN READER AVATAR AI ERROR:', err.message);
      return res.status(500).json({ error: 'AI profil görseli oluşturulamadı.' });
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
        err.code === 'card_too_short' ||
        err.code === 'card_incomplete' ||
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
      readerId: data.readerId,
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

app.post('/notify-admin-problem-report', requireAuth, async (req, res) => {
  const reportId = req.body?.reportId?.toString().trim();
  if (!reportId) return res.status(400).json({ error: 'reportId gerekli' });

  const db = getFirestore();
  if (!db) {
    return res.status(503).json({ error: 'Firebase Admin yapılandırılmadı' });
  }

  try {
    const doc = await db.collection('problem_reports').doc(reportId).get();
    if (!doc.exists) return res.status(404).json({ error: 'Bildirim bulunamadı' });
    const data = doc.data() || {};
    if (data.userId !== req.auth.uid) {
      return res.status(403).json({ error: 'Yetkisiz' });
    }
    if (data.status !== 'open') {
      return res.json({ success: false, reason: 'not_open' });
    }
    const result = await notifyAdminsForProblemReport(reportId);
    return res.json(result);
  } catch (err) {
    console.error('FCM ADMIN PROBLEM REPORT ERROR:', err.message);
    return res.status(500).json({ error: 'Admin bildirimi gönderilemedi' });
  }
});

app.post('/support/messages', requireAuth, async (req, res) => {
  const reportId = String(req.body?.reportId || '').trim();
  const text = String(req.body?.text || '').trim();
  if (!reportId || !text || text.length > 1500) {
    return res.status(400).json({ error: 'Mesaj 1-1500 karakter olmalı.' });
  }
  const db = getFirestore();
  if (!db) return res.status(503).json({ error: 'Destek servisi hazır değil.' });
  try {
    const reportRef = db.collection('problem_reports').doc(reportId);
    const report = await reportRef.get();
    if (!report.exists) return res.status(404).json({ error: 'Destek talebi bulunamadı.' });
    const data = report.data() || {};
    if (data.status !== 'open') {
      return res.status(409).json({ error: 'Bu destek görüşmesi kapatılmış.' });
    }
    const { isAdminUser } = require('./admin_config');
    const adminSender = isAdminUser(req.auth.uid, req.auth.email);
    if (!adminSender && data.userId !== req.auth.uid) {
      return res.status(403).json({ error: 'Bu görüşmeye erişim yetkiniz yok.' });
    }
    const messageRef = await reportRef.collection('messages').add({
      text,
      senderRole: adminSender ? 'admin' : 'user',
      senderId: req.auth.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    const notification = adminSender
      ? await notifyUserSupportReply({ userId: data.userId, reportId })
      : await notifyAdminsSupportReply({
          reportId,
          displayName: data.displayName,
        });
    return res.status(201).json({
      success: true,
      messageId: messageRef.id,
      notification,
    });
  } catch (err) {
    console.error('SUPPORT MESSAGE ERROR:', err.message);
    return res.status(500).json({ error: 'Destek mesajı gönderilemedi.' });
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
      if (!result.alreadyProcessed) {
        try {
          await notifyAdminsNewTokenPurchase({
            productId: req.body?.productId,
            tokensGranted: result.tokensGranted,
            userEmail: req.auth.email,
            orderId: result.orderId,
          });
        } catch (notifyError) {
          // Admin push sorunu başarılı satın alma yanıtını bozmamalı.
          console.error('FCM ADMIN TOKEN PURCHASE ERROR:', notifyError.message);
        }
      }
      return res.json(result);
    } catch (err) {
      console.error('token billing error:', err.message);
      return res
        .status(err.statusCode || 500)
        .json({ error: err.message || 'Satın alma doğrulanamadı' });
    }
  },
);

function bulletinError(res, err) {
  console.error('BULLETIN ERROR:', err.message);
  return res.status(err.statusCode || 500).json({
    error: err.message || 'Bülten işlemi tamamlanamadı.',
    code: err.code || 'bulletin_error',
  });
}
app.get('/bulletin/feed',requireAuth,async(req,res)=>{try{return res.json(await bulletin.feed(req.auth.uid,req.query));}catch(e){return bulletinError(res,e);}});
app.get('/bulletin/posts/:id',requireAuth,async(req,res)=>{try{return res.json(await bulletin.detail(req.auth.uid,req.params.id,req.query.commentCursor));}catch(e){return bulletinError(res,e);}});
app.post('/bulletin/posts/:id/like',requireAuth,requireVerifiedEmail,async(req,res)=>{try{return res.json(await bulletin.toggleLike(req.auth.uid,req.params.id));}catch(e){return bulletinError(res,e);}});
app.post('/bulletin/posts/:id/comments',requireAuth,requireVerifiedEmail,async(req,res)=>{try{return res.status(201).json(await bulletin.addComment(req.auth.uid,req.params.id,req.body||{}));}catch(e){return bulletinError(res,e);}});
app.post('/bulletin/comments/report',requireAuth,requireVerifiedEmail,async(req,res)=>{try{return res.status(201).json(await bulletin.reportComment(req.auth.uid,req.body||{}));}catch(e){return bulletinError(res,e);}});
app.post('/bulletin/blocks',requireAuth,requireVerifiedEmail,async(req,res)=>{try{return res.status(201).json(await bulletin.block(req.auth.uid,req.body?.userId));}catch(e){return bulletinError(res,e);}});
app.post('/bulletin/content-requests',requireAuth,requireVerifiedEmail,async(req,res)=>{try{return res.status(201).json(await bulletin.submitContentRequest(req.auth.uid,req.body||{}));}catch(e){return bulletinError(res,e);}});
app.get('/bulletin/polls/active',requireAuth,async(req,res)=>{try{return res.json(await bulletin.activePoll(req.auth.uid));}catch(e){return bulletinError(res,e);}});
app.post('/bulletin/polls/:id/vote',requireAuth,requireVerifiedEmail,async(req,res)=>{try{return res.json(await bulletin.votePoll(req.auth.uid,req.params.id,req.body?.optionId));}catch(e){return bulletinError(res,e);}});
app.get('/admin/bulletin/overview',requireAuth,requireAdmin,async(_req,res)=>{try{return res.json(await bulletin.adminOverview());}catch(e){return bulletinError(res,e);}});
app.get('/admin/bulletin/posts',requireAuth,requireAdmin,async(req,res)=>{try{return res.json({items:await bulletin.adminPosts(req.query)});}catch(e){return bulletinError(res,e);}});
app.post('/admin/bulletin/posts',requireAuth,requireAdmin,async(req,res)=>{try{return res.status(201).json(await bulletin.adminSavePost(req.auth.uid,null,req.body||{}));}catch(e){return bulletinError(res,e);}});
app.post('/admin/bulletin/posts/:id',requireAuth,requireAdmin,async(req,res)=>{try{return res.json(await bulletin.adminSavePost(req.auth.uid,req.params.id,req.body||{}));}catch(e){return bulletinError(res,e);}});
app.post('/admin/bulletin/posts/:id/image',requireAuth,requireAdmin,async(req,res)=>{try{return res.json(await bulletin.adminUploadImage(req.params.id,req.body?.image));}catch(e){return bulletinError(res,e);}});
app.post('/admin/bulletin/posts/:id/action',requireAuth,requireAdmin,async(req,res)=>{try{return res.json(await bulletin.adminPostAction(req.auth.uid,req.params.id,req.body?.action));}catch(e){return bulletinError(res,e);}});
app.get('/admin/bulletin/polls',requireAuth,requireAdmin,async(_req,res)=>{try{return res.json({items:await bulletin.adminPolls()});}catch(e){return bulletinError(res,e);}});
app.post('/admin/bulletin/polls',requireAuth,requireAdmin,async(req,res)=>{try{return res.status(201).json(await bulletin.adminCreatePoll(req.auth.uid,req.body||{}));}catch(e){return bulletinError(res,e);}});
app.post('/admin/bulletin/polls/:id/action',requireAuth,requireAdmin,async(req,res)=>{try{return res.json(await bulletin.adminPollAction(req.params.id,req.body?.action,req.body?.optionId));}catch(e){return bulletinError(res,e);}});
app.get('/admin/bulletin/reports',requireAuth,requireAdmin,async(_req,res)=>{try{return res.json({items:await bulletin.adminReports()});}catch(e){return bulletinError(res,e);}});
app.get('/admin/bulletin/comments',requireAuth,requireAdmin,async(_req,res)=>{try{return res.json({items:await bulletin.adminComments()});}catch(e){return bulletinError(res,e);}});
app.post('/admin/bulletin/comments/action',requireAuth,requireAdmin,async(req,res)=>{try{return res.json(await bulletin.adminCommentAction(req.auth.uid,req.body||{}));}catch(e){return bulletinError(res,e);}});
app.post('/admin/bulletin/reports/action',requireAuth,requireAdmin,async(req,res)=>{try{return res.json(await bulletin.adminReportAction(req.auth.uid,req.body||{}));}catch(e){return bulletinError(res,e);}});
app.get('/admin/bulletin/content-requests',requireAuth,requireAdmin,async(_req,res)=>{try{return res.json({items:await bulletin.adminContentRequests()});}catch(e){return bulletinError(res,e);}});
app.post('/admin/bulletin/content-requests/:id/action',requireAuth,requireAdmin,async(req,res)=>{try{return res.json(await bulletin.adminContentRequestAction(req.auth.uid,req.params.id,req.body?.action));}catch(e){return bulletinError(res,e);}});
app.get('/admin/bulletin/bans',requireAuth,requireAdmin,async(_req,res)=>{try{return res.json({items:await bulletin.adminBans()});}catch(e){return bulletinError(res,e);}});
app.post('/admin/bulletin/bans/:uid/unban',requireAuth,requireAdmin,async(req,res)=>{try{return res.json(await bulletin.adminUnban(req.params.uid));}catch(e){return bulletinError(res,e);}});
app.post('/admin/bulletin/cleanup',requireAuth,requireAdmin,async(_req,res)=>{try{return res.json(await bulletin.cleanupExpired());}catch(e){return bulletinError(res,e);}});

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
    await failGeneratedRequest(req);
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
    bulletin.startCleanupLoop();
  } else {
    console.error(
      'Firebase Admin kapalı — Railway Variables içine FIREBASE_SERVICE_ACCOUNT_JSON ekleyin.',
    );
  }
});
