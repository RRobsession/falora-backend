import 'package:falora/config/referral_config.dart';
import 'package:falora/services/referral_service.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:flutter/material.dart';

class InviteFriendScreen extends StatefulWidget {
  const InviteFriendScreen({super.key, required this.userId});

  final String userId;

  @override
  State<InviteFriendScreen> createState() => _InviteFriendScreenState();
}

class _InviteFriendScreenState extends State<InviteFriendScreen> {
  String? _code;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCode();
  }

  Future<void> _loadCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final code = await ReferralService.instance.ensureReferralCode(widget.userId);
      if (!mounted) return;
      setState(() {
        _code = code;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _copyCode() async {
    final code = _code;
    if (code == null) return;
    await ReferralService.instance.copyReferralCode(code);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Davet kodu kopyalandı.')),
    );
  }

  Future<void> _shareCode(BuildContext buttonContext) async {
    final code = _code;
    if (code == null) return;

    Rect? shareOrigin;
    final renderBox = buttonContext.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      shareOrigin = renderBox.localToGlobal(Offset.zero) & renderBox.size;
    }

    final outcome = await ReferralService.instance.shareReferralCode(
      code,
      sharePositionOrigin: shareOrigin,
    );
    if (!mounted) return;

    final message = switch (outcome) {
      ReferralShareOutcome.clipboardFallback =>
        'Davet mesajı panoya kopyalandı',
      ReferralShareOutcome.nativeShare ||
      ReferralShareOutcome.webShare =>
        'Paylaşım menüsü açıldı',
      ReferralShareOutcome.dismissed => null,
      ReferralShareOutcome.failed =>
        'Paylaşım açılamadı. Lütfen tekrar deneyin.',
    };

    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Arkadaşını Davet Et')),
      body: FaloraBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadCode,
                            child: const Text('Tekrar Dene'),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      24 + MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: faloraGlassDecoration(
                            accent: faloraAccent,
                            radius: 22,
                            opacity: 0.18,
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Davet Kodun',
                                style: TextStyle(
                                  color: faloraTextSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SelectableText(
                                _code ?? '—',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: faloraGold,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Arkadaşın kayıt olurken bu kodu girsin. E-postasını doğruladığında '
                          'sen $referralInviterRewardTokens, o $referralInviteeRewardTokens jeton kazanır.',
                          style: const TextStyle(
                            color: faloraTextSecondary,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _copyCode,
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Kodu Kopyala'),
                        ),
                        const SizedBox(height: 12),
                        Builder(
                          builder: (buttonContext) {
                            return OutlinedButton.icon(
                              onPressed: () => _shareCode(buttonContext),
                              icon: const Icon(Icons.share_rounded),
                              label: const Text('Paylaş'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: faloraGold,
                                side: BorderSide(
                                  color: faloraGold.withValues(alpha: 0.45),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
