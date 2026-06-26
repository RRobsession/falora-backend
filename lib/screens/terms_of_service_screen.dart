import 'package:falora/config/app_branding.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  static const _sections = <_TermsSection>[
    _TermsSection(
      title: '1. Taraflar ve Kabul',
      body:
          'Bu Kullanıcı Sözleşmesi, $appDisplayName mobil uygulamasını kullanan siz '
          '(“Kullanıcı”) ile uygulama hizmet sağlayıcısı arasında geçerlidir. '
          'Kayıt olarak veya uygulamayı kullanarak bu sözleşmeyi, 18 yaşını '
          'doldurduğunuzu ve yasal ehliyete sahip olduğunuzu beyan ederek kabul etmiş olursunuz.',
    ),
    _TermsSection(
      title: '2. Hizmetin Niteliği',
      body:
          '$appDisplayName; tarot, kahve, su, bakla, iskambil falı, rüya tabiri, '
          'numeroloji, burç yorumu, çift uyumu analizi ve ilişki tavsiyesi gibi '
          'eğlence ve kişisel farkındalık amaçlı dijital içerikler sunar. '
          'Sunulan tüm yorumlar ve tavsiyeler yalnızca genel bilgilendirme ve '
          'eğlence amaçlıdır; bilimsel, tıbbi, hukuki, finansal veya psikolojik '
          'danışmanlık yerine geçmez.',
    ),
    _TermsSection(
      title: '3. Doğruluk ve Sorumluluk Reddi',
      body:
          'Fal yorumları, spiritüel analizler, çift uyumu değerlendirmeleri ve '
          'ilişki tavsiyeleri kişisel yorum niteliğindedir; %100 doğruluk, kesin '
          'sonuç veya geleceğe dair garanti verilmez. Kararlarınızı yalnızca bu '
          'içeriklere dayanarak vermemeniz; önemli konularda yetkili uzmanlara '
          'danışmanız önerilir. Uygulama içeriğine dayanılarak alınan kararlardan '
          'doğabilecek doğrudan veya dolaylı zararlardan hizmet sağlayıcı sorumlu tutulamaz.',
    ),
    _TermsSection(
      title: '4. İlişki Tavsiyesi Özel Uyarısı',
      body:
          'İlişki tavsiyesi özelliği profesyonel çift terapisi, psikolojik danışmanlık '
          'veya hukuki danışmanlık değildir. Acil risk, şiddet, istismar veya kriz '
          'durumlarında derhal yetkili kurumlardan veya acil yardım hatlarından destek '
          'almanız gerekir. Paylaştığınız sohbet görselleri ve metinler yalnızca '
          'tavsiye üretimi amacıyla işlenir.',
    ),
    _TermsSection(
      title: '5. Hesap ve Jetonlar',
      body:
          'Hesap bilgilerinizin gizliliğinden siz sorumlusunuz. Jetonlar dijital '
          'hizmet kredisi niteliğindedir; kullanılmış jetonlar için yasal zorunluluklar '
          'saklı kalmak kaydıyla iade yapılmayabilir. Teknik arıza nedeniyle oluşturulamayan '
          'hizmetlerde uygulama içi iade politikası geçerli olabilir. Fal yorumları, ilişki '
          'tavsiyeleri, çift uyumu raporları ve spiritüel analiz kayıtları oluşturulma '
          'tarihinden itibaren en fazla 15 gün saklanır; bu sürenin sonunda otomatik olarak '
          'silinir. Hesap bilgileriniz ve jeton bakiyeniz bu kapsamın dışındadır.',
    ),
    _TermsSection(
      title: '6. Kullanıcı Yükümlülükleri',
      body:
          'Uygulamayı yürürlükteki mevzuata, üçüncü kişilerin haklarına ve genel ahlak '
          'kurallarına uygun kullanmayı kabul edersiniz. Yanıltıcı bilgi vermek, sistemi '
          'kötüye kullanmak veya hizmeti tersine mühendislik ile kopyalamak yasaktır.',
    ),
    _TermsSection(
      title: '7. Fikri Mülkiyet',
      body:
          'Uygulama tasarımı, markası, metinleri ve yazılımı hizmet sağlayıcıya aittir. '
          'İzinsiz kopyalama, dağıtma veya ticari kullanım yasaktır.',
    ),
    _TermsSection(
      title: '8. Hesabın Askıya Alınması ve Fesih',
      body:
          'Sözleşmeye aykırı kullanım tespit edilirse hesabınız uyarı verilmeksizin '
          'askıya alınabilir veya sonlandırılabilir. Kullanıcı, profil ekranından '
          'hesabını istediği zaman silebilir.',
    ),
    _TermsSection(
      title: '9. Değişiklikler',
      body:
          'Bu sözleşme güncellenebilir. Güncel metin uygulama içinde yayımlanır. '
          'Kullanıma devam etmeniz güncellenmiş metni kabul ettiğiniz anlamına gelir.',
    ),
    _TermsSection(
      title: '10. İletişim',
      body: 'Sözleşme ile ilgili sorularınız için: falora.admin@falora.app',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kullanıcı Sözleşmesi')),
      body: FaloraBackground(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            24 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
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

class _TermsSection {
  const _TermsSection({required this.title, required this.body});
  final String title;
  final String body;
}
