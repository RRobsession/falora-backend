#!/usr/bin/env node
/**
 * Railway dashboard'a yapıştırmak için Play billing env değerlerini yazdırır.
 */
const fs = require('fs');
const path = require('path');

const PLAY_SA_PATH = path.join(__dirname, '..', 'google-play-service-account.json');
const PACKAGE_NAME = process.env.GOOGLE_PLAY_PACKAGE_NAME || 'com.rrlime.falora';

if (!fs.existsSync(PLAY_SA_PATH)) {
  console.error(`Dosya bulunamadı: ${PLAY_SA_PATH}`);
  console.error('Önce setup-play-billing-access.js çalıştırın veya key dosyasını oluşturun.');
  process.exit(1);
}

const json = fs.readFileSync(PLAY_SA_PATH, 'utf8').trim();

console.log('Railway > falora-backend > Variables bölümüne ekleyin:\n');
console.log(`GOOGLE_PLAY_PACKAGE_NAME=${PACKAGE_NAME}`);
console.log('\nGOOGLE_PLAY_SERVICE_ACCOUNT_JSON=');
console.log(json);
console.log('\nKaydettikten sonra servisi redeploy edin.');
