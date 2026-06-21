# Google Play Billing Setup

## 1. Service account

1. Google Cloud Console'da bir service account oluşturun.
2. JSON private key indirin.
3. Play Console > `Setup` > `API access` altında bu service account'u bağlayın.
4. Uygulama için en az ürün/satın alma görüntüleme yetkisi verin.

## 2. Backend env

`.env` içine aşağıdaki alanları ekleyin:

```env
GOOGLE_PLAY_PACKAGE_NAME=com.rrlime.falora
GOOGLE_PLAY_SERVICE_ACCOUNT_PATH=./google-play-service-account.json
```

Alternatif olarak JSON içeriğini tek satır `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` olarak verebilirsiniz.

## 3. Play Console products

Managed product kimlikleri (yalnızca jeton paketleri):

- `tokens_50`
- `tokens_100`
- `tokens_150`
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
