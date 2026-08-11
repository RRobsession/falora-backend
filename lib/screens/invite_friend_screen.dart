import 'package:falora/config/referral_config.dart';
import 'package:falora/models/app_user.dart';
import 'package:falora/services/referral_service.dart';
import 'package:falora/services/token_service.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InviteFriendScreen extends StatefulWidget {
  const InviteFriendScreen({super.key, required this.userId});

  final String userId;

  @override
  State<InviteFriendScreen> createState() => _InviteFriendScreenState();
}

class _InviteFriendScreenState extends State<InviteFriendScreen> {
  final _enterCodeCtrl = TextEditingController();
  String? _code;
  bool _loading = true;
  bool _claiming = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCode();
  }

  @override
  void dispose() {
    _enterCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final code =
          await ReferralService.instance.ensureReferralCode(widget.userId);
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

  Future<void> _submitEnteredCode() async {
    if (_claiming) return;
    final raw = _enterCodeCtrl.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir davet kodu girin.')),
      );
      return;
    }

    setState(() => _claiming = true);
    try {
      final message = await ReferralService.instance.claimEnteredReferralCode(
        uid: widget.userId,
        referralCode: raw,
      );
      if (!mounted) return;
      _enterCodeCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      setState(() {});
    } on ReferralException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(referralClaimFailedMessage)),
      );
    } finally {
      if (mounted) setState(() => _claiming = false);
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
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: FaloraTypography.bodyOnParchment,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadCode,
                            child: const Text('Tekrar Dene'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ValueListenableBuilder<AppUser?>(
                    valueListenable: TokenService.instance.liveUser,
                    builder: (context, liveUser, _) {
                      final canEnter =
                          liveUser?.userId == widget.userId
                              ? (liveUser?.canEnterReferralCode ?? true)
                              : true;
                      return SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          20,
                          20,
                          24 + MediaQuery.viewPaddingOf(context).bottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FaloraParchmentCard(
                              padding: const EdgeInsets.all(22),
                              child: Column(
                                children: [
                                  Text(
                                    'Davet Kodun',
                                    style: FaloraTypography.labelLarge.copyWith(
                                      color: faloraInkSoft,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SelectableText(
                                    _code ?? '—',
                                    textAlign: TextAlign.center,
                                    style:
                                        FaloraTypography.goldReadable.copyWith(
                                      fontSize: 32,
                                      letterSpacing: 4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Kodunu istediğin kadar paylaş. Arkadaşın kayıt olurken '
                              'veya bu ekrandan kodunu girince sen +$referralInviterRewardTokens, '
                              'o +$referralInviteeRewardTokens jeton kazanır.',
                              style: FaloraTypography.bodyOnParchment,
                            ),
                            const SizedBox(height: 24),
                            FaloraPrimaryButton(
                              label: 'Kodu Kopyala',
                              icon: Icons.copy_rounded,
                              onPressed: _copyCode,
                            ),
                            const SizedBox(height: 12),
                            Builder(
                              builder: (buttonContext) {
                                return FaloraSealButton(
                                  label: 'Paylaş',
                                  icon: Icons.share_rounded,
                                  onPressed: () => _shareCode(buttonContext),
                                );
                              },
                            ),
                            const SizedBox(height: 28),
                            Text(
                              'Arkadaşının kodunu gir',
                              style: FaloraTypography.sectionHeading.copyWith(
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              canEnter
                                  ? 'Her hesap yalnızca bir kez davet kodu girebilir. '
                                      'Doğru kodda +$referralInviteeRewardTokens jeton kazanırsın.'
                                  : 'Davet kodu hakkını zaten kullandın.',
                              style: FaloraTypography.bodyOnParchment,
                            ),
                            const SizedBox(height: 14),
                            if (canEnter) ...[
                              TextField(
                                controller: _enterCodeCtrl,
                                textCapitalization:
                                    TextCapitalization.characters,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[A-Za-z0-9]'),
                                  ),
                                  LengthLimitingTextInputFormatter(
                                    referralCodeLength,
                                  ),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Davet kodu',
                                  hintText: 'Örn. AB12CD34',
                                  border: OutlineInputBorder(),
                                ),
                                enabled: !_claiming,
                                onSubmitted: (_) => _submitEnteredCode(),
                              ),
                              const SizedBox(height: 12),
                              FaloraPrimaryButton(
                                label: _claiming
                                    ? 'İşleniyor...'
                                    : 'Kodu kullan (+$referralInviteeRewardTokens jeton)',
                                icon: Icons.card_giftcard_rounded,
                                onPressed:
                                    _claiming ? null : _submitEnteredCode,
                              ),
                            ] else
                              FaloraParchmentCard(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      color: faloraBronzeDark,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        referralAlreadyClaimedMessage,
                                        style:
                                            FaloraTypography.bodyOnParchment,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
