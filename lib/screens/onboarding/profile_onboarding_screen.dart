import 'package:falora/models/app_user.dart';
import 'package:falora/models/fortune_models.dart';
import 'package:falora/services/user_profile_service.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/falora_logo_header.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:falora/widgets/preset_avatar_picker.dart';
import 'package:falora/widgets/turkish_birth_date_field.dart';
import 'package:flutter/material.dart';

class ProfileOnboardingScreen extends StatefulWidget {
  const ProfileOnboardingScreen({
    super.key,
    required this.user,
    required this.onCompleted,
  });

  final AppUser user;
  final VoidCallback onCompleted;

  @override
  State<ProfileOnboardingScreen> createState() =>
      _ProfileOnboardingScreenState();
}

class _ProfileOnboardingScreenState extends State<ProfileOnboardingScreen> {
  late int _stepIndex;
  final _nameCtrl = TextEditingController();

  final _birthDateFieldKey = GlobalKey<TurkishBirthDateFieldState>();
  DateTime? _birthDate;
  String? _selectedZodiac;
  String? _selectedAvatarAsset;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final first = UserProfileService.firstIncompleteStep(widget.user);
    _stepIndex = first == null ? 0 : UserProfileService.stepIndex(first);
    _nameCtrl.text = widget.user.effectiveDisplayName;
    _birthDate = widget.user.birthDate;
    _selectedZodiac = widget.user.zodiac;
    _selectedAvatarAsset = widget.user.avatarAsset;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  ProfileOnboardingStep get _currentStep =>
      ProfileOnboardingStep.values[_stepIndex];

  Future<void> _saveName() async {
    if (_saving) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İsim gerekli')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await UserProfileService.instance
          .saveDisplayName(widget.user.userId, name);
      if (!mounted) return;
      setState(() => _stepIndex++);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kaydedilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveBirthDate() async {
    if (_saving) return;
    if (!(_birthDateFieldKey.currentState?.isValid ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir doğum tarihi girin')),
      );
      return;
    }
    final birthDate = _birthDateFieldKey.currentState!.selectedDate;
    if (birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir doğum tarihi girin')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await UserProfileService.instance
          .saveBirthDate(widget.user.userId, birthDate);
      if (!mounted) return;
      setState(() => _stepIndex++);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kaydedilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveZodiac() async {
    if (_saving) return;
    final zodiac = _selectedZodiac?.trim();
    if (zodiac == null || zodiac.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Burç seçin')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await UserProfileService.instance.saveZodiac(widget.user.userId, zodiac);
      if (!mounted) return;
      setState(() => _stepIndex++);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kaydedilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _finishAvatar({required bool skipped}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final uid = widget.user.userId;
      if (!skipped && _selectedAvatarAsset != null) {
        await UserProfileService.instance
            .saveAvatarAsset(uid, _selectedAvatarAsset!);
      }
      await UserProfileService.instance.completeProfile(uid);
      if (!mounted) return;
      widget.onCompleted();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil tamamlanamadı: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: faloraAuthBackground(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    const FaloraLogoHeader(
                      compact: true,
                      subtitle: 'Profilini tamamla',
                    ),
                    const SizedBox(height: 20),
                    _OnboardingProgress(
                      current: _stepIndex,
                      total: ProfileOnboardingStep.values.length,
                    ),
                    const SizedBox(height: 20),
                    AuthCard(child: _buildStep()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case ProfileOnboardingStep.name:
        return _NameStep(
          controller: _nameCtrl,
          saving: _saving,
          onContinue: _saveName,
        );
      case ProfileOnboardingStep.birthDate:
        return _BirthDateStep(
          fieldKey: _birthDateFieldKey,
          initialDate: _birthDate,
          saving: _saving,
          onDateChanged: (date) => _birthDate = date,
          onContinue: _saveBirthDate,
        );
      case ProfileOnboardingStep.zodiac:
        return _ZodiacStep(
          selected: _selectedZodiac,
          saving: _saving,
          onSelected: (v) => setState(() => _selectedZodiac = v),
          onContinue: _saveZodiac,
        );
      case ProfileOnboardingStep.avatar:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Avatar seç',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: faloraTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hazır avatarlardan birini seç. İstersen atlayabilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: faloraTextSecondary.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 16),
            PresetAvatarPicker(
              initialAsset: _selectedAvatarAsset,
              showSkip: true,
              enabled: !_saving,
              confirmLabel: _saving ? 'Kaydediliyor…' : 'Bu avatarı kullan',
              onConfirm: (asset) {
                setState(() => _selectedAvatarAsset = asset);
                _finishAvatar(skipped: false);
              },
              onSkip: () => _finishAvatar(skipped: true),
            ),
          ],
        );
    }
  }
}

class _OnboardingProgress extends StatelessWidget {
  const _OnboardingProgress({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (index) {
        final active = index <= current;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: index == total - 1 ? 0 : 6),
            decoration: BoxDecoration(
              color: active ? faloraGoldDark : faloraBronze.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}

class _NameStep extends StatelessWidget {
  const _NameStep({
    required this.controller,
    required this.saving,
    required this.onContinue,
  });

  final TextEditingController controller;
  final bool saving;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Adın nedir?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: faloraTextPrimary,
          ),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: controller,
          enabled: !saving,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'İsim',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: saving ? null : onContinue,
          child: saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Devam Et'),
        ),
      ],
    );
  }
}

class _BirthDateStep extends StatelessWidget {
  const _BirthDateStep({
    required this.fieldKey,
    required this.initialDate,
    required this.saving,
    required this.onDateChanged,
    required this.onContinue,
  });

  final GlobalKey<TurkishBirthDateFieldState> fieldKey;
  final DateTime? initialDate;
  final bool saving;
  final ValueChanged<DateTime?> onDateChanged;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Doğum tarihin',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: faloraTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Yaşın otomatik hesaplanacak.',
          textAlign: TextAlign.center,
          style: TextStyle(color: faloraTextSecondary.withValues(alpha: 0.9)),
        ),
        const SizedBox(height: 20),
        TurkishBirthDateField(
          key: fieldKey,
          initialDate: initialDate,
          enabled: !saving,
          onChanged: onDateChanged,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: saving ? null : onContinue,
          child: saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Devam Et'),
        ),
      ],
    );
  }
}

class _ZodiacStep extends StatelessWidget {
  const _ZodiacStep({
    required this.selected,
    required this.saving,
    required this.onSelected,
    required this.onContinue,
  });

  final String? selected;
  final bool saving;
  final ValueChanged<String> onSelected;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Burcun',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: faloraTextPrimary,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.4,
          ),
          itemCount: burclar.length,
          itemBuilder: (context, index) {
            final burc = burclar[index];
            final isSelected = selected == burc;
            return InkWell(
              onTap: saving ? null : () => onSelected(burc),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? faloraGold.withValues(alpha: 0.35)
                      : faloraParchmentRaised,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? faloraGoldDark : faloraBronze.withValues(alpha: 0.3),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Text(
                  burc,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: faloraInk,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: saving ? null : onContinue,
          child: saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Devam Et'),
        ),
      ],
    );
  }
}
