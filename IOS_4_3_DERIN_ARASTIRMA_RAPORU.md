# Falora iOS: Guideline 4.3(b) Derin Araştırma ve Uygulama Raporu

**Tarih:** 2 Eylül 2026  
**Amaç:** Falora’yı fal özelliklerini kaldırmadan, Apple’ın “anlamlı derecede farklı veya geliştirilmiş deneyim” eşiğine taşıyacak gerçek ürün değişikliğini belirlemek.

## Yönetici kararı

Şu an yaptığımız iOS ana sayfa düzenlemesi yararlı fakat **4.3(b)’yi aşmak için yeterli değil**. “Fal türleri” kutularını “Ritüel oluştur / Uzmana danış / İlişkimi keşfet” şeklinde gruplamak sunumu iyileştirir; çekirdek ürün hâlâ tek seferlik fal sonucu üretirse Apple bunu aynı doygun kategorinin başka bir varyantı sayabilir.

Apple falcılığı 4.3(b)’de açıkça doygun kategori olarak tanımlıyor ve yeni başvurularda “meaningfully different or improved experience” arıyor. 4.2 de uygulamanın katalog olmanın ötesinde kalıcı fayda veya eğlence değeri sunmasını istiyor. Bu yüzden güvenilir çözüm, falı gizlemek değil, Falora’nın **kullanıcı tarafından oluşturulan ritüel eseri + zaman içinde gelişen kişisel ritüel günlüğü** olmasını sağlamaktır. [Apple App Review Guidelines, 4.2 ve 4.3(b)](https://developer.apple.com/app-store/review/guidelines/)

Hiç kimse “kesin geçer” garantisi veremez. Fakat aşağıdaki çekirdek akış tamamlanır ve incelemeciye kanıtlanırsa, yalnızca yeni bir tema uygulamış olmaktan çok daha savunulabilir bir başvuru elde ederiz.

## Neden mevcut farklılıklar tek başına yetmiyor?

Falora’da hâlihazırda değerli parçalar var:

- Kullanıcı ekranda baklaları kendisi serpiyor.
- Tarot ve iskambil kartlarını kendisi seçiyor.
- Su yüzeyinde sembol oluşturuyor.
- Seçimler ve saçılım verileri sonuçla birlikte kaydediliyor.
- Serdar veya Hatice’ye kişisel yorum talebi gönderilebiliyor.
- Yorumcu çalışma saati, günlük kota, durum ve yanıt geçmişi bulunuyor.
- Çift uyumu ve duruma özel ilişki tavsiyesi akışları var.

Ancak pazar araştırması, **canlı/gerçek yorumcu, etkileşimli tarot, ilişki uyumu, burç ve kişisel geçmiş** gibi özelliklerin mevcut App Store uygulamalarında zaten yaygın olduğunu gösteriyor. Keen; canlı uzman, eşleştirme ve mesaj özellikleri sunuyor. MyStar; etkileşimli tarot, canlı uzman, burç ve ilişki uyumunu aynı uygulamada birleştiriyor. Falavanga ise Türkçe pazarda kahve, tarot, burç ve 3D tarot sunuyor. Dolayısıyla “bizde gerçek yorumcu ve kart seçimi var” savunması tek başına güçlü bir ayrım değildir. [Keen](https://apps.apple.com/us/app/keen-psychic-reading-tarot/id1008861332), [MyStar](https://apps.apple.com/us/app/mystar-live-psychic-tarot/id6738414334), [Falavanga](https://apps.apple.com/tr/app/falavanga-tarot-ve-kahve-fal%C4%B1/id1052259067)

## Önerilen yeni çekirdek: Falora Ritüel Günlüğü

Falora’nın iOS sürümündeki ana ürün cümlesi şu olmalı:

> Falora, kullanıcının kendi ritüel eserini oluşturduğu, önce kendi gözlemini kaydettiği, isterse aynı eseri gerçek bir yorumcuya gönderdiği ve zaman içinde tekrar eden sembollerini keşfettiği katılımcı bir Türk ritüel günlüğüdür.

Bu yalnızca isim değişikliği olmayacak. Her çalışma aşağıdaki beş aşamadan geçecek:

### 1. Niyet

Kullanıcı “Bugün neyi anlamaya çalışıyorum?” sorusuna kısa bir cevap verir ve duygu durumunu seçer. Bu giriş sadece yorum üretmek için değil, daha sonra karşılaştırılacak günlük kaydı için saklanır.

### 2. Ritüel eseri oluşturma

Kullanıcı yöntemine göre gerçek bir eser üretir:

- Bakla: saçılım koordinatları, kümeler ve işaretlenen semboller.
- Su: kullanıcının oluşturduğu semboller ve sıraları.
- Tarot/iskambil: seçilen kartlar, seçim sırası ve açılımdaki konumları.
- Kahve/el: kullanıcının çektiği özgün fotoğraflar.

Projede bu verilerin önemli bölümü zaten kaydediliyor. Yeni iş, bunları geçici yorum girdisi olmaktan çıkarıp kullanıcıya ait, tekrar açılabilir bir “ritüel eseri” modeline dönüştürmek.

### 3. Önce kullanıcının kendi gözlemi

Sonuç gösterilmeden önce kullanıcıya şunlar sorulur:

- İlk dikkatini çeken sembol/kart ne?
- Bunun sende uyandırdığı duygu ne?
- Bu çalışmadan beklediğin soru ne?

Bu adım kritik farklılıktır: kullanıcı pasif rapor tüketmez, eserin anlamlandırılmasına katılır. Apple’ın onboarding rehberi de insanlara yalnızca açıklama göstermek yerine işi etkileşim içinde yaptırmayı öneriyor. [Apple HIG — Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding)

### 4. Yorum yolu

Aynı ritüel eseri için kullanıcı üç yoldan birini seçer:

- Kendi notlarımla günlüğe kaydet.
- Otomatik sembolik yorum al.
- Serdar veya Hatice’ye kişisel yorum için gönder.

Böylece gerçek yorumcular ayrı bir “fal çeşidi” değil, kullanıcının oluşturduğu eserin yorumlanma yollarından biri olur.

### 5. Sonradan yansıma ve örüntü

24–72 saat sonra uygulama kullanıcıya “Bu çalışmadan ne kaldı?” sorusunu yöneltir. Kullanıcı kısa bir not ve fayda/uyum değerlendirmesi ekler. En az üç çalışma oluştuğunda günlük şunları gösterebilir:

- Tekrar eden semboller ve kartlar.
- En sık çalışılan yaşam alanları.
- Başlangıç ve sonradan yansıma duygu değişimi.
- Kullanıcının kendi notlarıyla yorumcu notlarının yan yana görünümü.

Bu bölüm “geleceği söyleyen raporlar koleksiyonu” yerine zaman içinde değer kazanan kişisel bir araç oluşturur ve Apple 4.2’deki kalıcı değer beklentisini destekler. [Apple App Review Guidelines, 4.2](https://developer.apple.com/app-store/review/guidelines/)

## iOS bilgi mimarisi

Önerilen alt menü:

1. **Bugün** — son açık çalışma, yeni niyet başlatma ve geri dönüş sorusu.
2. **Ritüel** — yöntem seçimi ve etkileşimli eser oluşturma.
3. **Günlüğüm** — zaman çizelgesi, ritüel eserleri ve sonraki yansıma.
4. **Yorumcular** — Serdar/Hatice profili, uygunluk, kota ve gönderimler.
5. **Profil** — hesap, satın alma, gizlilik ve destek.

Burç, rüya, numeroloji, çift uyumu ve ilişki tavsiyesi kaldırılmaz; **Ritüel** veya **Günlüğüm** içinde çalışma şablonları hâline gelir. Ana ekranda on farklı fal kategorisini aynı ağırlıkta göstermek bırakılır.

## Gönderimden önce zorunlu ürün kapsamı

### P0 — Başvuru için olmazsa olmaz

- Tek bir ritüelin niyet → eser → kişisel gözlem → yorum yolu → günlük kaydı akışını eksiksiz çalıştırması.
- Bakla, su, tarot ve iskambil eserlerinin yeniden açılabilir görsel kaydı.
- “Günlüğüm” zaman çizelgesi.
- Kullanıcının kendi gözlem notu.
- En az bir sonradan yansıma mekanizması.
- İnceleme hesabında önceden hazırlanmış en az üç örnek çalışma.
- Serdar/Hatice akışının inceleme saatinden bağımsız test edilebilmesi için demo veri veya tam özellikli demo modu. Apple, hesap tabanlı özelliklerde etkin demo hesabı ya da tam özellikli demo modu ve canlı backend ister. [Apple App Review Guidelines — Before You Submit](https://developer.apple.com/app-store/review/guidelines/)

### P1 — Savunmayı ciddi biçimde güçlendirir

- Tekrar eden sembol/kart özeti.
- Kendi gözlemi ile yorumcu yorumunu yan yana karşılaştırma.
- Ritüel eserini salt okunur görsel kart olarak dışa aktarma.
- Yorumcu profilinde gerçek kişi açıklaması, yanıt süreci ve geçmiş talepler.
- iPad için gerçek uyarlanabilir düzen; yalnızca büyütülmüş telefon grid’i olmaması.

### P2 — Sonraki sürüme bırakılabilir

- Gelişmiş örüntü grafikleri.
- Hatırlatma zamanını kullanıcının seçmesi.
- Bir ritüel çalışmasının özel paylaşım bağlantısı.
- Yeni ritüel araçları.

## Yapılmaması gerekenler

- Yalnızca “Fal” kelimelerini “Atölye” veya “Keşif” olarak değiştirmek.
- Özellikleri App Review’a özel saklamak veya farklı davranan inceleme sürümü hazırlamak.
- Çalışmayan ekranları benzersizlik kanıtı gibi sunmak.
- Mevcut canlı yorumcu uygulamalarının varlığını “biz de farklıyız” kanıtı saymak.
- Yeni bir Bundle ID açıp aynı uygulamayı tekrar göndermek; 4.3(a) bunu ayrıca riskli kılar.
- Falı kaldırmış gibi metadata yazıp uygulama içinde fal ağırlığını korumak. Apple metadata’nın doğru ve güncel olmasını şart koşar. [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

## App Store inceleme kanıt paketi

### İlk üç ekran görüntüsü

1. **Ritüelini kendin oluştur** — ekranda gerçek bakla saçılımı veya su sembolü üretimi.
2. **Önce kendi gözlemini kaydet** — sembol seçimi, duygu ve kişisel not.
3. **Zaman içindeki örüntülerini keşfet** — günlük zaman çizelgesi ve tekrar eden semboller.

Sonraki görüntüler gerçek yorumcuya gönderim, çift çalışması ve tarot seçim akışını gösterebilir. Apple bir yerelleştirme ve cihaz boyutu için 1–10 ekran görüntüsüne, ayrıca üç uygulama önizlemesine izin veriyor. [Apple — ekran görüntüleri ve önizlemeler](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/)

### 15–30 saniyelik uygulama önizlemesi

Kesintisiz biçimde şu akış gösterilmeli:

1. Niyet yaz.
2. Baklaları serp.
3. Bir sembolü işaretle ve kendi gözlemini ekle.
4. Günlük eserini aç.
5. Aynı eseri Serdar/Hatice’ye gönderme seçeneğini göster.

Apple’ın uygulama önizlemesi için belirlediği süre 15–30 saniyedir. [Apple App Preview Specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications)

### App Review notu iskeleti

> Falora is not a catalog of prewritten fortune reports. Its core experience is a participatory ritual journal. Reviewers can create a unique ritual artifact by scattering beans, arranging water symbols, or selecting cards; record their own observation before any interpretation; preserve the artifact in a chronological journal; compare later reflections; and optionally send the same user-created artifact to a named human reader.  
>  
> Test path: Sign in with the review account → Today → Create Ritual → Bean Ritual → enter intention → scatter beans → mark a symbol → add personal observation → Save to Journal. Then open Journal to inspect the saved scatter and prepared historical entries. Open “Interpretation Path” to view the human-reader workflow. No purchase is required for the prepared review account.

Bu not, özelliklerin yalnızca var olduğunu iddia etmemeli; incelemecinin iki dakika içinde uygulayabileceği kesin yol vermeli. Apple, açık olmayan özelliklerin ve uygulama içi satın almaların Review Notes alanında ayrıntılı açıklanmasını ister. [Apple App Review Guidelines — Before You Submit](https://developer.apple.com/app-store/review/guidelines/)

## Risk matrisi

| Seçenek | 4.3(b) riski | Gerekçe |
|---|---:|---|
| Mevcut kategori grid’ini yeniden gönderme | Çok yüksek | Standart fal kataloğu izlenimi sürüyor. |
| Yalnızca üç amaç kartlı yeni ana sayfa | Yüksek | Sunum değişiyor, çekirdek çıktı değişmiyor. |
| Gerçek yorumcuları ana fark olarak sunma | Orta-yüksek | Rakiplerde canlı uzman ve eşleştirme yaygın. |
| Ritüel eseri + kişisel gözlem + günlük | Orta | Test edilebilir, kullanıcı üretimli ve kalıcı çekirdek fark oluşturuyor. |
| Yukarıdakine örüntü ve sonradan yansımayı ekleme | Orta-düşük | Tek seferlik faldan zaman içinde gelişen kişisel araca dönüşüyor. Yine de Apple kararı garanti değildir. |

## Gönderim stratejisi

1. **Mevcut değişikliği hemen göndermeyelim.** Üç amaç kartlı ana sayfa tek başına yeterli kanıt değil.
2. Önce P0 akışını gerçek iOS kodunda tamamlayalım ve TestFlight’ta doğrulayalım.
3. Yeni build numarasıyla, yeni ekran görüntüleri ve uygulama önizlemesiyle gönderelim.
4. Önceki 4.3(b) mesajına sakin ve kısa yanıt verip hangi çekirdek işlevlerin eklendiğini maddeleyelim.
5. Yeniden aynı genel ret gelirse, çalışan akışın ekran kaydı ve kesin test yolu ile App Review Board’a itiraz edelim. Apple, ret hakkında App Store Connect üzerinden iletişimi ve karara katılmıyorsanız itirazı resmi yollar olarak gösteriyor. [Apple App Review Guidelines — Rejections and Appeals](https://developer.apple.com/app-store/review/guidelines/)

## Sonuç

4.3(b)’yi “tasarımı farklı göstererek” doğrudan aşamayız. En güçlü ve dürüst yol, Falora’nın zaten sahip olduğu etkileşimli saçılım/kart verisini yeni bir ürün çekirdeğine dönüştürmektir: **kullanıcının oluşturduğu ritüel eseri, kendi gözlemi, yorum yolu, sonradan yansıması ve zaman içindeki örüntüleri**.

Bu yaklaşım falı kaldırmaz. Fal, burç, çift uyumu ve ilişki tavsiyesi kalır; fakat uygulamanın kendisi artık başka bir fal menüsü değil, katılımcı ve zaman içinde değer kazanan bir ritüel günlüğü olur.
