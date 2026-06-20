import 'package:falora/config/app_links_config.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _sections = <_PolicySection>[
    _PolicySection(
      title: '1. Giriş',
      body:
          'Falora uygulamasını kullanarak bu gizlilik politikasını kabul etmiş olursunuz. '
          'Kişisel verilerinizin güvenliği bizim için önemlidir.',
    ),
    _PolicySection(
      title: '2. Toplanan Veriler',
      body:
          'Hesap oluştururken ad, e-posta adresi ve uygulama kullanım verileri toplanabilir. '
          'Fal formlarında girdiğiniz isim, yaş, burç, niyet, sorular ve yüklediğiniz fotoğraflar '
          'hizmetin sunulması için işlenir.',
    ),
    _PolicySection(
      title: '3. Verilerin Kullanımı',
      body:
          'Verileriniz fal yorumlarının oluşturulması, manuel fal taleplerinin yönetilmesi, '
          'jeton bakiyenizin takibi, bildirim gönderimi ve hesap güvenliği amacıyla kullanılır.',
    ),
    _PolicySection(
      title: '4. Üçüncü Taraf Hizmetler',
      body:
          'Uygulama Firebase (kimlik doğrulama, veritabanı, bildirimler), yapay zeka servisleri '
          've ödeme altyapıları gibi üçüncü taraf hizmetler kullanabilir. Bu hizmetler kendi '
          'gizlilik politikalarına tabidir.',
    ),
    _PolicySection(
      title: '5. Veri Saklama ve Güvenlik',
      body:
          'Verileriniz güvenli sunucularda saklanır. Hesabınızı sildiğinizde ilgili veriler '
          'kalıcı olarak silinmeye çalışılır. Hiçbir sistem %100 güvenlik garantisi veremez; '
          'makul teknik ve idari önlemler alınır.',
    ),
    _PolicySection(
      title: '6. Haklarınız',
      body:
          'Verilerinize erişme, düzeltme ve hesabınızı silme hakkına sahipsiniz. '
          'Profil ekranından hesabınızı silebilir veya bizimle iletişime geçebilirsiniz.',
    ),
    _PolicySection(
      title: '7. Çocukların Gizliliği',
      body:
          'Falora 18 yaş altı kullanıcılar için tasarlanmamıştır. Bilerek çocuklardan '
          'kişisel veri toplanmaz.',
    ),
    _PolicySection(
      title: '8. Değişiklikler',
      body:
          'Bu politika zaman zaman güncellenebilir. Önemli değişiklikler uygulama içinde '
          'duyurulabilir. Güncel metin bu sayfada yayımlanır.',
    ),
    _PolicySection(
      title: '9. İletişim',
      body:
          'Gizlilik ile ilgili sorularınız için: falora.admin@falora.app',
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
                icon: const Icon(Icons.open_in_new),
                label: const Text('Web sürümünü aç'),
              ),
              const SizedBox(height: 16),
            ],
            for (final section in _sections) ...[
              Text(
                section.title,
                style: const TextStyle(
                  color: faloraGold,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                section.body,
                style: const TextStyle(
                  color: faloraTextSecondary,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
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
