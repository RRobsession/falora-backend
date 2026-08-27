import 'package:falora/models/app_user.dart';
import 'package:falora/services/token_service.dart';
import 'package:falora/widgets/falora_component_library.dart';
import 'package:flutter/material.dart';

/// Firestore `users/{uid}.tokens` alanını realtime dinleyen builder.
class LiveTokenBuilder extends StatelessWidget {
  const LiveTokenBuilder({
    super.key,
    required this.builder,
    this.fallbackTokens = 0,
  });

  final Widget Function(BuildContext context, int tokens) builder;
  final int fallbackTokens;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppUser?>(
      valueListenable: TokenService.instance.liveUser,
      builder: (context, user, _) {
        return builder(context, user?.tokens ?? fallbackTokens);
      },
    );
  }
}

/// Canlı jeton bakiyesi — dokunulunca mağazaya yönlendirir.
class FaloraLiveTappableTokenBalance extends StatelessWidget {
  const FaloraLiveTappableTokenBalance({
    super.key,
    required this.onOpenShop,
    this.compact = false,
    this.showLabel = true,
    this.showHint = true,
    this.fallbackTokens = 0,
  });

  final VoidCallback onOpenShop;
  final bool compact;
  final bool showLabel;
  final bool showHint;
  final int fallbackTokens;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppUser?>(
      valueListenable: TokenService.instance.liveUser,
      builder: (context, user, _) => Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FaloraTappableTokenBalance(
            tokens: user?.tokens ?? fallbackTokens,
            onTap: onOpenShop,
            compact: compact,
            showLabel: showLabel,
            showHint: showHint,
          ),
          InkWell(
            onTap: onOpenShop,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 10,
                vertical: compact ? 5 : 7,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              child: Text(
                'Özel Fal Hakkı: ${user?.specialFortuneRights ?? 0}',
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tam kullanıcı verisi gerektiğinde (profil vb.).
class LiveUserBuilder extends StatelessWidget {
  const LiveUserBuilder({
    super.key,
    required this.builder,
    required this.fallbackUser,
  });

  final Widget Function(BuildContext context, AppUser user) builder;
  final AppUser fallbackUser;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppUser?>(
      valueListenable: TokenService.instance.liveUser,
      builder: (context, user, _) {
        return builder(context, user ?? fallbackUser);
      },
    );
  }
}
