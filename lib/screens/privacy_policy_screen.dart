import 'package:falora/config/app_branding.dart';
import 'package:falora/config/app_links_config.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  List<_PolicySection> get _sections => [
    _PolicySection(
      title: '1. Giriş',
      body:
          '$appDisplayName uygulamasını kullanarak bu gizlilik politikasını kabul etmiş olursunuz. '
          'Kişisel verilerinizin güvenliği bizim için önemlidir.',
    ),
    _PolicySection(
      title: '2. Veri Sorumlusu',
      body:
          'Veri sorumlusu: Falora / $appDisplayName uygulama hizmet sağlayıcısı.\n'
          'İletişim: prserdar.cakir@gmail.com\n'
          'KVKK ve GDPR kapsamındaki başvurularınızı bu adrese iletebilirsiniz.',
    ),
    _PolicySection(
      title: '3. Toplanan Veriler',
      body:
          'Hesap oluştururken ad, e-posta adresi, doğum tarihi, burç ve profil görseli toplanabilir. '
          'Fal formlarında girdiğiniz isim, yaş, burç, niyet, sorular ve yüklediğiniz fotoğraflar '
          'hizmetin sunulması için işlenir. Cihaz bildirim token\'ı (FCM), jeton bakiyesi, satın alma '
          'doğrulama kayıtları ve uygulama içi işlem kayıtları da işlenebilir.',
    ),
    _PolicySection(
      title: '4. Verilerin Kullanımı ve Hukuki Dayanak',
      body:
          'Verileriniz fal yorumlarının oluşturulması, manuel fal taleplerinin yönetilmesi, '
          'jeton bakiyenizin takibi, bildirim gönderimi, reklam sunumu, dolandırıcılık önleme '
          've hesap güvenliği amacıyla işlenir. Hukuki dayanaklar; sözleşmenin ifası, meşru menfaat '
          've yürürlükteki mevzuat kapsamında açık rızanızın gerektiği hallerdir.',
    ),
    _PolicySection(
      title: '5. Fal ve Tavsiye İçerikleri',
      body:
          'Uygulamada sunulan fal yorumları, spiritüel analizler, çift uyumu sonuçları ve '
          'ilişki tavsiyeleri eğlence ve kişisel farkındalık amaçlıdır; kesin doğruluk '
          'garantisi verilmez. Bu içerikler profesyonel danışmanlık yerine geçmez. '
          'Önemli yaşam kararlarınızı yalnızca uygulama çıktılarına dayanarak vermemenizi öneririz.',
    ),
    _PolicySection(
      title: '6. Yapay Zeka ve Manuel Yorum',
      body:
          'Otomatik fal yorumları OpenAI yapay zeka hizmetleri kullanılarak oluşturulabilir; '
          'gönderdiğiniz metin ve görseller bu amaçla işlenir. Serdar, Hatice gibi özel yorumcular '
          'için gönderdiğiniz bilgiler ve görseller insan yorumcusu tarafından değerlendirilir. '
          'Her iki durumda da içerik eğlence amaçlıdır.',
    ),
    _PolicySection(
      title: '7. Üçüncü Taraf Hizmetler',
      body:
          'Uygulama şu hizmet sağlayıcıları kullanabilir:\n'
          '• Google Firebase (kimlik doğrulama, veritabanı, bildirimler)\n'
          '• Google AdMob (reklamlar; cihaz reklam kimliği AB/EEA\'da rızanızla)\n'
          '• OpenAI (yapay zeka yorum üretimi)\n'
          '• Google Play (uygulama içi satın alma doğrulaması)\n'
          'Bu hizmetler kendi gizlilik politikalarına tabidir.',
    ),
    _PolicySection(
      title: '8. Yurt Dışına Aktarım',
      body:
          'Verileriniz Türkiye dışındaki sunucularda (ör. ABD, AB) işlenebilir. Firebase, '
          'Google AdMob, OpenAI ve Google Play altyapıları uluslararası veri aktarımına tabi '
          'olabilir. Bu aktarımlar hizmetin sunulması için gereklidir.',
    ),
    _PolicySection(
      title: '9. Veri Saklama ve Güvenlik',
      body:
          'Verileriniz güvenli sunucularda saklanır. Fal yorumları, ilişki tavsiyeleri, '
          'çift uyumu raporları, rüya tabiri, burç yorumu, numeroloji ve manuel fal talepleri '
          '(yüklenen görseller dahil) oluşturulma tarihinden itibaren en fazla 15 gün saklanır; '
          'bu sürenin sonunda otomatik olarak silinir. Hesap bilgileriniz ve jeton bakiyeniz bu '
          'kapsamın dışındadır. Hesabınızı sildiğinizde ilgili veriler kalıcı olarak silinmeye '
          'çalışılır.',
    ),
    _PolicySection(
      title: '10. Haklarınız',
      body:
          'KVKK ve GDPR kapsamında verilerinize erişme, düzeltme, silme, işlemeyi kısıtlama '
          've itiraz etme haklarına sahipsiniz. Profil ekranından hesabınızı silebilir veya '
          'prserdar.cakir@gmail.com adresinden veri talebinde bulunabilirsiniz. Veri taşınabilirliği '
          'talepleri de aynı kanaldan iletilebilir.',
    ),
    _PolicySection(
      title: '11. Çocukların Gizliliği',
      body:
          '$appDisplayName 18 yaş altı kullanıcılar için tasarlanmamıştır. Bilerek çocuklardan '
          'kişisel veri toplanmaz. 18 yaş altı olduğunuz tespit edilirse hesabınız sonlandırılabilir.',
    ),
    _PolicySection(
      title: '12. Değişiklikler',
      body:
          'Bu politika zaman zaman güncellenebilir. Önemli değişiklikler uygulama içinde '
          'duyurulabilir. Güncel metin bu sayfada ve barındırılan web adresinde yayımlanır.',
    ),
    _PolicySection(
      title: '13. İletişim',
      body: 'Gizlilik ile ilgili sorularınız için: prserdar.cakir@gmail.com',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final externalUrl = privacyPolicyUrl.trim();
    return Scaffold(
      appBar: AppBar(title: const Text('Gizlilik Politikası')),
      body: FaloraBackground(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            24 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            if (externalUrl.isNotEmpty) ...[
              OutlinedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(externalUrl);
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Web sürümünü aç'),
              ),
              const SizedBox(height: 16),
            ],
            for (final section in _sections) ...[
              Text(section.title, style: FaloraTypography.sectionHeading),
              const SizedBox(height: 8),
              Text(section.body, style: FaloraTypography.bodyOnParchment),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _PolicySection {
  const _PolicySection({required this.title, required this.body});
  final String title;
  final String body;
}
