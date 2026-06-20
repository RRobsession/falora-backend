import 'package:falora/services/token_service.dart';

import 'package:falora/theme/falora_theme.dart';

import 'package:falora/token_config.dart';

import 'package:falora/widgets/live_token_builder.dart';

import 'package:falora/widgets/premium_ui.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';



class ShopScreen extends StatelessWidget {

  const ShopScreen({

    super.key,

    required this.userId,

  });



  final String userId;



  Future<void> _buy(BuildContext context, int amount) async {
    if (!kDebugMode) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Satın alma yakında aktif olacak.'),
        ),
      );
      return;
    }

    try {

      await TokenService.instance.mockPurchase(userId, amount);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text('$amount jeton hesabına eklendi (mock)')),

      );

    } catch (e) {

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text('Satın alma başarısız: $e')),

      );

    }

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(title: const Text('Jeton Mağazası')),

      body: FaloraBackground(

        child: LiveTokenBuilder(

          builder: (context, tokens) {

            return ListView(

              padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),

              children: [

                ClipRRect(

                  borderRadius: BorderRadius.circular(24),

                  child: Container(

                    padding: const EdgeInsets.all(22),

                    decoration: faloraGlassDecoration(radius: 24, opacity: 0.16),

                    child: Column(

                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        Text(

                          'Premium Jeton Mağazası',

                          style: TextStyle(

                            color: faloraGold.withValues(alpha: 0.95),

                            fontSize: 13,

                            fontWeight: FontWeight.w700,

                            letterSpacing: 1.2,

                          ),

                        ),

                        const SizedBox(height: 16),

                        PremiumTokenBalanceCard(tokens: tokens, compact: true),

                        const SizedBox(height: 14),

                        Text(

                          'Fallar falcıya göre 50–150 jeton; çift uyumu $coupleTokenCost jeton harcar.',

                          style: TextStyle(

                            color: faloraTextSecondary.withValues(alpha: 0.92),

                            fontSize: 13,

                            height: 1.45,

                          ),

                        ),

                      ],

                    ),

                  ),

                ),

                const SizedBox(height: 28),

                ...shopPackageCatalog.map(

                  (pkg) => Padding(

                    padding: const EdgeInsets.only(bottom: 10),

                    child: ShopPackageCard(

                      tokens: pkg.tokens,

                      priceTry: pkg.priceTry,

                      badge: pkg.badge,

                      highlight: pkg.highlight,

                      onBuy: () => _buy(context, pkg.tokens),

                    ),

                  ),

                ),

                Text(

                  'Gerçek ödeme entegrasyonu yakında eklenecek.',

                  textAlign: TextAlign.center,

                  style: TextStyle(

                    color: faloraTextSecondary.withValues(alpha: 0.65),

                    fontSize: 12,

                  ),

                ),

              ],

            );

          },

        ),

      ),

    );

  }

}


