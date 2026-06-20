import 'package:falora/config/app_links_config.dart';
import 'package:falora/screens/privacy_policy_screen.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyService {
  PrivacyPolicyService._();

  static final PrivacyPolicyService instance = PrivacyPolicyService._();

  Future<void> openPrivacyPolicy(BuildContext context) async {
    debugPrint('PRIVACY_POLICY_OPEN_START');
    try {
      final url = privacyPolicyUrl.trim();
      if (url.isNotEmpty) {
        final uri = Uri.parse(url);
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          debugPrint('PRIVACY_POLICY_OPEN_SUCCESS external');
          return;
        }
      }

      if (!context.mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
      );
      debugPrint('PRIVACY_POLICY_OPEN_SUCCESS in_app');
    } catch (e, stack) {
      debugPrint('PRIVACY_POLICY_OPEN_ERROR: $e');
      debugPrint(stack.toString());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gizlilik politikası şu anda açılamıyor.'),
          ),
        );
      }
    }
  }
}
