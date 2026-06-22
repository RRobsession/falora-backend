import 'package:falora/auth/auth_service.dart';

import 'package:falora/models/app_user.dart';

import 'package:falora/screens/invite_friend_screen.dart';
import 'package:falora/screens/shop_screen.dart';
import 'package:falora/services/privacy_policy_service.dart';

import 'package:falora/services/rewarded_ad_service.dart';

import 'package:falora/theme/falora_theme.dart';

import 'package:falora/widgets/live_token_builder.dart';

import 'package:falora/widgets/premium_ui.dart';

import 'package:falora/widgets/reward_ad_helper.dart';

import 'package:flutter/material.dart';



class ProfileScreen extends StatefulWidget {

  const ProfileScreen({

    super.key,

    required this.user,

    required this.onLogout,

    this.authService,

  });



  final AppUser user;

  final VoidCallback onLogout;

  final AuthService? authService;



  @override

  State<ProfileScreen> createState() => _ProfileScreenState();

}



class _ProfileScreenState extends State<ProfileScreen> {

  late final AuthService _authService =

      widget.authService ?? createAuthService();



  bool _deletingAccount = false;



  @override

  void initState() {

    super.initState();

    debugPrint('PROFILE SCREEN LOADED userId=${widget.user.userId}');

  }



  Future<void> _watchRewardAd(BuildContext context) async {

    await watchRewardAdFlow(context, user: widget.user);

  }



  void _openShop(BuildContext context) {

    Navigator.of(context).push(

      faloraPageRoute<void>(ShopScreen(userId: widget.user.userId)),

    );

  }



  void _openInvite(BuildContext context) {
    Navigator.of(context).push(
      faloraPageRoute<void>(
        InviteFriendScreen(userId: widget.user.userId),
      ),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    await PrivacyPolicyService.instance.openPrivacyPolicy(context);
  }

  void _showComingSoon(String feature) {

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(content: Text('$feature yakında aktif olacak.')),

    );

  }



  Future<void> _confirmLogout() async {

    final confirm = await showDialog<bool>(

      context: context,

      builder: (ctx) => AlertDialog(

        title: const Text('Çıkış Yap'),

        content: const Text('Çıkış yapmak istediğine emin misin?'),

        actions: [

          TextButton(

            onPressed: () => Navigator.pop(ctx, false),

            child: const Text('İptal'),

          ),

          TextButton(

            onPressed: () => Navigator.pop(ctx, true),

            child: const Text('Çıkış'),

          ),

        ],

      ),

    );



    if (confirm == true) widget.onLogout();

  }



  Future<String?> _askPasswordForReauth() async {

    final controller = TextEditingController();

    final formKey = GlobalKey<FormState>();



    try {

      return showDialog<String>(

        context: context,

        barrierDismissible: false,

        builder: (ctx) => AlertDialog(

          title: const Text('Kimlik Doğrulama'),

          content: Form(

            key: formKey,

            child: Column(

              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment: CrossAxisAlignment.stretch,

              children: [

                const Text(

                  'Hesabını silmek için güvenlik nedeniyle şifreni tekrar girmelisin.',

                ),

                const SizedBox(height: 16),

                TextFormField(

                  controller: controller,

                  obscureText: true,

                  decoration: const InputDecoration(labelText: 'Şifre'),

                  validator: (v) {

                    if (v == null || v.isEmpty) return 'Şifre gerekli';

                    return null;

                  },

                  onFieldSubmitted: (_) {

                    if (formKey.currentState?.validate() ?? false) {

                      Navigator.pop(ctx, controller.text);

                    }

                  },

                ),

              ],

            ),

          ),

          actions: [

            TextButton(

              onPressed: () => Navigator.pop(ctx),

              child: const Text('İptal'),

            ),

            TextButton(

              onPressed: () {

                if (formKey.currentState?.validate() ?? false) {

                  Navigator.pop(ctx, controller.text);

                }

              },

              child: const Text('Devam Et'),

            ),

          ],

        ),

      );

    } finally {

      controller.dispose();

    }

  }



  void _showError(String message) {

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(content: Text(message)),

    );

  }



  Future<void> _deleteAccount({String? password}) async {

    await _authService.deleteAccount(password: password);

    if (!mounted) return;

    widget.onLogout();

  }



  Future<void> _onDeleteAccountPressed() async {

    final confirm = await showDialog<bool>(

      context: context,

      builder: (ctx) => AlertDialog(

        title: const Text('Hesabımı Sil'),

        content: const Text(

          'Hesabını silersen tüm verilerin kalıcı olarak silinir.',

        ),

        actions: [

          TextButton(

            onPressed: () => Navigator.pop(ctx, false),

            child: const Text('İptal'),

          ),

          TextButton(

            onPressed: () => Navigator.pop(ctx, true),

            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),

            child: const Text('Hesabımı Sil'),

          ),

        ],

      ),

    );



    if (confirm != true || !mounted) return;



    setState(() => _deletingAccount = true);



    try {

      await _deleteAccount();

    } on AuthException catch (e) {

      if (!mounted) return;



      if (e.requiresReauth) {

        final password = await _askPasswordForReauth();

        if (password == null || !mounted) return;



        setState(() => _deletingAccount = true);

        try {

          await _deleteAccount(password: password);

        } on AuthException catch (e2) {

          _showError(e2.message);

        } catch (_) {

          _showError('Hesap silinemedi. Lütfen tekrar deneyin.');

        }

      } else {

        _showError(e.message);

      }

    } catch (_) {

      _showError('Hesap silinemedi. Lütfen tekrar deneyin.');

    } finally {

      if (mounted) setState(() => _deletingAccount = false);

    }

  }



  String get _initial {

    final name = widget.user.name.trim();

    if (name.isNotEmpty) return name[0].toUpperCase();

    final email = widget.user.email.trim();

    if (email.isNotEmpty) return email[0].toUpperCase();

    return '?';

  }



  @override

  Widget build(BuildContext context) {

    final adService = RewardedAdService.instance;

    final hasReward = adService.hasDailyRewardAvailable(widget.user);

    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;



    return Stack(

      children: [

        Container(

          decoration: const BoxDecoration(

            gradient: LinearGradient(

              begin: Alignment.topCenter,

              end: Alignment.bottomCenter,

              colors: [faloraBg, Color(0xFF110D1F), faloraBg],

            ),

          ),

          child: SafeArea(

            child: SingleChildScrollView(

              padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.stretch,

                children: [

                  const Text(

                    'Profilim',

                    style: TextStyle(

                      color: faloraTextPrimary,

                      fontSize: 24,

                      fontWeight: FontWeight.w800,

                    ),

                  ),

                  const SizedBox(height: 16),

                  _ProfileUserCard(

                    initial: _initial,

                    name: widget.user.name,

                    email: widget.user.email,

                    fallbackTokens: widget.user.tokens,

                  ),

                  if (hasReward) ...[

                    const SizedBox(height: 12),

                    GiftRewardCard(

                      hasReward: hasReward,

                      onWatch: () => _watchRewardAd(context),

                    ),

                  ],

                  const SizedBox(height: 20),

                  _ProfileMenuSection(

                    children: [

                      _ProfileMenuTile(

                        icon: Icons.storefront_rounded,

                        iconColor: faloraBronzeDark,

                        title: 'Jeton Mağazası',

                        subtitle: 'Premium jeton paketleri',

                        onTap: () => _openShop(context),

                      ),

                      _ProfileMenuTile(

                        icon: Icons.person_add_alt_1_rounded,

                        iconColor: faloraAccent,

                        title: 'Arkadaşını Davet Et',

                        subtitle: 'Davet kodunla jeton kazan',

                        onTap: () => _openInvite(context),

                      ),

                      _ProfileMenuTile(

                        icon: Icons.notifications_outlined,

                        iconColor: const Color(0xFF64D4C8),

                        title: 'Bildirimler',

                        subtitle: 'Fal hazır bildirimleri',

                        onTap: () => _showComingSoon('Bildirim ayarları'),

                      ),

                      _ProfileMenuTile(

                        icon: Icons.privacy_tip_outlined,

                        iconColor: faloraTextSecondary,

                        title: 'Gizlilik Politikası',

                        subtitle: 'Veri kullanımı ve gizlilik',

                        onTap: _openPrivacyPolicy,

                      ),

                      _ProfileMenuTile(

                        icon: Icons.delete_forever_outlined,

                        iconColor: Colors.redAccent,

                        title: 'Hesabımı Sil',

                        subtitle: 'Tüm veriler kalıcı silinir',

                        onTap: _deletingAccount ? null : _onDeleteAccountPressed,

                        isDestructive: true,

                        showDivider: false,

                      ),

                    ],

                  ),

                  const SizedBox(height: 20),

                  SizedBox(

                    width: double.infinity,

                    child: OutlinedButton.icon(

                      onPressed: _deletingAccount ? null : _confirmLogout,

                      icon: const Icon(Icons.logout_rounded),

                      label: const Text('Çıkış Yap'),

                      style: OutlinedButton.styleFrom(

                        foregroundColor: faloraBronzeDark,

                        side: BorderSide(

                          color: faloraBronze.withValues(alpha: 0.6),

                        ),

                        padding: const EdgeInsets.symmetric(vertical: 14),

                        shape: RoundedRectangleBorder(

                          borderRadius: BorderRadius.circular(14),

                        ),

                      ),

                    ),

                  ),

                ],

              ),

            ),

          ),

        ),

        if (_deletingAccount)

          const ColoredBox(

            color: Color(0x88000000),

            child: Center(

              child: Card(

                child: Padding(

                  padding: EdgeInsets.all(24),

                  child: Column(

                    mainAxisSize: MainAxisSize.min,

                    children: [

                      CircularProgressIndicator(),

                      SizedBox(height: 16),

                      Text('Hesabın siliniyor...'),

                    ],

                  ),

                ),

              ),

            ),

          ),

      ],

    );

  }

}



class _ProfileUserCard extends StatelessWidget {

  const _ProfileUserCard({

    required this.initial,

    required this.name,

    required this.email,

    required this.fallbackTokens,

  });



  final String initial;

  final String name;

  final String email;

  final int fallbackTokens;



  @override

  Widget build(BuildContext context) {

    return Container(

      padding: const EdgeInsets.all(20),

      decoration: faloraGlassDecoration(

        accent: faloraAccent,

        radius: 22,

        opacity: 0.16,

      ),

      child: Row(

        children: [

          Container(

            width: 64,

            height: 64,

            decoration: BoxDecoration(

              shape: BoxShape.circle,

              gradient: LinearGradient(

                colors: [

                  faloraAccent.withValues(alpha: 0.55),

                  faloraGold.withValues(alpha: 0.25),

                ],

              ),

              border: Border.all(color: faloraGold.withValues(alpha: 0.35)),

            ),

            alignment: Alignment.center,

            child: Text(

              initial,

              style: const TextStyle(

                fontSize: 28,

                fontWeight: FontWeight.w800,

                color: faloraInkHeading,

              ),

            ),

          ),

          const SizedBox(width: 16),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  name.isNotEmpty ? name : 'Kullanıcı',

                  style: const TextStyle(

                    fontSize: 18,

                    fontWeight: FontWeight.w800,

                    color: faloraTextPrimary,

                  ),

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                ),

                const SizedBox(height: 4),

                Text(

                  email,

                  style: const TextStyle(

                    color: faloraTextSecondary,

                    fontSize: 13,

                  ),

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                ),

                const SizedBox(height: 10),

                LiveTokenBuilder(

                  fallbackTokens: fallbackTokens,

                  builder: (context, tokens) {

                    return Container(

                      padding: const EdgeInsets.symmetric(

                        horizontal: 12,

                        vertical: 6,

                      ),

                      decoration: BoxDecoration(

                        color: faloraGold.withValues(alpha: 0.12),

                        borderRadius: BorderRadius.circular(20),

                        border: Border.all(

                          color: faloraGold.withValues(alpha: 0.28),

                        ),

                      ),

                      child: Row(

                        mainAxisSize: MainAxisSize.min,

                        children: [

                          const Icon(Icons.toll, color: faloraGoldReadable, size: 18),

                          const SizedBox(width: 6),

                          Text(

                            '$tokens jeton',

                            style: const TextStyle(

                              color: faloraInkHeading,

                              fontWeight: FontWeight.w700,

                              fontSize: 14,

                            ),

                          ),

                        ],

                      ),

                    );

                  },

                ),

              ],

            ),

          ),

        ],

      ),

    );

  }

}



class _ProfileMenuSection extends StatelessWidget {

  const _ProfileMenuSection({required this.children});



  final List<Widget> children;



  @override

  Widget build(BuildContext context) {

    return Container(

      decoration: faloraGlassDecoration(radius: 20, opacity: 0.12),

      child: Column(children: children),

    );

  }

}



class _ProfileMenuTile extends StatelessWidget {

  const _ProfileMenuTile({

    required this.icon,

    required this.iconColor,

    required this.title,

    required this.subtitle,

    required this.onTap,

    this.isDestructive = false,

    this.showDivider = true,

  });



  final IconData icon;

  final Color iconColor;

  final String title;

  final String subtitle;

  final VoidCallback? onTap;

  final bool isDestructive;

  final bool showDivider;



  @override

  Widget build(BuildContext context) {

    return Column(

      children: [

        ListTile(

          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),

          leading: Container(

            width: 42,

            height: 42,

            decoration: BoxDecoration(

              color: iconColor.withValues(alpha: isDestructive ? 0.14 : 0.12),

              borderRadius: BorderRadius.circular(12),

            ),

            child: Icon(icon, color: iconColor, size: 22),

          ),

          title: Text(

            title,

            style: TextStyle(

              fontWeight: FontWeight.w600,

              color: isDestructive ? Colors.redAccent : faloraTextPrimary,

            ),

          ),

          subtitle: Text(

            subtitle,

            style: const TextStyle(fontSize: 12, color: faloraTextSecondary),

          ),

          trailing: Icon(

            Icons.chevron_right_rounded,

            color: isDestructive

                ? Colors.redAccent.withValues(alpha: 0.7)

                : faloraTextSecondary,

          ),

          onTap: onTap,

        ),

        if (showDivider)

          Divider(

            height: 1,

            indent: 72,

            color: Colors.white.withValues(alpha: 0.06),

          ),

      ],

    );

  }

}

