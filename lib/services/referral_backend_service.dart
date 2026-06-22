import 'dart:convert';

import 'package:falora/ai_config.dart';
import 'package:falora/services/backend_auth_client.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum ReferralClaimCode {
  success,
  notFound,
  alreadyClaimed,
  selfReferral,
  serverError,
}

class ReferralClaimResult {
  const ReferralClaimResult({
    required this.code,
    this.rewardTokens = 0,
  });

  final ReferralClaimCode code;
  final int rewardTokens;
}

class ReferralBackendException implements Exception {
  ReferralBackendException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ReferralBackendService {
  ReferralBackendService._();

  static final ReferralBackendService instance = ReferralBackendService._();

  Future<ReferralClaimResult> claimReferral({
    required String referralCode,
  }) async {
    debugPrint('REFERRAL_CLAIM_START code=${referralCode.trim()}');
    final uri = Uri.parse('$apiBaseUrl/referrals/claim');
    final headers = await BackendAuthClient.authHeaders();

    http.Response response;
    try {
      response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({'referralCode': referralCode.trim()}),
      );
    } catch (e, stackTrace) {
      debugPrint('REFERRAL_TRANSACTION_FAILED network: $e');
      debugPrint(stackTrace.toString());
      throw ReferralBackendException('Referans ödülü şu an işlenemedi.');
    }

    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {}

    if (response.statusCode == 404) {
      debugPrint('REFERRAL_CODE_NOT_FOUND');
      debugPrint('REFERRAL_IGNORED_REGISTRATION_CONTINUES');
      return const ReferralClaimResult(code: ReferralClaimCode.notFound);
    }

    if (response.statusCode == 409) {
      final raw = data['code'] as String? ?? '';
      if (raw == 'self_referral') {
        debugPrint('REFERRAL_SELF_REFERRAL_BLOCKED');
        return const ReferralClaimResult(code: ReferralClaimCode.selfReferral);
      }
      debugPrint('REFERRAL_ALREADY_CLAIMED');
      return const ReferralClaimResult(code: ReferralClaimCode.alreadyClaimed);
    }

    if (response.statusCode >= 200 && response.statusCode < 300 && data['ok'] == true) {
      final reward = (data['rewardTokens'] as num?)?.toInt() ?? 0;
      debugPrint('REFERRAL_TRANSACTION_SUCCESS reward=$reward');
      return ReferralClaimResult(
        code: ReferralClaimCode.success,
        rewardTokens: reward,
      );
    }

    debugPrint('REFERRAL_TRANSACTION_FAILED status=${response.statusCode} body=${response.body}');
    throw ReferralBackendException(
      data['error'] as String? ?? 'Referans ödülü işlenemedi.',
    );
  }
}
