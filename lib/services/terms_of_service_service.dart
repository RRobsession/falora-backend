import 'package:falora/config/app_links_config.dart';
import 'package:falora/screens/terms_of_service_screen.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TermsOfServiceService {
  TermsOfServiceService._();

  static final TermsOfServiceService instance = TermsOfServiceService._();

  Future<void> openTermsOfService(BuildContext context) async {
    try {
      final url = termsOfServiceUrl.trim();
      if (url.isNotEmpty) {
        final launched = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      }

      if (!context.mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kullanıcı sözleşmesi şu anda açılamıyor.'),
          ),
        );
      }
    }
  }
}
