import 'package:falora/screens/terms_of_service_screen.dart';
import 'package:flutter/material.dart';

class TermsOfServiceService {
  TermsOfServiceService._();

  static final TermsOfServiceService instance = TermsOfServiceService._();

  Future<void> openTermsOfService(BuildContext context) async {
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
    );
  }
}
