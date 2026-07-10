#!/usr/bin/env node
/**
 * Play Console'a billing service account yetkisi verir ve doğrulamayı test eder.
 *
 * Kullanım:
 *   node scripts/setup-play-billing-access.js
 *   node scripts/setup-play-billing-access.js --manual
 */
const crypto = require('crypto');
const fs = require('fs');
const http = require('http');
const path = require('path');
const { exec } = require('child_process');
const { google } = require('googleapis');

const BACKEND_DIR = path.join(__dirname, '..');
const PLAY_SA_PATH = path.join(BACKEND_DIR, 'google-play-service-account.json');
const PACKAGE_NAME = process.env.GOOGLE_PLAY_PACKAGE_NAME || 'com.rrlime.falora';
const REDIRECT_PORT = 8765;
const REDIRECT_URI = `http://127.0.0.1:${REDIRECT_PORT}/oauth/callback`;
const OAUTH_CLIENT_ID =
  process.env.PLAY_SETUP_OAUTH_CLIENT_ID ||
  '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const SCOPES = ['https://www.googleapis.com/auth/androidpublisher'];

function openBrowser(url) {
  const cmd =
    process.platform === 'win32'
      ? `start "" "${url}"`
      : process.platform === 'darwin'
        ? `open "${url}"`
        : `xdg-open "${url}"`;
  exec(cmd);
}

function loadPlayServiceAccount() {
  if (!fs.existsSync(PLAY_SA_PATH)) {
    throw new Error(`Service account dosyası bulunamadı: ${PLAY_SA_PATH}`);
  }
  return JSON.parse(fs.readFileSync(PLAY_SA_PATH, 'utf8'));
}

async function getUserOAuthClient() {
  const verifier = crypto.randomBytes(32).toString('base64url');
  const challenge = crypto.createHash('sha256').update(verifier).digest('base64url');

  const authUrl = new URL('https://accounts.google.com/o/oauth2/v2/auth');
  authUrl.searchParams.set('client_id', OAUTH_CLIENT_ID);
  authUrl.searchParams.set('redirect_uri', REDIRECT_URI);
  authUrl.searchParams.set('response_type', 'code');
  authUrl.searchParams.set('scope', SCOPES.join(' '));
  authUrl.searchParams.set('access_type', 'offline');
  authUrl.searchParams.set('prompt', 'consent');
  authUrl.searchParams.set('code_challenge', challenge);
  authUrl.searchParams.set('code_challenge_method', 'S256');

  const code = await new Promise((resolve, reject) => {
    const server = http.createServer((req, res) => {
      if (!req.url?.startsWith('/oauth/callback')) {
        res.writeHead(404);
        res.end('Not found');
        return;
      }

      const url = new URL(req.url, `http://127.0.0.1:${REDIRECT_PORT}`);
      const authCode = url.searchParams.get('code');
      const error = url.searchParams.get('error');

      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      if (error) {
        res.end('<h2>Yetkilendirme iptal edildi.</h2><p>Bu pencereyi kapatabilirsiniz.</p>');
        server.close();
        reject(new Error(`OAuth iptal: ${error}`));
        return;
      }

      res.end('<h2>Yetkilendirme tamam.</h2><p>Bu pencereyi kapatabilirsiniz.</p>');
      server.close();
      resolve(authCode);
    });

    server.listen(REDIRECT_PORT, '127.0.0.1', () => {
      console.log('Tarayıcı açılıyor; Play Console yönetici hesabıyla giriş yapın...');
      console.log('Yetkilendirme URL (tarayıcı açılmazsa kopyalayın):');
      console.log(authUrl.toString());
      openBrowser(authUrl.toString());
    });

    server.on('error', reject);
  });

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: OAUTH_CLIENT_ID,
      code,
      redirect_uri: REDIRECT_URI,
      grant_type: 'authorization_code',
      code_verifier: verifier,
    }),
  });

  const tokenJson = await tokenRes.json();
  if (!tokenJson.access_token) {
    throw new Error(
      `OAuth token alınamadı: ${tokenJson.error || 'unknown'} ${tokenJson.error_description || ''}`.trim(),
    );
  }

  const oauth2 = new google.auth.OAuth2();
  oauth2.setCredentials(tokenJson);
  return oauth2;
}

async function discoverDeveloperId(auth) {
  const publisher = google.androidpublisher({ version: 'v3', auth });

  const candidates = new Set([
    process.env.PLAY_DEVELOPER_ID,
    '688744850733',
  ].filter(Boolean));

  for (const developerId of candidates) {
    try {
      const response = await publisher.users.list({
        parent: `developers/${developerId}`,
      });
      if (response.data?.users) {
        console.log(`Play developer ID bulundu: ${developerId}`);
        return developerId;
      }
    } catch (error) {
      const message = error?.response?.data?.error?.message || error.message;
      console.log(`developer ${developerId} denendi: ${message}`);
    }
  }

  throw new Error(
    'Play developer ID bulunamadı. PLAY_DEVELOPER_ID ortam değişkeni ile tekrar deneyin.',
  );
}

async function ensureServiceAccountAccess(auth, developerId, serviceAccountEmail) {
  const publisher = google.androidpublisher({ version: 'v3', auth });
  const parent = `developers/${developerId}`;
  const userName = `${parent}/users/${encodeURIComponent(serviceAccountEmail)}`;

  const grantBody = {
    name: userName,
    email: serviceAccountEmail,
    developerAccountPermissions: [
      'CAN_VIEW_FINANCIAL_DATA_GLOBAL',
      'CAN_MANAGE_ORDERS_GLOBAL',
    ],
    grants: [
      {
        packageName: PACKAGE_NAME,
        appLevelPermissions: [
          'CAN_VIEW_FINANCIAL_DATA',
          'CAN_MANAGE_ORDERS',
        ],
      },
    ],
  };

  try {
    await publisher.users.create({
      parent,
      requestBody: grantBody,
    });
    console.log(`Play Console erişimi verildi: ${serviceAccountEmail}`);
    return;
  } catch (createError) {
    const createMessage =
      createError?.response?.data?.error?.message || createError.message;
    console.log(`create denemesi: ${createMessage}`);
  }

  await publisher.users.patch({
    name: userName,
    updateMask: 'developerAccountPermissions,grants',
    requestBody: grantBody,
  });
  console.log(`Play Console erişimi güncellendi: ${serviceAccountEmail}`);
}

async function testServiceAccountVerification(serviceAccount) {
  const auth = new google.auth.GoogleAuth({
    credentials: serviceAccount,
    scopes: SCOPES,
  });
  const publisher = google.androidpublisher({ version: 'v3', auth });

  try {
    await publisher.purchases.products.get({
      packageName: PACKAGE_NAME,
      productId: 'tokens_100',
      token: 'invalid-test-token',
    });
    console.log('Beklenmeyen: geçersiz token ile başarı döndü.');
  } catch (error) {
    const message = error?.response?.data?.error?.message || error.message;
    const status = error?.response?.status;
    if (status === 400 || status === 404) {
      console.log('Service account Play API erişimi OK (geçersiz token beklenen hata).');
      return;
    }
    throw new Error(`Service account testi başarısız (${status}): ${message}`);
  }
}

async function main() {
  const serviceAccount = loadPlayServiceAccount();
  console.log(`Play billing service account: ${serviceAccount.client_email}`);

  if (process.argv.includes('--manual')) {
    const firebaseSaPath = path.join(BACKEND_DIR, 'firebase-service-account.json');
    let firebaseEmail = null;
    if (fs.existsSync(firebaseSaPath)) {
      firebaseEmail = JSON.parse(fs.readFileSync(firebaseSaPath, 'utf8')).client_email;
    }

    console.log('\nManuel kurulum (Play Console):');
    console.log('1. https://play.google.com/console/developers/users-and-permissions/invites');
    console.log('2. Aşağıdaki service account e-postalarından BİRİNİ davet edin:');
    console.log(`   - ${serviceAccount.client_email} (önerilen, ayrı billing hesabı)`);
    if (firebaseEmail) {
      console.log(`   - ${firebaseEmail} (Railway zaten bunu kullanıyorsa yeterli)`);
    }
    console.log('3. Uygulama: com.rrlime.falora');
    console.log('4. Yetkiler: Finansal verileri görüntüle + Siparişleri yönet');
    console.log('5. Davet et (service account onay beklemez, anında aktif olur)');
    console.log('\nSonra: node scripts/verify-play-billing.js');
    console.log('Railway env için (ayrı billing hesabı kullanıyorsanız): node scripts/print-railway-play-env.js');
    return;
  }

  const userAuth = await getUserOAuthClient();
  const developerId = await discoverDeveloperId(userAuth);
  await ensureServiceAccountAccess(userAuth, developerId, serviceAccount.client_email);

  console.log('Service account yetkisi yayılıyor; 10 sn bekleniyor...');
  await new Promise((resolve) => setTimeout(resolve, 10000));

  await testServiceAccountVerification(serviceAccount);

  const jsonOneLine = JSON.stringify(serviceAccount);
  console.log('\nRailway Variables içine ekleyin:');
  console.log('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON=<aşağıdaki JSON tek satır>');
  console.log(`GOOGLE_PLAY_PACKAGE_NAME=${PACKAGE_NAME}`);
  console.log('\nJSON (kopyalamak için):');
  console.log(jsonOneLine);
}

main().catch((error) => {
  console.error('Kurulum başarısız:', error.message);
  process.exit(1);
});
