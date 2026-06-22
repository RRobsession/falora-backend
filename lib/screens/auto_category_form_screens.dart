import 'package:falora/config/category_fortune_config.dart';
import 'package:falora/models/fortune_models.dart';
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
  });

  final int tokenCost;
  final Future<void> Function(String name, DateTime birthDate) onSubmit;
  final VoidCallback onOpenShop;

  @override
  State<NumerologyFormPage> createState() => _NumerologyFormPageState();
}

class _NumerologyFormPageState extends State<NumerologyFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  DateTime? _birthDate;
  String _analysisType = numerologyAnalysisTypes.first;
  var _submitting = false;

  static const _accent = Color(0xFFB8860B);

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Doğum tarihi seçin',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: faloraBronze,
              onPrimary: faloraParchmentRaised,
              surface: faloraParchmentCard,
              onSurface: faloraInk,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doğum tarihi seçin')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final first = _firstNameCtrl.text.trim();
      final last = _lastNameCtrl.text.trim();
      final baseName = last.isEmpty ? first : '$first $last';
      final fullName = '$baseName — $_analysisType';
      await widget.onSubmit(fullName, _birthDate!);
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
                  _DatePickerTile(
                    accent: _accent,
                    label: 'Doğum tarihi',
                    value: _birthDate == null
                        ? null
                        : formatBirthDate(_birthDate!),
                    onTap: _pickBirthDate,
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
  });

  final int tokenCost;
  final Future<void> Function(
    String sunSign,
    String moonSign,
    String focusArea,
  ) onSubmit;
  final VoidCallback onOpenShop;

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
    return TextFormField(
      controller: controller,
      textCapitalization: textCapitalization,
      style: const TextStyle(color: faloraTextPrimary, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: faloraTextSecondary.withValues(alpha: 0.85)),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      validator: validator,
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
