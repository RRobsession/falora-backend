const fs = require('fs');
const path = require('path');

const BACKEND_DIR = __dirname;

function resolveServiceAccountPath(configuredPath, defaultPath) {
  const candidate = configuredPath || defaultPath;
  if (!candidate) return null;
  if (path.isAbsolute(candidate)) return candidate;

  const fromBackend = path.resolve(BACKEND_DIR, candidate);
  if (fs.existsSync(fromBackend)) return fromBackend;
  return path.resolve(process.cwd(), candidate);
}

function normalizeServiceAccount(raw) {
  if (!raw || typeof raw !== 'object') return null;

  const account = { ...raw };
  if (typeof account.private_key === 'string') {
    account.private_key = account.private_key.replace(/\\n/g, '\n');
  }

  if (
    account.type !== 'service_account' ||
    typeof account.client_email !== 'string' ||
    typeof account.private_key !== 'string' ||
    !account.private_key.includes('BEGIN PRIVATE KEY')
  ) {
    return null;
  }

  return account;
}

function parseServiceAccountJson(raw) {
  if (raw == null) return null;

  const text = typeof raw === 'string' ? raw.trim() : raw;
  if (typeof text !== 'string' || !text) return null;

  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch (error) {
    const wrapped = new Error(`JSON parse hatası: ${error.message}`);
    wrapped.cause = error;
    throw wrapped;
  }

  const normalized = normalizeServiceAccount(parsed);
  if (!normalized) {
    throw new Error('Geçersiz service account JSON (type/client_email/private_key).');
  }

  return normalized;
}

function loadServiceAccount({
  label = 'Service account',
  jsonEnv,
  pathEnv,
  defaultPath,
}) {
  const jsonRaw = process.env[jsonEnv];
  if (jsonRaw && String(jsonRaw).trim()) {
    try {
      const credentials = parseServiceAccountJson(String(jsonRaw));
      console.log(`${label}: ${jsonEnv} env değişkeninden yüklendi.`);
      return { credentials, source: jsonEnv };
    } catch (error) {
      console.error(`${label}: ${jsonEnv} okunamadı — ${error.message}`);
    }
  }

  const configuredPath = process.env[pathEnv];
  const resolved = resolveServiceAccountPath(configuredPath, defaultPath);

  if (resolved && fs.existsSync(resolved)) {
    try {
      const credentials = parseServiceAccountJson(
        fs.readFileSync(resolved, 'utf8'),
      );
      console.log(`${label}: dosyadan yüklendi (${resolved}).`);
      return { credentials, source: resolved };
    } catch (error) {
      console.error(
        `${label}: dosya okunamadı (${resolved}) — ${error.message}`,
      );
    }
  }

  console.error(`${label}: yapılandırılmadı.`);
  console.error(
    `${label}: Railway için ${jsonEnv} değişkenine service account JSON'un tamamını ekleyin.`,
  );
  if (resolved) {
    console.error(`${label}: Dosya fallback denendi ama bulunamadı: ${resolved}`);
  } else {
    console.error(
      `${label}: Yerel geliştirme için ${pathEnv} veya ${jsonEnv} tanımlayın.`,
    );
  }

  return null;
}

function describeServiceAccountEnv(jsonEnv, pathEnv) {
  const resolved = resolveServiceAccountPath(
    process.env[pathEnv],
    path.join(BACKEND_DIR, 'firebase-service-account.json'),
  );

  return {
    hasJsonEnv: Boolean(process.env[jsonEnv]?.trim()),
    hasPathEnv: Boolean(process.env[pathEnv]?.trim()),
    pathExists: Boolean(resolved && fs.existsSync(resolved)),
  };
}

module.exports = {
  parseServiceAccountJson,
  normalizeServiceAccount,
  loadServiceAccount,
  describeServiceAccountEnv,
  resolveServiceAccountPath,
};
