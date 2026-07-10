# Google Play Billing Setup

## Durum kontrolü

```bash
cd backend
npm run billing:verify
```

Başarılı çıktı: `OK: Play billing doğrulama erişimi hazır.`

## 1. Google Cloud API (bir kez)

Google Play Android Developer API etkin olmalı:

https://console.developers.google.com/apis/api/androidpublisher.googleapis.com/overview?project=falora35

## 2. Service account

Billing için ayrı service account kullanın (ör. `falora-play-billing@falora35.iam.gserviceaccount.com`).

JSON key dosyası: `backend/google-play-service-account.json` (git'e eklenmez).

## 3. Play Console yetkisi (zorunlu)

Play Console > **Users and permissions** > **Invite new users**

- E-posta: billing service account adresi (`...@...iam.gserviceaccount.com`)
- Uygulama: `com.rrlime.falora`
- Yetkiler:
  - **View financial data**
  - **Manage orders and subscriptions**

Service account davet onayı beklemez; kaydettikten sonra aktif olur.

Otomatik (tarayıcı OAuth): `npm run billing:setup`  
Manuel adımlar: `npm run billing:setup -- --manual`

## 4. Backend env

Yerel `.env`:

```env
GOOGLE_PLAY_PACKAGE_NAME=com.rrlime.falora
GOOGLE_PLAY_SERVICE_ACCOUNT_PATH=./google-play-service-account.json
```

Railway Variables (production):

```bash
node scripts/print-railway-play-env.js
```

Çıktıdaki `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` değerini Railway'e ekleyin ve redeploy edin.

## 5. Play Console products

Managed product kimlikleri (yalnızca jeton paketleri):

- `tokens_50`
- `tokens_100`
- `tokens_150`
- `tokens_200`
- `tokens_1500`

## 4. Test purchase

1. Uygulamayı `internal testing` kanalına yükleyin.
2. Test kullanıcısını Play Console test hesabı olarak ekleyin.
3. Android cihazda aynı hesapla Play Store oturumu açın.
4. Uygulama içinden ürün sorgulaması geliyorsa test purchase akışı hazırdır.

## 5. Validation checklist

- Backend açılış logunda `Google Play servis hesabı env tanımlı.` görünmeli.
- `flutter analyze` temiz geçmeli veya yalnızca önceden var olan uyarılar kalmalı.
- Jeton satın alımında `play_purchases/{purchaseToken}` dokümanı oluşmalı.
- Manuel fal (Serdar/Hatice) jeton ile gönderildiğinde `manual_fortune_requests/{requestId}` oluşmalı.
- Aynı `purchaseToken` ile ikinci istek yeni kredi oluşturmamalı.
