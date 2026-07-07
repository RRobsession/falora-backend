import 'package:file_picker/file_picker.dart';
import 'package:falora/config/category_fortune_config.dart';
import 'package:falora/config/legal_config.dart';
import 'package:falora/image_upload_card.dart';
import 'package:falora/models/fortune_models.dart';
import 'package:falora/picked_image.dart';
import 'package:falora/services/fortune_form_prefill.dart';
import 'package:falora/widgets/turkish_birth_date_field.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/live_token_builder.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class DreamInterpretationFormPage extends StatefulWidget {
  const DreamInterpretationFormPage({
    super.key,
    required this.tokenCost,
    required this.onSubmit,
    required this.onOpenShop,
  });

  final int tokenCost;
  final Future<void> Function(String dreamText) onSubmit;
  final VoidCallback onOpenShop;

  @override
  State<DreamInterpretationFormPage> createState() =>
      _DreamInterpretationFormPageState();
}

class _DreamInterpretationFormPageState extends State<DreamInterpretationFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _dreamCtrl = TextEditingController();
  String _dreamType = dreamTypes.first;
  var _submitting = false;

  static const _accent = Color(0xFF5C4A6E);

  @override
  void dispose() {
    _dreamCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final body = _dreamCtrl.text.trim();
      final payload = 'Rüya türü: $_dreamType\n\n$body';
      await widget.onSubmit(payload);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PremiumCategoryShell(
      title: FortuneCategory.ruyaTabiri.label,
      accent: _accent,
      onOpenShop: widget.onOpenShop,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CategoryHeroCard(
              accent: _accent,
              emoji: '🌙',
              title: 'Rüya Tabiri',
              subtitle: 'Kelimelerin ötesindeki sembolleri keşfet',
              tokenCost: widget.tokenCost,
              hints: const [
                'Son gördüğünüz rüyayı anlatın',
                'İstediğiniz kadar detay ekleyebilirsiniz',
              ],
            ),
            const SizedBox(height: 28),
            _PremiumSectionCard(
              accent: _accent,
              title: 'Rüyanız',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: faloraParchmentRaised,
                  borderRadius: BorderRadius.circular(FaloraRadius.lg),
                  border: Border.all(
                    color: faloraBronze.withValues(alpha: 0.3),
                  ),
                ),
                child: TextFormField(
                  controller: _dreamCtrl,
                  style: const TextStyle(
                    color: faloraTextPrimary,
                    fontSize: 15,
                    height: 1.55,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Rüyanızı mümkün olduğunca detaylı anlatın…',
                    hintStyle: TextStyle(
                      color: faloraTextSecondary.withValues(alpha: 0.65),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  minLines: 5,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) {
                    final text = v?.trim() ?? '';
                    if (text.length < 20) {
                      return 'En az 20 karakter girin';
                    }
                    return null;
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            _PremiumSectionCard(
              accent: _accent,
              title: 'Rüya türü',
              child: _OptionChipGroup(
                accent: _accent,
                options: dreamTypes,
                selected: _dreamType,
                onSelected: (v) => setState(() => _dreamType = v),
              ),
            ),
            const SizedBox(height: 32),
            _PremiumSubmitButton(
              accent: _accent,
              label: 'Rüyamı Yorumla',
              tokenCost: widget.tokenCost,
              loading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class NumerologyFormPage extends StatefulWidget {
  const NumerologyFormPage({
    super.key,
    required this.tokenCost,
    required this.onSubmit,
    required this.onOpenShop,
    this.prefill,
  });

  final int tokenCost;
  final Future<void> Function(String name, DateTime birthDate) onSubmit;
  final VoidCallback onOpenShop;
  final FortuneFormPrefill? prefill;

  @override
  State<NumerologyFormPage> createState() => _NumerologyFormPageState();
}

class _NumerologyFormPageState extends State<NumerologyFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _birthDateFieldKey = GlobalKey<TurkishBirthDateFieldState>();
  DateTime? _birthDate;
  String _analysisType = numerologyAnalysisTypes.first;
  var _submitting = false;

  static const _accent = Color(0xFFB8860B);

  @override
  void initState() {
    super.initState();
    final prefill = widget.prefill;
    if (prefill != null && prefill.hasAny) {
      prefill.applyNameParts(
        firstName: _firstNameCtrl,
        lastName: _lastNameCtrl,
      );
      if (prefill.birthDate != null) {
        _birthDate = prefill.birthDate;
      }
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!(_birthDateFieldKey.currentState?.isValid ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir doğum tarihi girin')),
      );
      return;
    }
    final birthDate = _birthDateFieldKey.currentState?.selectedDate;
    if (birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir doğum tarihi girin')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final first = _firstNameCtrl.text.trim();
      final last = _lastNameCtrl.text.trim();
      final baseName = last.isEmpty ? first : '$first $last';
      final fullName = '$baseName — $_analysisType';
      await widget.onSubmit(fullName, birthDate);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PremiumCategoryShell(
      title: FortuneCategory.numeroloji.label,
      accent: _accent,
      onOpenShop: widget.onOpenShop,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CategoryHeroCard(
              accent: _accent,
              heroVisual: const _NumerologyHeroSymbol(),
              title: 'Numeroloji Analizi',
              subtitle: 'İsminiz ve doğum tarihinizin enerjisini keşfedin',
              tokenCost: widget.tokenCost,
            ),
            const SizedBox(height: 28),
            _PremiumSectionCard(
              accent: _accent,
              title: 'Kişisel bilgiler',
              child: Column(
                children: [
                  _PremiumTextField(
                    controller: _firstNameCtrl,
                    label: 'İsim',
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'İsim gerekli' : null,
                  ),
                  const SizedBox(height: 16),
                  _PremiumTextField(
                    controller: _lastNameCtrl,
                    label: 'Soyisim',
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TurkishBirthDateField(
                    key: _birthDateFieldKey,
                    initialDate: _birthDate,
                    onChanged: (date) => _birthDate = date,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _PremiumSectionCard(
              accent: _accent,
              title: 'Analiz odağı',
              child: _OptionChipGroup(
                accent: _accent,
                options: numerologyAnalysisTypes,
                selected: _analysisType,
                onSelected: (v) => setState(() => _analysisType = v),
                dense: true,
              ),
            ),
            const SizedBox(height: 32),
            _PremiumSubmitButton(
              accent: _accent,
              label: 'Analizi Başlat',
              tokenCost: widget.tokenCost,
              loading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class HoroscopeFormPage extends StatefulWidget {
  const HoroscopeFormPage({
    super.key,
    required this.tokenCost,
    required this.onSubmit,
    required this.onOpenShop,
    this.prefill,
  });

  final int tokenCost;
  final Future<void> Function(
    String sunSign,
    String moonSign,
    String focusArea,
  ) onSubmit;
  final VoidCallback onOpenShop;
  final FortuneFormPrefill? prefill;

  @override
  State<HoroscopeFormPage> createState() => _HoroscopeFormPageState();
}

class _HoroscopeFormPageState extends State<HoroscopeFormPage> {
  final _formKey = GlobalKey<FormState>();
  String _sunSign = burclar.first;
  String _moonSign = burclar.first;
  String _focusUiKey = '🌟 Genel';
  var _submitting = false;

  static const _accent = Color(0xFF7A5C3E);

  @override
  void initState() {
    super.initState();
    final prefill = widget.prefill;
    if (prefill != null && prefill.hasAny) {
      _sunSign = prefill.applyToZodiac(_sunSign);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final focusArea = horoscopeFocusUiOptions[_focusUiKey] ?? 'Genel';
      await widget.onSubmit(_sunSign, _moonSign, focusArea);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PremiumCategoryShell(
      title: FortuneCategory.burcYorumu.label,
      accent: _accent,
      onOpenShop: widget.onOpenShop,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CategoryHeroCard(
              accent: _accent,
              emoji: '✨',
              title: 'Burç Yorumu',
              subtitle: 'Kozmik enerjilerin sizin için ne söylediğini öğrenin',
              tokenCost: widget.tokenCost,
            ),
            const SizedBox(height: 28),
            _PremiumSectionCard(
              accent: _accent,
              title: 'Güneş burcu',
              child: _ZodiacPickerGrid(
                accent: _accent,
                selected: _sunSign,
                onSelected: (v) => setState(() => _sunSign = v),
              ),
            ),
            const SizedBox(height: 20),
            _PremiumSectionCard(
              accent: _accent,
              title: 'Ay burcu',
              child: _ZodiacPickerGrid(
                accent: _accent,
                selected: _moonSign,
                onSelected: (v) => setState(() => _moonSign = v),
              ),
            ),
            const SizedBox(height: 20),
            _PremiumSectionCard(
              accent: _accent,
              title: 'Odak alanı',
              child: _FocusAreaButtons(
                accent: _accent,
                selectedKey: _focusUiKey,
                onSelected: (v) => setState(() => _focusUiKey = v),
              ),
            ),
            const SizedBox(height: 32),
            _PremiumSubmitButton(
              accent: _accent,
              label: 'Yorumumu Al',
              tokenCost: widget.tokenCost,
              loading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class RelationshipAdviceFormPage extends StatefulWidget {
  const RelationshipAdviceFormPage({
    super.key,
    required this.tokenCost,
    required this.onSubmit,
    required this.onOpenShop,
  });

  final int tokenCost;
  final Future<void> Function({
    required String partnerName,
    required String partnerGender,
    required String partnerZodiac,
    required int partnerAge,
    required String problemText,
    required List<PickedImage> chatImages,
  }) onSubmit;
  final VoidCallback onOpenShop;

  @override
  State<RelationshipAdviceFormPage> createState() =>
      _RelationshipAdviceFormPageState();
}

class _RelationshipAdviceFormPageState extends State<RelationshipAdviceFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _problemCtrl = TextEditingController();
  String _gender = partnerGenderOptions.first;
  String _zodiac = burclar.first;
  PickedImage? _chat1;
  PickedImage? _chat2;
  PickedImage? _chat3;
  var _submitting = false;

  static const _accent = Color(0xFF8B4A62);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _problemCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final images = [_chat1, _chat2, _chat3]
          .whereType<PickedImage>()
          .toList(growable: false);
      await widget.onSubmit(
        partnerName: _nameCtrl.text.trim(),
        partnerGender: _gender,
        partnerZodiac: _zodiac,
        partnerAge: int.parse(_ageCtrl.text.trim()),
        problemText: _problemCtrl.text.trim(),
        chatImages: images,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PremiumCategoryShell(
      title: FortuneCategory.iliskiTavsiyesi.label,
      accent: _accent,
      onOpenShop: widget.onOpenShop,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RelationshipHeroCard(
              accent: _accent,
              tokenCost: widget.tokenCost,
            ),
            const SizedBox(height: 28),
            _PremiumSectionCard(
              accent: _accent,
              title: 'Karşı taraf',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PremiumTextField(
                    controller: _nameCtrl,
                    label: 'İsim',
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty) {
                        return 'İsim gerekli';
                      }
                      return null;
                    },
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cinsiyet',
                    style: FaloraTypography.labelSmall.copyWith(
                      color: faloraInkMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _OptionChipGroup(
                    accent: _accent,
                    options: partnerGenderOptions,
                    selected: _gender,
                    onSelected: (v) => setState(() => _gender = v),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Yaş',
                    style: FaloraTypography.labelSmall.copyWith(
                      color: faloraInkMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: faloraTextPrimary, fontSize: 15),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: faloraParchmentRaised,
                      hintText: 'Örn. 28',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(FaloraRadius.md),
                        borderSide:
                            BorderSide(color: faloraBronze.withValues(alpha: 0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(FaloraRadius.md),
                        borderSide:
                            BorderSide(color: faloraBronze.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(FaloraRadius.md),
                        borderSide:
                            const BorderSide(color: faloraGoldDark, width: 1.2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    validator: (v) {
                      final age = int.tryParse(v?.trim() ?? '');
                      return validateFortuneSubjectAge(age);
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Burç',
                    style: FaloraTypography.labelSmall.copyWith(
                      color: faloraInkMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ZodiacPickerGrid(
                    accent: _accent,
                    selected: _zodiac,
                    onSelected: (v) => setState(() => _zodiac = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _PremiumSectionCard(
              accent: _accent,
              title: 'Yaşadığınız sorun',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: faloraParchmentRaised,
                  borderRadius: BorderRadius.circular(FaloraRadius.lg),
                  border: Border.all(
                    color: faloraBronze.withValues(alpha: 0.3),
                  ),
                ),
                child: TextFormField(
                  controller: _problemCtrl,
                  style: const TextStyle(
                    color: faloraTextPrimary,
                    fontSize: 15,
                    height: 1.55,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ahmet günaydın mesajına görüldü attı',
                    hintStyle: TextStyle(
                      color: faloraTextSecondary.withValues(alpha: 0.65),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  minLines: 4,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) {
                    final text = v?.trim() ?? '';
                    if (text.length < 15) {
                      return 'Sorunu en az 15 karakterle anlatın';
                    }
                    return null;
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            _PremiumSectionCard(
              accent: _accent,
              title: 'Sohbet ekran görüntüleri (isteğe bağlı)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(FaloraRadius.lg),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _accent.withValues(alpha: 0.1),
                          faloraParchmentRaised,
                        ],
                      ),
                      border: Border.all(
                        color: _accent.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: FaIcon(
                            FontAwesomeIcons.message,
                            size: 14,
                            color: _accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Sorun yaşadığınız sohbet anını yükleyin. '
                            'Yalnızca kendi verilerinizi ve üçüncü kişilerin '
                            'açık rızası olan içerikleri paylaşın. Görseller '
                            'en fazla 15 gün saklanır ve eğlence amaçlı '
                            'tavsiye üretimi için işlenir.',
                            style: FaloraTypography.bodyMedium.copyWith(
                              color: faloraInkSoft,
                              height: 1.45,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _CompactChatPhotoSlot(
                          label: '1',
                          image: _chat1,
                          accent: _accent,
                          onChanged: (v) => setState(() => _chat1 = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CompactChatPhotoSlot(
                          label: '2',
                          image: _chat2,
                          accent: _accent,
                          onChanged: (v) => setState(() => _chat2 = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CompactChatPhotoSlot(
                          label: '3',
                          image: _chat3,
                          accent: _accent,
                          onChanged: (v) => setState(() => _chat3 = v),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _PremiumSubmitButton(
              accent: _accent,
              label: 'Tavsiye Al',
              tokenCost: widget.tokenCost,
              loading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _RelationshipHeroCard extends StatelessWidget {
  const _RelationshipHeroCard({
    required this.accent,
    required this.tokenCost,
  });

  final Color accent;
  final int tokenCost;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: faloraParchmentDecoration(
        base: Color.lerp(faloraParchmentCard, accent, 0.06)!,
        radius: FaloraRadius.xl,
        raised: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.24)),
                ),
                child: FaIcon(
                  FontAwesomeIcons.comments,
                  size: 20,
                  color: accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'İlişki Tavsiyesi',
                      style: FaloraTypography.displayMedium.copyWith(
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tarafsız ve dengeli uzman bakışı',
                      style: FaloraTypography.bodyLarge.copyWith(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _RelationshipStepRow(
            number: '1',
            text: 'Karşı tarafın bilgilerini girin',
          ),
          const SizedBox(height: 8),
          const _RelationshipStepRow(
            number: '2',
            text: 'Yaşadığınız sorunu açıkça anlatın',
          ),
          const SizedBox(height: 8),
          const _RelationshipStepRow(
            number: '3',
            text: 'İsterseniz sohbet görüntüsü ekleyin',
          ),
          const SizedBox(height: 18),
          FaloraTokenBadge(amount: tokenCost, compact: true),
        ],
      ),
    );
  }
}

class _RelationshipStepRow extends StatelessWidget {
  const _RelationshipStepRow({
    required this.number,
    required this.text,
  });

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: faloraParchmentInset,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: faloraBronze.withValues(alpha: 0.28)),
          ),
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: faloraInkHeading,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: FaloraTypography.bodyMedium.copyWith(fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _CompactChatPhotoSlot extends StatelessWidget {
  const _CompactChatPhotoSlot({
    required this.label,
    required this.image,
    required this.accent,
    required this.onChanged,
  });

  final String label;
  final PickedImage? image;
  final Color accent;
  final ValueChanged<PickedImage?> onChanged;

  Future<void> _pick(BuildContext context) async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return;
    onChanged(PickedImage(name: file.name, bytes: bytes));
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = image != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _pick(context),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 108,
          decoration: BoxDecoration(
            color: faloraParchmentRaised,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasImage
                  ? accent.withValues(alpha: 0.55)
                  : faloraBronze.withValues(alpha: 0.28),
            ),
          ),
          child: hasImage
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Image.memory(
                        image!.bytes,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: () => onChanged(null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FaIcon(
                      FontAwesomeIcons.plus,
                      size: 16,
                      color: accent.withValues(alpha: 0.8),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Paylaşılan premium bileşenler
// ---------------------------------------------------------------------------

class _PremiumCategoryShell extends StatelessWidget {
  const _PremiumCategoryShell({
    required this.title,
    required this.accent,
    required this.onOpenShop,
    required this.child,
  });

  final String title;
  final Color accent;
  final VoidCallback onOpenShop;
  final Widget child;
  static const _horizontalPadding = 20.0;
  static const _topSpacing = 16.0;
  static const _bottomSpacing = 28.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(title),
      ),
      body: FaloraBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              _horizontalPadding,
              _topSpacing,
              _horizontalPadding,
              _bottomSpacing + MediaQuery.viewPaddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FaloraLiveTappableTokenBalance(onOpenShop: onOpenShop),
                const SizedBox(height: 12),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryHeroCard extends StatelessWidget {
  const _CategoryHeroCard({
    required this.accent,
    this.emoji,
    this.heroVisual,
    required this.title,
    required this.subtitle,
    required this.tokenCost,
    this.hints = const [],
  });

  final Color accent;
  final String? emoji;
  final Widget? heroVisual;
  final String title;
  final String subtitle;
  final int tokenCost;
  final List<String> hints;
  static const _cardPadding = EdgeInsets.fromLTRB(20, 24, 20, 22);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: _cardPadding,
      decoration: faloraParchmentDecoration(
        base: Color.lerp(faloraParchmentCard, accent, 0.06)!,
        radius: FaloraRadius.xl,
        raised: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heroVisual ??
              Text(
                emoji ?? '',
                style: const TextStyle(fontSize: 36),
              ),
          const SizedBox(height: 14),
          Text(
            title,
            style: FaloraTypography.displayMedium,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: FaloraTypography.bodyLarge,
          ),
          if (hints.isNotEmpty) ...[
            const SizedBox(height: 18),
            ...hints.map(
              (hint) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FaIcon(
                      FontAwesomeIcons.solidCircle,
                      size: 6,
                      color: faloraBronze.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        hint,
                        style: FaloraTypography.bodyMedium.copyWith(
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          FaloraTokenBadge(amount: tokenCost, compact: true),
        ],
      ),
    );
  }
}

class _NumerologyHeroSymbol extends StatelessWidget {
  const _NumerologyHeroSymbol();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: faloraGoldDark, width: 1.4),
              color: faloraParchmentInset.withValues(alpha: 0.5),
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: faloraBronze.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
          ),
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: faloraGoldDark,
            ),
          ),
          const Positioned(top: 2, child: _NumerologyGlyph(value: '3')),
          const Positioned(right: 4, child: _NumerologyGlyph(value: '6')),
          Positioned(
            bottom: 4,
            child: _NumerologyGlyph(value: '9'),
          ),
          Positioned(
            left: 6,
            child: _NumerologyGlyph(value: '1'),
          ),
          Transform.rotate(
            angle: 0.78,
            child: Container(
              width: 30,
              height: 1.2,
              color: faloraGold.withValues(alpha: 0.75),
            ),
          ),
          Transform.rotate(
            angle: -0.78,
            child: Container(
              width: 30,
              height: 1.2,
              color: faloraGold.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumerologyGlyph extends StatelessWidget {
  const _NumerologyGlyph({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: TextStyle(
        color: faloraInkHeading,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _PremiumSectionCard extends StatelessWidget {
  const _PremiumSectionCard({
    required this.accent,
    required this.title,
    required this.child,
  });

  final Color accent;
  final String title;
  final Widget child;
  static const _cardPadding = EdgeInsets.fromLTRB(20, 20, 20, 20);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: _cardPadding,
      decoration: faloraGlassDecoration(accent: accent, radius: 22, opacity: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: accent.withValues(alpha: 0.95),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _PremiumTextField extends StatelessWidget {
  const _PremiumTextField({
    required this.controller,
    required this.label,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            color: faloraInkHeading,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          textCapitalization: textCapitalization,
          style: const TextStyle(color: faloraTextPrimary, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: faloraParchmentRaised,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FaloraRadius.md),
              borderSide: BorderSide(color: faloraBronze.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FaloraRadius.md),
              borderSide: BorderSide(color: faloraBronze.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FaloraRadius.md),
              borderSide: const BorderSide(color: faloraGoldDark, width: 1.2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: validator,
        ),
      ],
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  const _DatePickerTile({
    required this.accent,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final Color accent;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: faloraParchmentRaised,
            borderRadius: BorderRadius.circular(FaloraRadius.md),
            border: Border.all(color: faloraBronze.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              FaIcon(
                FontAwesomeIcons.calendarDays,
                size: 16,
                color: accent.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: faloraTextSecondary.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value ?? 'Tarih seçin',
                      style: TextStyle(
                        color: value == null
                            ? faloraTextSecondary.withValues(alpha: 0.65)
                            : faloraTextPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              FaIcon(
                FontAwesomeIcons.chevronRight,
                size: 12,
                color: faloraTextSecondary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionChipGroup extends StatelessWidget {
  const _OptionChipGroup({
    required this.accent,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.dense = false,
  });

  final Color accent;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((option) {
        final isSelected = option == selected;
        return GestureDetector(
          onTap: () => onSelected(option),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: dense ? 14 : 18,
              vertical: dense ? 10 : 12,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [faloraBronze, faloraBronzeDark],
                    )
                  : null,
              color: isSelected ? null : faloraParchmentInset.withValues(alpha: 0.5),
              border: Border.all(
                color: isSelected
                    ? faloraGold.withValues(alpha: 0.65)
                    : faloraBronze.withValues(alpha: 0.25),
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              option,
              style: TextStyle(
                color: isSelected ? faloraParchmentRaised : faloraTextSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: dense ? 13 : 14,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ZodiacPickerGrid extends StatelessWidget {
  const _ZodiacPickerGrid({
    required this.accent,
    required this.selected,
    required this.onSelected,
  });

  final Color accent;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.4,
      ),
      itemCount: burclar.length,
      itemBuilder: (context, index) {
        final sign = burclar[index];
        final isSelected = sign == selected;
        return GestureDetector(
          onTap: () => onSelected(sign),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [faloraBronze, faloraBronzeDark],
                    )
                  : null,
              color: isSelected ? null : faloraParchmentInset.withValues(alpha: 0.5),
              border: Border.all(
                color: isSelected
                    ? faloraGold.withValues(alpha: 0.6)
                    : faloraBronze.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              sign,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? faloraParchmentRaised : faloraTextSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FocusAreaButtons extends StatelessWidget {
  const _FocusAreaButtons({
    required this.accent,
    required this.selectedKey,
    required this.onSelected,
  });

  final Color accent;
  final String selectedKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: horoscopeFocusUiOptions.keys.map((key) {
        final isSelected = key == selectedKey;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => onSelected(key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(FaloraRadius.md),
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [faloraBronze, faloraBronzeDark],
                      )
                    : null,
                color: isSelected ? null : faloraParchmentInset.withValues(alpha: 0.5),
                border: Border.all(
                  color: isSelected
                      ? faloraGold.withValues(alpha: 0.55)
                      : faloraBronze.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                key,
                style: TextStyle(
                  color: isSelected ? faloraParchmentRaised : faloraTextPrimary,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PremiumSubmitButton extends StatelessWidget {
  const _PremiumSubmitButton({
    required this.accent,
    required this.label,
    required this.tokenCost,
    required this.loading,
    required this.onPressed,
  });

  final Color accent;
  final String label;
  final int tokenCost;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FaloraPrimaryButton(
      label: label,
      loading: loading,
      onPressed: onPressed,
      trailing: FaloraTokenBadge(amount: tokenCost, compact: true),
    );
  }
}
