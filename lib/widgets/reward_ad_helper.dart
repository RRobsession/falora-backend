import 'dart:ui';



import 'package:falora/models/app_user.dart';

import 'package:falora/services/rewarded_ad_service.dart';

import 'package:falora/token_config.dart';

import 'package:falora/widgets/premium_ui.dart';

import 'package:flutter/material.dart';



Future<void> showRewardAdSheet(

  BuildContext context, {

  required AppUser user,

}) {

  final adService = RewardedAdService.instance;

  final hasReward = adService.hasDailyRewardAvailable(user);



  return showGeneralDialog<void>(

    context: context,

    barrierDismissible: true,

    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,

    barrierColor: Colors.black.withValues(alpha: 0.42),

    transitionDuration: const Duration(milliseconds: 260),

    pageBuilder: (ctx, _, __) {

      return Material(

        type: MaterialType.transparency,

        child: Stack(

          fit: StackFit.expand,

          children: [

            BackdropFilter(

              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),

              child: const SizedBox.expand(),

            ),

            Center(

              child: GiftRewardModal(

                hasReward: hasReward,

                onClose: () => Navigator.pop(ctx),

                onWatch: hasReward

                    ? () async {

                        Navigator.pop(ctx);

                        await watchRewardAdFlow(

                          context,

                          user: user,

                        );

                      }

                    : null,

              ),

            ),

          ],

        ),

      );

    },

    transitionBuilder: (context, animation, _, child) {

      final curved = CurvedAnimation(

        parent: animation,

        curve: Curves.easeOutCubic,

        reverseCurve: Curves.easeInCubic,

      );

      return FadeTransition(

        opacity: curved,

        child: ScaleTransition(

          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),

          child: child,

        ),

      );

    },

  );

}



Future<void> watchRewardAdFlow(

  BuildContext context, {

  required AppUser user,

}) async {

  final adService = RewardedAdService.instance;

  if (!adService.hasDailyRewardAvailable(user)) {

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(

      const SnackBar(

        content: Text('Bugünkü ücretsiz jeton hakkını kullandın.'),

      ),

    );

    return;

  }



  final result = await adService.watchAndClaim(

    context: context,

    userId: user.userId,

    user: user,

  );

  if (!context.mounted) return;



  switch (result) {

    case RewardedAdResult.rewarded:

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text('+$rewardAdTokenGrant jeton kazandınız!')),

      );

    case RewardedAdResult.limitReached:

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(

          content: Text('Bugünkü ücretsiz jeton hakkını kullandın.'),

        ),

      );

    case RewardedAdResult.cancelled:

      break;

    case RewardedAdResult.failed:

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(

          content: Text('Reklam ödülü alınamadı, tekrar deneyin.'),

        ),

      );

  }

}


