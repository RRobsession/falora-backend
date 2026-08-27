import 'package:falora/image_upload_card.dart';
import 'package:falora/config/category_fortune_config.dart';
import 'package:falora/models/fortune_models.dart';
import 'package:falora/models/fortune_teller_models.dart';
import 'package:falora/picked_image.dart';
import 'package:falora/services/fortune_form_prefill.dart';
import 'package:falora/services/marital_status_preference.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/falora_labeled_form_field.dart';
import 'package:falora/widgets/live_token_builder.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

typedef PalmFortuneSubmit = Future<void> Function({
  required String name,
  required int age,
  required String zodiac,
  required String maritalStatus,
  required PickedImage rightHand,
  required PickedImage leftHand,
});

class PalmFortuneFormPage extends StatefulWidget {
  const PalmFortuneFormPage({
    super.key,
    required this.teller,
    required this.onSubmit,
    required this.onOpenShop,
    this.prefill,
  });

  final FortuneTeller teller;
  final PalmFortuneSubmit onSubmit;
  final VoidCallback onOpenShop;
  final FortuneFormPrefill? prefill;

  @override
  State<PalmFortuneFormPage> createState() => _PalmFortuneFormPageState();
}

class _PalmFortuneFormPageState extends State<PalmFortuneFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _zodiac = burclar.first;
  String _maritalStatus = MaritalStatusPreference.instance.current;
  PickedImage? _rightHand;
  PickedImage? _leftHand;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final prefill = widget.prefill;
    if (prefill != null && prefill.hasAny) {
      prefill.applyToNameController(_nameController);
      prefill.applyToAgeController(_ageController);
      _zodiac = prefill.applyToZodiac(_zodiac);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    if (_rightHand == null || _leftHand == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen sağ ve sol el fotoğraflarını ekleyin.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        name: _nameController.text.trim(),
        age: int.parse(_ageController.text.trim()),
        zodiac: _zodiac,
        maritalStatus: _maritalStatus,
        rightHand: _rightHand!,
        leftHand: _leftHand!,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('El Falı')),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FaloraLiveTappableTokenBalance(onOpenShop: widget.onOpenShop),
              const SizedBox(height: 12),
              Text(
                '${widget.teller.name} · ${widget.teller.title}',
                style: FaloraTypography.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Bilgilerini kontrol et, iki avucunun net fotoğrafını ekle.',
                style: FaloraTypography.bodyMedium,
              ),
              const SizedBox(height: 20),
              FaloraLabeledFormField(
                label: 'İsim',
                controller: _nameController,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'İsim gerekli'
                    : null,
              ),
              const SizedBox(height: 18),
              FaloraLabeledFormField(
                label: 'Yaş',
                controller: _ageController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  final age = int.tryParse(value?.trim() ?? '');
                  if (age == null || age < 13 || age > 120) {
                    return 'Geçerli bir yaş girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              FaloraLabeledDropdown<String>(
                label: 'Burç',
                value: _zodiac,
                items: burclar
                    .map((item) =>
                        DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _zodiac = value ?? _zodiac),
              ),
              const SizedBox(height: 18),
              FaloraLabeledDropdown<String>(
                label: 'Medeni Durum',
                value: _maritalStatus,
                items: maritalStatusOptions
                    .map((item) =>
                        DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
                onChanged: (value) {
                  final next = value ?? _maritalStatus;
                  setState(() => _maritalStatus = next);
                  MaritalStatusPreference.instance.save(next);
                },
              ),
              const SizedBox(height: 24),
              ImageUploadCard(
                label: 'Sağ El Fotoğrafı',
                allowCamera: true,
                image: _rightHand,
                icon: FontAwesomeIcons.hand,
                accentColor: const Color(0xFF9A6B62),
                onChanged: (image) => setState(() => _rightHand = image),
              ),
              const SizedBox(height: 12),
              ImageUploadCard(
                label: 'Sol El Fotoğrafı',
                allowCamera: true,
                image: _leftHand,
                icon: FontAwesomeIcons.hand,
                accentColor: const Color(0xFF9A6B62),
                onChanged: (image) => setState(() => _leftHand = image),
              ),
              const SizedBox(height: 8),
              Text(
                'Avuç içleri açık, iyi aydınlatılmış ve çizgiler net görünmeli.',
                style: FaloraTypography.bodyMedium.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 28),
              FaloraPrimaryButton(
                label: 'Falı Gönder',
                loading: _submitting,
                onPressed: _submitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
