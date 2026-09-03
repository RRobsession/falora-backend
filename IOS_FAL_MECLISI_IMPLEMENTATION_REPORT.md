# iOS Fal Meclisi uygulama raporu

## Mimari

- Flutter: `MaterialApp` + `AuthGate`, servis tabanlı yerel durum ve `StatefulWidget`.
- Kimlik: Firebase Auth; profil ve uygulama verileri Firestore.
- Backend: Railway üzerinde Express, Firebase Admin, FCM ve App Store Server API.
- Satın alma: Flutter `in_app_purchase`; Android ve iOS jetonları backend'de ayrı doğrulanıyor.
- Admin: Firebase admin allowlist'i ile korunan uygulama içi admin paneli.

## Eklenen alanlar

- iOS açılış geçidi: Kişisel Fal / Fal Meclisi.
- Fal Meclisi kategori, konu listesi, anahtar kelime araması, konu ayrıntısı ve premium kilidi.
- Tombik Teyze+ dinamik StoreKit fiyatı, satın alma ve geri yükleme.
- Backend App Store doğrulaması, transaction zinciri tek hesap sahipliği, süre/iade kontrolü ve App Store Server Notifications endpoint'i.
- Premium konu/cevap oluşturma, çözüm seçme, raporlama, engelleme backend'i.
- Üç görsele kadar istemci sıkıştırması, backend boyut/MIME kontrolü ve Firebase Storage yüklemesi.
- Türkçe normalize edilen iki katmanlı moderasyonun yetkili backend katmanı.
- Admin özet, konu/rapor moderasyonu, kategori aç/kapat, kullanıcı uzaklaştırma/yasaklama.
- Yeni konu admin push'u; yeni cevap, doğrulanmış yorumcu cevabı ve çözüm push'u.
- Süre dolan konuların ve Storage dosyalarının altı saatte bir temizlenmesi.

## Koleksiyonlar

- `community_categories`
- `community_topics` ve `community_topics/{topicId}/replies`
- `community_reports`
- `community_blocks`
- `community_entitlements`
- `community_subscription_transactions`
- `community_config`
- `community_moderation_events`

Konu özetleri yazar görünen adı, kategori adı, sayaçlar ve son aktiviteyi denormalize tutar. Feed 15 kayıt, cevaplar 20 kayıt ile sınırlıdır. Feed realtime listener kullanmaz.

## Manuel kurulum

1. App Store Connect'te `tombik_teyze_plus_monthly` kimliğiyle aylık auto-renewable subscription oluşturun, yaklaşık 300 TL fiyat kademesini seçin ve inceleme görseli/metnini ekleyin.
2. Railway: `APPLE_COMMUNITY_SUBSCRIPTION_ID=tombik_teyze_plus_monthly` ve doğru bucket için `COMMUNITY_STORAGE_BUCKET` ekleyin. Mevcut `APPLE_IAP_KEY_ID`, `APPLE_IAP_ISSUER_ID`, `APPLE_IAP_PRIVATE_KEY`, `APPLE_IAP_BUNDLE_ID` kalır.
3. App Store Connect App Store Server Notifications V2 URL: `https://<railway-domain>/billing/apple/notifications` (Production ve Sandbox).
4. `firebase deploy --only firestore:rules,firestore:indexes,hosting` çalıştırın.
5. Firestore TTL'de `community_topics.expiresAt` politikasını etkinleştirin. Backend temizliği görselleri de sildiğinden Railway servisinin sürekli çalışması gerekir.
6. Firebase Storage bucket adını doğrulayın ve Railway service account'una Storage Object Admin yetkisi verin.
7. App Privacy beyanlarını gerçek veri akışına göre UGC, kullanıcı içeriği ve görseller için güncelleyin. Gizlilik/koşul metinleri repoda güncellendi.

## Maliyet modeli

- Feed sayfası: en fazla 15 görünür sonuç; engel filtresi nedeniyle sunucu en fazla 30 aday + engel sorgusu okur.
- Konu ayrıntısı: 1 konu; premium ise en fazla 20 cevap, ücretsiz ise 0 cevap okuması.
- Sayaçlar transaction/increment ile tutulur; saymak için cevap koleksiyonu okunmaz.
- Arama `searchKeywords array-contains` ile indeksli; istemcide koleksiyon taraması yok.
- Görseller en fazla 3, yaklaşık 1280 px ve backend'de görsel başına 1,2 MB sınırı.
- Görüntülenme başına yazma ve feed genelinde snapshot listener yok.

## Doğrulama

- Backend: 8/8 Node testi geçti.
- Flutter: tüm mevcut testler 6/6 geçti.
- Dart/Flutter analizinde derleme hatası yok. Repo genelindeki önceden var olan 11 warning ve stil info kayıtları nedeniyle `flutter analyze` çıkış kodu 1.
- `git diff --check` temiz.

## Tamamlanması gereken üretim QA işleri

- Fiziksel iPhone'da Sandbox abonelik yenileme/iptal/iade/grace-period senaryoları.
- Firebase Emulator ile Security Rules allow/deny entegrasyon testleri.
- Çok sayfalı cevap listesinin istemci “daha fazla” kontrolü.
- Konu ayrıntısında kullanıcı engelleme ve tek tek cevap raporlama kontrollerinin görünür UI'si (backend endpoint'leri hazır).
- Admin kategorilerinde oluşturma/yeniden adlandırma/sıralama için ayrıntılı form (backend alanları hazır; ilk UI aç/kapat sunuyor).
- Helpful oy sistemi istekte opsiyonel olduğundan eklenmedi.

## Önerilen App Review Notes

Tombik Teyze now provides two distinct iOS experiences presented at launch. “Kişisel Fal” opens the existing personalized interactive reading tools. “Fal Meclisi” is a working structured question-and-answer community where registered users can browse and search public questions, while Tombik Teyze+ subscribers can create topics, view paginated answers, reply, share optimized images, report content, block users, and mark one answer as the accepted solution. Verified human interpreters are visibly distinguished from ordinary members. User-generated content is protected by server-side moderation, reporting, blocking, rate limits, and an administrator moderation dashboard. Tombik Teyze+ is an auto-renewable App Store subscription with dynamic localized pricing and Restore Purchases. No external payment is used. Android retains the existing application experience.
