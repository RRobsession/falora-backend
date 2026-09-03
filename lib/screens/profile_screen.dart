import 'package:falora/auth/auth_service.dart';
import 'package:falora/models/app_user.dart';
import 'package:falora/screens/invite_friend_screen.dart';
import 'package:falora/screens/report_problem_screen.dart';
import 'package:falora/screens/shop_screen.dart';
import 'package:falora/widgets/compact_birth_date_dialog.dart';
import 'package:falora/widgets/preset_avatar_picker.dart';
import 'package:falora/models/fortune_models.dart';
import 'package:falora/services/notification_service.dart';
import 'package:falora/services/ads/ad_consent_service.dart';
import 'package:falora/services/user_profile_service.dart';
import 'package:falora/services/marital_status_preference.dart';
import 'package:falora/config/category_fortune_config.dart';
import 'package:falora/services/privacy_policy_service.dart';
import 'package:falora/services/terms_of_service_service.dart';
import 'package:falora/services/rewarded_ad_service.dart';
import 'package:falora/services/token_service.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/utils/format_tokens.dart';
import 'package:falora/widgets/faq_dialog.dart';
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
    Navigator.of(
      context,
    ).push(faloraPageRoute<void>(ShopScreen(userId: widget.user.userId)));
  }

  void _openInvite(BuildContext context) {
    Navigator.of(context).push(
      faloraPageRoute<void>(InviteFriendScreen(userId: widget.user.userId)),
    );
  }

  void _openReportProblem(BuildContext context) {
    final user = TokenService.instance.liveUser.value ?? widget.user;
    Navigator.of(
      context,
    ).push(faloraPageRoute<void>(ReportProblemScreen(user: user)));
  }

  Future<void> _openPrivacyPolicy() async {
    await PrivacyPolicyService.instance.openPrivacyPolicy(context);
  }

  Future<void> _openPrivacyChoices() async {
    await PrivacyPolicyService.instance.openPrivacyChoices(context);
  }

  Future<void> _openTermsOfService() async {
    await TermsOfServiceService.instance.openTermsOfService(context);
  }

  Future<void> _openAdPrivacyOptions() async {
    final error = await AdConsentService.showPrivacyOptions();
    if (error != null) _showError(error);
  }

  Future<void> _openFaq() async {
    await showFaqDialog(context);
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
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _ReauthPasswordDialog(),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

      if (e.userCancelled) return;

      if (e.requiresReauth) {
        final password = await _askPasswordForReauth();
        if (password == null || !mounted) return;

        setState(() => _deletingAccount = true);
        try {
          await _deleteAccount(password: password);
        } on AuthException catch (e2) {
          if (e2.userCancelled) return;
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
      await UserProfileService.instance.saveGalleryAvatar(
        liveUser.userId,
        bytes,
      );
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
      await UserProfileService.instance.saveAvatarAsset(
        widget.user.userId,
        assetPath,
      );
    } catch (e) {
      _showError('Avatar seçilemedi');
    } finally {
      if (mounted) setState(() => _updatingAvatar = false);
    }
  }

  Future<void> _editName(AppUser liveUser) async {
    final controller = TextEditingController(
      text: liveUser.effectiveDisplayName,
    );
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kaydet'),
          ),
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
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    await UserProfileService.instance.saveZodiac(liveUser.userId, selected);
  }

  Future<void> _editMaritalStatus(AppUser liveUser) async {
    var selected =
        liveUser.maritalStatus ?? MaritalStatusPreference.instance.current;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Medeni durum'),
          content: DropdownButtonFormField<String>(
            initialValue: selected,
            items: maritalStatusOptions
                .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                .toList(),
            onChanged: (value) {
              if (value != null) setLocal(() => selected = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await UserProfileService.instance.saveMaritalStatus(
        liveUser.userId,
        selected,
      );
      await MaritalStatusPreference.instance.save(selected);
    }
  }

  Future<void> _openProfileEditor(AppUser liveUser) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                'Profili Düzenle',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.alternate_email_rounded),
              title: const Text('E-posta'),
              subtitle: SelectableText(liveUser.email),
            ),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('İsim'),
              subtitle: Text(liveUser.effectiveDisplayName),
              onTap: () {
                Navigator.pop(sheet);
                _editName(liveUser);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cake_outlined),
              title: const Text('Doğum tarihi ve yaş'),
              subtitle: Text(
                liveUser.computedAge == null
                    ? 'Belirtilmedi'
                    : '${liveUser.computedAge} yaş',
              ),
              onTap: () {
                Navigator.pop(sheet);
                _editBirthDate(liveUser);
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Burç'),
              subtitle: Text(liveUser.zodiac ?? 'Belirtilmedi'),
              onTap: () {
                Navigator.pop(sheet);
                _editZodiac(liveUser);
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite_border),
              title: const Text('Medeni durum'),
              subtitle: Text(liveUser.maritalStatus ?? 'Belirtilmedi'),
              onTap: () {
                Navigator.pop(sheet);
                _editMaritalStatus(liveUser);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Profil fotoğrafı'),
              onTap: () {
                Navigator.pop(sheet);
                _showAvatarOptions(liveUser);
              },
            ),
          ],
        ),
      ),
    );
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
                      final rewardAdsUsed = TokenService.instance
                          .rewardedAdsUsedToday(liveUser);
                      final hasReward = adService.hasDailyRewardAvailable(
                        liveUser,
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ProfileUserCard(
                            initial: _initial,
                            name: liveUser.effectiveDisplayName,
                            age: liveUser.computedAge,
                            zodiac: liveUser.zodiac,
                            fallbackTokens: liveUser.tokens,
                            specialFortuneRights: liveUser.specialFortuneRights,
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
                  const Text(
                    'Hızlı İşlemler',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: faloraInk,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: MediaQuery.sizeOf(context).width >= 700
                        ? 4
                        : 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.65,
                    children: [
                      _ProfileActionCard(
                        icon: Icons.manage_accounts_outlined,
                        title: 'Profili Düzenle',
                        detail: 'Kişisel bilgilerin',
                        onTap: () => _openProfileEditor(
                          TokenService.instance.liveUser.value ?? widget.user,
                        ),
                      ),
                      _ProfileActionCard(
                        icon: Icons.storefront_rounded,
                        title: 'Jeton Mağazası',
                        detail: 'Paketler ve haklar',
                        onTap: () => _openShop(context),
                      ),
                      _ProfileActionCard(
                        icon: Icons.person_add_alt_1_rounded,
                        title: 'Arkadaşını Davet Et',
                        detail: 'Kod paylaş, jeton kazan',
                        onTap: () => _openInvite(context),
                      ),
                      _ProfileActionCard(
                        icon: Icons.support_agent_rounded,
                        title: 'Destek',
                        detail: 'Sorun bildir ve yanıtları gör',
                        onTap: () => _openReportProblem(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Ayarlar',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: faloraInk,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ProfileSettingsPanel(
                    onNotifications: _openNotificationSettings,
                    onFaq: _openFaq,
                    onPrivacy: _openPrivacyPolicy,
                    onPrivacyChoices: _openPrivacyChoices,
                    onTerms: _openTermsOfService,
                    onAdPrivacy: AdConsentService.privacyOptionsRequired
                        ? _openAdPrivacyOptions
                        : null,
                    onLogout: _deletingAccount ? null : _confirmLogout,
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
    required this.age,
    required this.zodiac,
    required this.fallbackTokens,
    required this.specialFortuneRights,
    required this.avatarAsset,
    required this.updatingAvatar,
    required this.onAvatarTap,
    required this.onOpenShop,
  });

  final String initial;
  final String name;
  final int? age;
  final String? zodiac;
  final int fallbackTokens;
  final int specialFortuneRights;
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
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
                          formatTokenAmount(tokens),
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
          Positioned(
            top: 25,
            right: 0,
            child: ScaleTap(
              onTap: onOpenShop,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: faloraParchmentRaised,
                  border: Border.all(color: faloraGoldDark, width: 1),
                ),
                child: Text(
                  'Özel Fal Hakkı: $specialFortuneRights',
                  style: const TextStyle(
                    color: faloraInk,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
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
                  padding: const EdgeInsets.only(right: 105),
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

/// Kimlik doğrulama dialogu — controller yaşam döngüsü bu State'e aittir.
/// (Dışarıda oluşturup dialog bitmeden dispose etmek "used after disposed" üretir.)
class _ReauthPasswordDialog extends StatefulWidget {
  const _ReauthPasswordDialog();

  @override
  State<_ReauthPasswordDialog> createState() => _ReauthPasswordDialogState();
}

class _ReauthPasswordDialogState extends State<_ReauthPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kimlik Doğrulama'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Hesabını silmek için güvenlik nedeniyle şifreni tekrar girmelisin.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Şifre'),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Şifre gerekli';
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        TextButton(onPressed: _submit, child: const Text('Devam Et')),
      ],
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

class _ProfileActionCard extends StatelessWidget {
  const _ProfileActionCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });
  final IconData icon;
  final String title, detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: faloraParchmentCard,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: faloraBronze.withValues(alpha: .32)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: faloraBronze.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: faloraBronzeDark),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: faloraInk,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: faloraTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProfileSettingsPanel extends StatelessWidget {
  const _ProfileSettingsPanel({
    required this.onNotifications,
    required this.onFaq,
    required this.onPrivacy,
    required this.onPrivacyChoices,
    required this.onTerms,
    required this.onLogout,
    this.onAdPrivacy,
  });
  final VoidCallback onNotifications,
      onFaq,
      onPrivacy,
      onPrivacyChoices,
      onTerms;
  final VoidCallback? onAdPrivacy, onLogout;

  @override
  Widget build(BuildContext context) => Container(
    decoration: faloraParchmentDecoration(
      radius: FaloraRadius.lg,
      raised: true,
    ),
    child: Column(
      children: [
        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('Bildirimler'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onNotifications,
        ),
        const Divider(height: 1, indent: 56),
        ListTile(
          leading: const Icon(Icons.help_outline_rounded),
          title: const Text('Sıkça Sorulan Sorular'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onFaq,
        ),
        const Divider(height: 1, indent: 56),
        ExpansionTile(
          leading: const Icon(Icons.gavel_outlined),
          title: const Text('Gizlilik ve Yasal'),
          subtitle: const Text('Politikalar ve tercihler'),
          children: [
            ListTile(
              contentPadding: const EdgeInsets.only(left: 72, right: 18),
              title: const Text('Gizlilik Politikası'),
              onTap: onPrivacy,
            ),
            ListTile(
              contentPadding: const EdgeInsets.only(left: 72, right: 18),
              title: const Text('Gizlilik Tercihleri'),
              onTap: onPrivacyChoices,
            ),
            ListTile(
              contentPadding: const EdgeInsets.only(left: 72, right: 18),
              title: const Text('Kullanıcı Sözleşmesi'),
              onTap: onTerms,
            ),
            if (onAdPrivacy != null)
              ListTile(
                contentPadding: const EdgeInsets.only(left: 72, right: 18),
                title: const Text('Reklam Gizlilik Tercihleri'),
                onTap: onAdPrivacy,
              ),
          ],
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.logout_rounded),
          title: const Text('Çıkış Yap'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onLogout,
        ),
      ],
    ),
  );
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
        border: Border.all(color: _profileDangerColor.withValues(alpha: 0.3)),
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
                              color: _profileDangerColor.withValues(
                                alpha: 0.72,
                              ),
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

class _NotificationSettingsSheetState
    extends State<_NotificationSettingsSheet> {
  bool? _enabled;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final enabled = await widget.service.areAppNotificationsEnabled(
      widget.userId,
    );
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
                  : Text(
                      enabled == true
                          ? 'Bildirimleri Kapat'
                          : 'Bildirimleri Aç',
                    ),
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
