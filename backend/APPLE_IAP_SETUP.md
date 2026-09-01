# Apple In-App Purchase doğrulaması

Backend, iOS consumable işlemlerini Apple App Store Server API üzerinden
doğrular. Android Google Play doğrulaması bu akıştan ayrıdır.

## Railway environment variables

Railway servisinin Variables bölümüne aşağıdaki değerleri ekleyin:

- `APPLE_IAP_BUNDLE_ID=com.rrlime.falora`
- `APPLE_IAP_KEY_ID`: App Store Connect In-App Purchase key ID
- `APPLE_IAP_ISSUER_ID`: App Store Connect In-App Purchase issuer ID
- `APPLE_IAP_PRIVATE_KEY`: indirilen `.p8` dosyasının Base64 içeriği veya PEM

Anahtar App Store Connect > Users and Access > Integrations > In-App Purchase
bölümünden oluşturulur. `.p8` dosyasını repository'ye eklemeyin.

## Doğrulama kuralları

- Önce production, işlem bulunamazsa sandbox/TestFlight sorgulanır.
- Transaction ID, ürün ID, Bundle ID ve ortam eşleşmelidir.
- Yalnız `Consumable` ürünler kabul edilir.
- İade edilmiş işlemler reddedilir.
- Her Apple transaction ID yalnızca bir kez jeton verir.

## Test

Railway değişkenleri eklendikten ve güncel backend deploy edildikten sonra build
47'yi TestFlight'a yükleyin. Sandbox kullanıcısıyla her ürünü satın alıp jeton
bakiyesini ve `apple_purchases` Firestore kaydını kontrol edin.
