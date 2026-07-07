import 'package:falora/auth/auth_service.dart';
import 'package:falora/models/app_user.dart';
import 'package:falora/screens/invite_friend_screen.dart';
import 'package:falora/screens/shop_screen.dart';
import 'package:falora/widgets/compact_birth_date_dialog.dart';
import 'package:falora/widgets/preset_avatar_picker.dart';
import 'package:falora/models/fortune_models.dart';
import 'package:falora/services/notification_service.dart';
import 'package:falora/services/user_profile_service.dart';
import 'package:falora/services/privacy_policy_service.dart';
import 'package:falora/services/terms_of_service_service.dart';
import 'package:falora/services/rewarded_ad_service.dart';
import 'package:falora/services/token_service.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/user_avatar_image.dart';
import 'package:falora/widgets/live_token_builder.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:falora/widgets/reward_ad_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

const _profileDangerColor = Color(0xFF8B3A3A);

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
  bool _updatingAvatar = false;

  @override
  void initState() {
    super.initState();
    debugPrint('PROFILE SCREEN LOADED userId=${widget.user.userId}');
  }

  Future<void> _watchRewardAd(BuildContext context) async {
    final user = TokenService.instance.liveUser.value ?? widget.user;
    await watchRewardAdFlow(context, user: user);
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

  Future<void> _openTermsOfService() async {
    await TermsOfServiceService.instance.openTermsOfService(context);
  }

  Future<void> _openNotificationSettings() async {
    final service = NotificationService.instance;
    final userId = widget.user.userId;

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return _NotificationSettingsSheet(
          userId: userId,
          service: service,
          hostContext: context,
        );
      },
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
            style: TextButton.styleFrom(foregroundColor: _profileDangerColor),
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

  Future<void> _pickGalleryAvatar(AppUser liveUser) async {
    if (_updatingAvatar) return;
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 82,
      );
      if (file == null) return;
      setState(() => _updatingAvatar = true);
      final bytes = await file.readAsBytes();
      await UserProfileService.instance
          .saveGalleryAvatar(liveUser.userId, bytes);
    } catch (e) {
      _showError('Fotoğraf seçilemedi');
    } finally {
      if (mounted) setState(() => _updatingAvatar = false);
    }
  }

  Future<void> _openPresetAvatarPicker(AppUser liveUser) async {
    final asset = await PresetAvatarPickerPage.open(
      context,
      initialAsset: liveUser.avatarAsset,
    );
    if (asset == null) return;
    await _selectPresetAvatar(asset);
  }

  Future<void> _selectPresetAvatar(String assetPath) async {
    if (_updatingAvatar) return;
    setState(() => _updatingAvatar = true);
    try {
      await UserProfileService.instance
          .saveAvatarAsset(widget.user.userId, assetPath);
    } catch (e) {
      _showError('Avatar seçilemedi');
    } finally {
      if (mounted) setState(() => _updatingAvatar = false);
    }
  }

  Future<void> _editName(AppUser liveUser) async {
    final controller = TextEditingController(text: liveUser.effectiveDisplayName);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İsim'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'İsim'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
        ],
      ),
    );
    if (saved != true) return;
    final name = controller.text.trim();
    if (name.isEmpty) {
      _showError('İsim boş olamaz');
      return;
    }
    await UserProfileService.instance.saveDisplayName(liveUser.userId, name);
  }

  Future<void> _editBirthDate(AppUser liveUser) async {
    final picked = await showCompactBirthDateDialog(
      context,
      initialDate: liveUser.birthDate,
    );
    if (picked == null) return;
    await UserProfileService.instance.saveBirthDate(liveUser.userId, picked);
  }

  Future<void> _editZodiac(AppUser liveUser) async {
    var selected = liveUser.zodiac ?? burclar.first;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Burç'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: burclar.map((burc) {
                return RadioListTile<String>(
                  value: burc,
                  groupValue: selected,
                  title: Text(burc),
                  onChanged: (v) {
                    if (v != null) setLocal(() => selected = v);
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    await UserProfileService.instance.saveZodiac(liveUser.userId, selected);
  }

  Future<void> _showAvatarOptions(AppUser liveUser) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          decoration: faloraParchmentDecoration(
            radius: FaloraRadius.xl,
            raised: true,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: faloraBronze.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Profil fotoğrafı',
                    style: FaloraTypography.titleMedium.copyWith(
                      color: faloraInkHeading,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PhotoSheetTile(
                    icon: Icons.photo_library_outlined,
                    label: 'Galeriden seç',
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickGalleryAvatar(liveUser);
                    },
                  ),
                  _PhotoSheetTile(
                    icon: Icons.face_retouching_natural_outlined,
                    label: 'Hazır avatar seç',
                    onTap: () {
                      Navigator.pop(ctx);
                      _openPresetAvatarPicker(liveUser);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String get _initial {
    final name = widget.user.effectiveDisplayName;
    if (name.isNotEmpty) return name[0].toUpperCase();
    final email = widget.user.email.trim();
    if (email.isNotEmpty) return email[0].toUpperCase();
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final adService = RewardedAdService.instance;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Stack(
      children: [
        FaloraBackground(
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(18, 6, 18, 10 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Profilim',
                    style: FaloraTypography.titleLarge.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: faloraInk,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LiveUserBuilder(
                    fallbackUser: widget.user,
                    builder: (context, liveUser) {
                      final rewardAdsUsed =
                          TokenService.instance.rewardedAdsUsedToday(liveUser);
                      final hasReward =
                          adService.hasDailyRewardAvailable(liveUser);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ProfileUserCard(
                            initial: _initial,
                            name: liveUser.effectiveDisplayName,
                            email: liveUser.email,
                            age: liveUser.computedAge,
                            zodiac: liveUser.zodiac,
                            fallbackTokens: liveUser.tokens,
                            avatarAsset: liveUser.avatarAsset,
                            updatingAvatar: _updatingAvatar,
                            onAvatarTap: () => _showAvatarOptions(liveUser),
                            onOpenShop: () => _openShop(context),
                          ),
                          const SizedBox(height: 10),
                          GiftRewardCard(
                            hasReward: hasReward,
                            rewardAdsUsed: rewardAdsUsed,
                            onWatch: hasReward
                                ? () => _watchRewardAd(context)
                                : null,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _ProfileMenuSection(
                    children: [
                      _ProfileMenuTile(
                        icon: Icons.badge_outlined,
                        iconColor: faloraBronze,
                        title: 'İsim',
                        subtitle: 'Görünen adını düzenle',
                        onTap: () => _editName(
                          TokenService.instance.liveUser.value ?? widget.user,
                        ),
                      ),
                      _ProfileMenuTile(
                        icon: Icons.cake_outlined,
                        iconColor: faloraGoldDark,
                        title: 'Doğum Tarihi',
                        subtitle: 'Yaş otomatik hesaplanır',
                        onTap: () => _editBirthDate(
                          TokenService.instance.liveUser.value ?? widget.user,
                        ),
                      ),
                      _ProfileMenuTile(
                        icon: Icons.auto_awesome_outlined,
                        iconColor: faloraBronzeDark,
                        title: 'Burç',
                        subtitle: 'Burcunu güncelle',
                        onTap: () => _editZodiac(
                          TokenService.instance.liveUser.value ?? widget.user,
                        ),
                      ),
                      _ProfileMenuTile(
                        icon: Icons.storefront_rounded,
                        iconColor: faloraBronzeDark,
                        title: 'Jeton Mağazası',
                        subtitle: 'Premium jeton paketleri',
                        onTap: () => _openShop(context),
                      ),
                      _ProfileMenuTile(
                        icon: Icons.person_add_alt_1_rounded,
                        iconColor: faloraBronze,
                        title: 'Arkadaşını Davet Et',
                        subtitle: 'Davet kodunla jeton kazan',
                        onTap: () => _openInvite(context),
                      ),
                      _ProfileMenuTile(
                        icon: Icons.notifications_outlined,
                        iconColor: faloraGoldDark,
                        title: 'Bildirimler',
                        subtitle: 'Fal hazır bildirimleri',
                        onTap: _openNotificationSettings,
                      ),
                      _ProfileMenuTile(
                        icon: Icons.privacy_tip_outlined,
                        iconColor: faloraInkSoft,
                        title: 'Gizlilik Politikası',
                        subtitle: 'Veri kullanımı ve gizlilik',
                        onTap: _openPrivacyPolicy,
                      ),
                      _ProfileMenuTile(
                        icon: Icons.description_outlined,
                        iconColor: faloraInkSoft,
                        title: 'Kullanıcı Sözleşmesi',
                        subtitle: 'Hizmet şartları ve feragatler',
                        onTap: _openTermsOfService,
                      ),
                      _ProfileLogoutTile(
                        onPressed: _deletingAccount ? null : _confirmLogout,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ProfileDeleteSection(
                    deleting: _deletingAccount,
                    onPressed: _onDeleteAccountPressed,
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
    required this.age,
    required this.zodiac,
    required this.fallbackTokens,
    required this.avatarAsset,
    required this.updatingAvatar,
    required this.onAvatarTap,
    required this.onOpenShop,
  });

  final String initial;
  final String name;
  final String email;
  final int? age;
  final String? zodiac;
  final int fallbackTokens;
  final String? avatarAsset;
  final bool updatingAvatar;
  final VoidCallback onAvatarTap;
  final VoidCallback onOpenShop;

  @override
  Widget build(BuildContext context) {
    const avatarSize = 48.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: faloraParchmentDecoration(
        base: Color.lerp(faloraParchmentCard, faloraGold, 0.05)!,
        radius: FaloraRadius.lg,
        raised: true,
        borderWidth: 1.1,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: LiveTokenBuilder(
              fallbackTokens: fallbackTokens,
              builder: (context, tokens) {
                return ScaleTap(
                  onTap: onOpenShop,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: faloraParchmentRaised,
                      border: Border.all(color: faloraGoldDark, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FaIcon(
                          FontAwesomeIcons.coins,
                          size: 9,
                          color: faloraBronzeDark,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$tokens',
                          style: const TextStyle(
                            color: faloraInk,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ScaleTap(
                onTap: updatingAvatar ? null : onAvatarTap,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: faloraGoldDark, width: 1.5),
                      ),
                      child: UserAvatarImage(
                        avatarAsset: avatarAsset,
                        size: avatarSize,
                        fallbackInitial: initial,
                      ),
                    ),
                    if (updatingAvatar)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.35),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: faloraParchmentRaised,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: faloraParchmentRaised,
                          border: Border.all(color: faloraGoldDark, width: 1),
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          size: 10,
                          color: faloraBronzeDark,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 52),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name.isNotEmpty ? name : 'Kullanıcı',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: faloraInk,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        email,
                        style: FaloraTypography.bodyMedium.copyWith(
                          color: faloraInkSoft,
                          fontSize: 11,
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((age != null && age! > 0) ||
                          (zodiac != null && zodiac!.isNotEmpty)) ...[
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (age != null && age! > 0)
                              _ProfileMiniBadge(label: 'Yaş $age'),
                            if (zodiac != null && zodiac!.isNotEmpty)
                              _ProfileMiniBadge(label: zodiac!),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileMiniBadge extends StatelessWidget {
  const _ProfileMiniBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: faloraParchmentRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: faloraBronze.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: faloraInk,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ProfileInfoBadges extends StatelessWidget {
  const _ProfileInfoBadges({
    required this.age,
    required this.zodiac,
  });

  final int? age;
  final String? zodiac;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (age != null && age! > 0) {
      chips.add(_ProfileInfoChip(label: 'Yaş', value: '$age'));
    }
    if (zodiac != null && zodiac!.isNotEmpty) {
      if (chips.isNotEmpty) chips.add(const SizedBox(width: 8));
      chips.add(_ProfileInfoChip(label: 'Burç', value: zodiac!));
    }
    if (chips.isEmpty) return const SizedBox.shrink();

    return Row(children: chips);
  }
}

class _ProfileInfoChip extends StatelessWidget {
  const _ProfileInfoChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: faloraParchmentRaised,
          borderRadius: BorderRadius.circular(FaloraRadius.md),
          border: Border.all(
            color: faloraGoldDark.withValues(alpha: 0.55),
            width: 1,
          ),
        ),
        child: RichText(
          text: TextSpan(
            style: FaloraTypography.labelSmall.copyWith(
              color: faloraInkSoft,
              fontSize: 11,
              height: 1.2,
            ),
            children: [
              TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              TextSpan(
                text: value,
                style: const TextStyle(
                  color: faloraInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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
      decoration: faloraParchmentDecoration(
        radius: FaloraRadius.lg,
        raised: true,
      ),
      clipBehavior: Clip.antiAlias,
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
    this.showDivider = true,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: iconColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Icon(icon, color: iconColor, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: FaloraTypography.titleMedium.copyWith(
                            fontSize: 14,
                            color: faloraInk,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          style: FaloraTypography.labelSmall.copyWith(
                            color: faloraInkSoft,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: faloraInkMuted.withValues(alpha: 0.75),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 62,
            endIndent: 14,
            color: faloraBronze.withValues(alpha: 0.12),
          ),
      ],
    );
  }
}

class _ProfileLogoutTile extends StatelessWidget {
  const _ProfileLogoutTile({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = enabled ? faloraBronzeDark : faloraInkMuted;

    return Column(
      children: [
        Divider(
          height: 1,
          indent: 14,
          endIndent: 14,
          color: faloraBronze.withValues(alpha: 0.12),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(FaloraRadius.md),
                  border: Border.all(
                    color: enabled
                        ? faloraGoldDark.withValues(alpha: 0.7)
                        : faloraInkMuted.withValues(alpha: 0.35),
                    width: 1.1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, size: 17, color: color),
                    const SizedBox(width: 7),
                    Text(
                      'Çıkış Yap',
                      style: FaloraTypography.labelLarge.copyWith(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

class _ProfileDeleteSection extends StatelessWidget {
  const _ProfileDeleteSection({
    required this.deleting,
    required this.onPressed,
  });

  final bool deleting;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _profileDangerColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(FaloraRadius.lg),
        border: Border.all(
          color: _profileDangerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tehlikeli Bölge',
            style: FaloraTypography.labelSmall.copyWith(
              color: _profileDangerColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.35,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 6),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: deleting ? null : onPressed,
              borderRadius: BorderRadius.circular(FaloraRadius.md),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _profileDangerColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.delete_forever_outlined,
                        color: _profileDangerColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hesabımı Sil',
                            style: FaloraTypography.titleMedium.copyWith(
                              fontSize: 13,
                              color: _profileDangerColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Tüm veriler kalıcı olarak silinir',
                            style: FaloraTypography.labelSmall.copyWith(
                              color:
                                  _profileDangerColor.withValues(alpha: 0.72),
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: _profileDangerColor.withValues(alpha: 0.65),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationSettingsSheet extends StatefulWidget {
  const _NotificationSettingsSheet({
    required this.userId,
    required this.service,
    required this.hostContext,
  });

  final String userId;
  final NotificationService service;
  final BuildContext hostContext;

  @override
  State<_NotificationSettingsSheet> createState() =>
      _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState extends State<_NotificationSettingsSheet> {
  bool? _enabled;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final enabled =
        await widget.service.areAppNotificationsEnabled(widget.userId);
    if (!mounted) return;
    setState(() => _enabled = enabled);
  }

  Future<void> _toggleNotifications() async {
    if (_busy) return;
    setState(() => _busy = true);

    final wasEnabled = _enabled ?? false;
    final nowEnabled = wasEnabled
        ? await widget.service.disableNotificationsForUser(widget.userId)
        : await widget.service.enableNotificationsForUser(widget.userId);

    if (!mounted) return;
    setState(() {
      _enabled = nowEnabled;
      _busy = false;
    });

    if (!widget.hostContext.mounted) return;
    ScaffoldMessenger.of(widget.hostContext).showSnackBar(
      SnackBar(
        content: Text(
          nowEnabled
              ? 'Bildirimler açıldı.'
              : wasEnabled
                  ? 'Bildirimler kapatıldı.'
                  : 'Bildirim izni verilmedi. Sistem ayarlarından açabilirsin.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    final statusText = enabled == null
        ? 'Bildirim durumu kontrol ediliyor...'
        : enabled
            ? 'Fal hazır bildirimleri açık. Falın hazır olduğunda haber veririz.'
            : 'Fal hazır bildirimleri kapalı. Açtığında falın hazır olduğunda haber veririz.';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Bildirim Ayarları',
              style: FaloraTypography.sectionHeading,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              statusText,
              style: FaloraTypography.bodyOnParchment,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: enabled == null || _busy ? null : _toggleNotifications,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(enabled == true ? 'Bildirimleri Kapat' : 'Bildirimleri Aç'),
            ),
            if (!kIsWeb) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () async {
                        await widget.service.openSystemSettings();
                        if (!context.mounted) return;
                        await _refreshStatus();
                      },
                style: faloraOutlinedOnParchmentStyle(),
                child: const Text('Sistem Ayarlarını Aç'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhotoSheetTile extends StatelessWidget {
  const _PhotoSheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final color = labelColor ?? faloraInk;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: FaloraTypography.titleMedium.copyWith(
          fontSize: 15,
          color: color,
        ),
      ),
      onTap: onTap,
    );
  }
}
