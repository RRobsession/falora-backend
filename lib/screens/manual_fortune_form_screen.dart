import 'package:falora/config/legal_config.dart';
import 'package:falora/config/category_fortune_config.dart';
import 'package:falora/config/manual_fortune_config.dart';
import 'package:falora/image_upload_card.dart';
import 'package:falora/models/fortune_models.dart';

import 'package:falora/models/manual_fortune_reader.dart';

import 'package:falora/picked_image.dart';

import 'package:falora/services/fortune_form_prefill.dart';
import 'package:falora/services/marital_status_preference.dart';
import 'package:falora/widgets/falora_labeled_form_field.dart';
import 'package:falora/theme/falora_theme.dart';

import 'package:falora/widgets/live_token_builder.dart';
import 'package:falora/widgets/manual_fortune_reader_avatar.dart';
import 'package:falora/services/manual_reader_quota_service.dart';

import 'package:falora/widgets/premium_ui.dart';

import 'package:flutter/material.dart';



typedef ManualFortuneSubmit = Future<void> Function({

  required FortuneCategory category,

  required ManualFortuneReader reader,

  required ManualFortuneOffer offer,

  required String name,

  required int age,

  required String zodiac,

  required String maritalStatus,

  required String intention,

  required List<String> questions,

  List<PickedImage>? images,

});



class ManualFortuneFormPage extends StatefulWidget {

  const ManualFortuneFormPage({

    super.key,

    required this.category,

    required this.reader,

    required this.offer,

    required this.onSubmit,

    required this.onOpenShop,

    this.prefill,

  });



  final FortuneCategory category;

  final ManualFortuneReader reader;

  final ManualFortuneOffer offer;

  final ManualFortuneSubmit onSubmit;

  final VoidCallback onOpenShop;

  final FortuneFormPrefill? prefill;



  @override

  State<ManualFortuneFormPage> createState() => _ManualFortuneFormPageState();

}



class _ManualFortuneFormPageState extends State<ManualFortuneFormPage> {

  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();

  final _ageCtrl = TextEditingController();

  final _niyetCtrl = TextEditingController();

  late final List<TextEditingController> _questionCtrls;

  String _burc = burclar.first;

  String _medeniDurum = MaritalStatusPreference.instance.current;

  PickedImage? _fincan1;

  PickedImage? _fincan2;

  PickedImage? _tabak;

  bool _submitting = false;



  ManualFortuneOffer get _offer => widget.offer;

  bool get _isKahve => widget.category == FortuneCategory.kahve;



  @override

  void initState() {

    super.initState();

    _questionCtrls =

        List.generate(_offer.questionLimit, (_) => TextEditingController());

    final prefill = widget.prefill;
    if (prefill != null && prefill.hasAny) {
      prefill.applyToNameController(_nameCtrl);
      prefill.applyToAgeController(_ageCtrl);
      _burc = prefill.applyToZodiac(_burc);
    }

    debugPrint('MANUAL QUESTION_LIMIT: ${_offer.questionLimit}');

    debugPrint('MANUAL PRICE SELECTED: ${_offer.priceLabel}');

  }



  @override

  void dispose() {

    _nameCtrl.dispose();

    _ageCtrl.dispose();

    _niyetCtrl.dispose();

    for (final c in _questionCtrls) {

      c.dispose();

    }

    super.dispose();

  }



  Future<void> _submit() async {

    if (_submitting || !_formKey.currentState!.validate()) return;

    if (!isManualReaderActiveNow) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(manualReaderInactiveInfo)),
      );
      return;
    }

    final quota = await ManualReaderQuotaService.instance.fetchToday();
    if (!mounted) return;
    if (!isManualReaderQuotaAvailable(quota.countFor(widget.reader.id))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(manualReaderQuotaFullInfo(widget.reader.name))),
      );
      return;
    }



    if (_isKahve && (_fincan1 == null || _fincan2 == null || _tabak == null)) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(

          content: Text(

            'Lütfen 2 fincan ve 1 tabak fotoğrafı yükleyin.',

          ),

        ),

      );

      return;

    }



    setState(() => _submitting = true);

    try {

      await widget.onSubmit(

        category: widget.category,

        reader: widget.reader,

        offer: _offer,

        name: _nameCtrl.text.trim(),

        age: int.parse(_ageCtrl.text.trim()),

        zodiac: _burc,

        maritalStatus: _medeniDurum,

        intention: _niyetCtrl.text.trim(),

        questions: _questionCtrls.map((c) => c.text.trim()).toList(),

        images: _isKahve

            ? [_fincan1!, _fincan2!, _tabak!]

            : null,

      );

    } finally {

      if (mounted) setState(() => _submitting = false);

    }

  }



  @override

  Widget build(BuildContext context) {

    final reader = widget.reader;

    final offer = _offer;

    return Scaffold(

      appBar: AppBar(title: Text('${reader.name} — ${widget.category.label}')),

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

              _ManualFormHeader(

                category: widget.category,

                reader: reader,

                offer: offer,

              ),

              const SizedBox(height: 16),

              Container(

                padding: const EdgeInsets.all(14),

                decoration: BoxDecoration(

                  color: reader.accentColor.withValues(alpha: 0.12),

                  borderRadius: BorderRadius.circular(14),

                  border: Border.all(

                    color: reader.accentColor.withValues(alpha: 0.28),

                  ),

                ),

                child: Text(

                  '${offer.priceLabel} · ${offer.questionLabel}\n'

                  '$manualReaderActiveHoursInfo\n'

                  'Özel yorumun en kısa sürede hazırlanacak.',

                  style: const TextStyle(

                    color: faloraTextSecondary,

                    fontSize: 13,

                    height: 1.45,

                  ),

                ),

              ),

              const SizedBox(height: 24),

              FaloraLabeledFormField(
                label: 'İsim',
                controller: _nameCtrl,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'İsim gerekli' : null,
              ),

              const SizedBox(height: 18),

              FaloraLabeledFormField(
                label: 'Yaş',
                controller: _ageCtrl,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Yaş gerekli';
                  final age = int.tryParse(v.trim());
                  return validateFortuneSubjectAge(age);
                },
              ),

              const SizedBox(height: 18),

              FaloraLabeledDropdown<String>(
                label: 'Burç',
                value: _burc,
                items: burclar
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (v) => setState(() => _burc = v ?? _burc),
              ),

              const SizedBox(height: 18),

              FaloraLabeledDropdown<String>(
                label: 'Medeni Durum',
                value: _medeniDurum,
                items: maritalStatusOptions
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) {
                  final next = v ?? _medeniDurum;
                  setState(() => _medeniDurum = next);
                  MaritalStatusPreference.instance.save(next);
                },
              ),

              const SizedBox(height: 18),

              FaloraLabeledFormField(
                label: offer.requiresIntention
                    ? 'Niyet / Konu *'
                    : 'Niyet / Konu (isteğe bağlı)',
                controller: _niyetCtrl,
                maxLines: 3,
                validator: (v) {
                  if (!offer.requiresIntention) return null;
                  if (v == null || v.trim().isEmpty) return 'Niyet gerekli';
                  return null;
                },
              ),

              const SizedBox(height: 24),

              Text(

                '${offer.questionLimit} Sorunuz',

                style: TextStyle(

                  color: reader.accentColor.withValues(alpha: 0.95),

                  fontWeight: FontWeight.w700,

                  fontSize: 15,

                ),

              ),

              const SizedBox(height: 12),

              for (var i = 0; i < offer.questionLimit; i++) ...[

                TextFormField(

                  controller: _questionCtrls[i],

                  decoration: InputDecoration(labelText: 'Soru ${i + 1}'),

                  maxLines: 2,

                  validator: (v) => (v == null || v.trim().isEmpty)

                      ? 'Soru ${i + 1} gerekli'

                      : null,

                ),

                const SizedBox(height: 12),

              ],

              if (_isKahve) ...[

                const SizedBox(height: 12),

                const Text(

                  'Kahve Falı Fotoğrafları',

                  style: TextStyle(

                    fontWeight: FontWeight.w600,

                    color: faloraTextPrimary,

                  ),

                ),

                const SizedBox(height: 12),

                ImageUploadCard(

                  label: 'Fincan 1',

                  image: _fincan1,

                  onChanged: (img) => setState(() => _fincan1 = img),

                ),

                const SizedBox(height: 12),

                ImageUploadCard(

                  label: 'Fincan 2',

                  image: _fincan2,

                  onChanged: (img) => setState(() => _fincan2 = img),

                ),

                const SizedBox(height: 12),

                ImageUploadCard(

                  label: 'Tabak',

                  image: _tabak,

                  onChanged: (img) => setState(() => _tabak = img),

                ),

              ],

              const SizedBox(height: 28),

              ScaleTap(

                onTap: _submitting ? null : _submit,

                child: Container(

                  padding: const EdgeInsets.symmetric(vertical: 15),

                  decoration: BoxDecoration(

                    borderRadius: BorderRadius.circular(14),

                    gradient: LinearGradient(

                      colors: [

                        reader.accentColor,

                        reader.accentColor.withValues(alpha: 0.75),

                      ],

                    ),

                  ),

                  alignment: Alignment.center,

                  child: _submitting

                      ? const SizedBox(

                          height: 22,

                          width: 22,

                          child: CircularProgressIndicator(

                            strokeWidth: 2,

                            color: Colors.white,

                          ),

                        )

                      : Text(
                          'Gönder (${offer.priceLabel})',

                          style: const TextStyle(

                            color: Colors.white,

                            fontWeight: FontWeight.w700,

                            fontSize: 14,

                          ),

                          textAlign: TextAlign.center,

                        ),

                ),

              ),

            ],

          ),

        ),

      ),

    );

  }

}



class _ManualFormHeader extends StatelessWidget {

  const _ManualFormHeader({

    required this.category,

    required this.reader,

    required this.offer,

  });



  final FortuneCategory category;

  final ManualFortuneReader reader;

  final ManualFortuneOffer offer;



  @override

  Widget build(BuildContext context) {

    return Row(

      children: [

        ManualFortuneReaderAvatar(reader: reader, size: 52),

        const SizedBox(width: 14),

        Expanded(

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Text(

                category.label,

                style: const TextStyle(

                  fontSize: 20,

                  fontWeight: FontWeight.bold,

                  color: faloraTextPrimary,

                ),

              ),

              const SizedBox(height: 4),

              Text(

                '${reader.name} · ${offer.priceLabel} · ${offer.questionLimit} soru',

                style: TextStyle(

                  fontSize: 13,

                  color: reader.accentColor.withValues(alpha: 0.95),

                  fontWeight: FontWeight.w600,

                ),

              ),

              const SizedBox(height: 2),

              Text(

                offer.intentionLabel,

                style: const TextStyle(

                  fontSize: 12,

                  color: faloraTextSecondary,

                ),

              ),

            ],

          ),

        ),

      ],

    );

  }

}

