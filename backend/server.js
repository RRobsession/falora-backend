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
const MODEL = process.env.OPENAI_MODEL || 'gpt-5.4-mini';
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
const { claimReferral } = require('./referrals');
const {
  requireAuth,
  requireVerifiedEmail,
  requireMatchingUserId,
} = require('./auth_middleware');
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
const { sendVerificationEmailWithIdToken } = require('./auth_verification');
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
  });
});

app.post('/auth/send-verification-email', requireAuth, async (req, res) => {
  if (req.auth?.emailVerified) {
    return res.json({ ok: true, alreadyVerified: true });
  }

  const header = req.headers.authorization || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    return res.status(401).json({ ok: false, error: 'Kimlik doğrulama gerekli' });
  }

  try {
    const result = await sendVerificationEmailWithIdToken(match[1]);
    if (!result.ok) {
      return res.status(502).json({
        ok: false,
        error: result.reason || 'verification_send_failed',
      });
    }
    return res.json({ ok: true, email: result.email });
  } catch (err) {
    console.error('AUTH VERIFY EMAIL ERROR:', err.message);
    return res.status(500).json({ ok: false, error: 'verification_send_failed' });
  }
});

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
    const teller = getFortuneTeller(tellerId || 'gizem_ana');
    const structure = pickFortuneStructure();
    logFortuneRequest(
      teller.id,
      structure.id,
      `${teller.minWords}-${teller.maxWords}`,
    );

    const result = await generate(
      openai,
      'fortune',
      buildFortuneSystemPrompt(teller, structure),
      buildFortuneUserPrompt(req.body, teller, structure),
      teller.maxCompletionTokens,
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
